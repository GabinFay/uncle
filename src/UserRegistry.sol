// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PackedBytesToField.sol"; // Import the library

/**
 * @title IWorldIdRouter
 * @dev Interface for the World ID Router contract.
 *      This is a simplified interface containing only the verifyProof function needed.
 */
interface IWorldIdRouter {
    /**
     * @dev Verifies a World ID proof. Reverts on failure.
     * @param root The Merkle tree root.
     * @param groupId The group ID (1 for Orb verifications).
     * @param signalHash The hash of the signal (e.g., user's address).
     * @param nullifierHash The unique nullifier hash for this proof.
     * @param externalNullifierHash The hash of the external nullifier (app_id + action_id).
     * @param proof The zero-knowledge proof.
     */
    function verifyProof(
        uint256 root,
        uint256 groupId,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256 externalNullifierHash,
        uint256[8] calldata proof
    ) external view;
}

/**
 * @title UserRegistry
 * @dev Manages user registration and links World ID to an Ethereum address.
 * This contract ensures that each on-chain identity (Ethereum address)
 * is associated with a unique, verified human (via World ID).
 */
contract UserRegistry {
    using PackedBytesToField for bytes; // Use the library for bytes type

    IWorldIdRouter public worldIdRouter;
    uint256 public immutable groupId; // Group ID for Orb verifications (typically 1)
    bytes32 public immutable appId; // Application specific ID
    bytes32 public immutable actionIdRegisterUser; // Action specific ID for user registration

    // Mapping from an Ethereum address to a World ID unique identifier (nullifier hash)
    mapping(address => uint256) public worldIdNullifiers;
    // Mapping from a World ID unique identifier (nullifier hash) to the registered Ethereum address
    mapping(uint256 => address) public registeredUsers;
    // Mapping to check if a World ID nullifier hash has already been registered
    mapping(uint256 => bool) public isNullifierRegistered;

    event UserRegistered(address indexed userAddress, uint256 indexed worldIdNullifier);
    event UserRemoved(address indexed userAddress, uint256 indexed worldIdNullifier);

    /**
     * @dev Constructor
     * @param _worldIdRouterAddress The address of the World ID Router contract.
     * @param _appIdString A string identifier for this application (e.g., "credease-v1").
     * @param _actionIdRegisterUserString A string identifier for the registration action (e.g., "register-user").
     */
    constructor(address _worldIdRouterAddress, string memory _appIdString, string memory _actionIdRegisterUserString) {
        require(_worldIdRouterAddress != address(0), "UserRegistry: Invalid World ID Router address");
        require(bytes(_appIdString).length > 0, "UserRegistry: App ID cannot be empty");
        require(bytes(_actionIdRegisterUserString).length > 0, "UserRegistry: Action ID cannot be empty");

        worldIdRouter = IWorldIdRouter(_worldIdRouterAddress);
        groupId = 1; // Standard group ID for Orb verifications
        appId = keccak256(abi.encodePacked(_appIdString));
        actionIdRegisterUser = keccak256(abi.encodePacked(_actionIdRegisterUserString));
    }

    /**
     * @dev Registers a new user, linking their Ethereum address to their World ID nullifier
     *      after verifying their World ID proof.
     * @param _userAddress The address of the user to register. This is used as the signal.
     * @param _root The Merkle tree root provided by World ID.
     * @param _nullifierHash The unique nullifier hash from World ID verification.
     * @param _proof The zero-knowledge proof from World ID.
     */
    function registerUser(
        address _userAddress,
        uint256 _root,
        uint256 _nullifierHash, // This is the actual nullifierHash from World ID
        uint256[8] calldata _proof
    ) public {
        require(_userAddress != address(0), "UserRegistry: Cannot register zero address");
        require(_nullifierHash != 0, "UserRegistry: World ID nullifier hash cannot be zero");
        require(!isNullifierRegistered[_nullifierHash], "UserRegistry: World ID nullifier hash already registered");
        require(worldIdNullifiers[_userAddress] == 0, "UserRegistry: Address already has a World ID registered");

        uint256 signalHash = abi.encodePacked(_userAddress).hashToField(); 
        uint256 externalNullifierHash = abi.encodePacked(appId, actionIdRegisterUser).hashToField();

        worldIdRouter.verifyProof(
            _root,
            groupId,
            signalHash,
            _nullifierHash,
            externalNullifierHash,
            _proof
        );

        worldIdNullifiers[_userAddress] = _nullifierHash;
        registeredUsers[_nullifierHash] = _userAddress;
        isNullifierRegistered[_nullifierHash] = true;

        emit UserRegistered(_userAddress, _nullifierHash);
    }

    /**
     * @dev Checks if a user (address) is registered with a World ID.
     * @param _userAddress The address to check.
     * @return True if the user is registered, false otherwise.
     */
    function isUserRegistered(address _userAddress) public view returns (bool) {
        return worldIdNullifiers[_userAddress] != 0;
    }

    /**
     * @dev Retrieves the World ID nullifier for a given registered address.
     * @param _userAddress The address of the user.
     * @return The World ID nullifier hash, or 0 if not registered.
     */
    function getWorldIdNullifier(address _userAddress) public view returns (uint256) {
        return worldIdNullifiers[_userAddress];
    }

    /**
     * @dev Retrieves the Ethereum address associated with a given World ID nullifier.
     * @param _worldIdNullifier The World ID nullifier hash.
     * @return The registered Ethereum address, or the zero address if not found.
     */
    function getAddressByNullifier(uint256 _worldIdNullifier) public view returns (address) {
        return registeredUsers[_worldIdNullifier];
    }

    /**
     * @dev Allows a registered user to remove their World ID association.
     * This might be necessary for privacy or if they want to re-link with a different address.
     * Consider the implications of this action on reputation systems.
     * IMPORTANT: This does NOT un-verify them from World ID itself, only from this contract's registry.
     * The nullifier hash cannot be reused with this contract's app_id/action_id combination
     * unless World ID supports nullifier hash resets for specific app/actions, which is unlikely.
     */
    function removeUser(address _userAddress) public {
        require(isUserRegistered(_userAddress), "UserRegistry: User not registered");
        
        uint256 nullifier = worldIdNullifiers[_userAddress];
        
        delete worldIdNullifiers[_userAddress];
        delete registeredUsers[nullifier];
        // We keep isNullifierRegistered[nullifier] = true to prevent re-registration with the same nullifier,
        // as per Sybil resistance principles for this app_id/action_id.
        // If true re-registration is desired after removal, this logic needs to change and World ID's
        // nullifier properties carefully considered. For now, removal is a one-way dissociation from this contract.

        emit UserRemoved(_userAddress, nullifier);
    }
} 