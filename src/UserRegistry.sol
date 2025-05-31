// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title UserRegistry
 * @dev Manages user registration and links World ID to an Ethereum address.
 * This contract ensures that each on-chain identity (Ethereum address)
 * is associated with a unique, verified human (via World ID).
 */
contract UserRegistry {
    // Mapping from an Ethereum address to a World ID unique identifier (e.g., nullifier hash)
    mapping(address => uint256) public worldIdNullifiers;
    // Mapping from a World ID unique identifier to the registered Ethereum address
    mapping(uint256 => address) public registeredUsers;
    // Mapping to check if a World ID nullifier hash has already been registered
    mapping(uint256 => bool) public isNullifierRegistered;

    event UserRegistered(address indexed userAddress, uint256 indexed worldIdNullifier);
    event UserRemoved(address indexed userAddress, uint256 indexed worldIdNullifier);

    /**
     * @dev Registers a new user, linking their Ethereum address to their World ID nullifier.
     * TODO: Implement actual World ID verification logic here.
     * This function should be callable only after a successful World ID verification proof.
     * For now, it's a placeholder.
     * @param _userAddress The address of the user to register.
     * @param _worldIdNullifier The unique nullifier hash from World ID verification.
     */
    function registerUser(address _userAddress, uint256 _worldIdNullifier) public {
        require(_userAddress != address(0), "UserRegistry: Cannot register zero address");
        require(_worldIdNullifier != 0, "UserRegistry: World ID nullifier cannot be zero");
        require(!isNullifierRegistered[_worldIdNullifier], "UserRegistry: World ID already registered");
        require(worldIdNullifiers[_userAddress] == 0, "UserRegistry: Address already has a World ID registered");

        worldIdNullifiers[_userAddress] = _worldIdNullifier;
        registeredUsers[_worldIdNullifier] = _userAddress;
        isNullifierRegistered[_worldIdNullifier] = true;

        emit UserRegistered(_userAddress, _worldIdNullifier);
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
     */
    function removeUser(address _userAddress) public {
        require(isUserRegistered(_userAddress), "UserRegistry: User not registered");
        
        uint256 nullifier = worldIdNullifiers[_userAddress];
        
        delete worldIdNullifiers[_userAddress];
        delete registeredUsers[nullifier];
        isNullifierRegistered[nullifier] = false;

        emit UserRemoved(_userAddress, nullifier);
    }
} 