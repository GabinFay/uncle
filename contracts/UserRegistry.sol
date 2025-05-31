// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UserRegistry
 * @dev Manages user registration and core identity attributes.
 * Users are verified via World ID (off-chain verification by backend, then recorded here).
 */
contract UserRegistry is Ownable {
    struct UserProfile {
        bool isWorldIdVerified;
        bytes32 worldIdNullifierHash; // Store hash of nullifier for privacy
        uint256 reputationScore; // Managed by ReputationOApp, potentially mirrored or linked
        string filecoinDataPointer; // e.g., Deal ID or CID
        // Add other relevant profile data as needed
    }

    mapping(address => UserProfile) public userProfiles;
    mapping(bytes32 => address) public worldIdNullifierToAddress; // To ensure one World ID per address

    event UserRegistered(address indexed userAddress, bytes32 indexed worldIdNullifierHash);
    event UserProfileUpdated(address indexed userAddress);

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Registers a new user or updates existing if World ID nullifier matches.
     * Only callable by the owner (backend service) after off-chain World ID proof verification.
     * @param userAddress The address of the user to register.
     * @param worldIdNullifierHash_ The hash of the user's World ID nullifier.
     */
    function registerOrUpdateUser(address userAddress, bytes32 worldIdNullifierHash_) external onlyOwner {
        require(userAddress != address(0), "UserRegistry: Invalid user address");
        require(worldIdNullifierHash_ != bytes32(0), "UserRegistry: Invalid World ID nullifier hash");

        // Check if this World ID nullifier is already registered to a different address
        if (worldIdNullifierToAddress[worldIdNullifierHash_] != address(0) &&
            worldIdNullifierToAddress[worldIdNullifierHash_] != userAddress) {
            revert("UserRegistry: World ID already registered to another address");
        }

        // Check if this address is already registered with a different World ID nullifier
        if (userProfiles[userAddress].isWorldIdVerified &&
            userProfiles[userAddress].worldIdNullifierHash != worldIdNullifierHash_) {
            revert("UserRegistry: Address already registered with a different World ID");
        }

        userProfiles[userAddress].isWorldIdVerified = true;
        userProfiles[userAddress].worldIdNullifierHash = worldIdNullifierHash_;
        worldIdNullifierToAddress[worldIdNullifierHash_] = userAddress;

        emit UserRegistered(userAddress, worldIdNullifierHash_);
    }

    /**
     * @dev Checks if a user is World ID verified.
     * @param userAddress The address of the user.
     * @return True if the user is World ID verified, false otherwise.
     */
    function isUserWorldIdVerified(address userAddress) external view returns (bool) {
        return userProfiles[userAddress].isWorldIdVerified;
    }

    /**
     * @dev Gets the profile of a user.
     * @param userAddress The address of the user.
     * @return The UserProfile struct.
     */
    function getUserProfile(address userAddress) external view returns (UserProfile memory) {
        return userProfiles[userAddress];
    }

    /**
     * @dev Updates the Filecoin data pointer for a user.
     * Only callable by the owner (backend service).
     * @param userAddress The address of the user.
     * @param filecoinDataPointer_ The new Filecoin data pointer.
     */
    function updateFilecoinDataPointer(address userAddress, string calldata filecoinDataPointer_) external onlyOwner {
        require(userProfiles[userAddress].isWorldIdVerified, "UserRegistry: User not registered/verified");
        userProfiles[userAddress].filecoinDataPointer = filecoinDataPointer_;
        emit UserProfileUpdated(userAddress);
    }

    /**
     * @dev Updates the reputation score for a user.
     * Typically called by the ReputationOApp contract or a trusted backend service.
     * For now, making it onlyOwner for simplicity until ReputationOApp is integrated.
     * @param userAddress The address of the user.
     * @param newReputationScore The new reputation score.
     */
    function updateReputationScore(address userAddress, uint256 newReputationScore) external onlyOwner { // TODO: Change access control
        require(userProfiles[userAddress].isWorldIdVerified, "UserRegistry: User not registered/verified");
        userProfiles[userAddress].reputationScore = newReputationScore;
        emit UserProfileUpdated(userAddress);
    }
} 