// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ReputationReader.sol";
import "../src/interfaces/LayerZero.sol";
import "../src/Reputation.sol"; // For Reputation.ReputationProfile
import "./mocks/MockLayerZeroEndpoint.sol";
import "./mocks/MockReadCodec.sol";

contract ReputationReaderTest is Test {
    ReputationReader public reputationReader;
    MockLayerZeroEndpoint public mockEndpoint;
    MockReadCodec public mockReadCodec;

    address owner;
    address userToQuery = vm.addr(1);
    address reputationContractOnTargetChain = vm.addr(2);
    uint32 targetChainEid = 102; // Example EID of the target chain
    uint16 lzReadChannelId = 1;  // Example lzRead channel ID

    function setUp() public {
        owner = address(this);
        mockEndpoint = new MockLayerZeroEndpoint();
        mockReadCodec = new MockReadCodec();
        reputationReader = new ReputationReader(address(mockEndpoint), address(mockReadCodec), owner);
    }

    function test_Constructor_SetsAddresses() public {
        assertEq(address(reputationReader.endpoint()), address(mockEndpoint));
        assertEq(address(reputationReader.readCodec()), address(mockReadCodec));
        assertEq(reputationReader.owner(), owner, "Owner mismatch");
    }

    function test_RequestReputation_CallsEncodeAndSend() public {
        // --- Setup expected EVMCallRequestV1 ----
        EVMCallRequestV1[] memory expectedRequests = new EVMCallRequestV1[](1);
        uint64 fixedTimestamp = uint64(block.timestamp); // Capture current timestamp
        vm.warp(fixedTimestamp + 60); // Ensure block.timestamp in contract call is fixedTimestamp + 60

        expectedRequests[0] = EVMCallRequestV1({
            appRequestLabel: 0,
            targetEid: targetChainEid,
            isBlockNum: false,
            blockNumOrTimestamp: fixedTimestamp, // Expected to be (current test time + 60) - 60 = current test time
            confirmations: 15,
            to: reputationContractOnTargetChain,
            callData: abi.encodeWithSelector(Reputation.getReputationProfile.selector, userToQuery)
        });
        bytes memory expectedEncodedRequests = abi.encode(expectedRequests);
        bytes memory mockEncodedMessage = hex"c0ffee";
        mockReadCodec.setMockEncodedResult(mockEncodedMessage);

        // --- Options for send ---
        bytes memory expectedOptions = abi.encodePacked(uint256(200000));
        bytes32 expectedReceiverBytes32 = bytes32(uint256(uint160(address(reputationReader))));

        // --- Perform the call ---
        uint256 fee = 1 ether; // Example fee
        vm.deal(owner, fee); // Ensure owner has balance to send msg.value
        
        vm.prank(owner);
        reputationReader.requestReputation{value: fee}(
            targetChainEid,
            reputationContractOnTargetChain,
            userToQuery,
            lzReadChannelId
        );
        vm.warp(block.timestamp); // Reset warp to current block.timestamp after the call if needed, though not strictly for this test's assertions.

        // --- Assertions ---
        assertEq(mockReadCodec.getLastEncodedRequestsInputBytes(), expectedEncodedRequests, "Encoded requests mismatch");
        assertEq(mockReadCodec.lastRequestsEncoded_inputCompute(), bytes(""), "Compute settings mismatch");
        assertEq(mockEndpoint.lastDstChainIdSent(), lzReadChannelId, "LZ Endpoint: DstChainId (ChannelId) mismatch");
        assertEq(mockEndpoint.lastReceiverSent(), expectedReceiverBytes32, "LZ Endpoint: Receiver mismatch");
        assertEq(mockEndpoint.lastMessageSent(), mockEncodedMessage, "LZ Endpoint: Message mismatch");
        assertEq(mockEndpoint.lastOptionsSent(), expectedOptions, "LZ Endpoint: Options mismatch");
        assertEq(mockEndpoint.lastRefundAddressSent(), owner, "LZ Endpoint: Refund address mismatch");
        assertEq(mockEndpoint.lastZroPaymentAddressSent(), address(0), "LZ Endpoint: ZRO Payment address mismatch");
        assertEq(mockEndpoint.lastAdapterParamsSent(), bytes(""), "LZ Endpoint: Adapter params mismatch");
        assertEq(mockEndpoint.lastValueSent(), fee, "LZ Endpoint: Value sent mismatch");
        assertEq(reputationReader.lastQueriedUser(), userToQuery, "Last queried user mismatch");
    }

    function test_LzReceive_Success() public {
        Reputation.ReputationProfile memory mockProfile = Reputation.ReputationProfile({
            userAddress: userToQuery,
            loansTaken: 5,
            loansGiven: 0,
            loansRepaidOnTime: 4,
            loansDefaulted: 1,
            totalValueBorrowed: 1000 * 1e18,
            totalValueLent: 0,
            currentReputationScore: 150,
            vouchingStakeAmount: 0,
            timesVouchedForOthers: 0,
            timesDefaultedAsVoucher: 0
        });
        bytes memory payload = abi.encode(mockProfile);

        vm.prank(owner);
        reputationReader.setLastQueriedUser_testOnly(userToQuery);

        uint16 srcChainId = 101;
        bytes memory srcAddress = abi.encodePacked(address(reputationReader));
        uint64 nonce = 123;

        vm.prank(address(mockEndpoint));
        // Expect the ReputationReceived event from the reputationReader contract
        // Check indexed user (topic1) and data part (newScore, payload)
        vm.expectEmit(true, false, false, true, address(reputationReader));
        emit ReputationReader.ReputationReceived(userToQuery, mockProfile.currentReputationScore, payload);

        reputationReader.lzReceive(srcChainId, srcAddress, nonce, payload);

        // Use the new getter
        Reputation.ReputationProfile memory receivedProfile = reputationReader.getFetchedReputationProfile(userToQuery);
        assertEq(receivedProfile.userAddress, mockProfile.userAddress, "userAddress mismatch");
        assertEq(receivedProfile.loansTaken, mockProfile.loansTaken, "loansTaken mismatch");
        assertEq(receivedProfile.currentReputationScore, mockProfile.currentReputationScore, "currentReputationScore mismatch");
    }

    function test_LzReceive_RevertIfNotEndpoint() public {
        bytes memory dummyPayload = abi.encode("test");
        vm.expectRevert("lzReceive: Invalid caller (not LZ endpoint)");
        reputationReader.lzReceive(101, abi.encodePacked(address(this)), 1, dummyPayload);
    }
} 