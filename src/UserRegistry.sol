// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UserRegistry
 * @author CreditInclusion Team
 * @notice Manages user registration, World ID verification status, and basic profile data.
 * @dev Verification of World ID is assumed to be done off-chain by a trusted backend (owner),
 * which then calls `registerOrUpdateUser` to record the verification status on-chain.
 */
contract UserRegistry is Ownable {
    /**
     * @notice Represents a user's profile data.
     * @param isWorldIdVerified True if the user has been verified with World ID.
     * @param worldIdNullifierHash The unique nullifier hash from World ID, ensuring privacy and uniqueness.
     * @param reputationScore A general reputation score, potentially aggregated or a summary.
     * @param filecoinDataPointer A pointer to user-related data stored on Filecoin (e.g., a CID or Deal ID).
     */
    struct UserProfile {
        bool isWorldIdVerified;
        bytes32 worldIdNullifierHash; // Store hash of nullifier for privacy
        uint256 reputationScore; // Managed by ReputationOApp, potentially mirrored or linked
        string filecoinDataPointer; // e.g., Deal ID or CID
        // Add other relevant profile data as needed
    }

    /**
     * @notice Maps a user's address to their profile.
     */
    mapping(address => UserProfile) public userProfiles;

    /**
     * @notice Maps a World ID nullifier hash to the user address it's registered with.
     * @dev Used to ensure a single World ID nullifier is not registered to multiple addresses.
     */
    mapping(bytes32 => address) public worldIdNullifierToAddress; // To ensure one World ID per address

    /**
     * @notice Emitted when a new user is registered or their World ID nullifier is updated.
     * @param userAddress The address of the registered/updated user.
     * @param worldIdNullifierHash The user's World ID nullifier hash.
     */
    event UserRegistered(address indexed userAddress, bytes32 indexed worldIdNullifierHash);

    /**
     * @notice Emitted when any part of a user's profile (excluding initial registration details) is updated.
     * @param userAddress The address of the user whose profile was updated.
     */
    event UserProfileUpdated(address indexed userAddress);

    /**
     * @notice Contract constructor.
     * @dev Initializes the contract and sets the deployer as the initial owner.
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @notice Registers a new user or updates an existing user's World ID nullifier.
     * @dev This function is `onlyOwner` and is intended to be called by a trusted backend service
     * after successful off-chain verification of the user's World ID.
     * It prevents registering the same nullifier to multiple addresses or the same address with multiple nullifiers.
     * @param userAddress The Ethereum address of the user.
     * @param worldIdNullifierHash_ The World ID nullifier hash for the user.
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
     * @notice Checks if a user has been verified with World ID.
     * @param userAddress The address of the user to check.
     * @return isVerified True if the user is World ID verified, false otherwise.
     */
    function isUserWorldIdVerified(address userAddress) external view returns (bool isVerified) {
        return userProfiles[userAddress].isWorldIdVerified;
    }

    /**
     * @notice Retrieves the profile data for a given user address.
     * @param userAddress The address of the user.
     * @return profile The UserProfile struct for the specified user.
     */
    function getUserProfile(address userAddress) external view returns (UserProfile memory profile) {
        return userProfiles[userAddress];
    }

    /**
     * @notice Updates the Filecoin data pointer associated with a user's profile.
     * @dev This function is `onlyOwner`, intended for backend updates.
     * Requires the user to be already registered and World ID verified.
     * @param userAddress The address of the user.
     * @param filecoinDataPointer_ The new Filecoin data pointer string (e.g., CID, Deal ID).
     */
    function updateFilecoinDataPointer(address userAddress, string calldata filecoinDataPointer_) external onlyOwner {
        require(userProfiles[userAddress].isWorldIdVerified, "UserRegistry: User not registered/verified");
        userProfiles[userAddress].filecoinDataPointer = filecoinDataPointer_;
        emit UserProfileUpdated(userAddress);
    }

    /**
     * @notice Updates the general reputation score for a user in their profile.
     * @dev This function is `onlyOwner`. Could be transitioned to be called by a dedicated Reputation contract/OApp.
     * Requires the user to be already registered and World ID verified.
     * The main reputation logic and detailed scores are expected to be in a separate `Reputation.sol` contract.
     * @param userAddress The address of the user.
     * @param newReputationScore The new general reputation score for the user.
     */
    function updateReputationScore(address userAddress, uint256 newReputationScore) external onlyOwner { // TODO: Change access control
        require(userProfiles[userAddress].isWorldIdVerified, "UserRegistry: User not registered/verified");
        userProfiles[userAddress].reputationScore = newReputationScore;
        emit UserProfileUpdated(userAddress);
    }
} 