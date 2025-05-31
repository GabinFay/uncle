// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/LayerZero.sol";
import "./Reputation.sol"; // For ReputationProfile struct
import "./UserRegistry.sol"; // For IWorldIdRouter, PackedBytesToField, needed by Reputation.sol if it were standalone
                             // but Reputation.sol itself does not directly use them beyond UserRegistry calls.
                             // We only need Reputation.ReputationProfile here.
import "@openzeppelin/contracts/access/Ownable.sol"; // Import Ownable

// A simple OApp to read reputation from another chain using LayerZero lzRead
contract ReputationReader is ILayerZeroReceiver, Ownable { // Inherit Ownable
    ILayerZeroEndpointV2 public immutable endpoint;
    IReadCodecV1 public immutable readCodec; // Address of the ReadCodecV1 contract

    // Changed to internal and added a getter
    mapping(address => Reputation.ReputationProfile) internal _fetchedReputations;
    // Store the last request details to correlate with lzReceive (simplified)
    address public lastQueriedUser;
    uint64 public lastNonceSent; // To potentially match with lzReceive, though lzReceive nonce is from source.
                                 // A more robust system would map nonces or request IDs.

    event ReputationRequested(address indexed user, uint32 indexed destinationEid, address reputationContract);
    event ReputationReceived(address indexed user, int256 newScore, bytes payload);
    event LzReceiveCalled(uint16 srcChainId, bytes srcAddress, uint64 nonce, uint256 payloadLength);

    // Constructor
    constructor(address _endpointAddress, address _readCodecAddress, address initialOwner) Ownable(initialOwner) { // Pass initialOwner to Ownable constructor
        require(_endpointAddress != address(0), "Invalid endpoint");
        require(_readCodecAddress != address(0), "Invalid read codec");
        endpoint = ILayerZeroEndpointV2(_endpointAddress);
        readCodec = IReadCodecV1(_readCodecAddress);
    }

    /**
     * @dev Requests the reputation profile for a user from a Reputation contract on another chain.
     * @param _targetEid LayerZero Endpoint ID of the chain where Reputation.sol is deployed.
     * @param _reputationContractAddress Address of the Reputation.sol contract on the target chain.
     * @param _userWhoseReputationToGet Address of the user whose reputation is being queried.
     * @param _lzReadChannelId The LayerZero channel ID configured for lzRead for this path.
     */
    function requestReputation(
        uint32 _targetEid, // Eid of the chain where Reputation.sol is
        address _reputationContractAddress,
        address _userWhoseReputationToGet,
        uint16 _lzReadChannelId // This is the _dstChainId for endpoint.send when using lzRead
    ) external payable { // payable to cover LayerZero fees
        // 1. Construct EVMCallRequestV1
        EVMCallRequestV1[] memory requests = new EVMCallRequestV1[](1);
        requests[0] = EVMCallRequestV1({
            appRequestLabel: 0,
            targetEid: _targetEid,
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp - 60),
            confirmations: 15,
            to: _reputationContractAddress,
            callData: abi.encodeWithSelector(Reputation.getReputationProfile.selector, _userWhoseReputationToGet)
        });

        // 2. Encode the request(s) using ReadCodecV1
        // _compute settings are bytes("") for simple reads without off-chain computation for now
        bytes memory message = readCodec.encode(0, requests, bytes(""));

        // 3. Send the message via LayerZero Endpoint
        // Options for gas payment (example: 200k gas for lzReceive execution on this chain)
        // This needs to be carefully estimated and configured based on LayerZero docs for the specific path.
        bytes memory options = abi.encodePacked(uint256(200000)); // Simple options, likely needs more complex builder
        
        // Receiver address on this chain (itself), packed to bytes32
        bytes32 receiverBytes32 = bytes32(uint256(uint160(address(this))));

        // Adapter params - usually for specific DVN configurations or advanced features
        bytes memory adapterParams = bytes(""); 

        // Store for simplified correlation - in a real app, manage multiple requests
        lastQueriedUser = _userWhoseReputationToGet;
        // lastNonceSent = endpoint.send(...); // Cannot get nonce before send easily

        endpoint.send{
            value: msg.value // LZ fee provided by caller
        }(
            _lzReadChannelId,       // For lzRead, this is the channelId, not destination EID
            receiverBytes32,        // This contract is the receiver of the lzRead response
            message,                // The encoded lzRead command
            options,                // Execution options (gas for lzReceive)
            payable(msg.sender),    // Refund address
            address(0),             // ZRO payment address (native gas payment)
            adapterParams           // Adapter parameters
        );

        emit ReputationRequested(_userWhoseReputationToGet, _targetEid, _reputationContractAddress);
    }

    /**
     * @dev Callback function for LayerZero to deliver messages (including lzRead responses).
     */
    function lzReceive(
        uint16 _srcChainId,    // Source chain (where the lzRead request was sent, i.e., this chain's EID for response)
        bytes calldata _srcAddress, // Address of the sender (OApp on the source chain, i.e. this contract for response)
        uint64 _nonce,         // Message nonce
        bytes calldata _payload // The ABI-encoded Reputation.ReputationProfile struct
    ) external override {
        emit LzReceiveCalled(_srcChainId, _srcAddress, _nonce, _payload.length);

        require(msg.sender == address(endpoint), "lzReceive: Invalid caller (not LZ endpoint)");
        // Additional check: ensure _srcAddress is this contract for lzRead responses
        // bytes32 thisContractBytes32 = bytes32(uint256(uint160(address(this))));
        // require(keccak256(_srcAddress) == keccak256(abi.encodePacked(thisContractBytes32)), "lzReceive: Response not for this contract");
        // Note: _srcChainId in lzReceive for an lzRead response *should* be the original requesting chain (this chain).
        // The _srcAddress should be this contract itself if the read is executed correctly by DVN and returned.

        // Decode the payload. For lzRead, the payload is the direct result of the eth_call(s).
        // Assuming the payload is (bool success, bytes memory returnData) from a single eth_call.
        // For a simple view function call like getReputationProfile, it should be just the abi.encoded struct.
        // This part needs to be aligned with exact lzRead response format.
        // If it's just the raw struct: 
        if (_payload.length > 0) {
            (Reputation.ReputationProfile memory profile) = abi.decode(_payload, (Reputation.ReputationProfile));
            
            // Use the lastQueriedUser for simplicity; a robust solution needs better request tracking.
            address user = lastQueriedUser; 
            _fetchedReputations[user] = profile;
            emit ReputationReceived(user, profile.currentReputationScore, _payload);
        } else {
            // Handle potential error or empty payload if the read failed on the DVN side
            // For now, just emit that we got an empty payload
            emit ReputationReceived(lastQueriedUser, -99999, _payload); // Indicate error with a sentinel score
        }
    }

    // Getter for the internal mapping
    function getFetchedReputationProfile(address user) external view returns (Reputation.ReputationProfile memory) {
        return _fetchedReputations[user];
    }

    // Test-only function to set lastQueriedUser
    function setLastQueriedUser_testOnly(address _user) external onlyOwner {
        lastQueriedUser = _user;
    }
} 