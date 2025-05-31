// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interfaces/LayerZero.sol";

contract MockReadCodec is IReadCodecV1 {
    bytes public lastRequestsEncoded_inputRequests; // To store the EVMCallRequestV1[] as bytes
    bytes public lastRequestsEncoded_inputCompute;
    bytes public mockEncodedResult = hex"deadbeef"; // Default mock result

    event Encoded(bytes requestsAsBytes, bytes compute);

    function encode(
        uint256, // options - ignored in mock
        EVMCallRequestV1[] memory _requests,
        bytes memory _compute
    ) external override returns (bytes memory) { // Changed to external (no mutability keyword)
        // For simplicity in checking, we abi.encode the array of structs.
        // In a real scenario, the test would compare struct fields if needed.
        lastRequestsEncoded_inputRequests = abi.encode(_requests); 
        lastRequestsEncoded_inputCompute = _compute;
        emit Encoded(lastRequestsEncoded_inputRequests, _compute);
        return mockEncodedResult;
    }

    // --- Test Admin Functions ---
    function setMockEncodedResult(bytes memory _newResult) external {
        mockEncodedResult = _newResult;
    }

    // Helper to get the last input requests for assertion (if needed to decode outside)
    function getLastEncodedRequestsInputBytes() external view returns (bytes memory) {
        return lastRequestsEncoded_inputRequests;
    }
} 