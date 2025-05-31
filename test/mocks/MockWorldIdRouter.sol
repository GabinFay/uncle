// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/UserRegistry.sol"; // To get IWorldIdRouter definition

contract MockWorldIdRouter is IWorldIdRouter {
    bool public shouldProofSucceed = true;
    string public revertMessage = "MockWorldIdRouter: Proof verification failed";

    mapping(uint256 => bool) public verifiedNullifiers; // Track for testing purposes

    function verifyProof(
        uint256, // root - not checked in mock
        uint256, // groupId - not checked in mock
        uint256, // signalHash - not checked in mock
        uint256 nullifierHash, // used by mock
        uint256, // externalNullifierHash - not checked in mock
        uint256[8] calldata // proof - not checked in mock
    ) external view override {
        if (!shouldProofSucceed) {
            revert(revertMessage);
        }
        // In a real scenario, the World ID contract would handle nullifier uniqueness
        // for its own scope. This mock doesn't need to enforce that, as UserRegistry does.
        // We can simulate that this specific proof (with this nullifierHash) passed for test inspection.
        // Note: this mapping is on the mock, not representing World ID's internal state.
        // verifiedNullifiers[nullifierHash] = true; // Cannot do this in a view function
    }

    // --- Admin functions for test setup ---
    function setShouldProofSucceed(bool _succeed) external {
        shouldProofSucceed = _succeed;
    }

    function setRevertMessage(string memory _message) external {
        revertMessage = _message;
    }
} 