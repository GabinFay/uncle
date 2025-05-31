// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interfaces/LayerZero.sol";

contract MockLayerZeroEndpoint is ILayerZeroEndpointV2 {
    uint32 public currentEid = 101; // Example EID for this mock endpoint
    bytes public lastMessageSent;
    uint16 public lastDstChainIdSent;
    bytes32 public lastReceiverSent;
    bytes public lastOptionsSent;
    address public lastRefundAddressSent;
    address public lastZroPaymentAddressSent;
    bytes public lastAdapterParamsSent;
    uint256 public lastValueSent;

    event MessageSent(
        uint16 dstChainId,
        bytes32 receiver,
        bytes message,
        bytes options,
        address refundAddress,
        address zroPaymentAddress,
        bytes adapterParams,
        uint256 value
    );

    function eid() external view override returns (uint32) {
        return currentEid;
    }

    function send(
        uint16 _dstChainId,
        bytes32 _receiver,
        bytes calldata _message,
        bytes calldata _options,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable override {
        lastDstChainIdSent = _dstChainId;
        lastReceiverSent = _receiver;
        lastMessageSent = _message;
        lastOptionsSent = _options;
        lastRefundAddressSent = _refundAddress;
        lastZroPaymentAddressSent = _zroPaymentAddress;
        lastAdapterParamsSent = _adapterParams;
        lastValueSent = msg.value;
        emit MessageSent(_dstChainId, _receiver, _message, _options, _refundAddress, _zroPaymentAddress, _adapterParams, msg.value);
    }

    // --- Test Admin Functions ---
    function setCurrentEid(uint32 _newEid) external {
        currentEid = _newEid;
    }
} 