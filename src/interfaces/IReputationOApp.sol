// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

// Minimal interface for a LayerZero OApp for reputation
// This would typically interact with ILayerZeroEndpointV2 or a similar messaging layer.
interface IReputationOApp is IERC165 {
    // Example LayerZero related function (simplified)
    // In a real OApp, you'd interact with LayerZeroEndpointV2.sol functions like send(), etc.
    // function estimateFees(uint32 _dstChainId, bytes calldata _toAddress, bytes calldata _payload, bool _useZro, bytes calldata _adapterParams) external view returns (uint nativeFee, uint zroFee);

    /**
     * @notice Updates a user's reputation on a remote chain (or locally if this is the destination).
     * @param user The address of the user whose reputation is to be updated.
     * @param reputationChange The change in reputation score (can be positive or negative).
     * @param sourceChainId The LayerZero chain ID from which this update originated (if applicable).
     */
    function updateReputation(address user, int256 reputationChange, uint32 sourceChainId) external; // Or payable if it involves fees

    /**
     * @notice Gets a user's current reputation score.
     * @param user The address of the user.
     * @return The current reputation score.
     */
    function getReputation(address user) external view returns (int256);

    // Potentially other functions like:
    // function sendReputationUpdate(uint32 _dstChainId, address _user, int256 _reputationChange, bytes calldata _adapterParams) external payable;
} 