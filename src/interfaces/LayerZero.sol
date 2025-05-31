// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Placeholder for LayerZero V2 EVM Call Request Struct
struct EVMCallRequestV1 {
    uint16 appRequestLabel; // Application-specific label for the request
    uint32 targetEid;       // Target chain LayerZero Endpoint ID
    bool isBlockNum;        // True if blockNumOrTimestamp is a block number, false if timestamp
    uint64 blockNumOrTimestamp; // Block number or timestamp for the read
    uint64 confirmations;   // Required confirmations on the target chain
    address to;             // Address of the contract to call on the target chain
    bytes callData;         // ABI-encoded calldata for the function to call
}

// Placeholder for LayerZero V2 Read Codec
interface IReadCodecV1 {
    function encode(
        uint256, // options - typically 0 for default
        EVMCallRequestV1[] memory _requests,
        bytes memory _compute // Placeholder for compute settings, pass empty bytes for now
    ) external returns (bytes memory);
}

// Placeholder for LayerZero V2 Endpoint Interface
interface ILayerZeroEndpointV2 {
    function eid() external view returns (uint32);

    function send(
        uint16 _dstChainId, // Note: In V2, this is often the _dstEid (endpoint ID)
        bytes32 _receiver,   // recipient address on the destination chain
        bytes calldata _message,
        bytes calldata _options, // options for the send (e.g., for gas payment)
        address payable _refundAddress, // address to refund leftover gas
        address _zroPaymentAddress, // address to pay ZRO fees, address(0) for native
        bytes calldata _adapterParams // adapter specific parameters
    ) external payable;

    // A more specific send signature for lzRead might exist, 
    // or options configure it for read. Using a general one for now.
    // From lzRead overview: "OApp sends a lzRead command by calling EndpointV2.send() with a read-specific eid argument called a channel identifier"
    // This suggests the _dstChainId might be a channelId for lzRead.
}

// Placeholder for LayerZero Receiver Interface (standard)
interface ILayerZeroReceiver {
    function lzReceive(
        uint16 _srcChainId,    // Source chain LayerZero Endpoint ID
        bytes calldata _srcAddress, // Address of the sender on the source chain (OApp address)
        uint64 _nonce,         // Message nonce
        bytes calldata _payload // Message payload (the data read)
    ) external;
} 