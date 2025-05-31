// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UserRegistry.sol";

contract UserRegistryTest is Test {
    UserRegistry public userRegistry;
    address user1 = address(0x1);
    address user2 = address(0x2);
    uint256 worldIdNullifier1 = 12345; // Using uint256 as in UserRegistry.sol
    uint256 worldIdNullifier2 = 67890; // Using uint256

    function setUp() public {
        userRegistry = new UserRegistry();
    }

    function testRegisterNewUser() public {
        userRegistry.registerUser(user1, worldIdNullifier1);
        assertTrue(userRegistry.isUserRegistered(user1), "User should be registered");
        assertEq(userRegistry.getWorldIdNullifier(user1), worldIdNullifier1, "World ID nullifier mismatch for user1");
        assertEq(userRegistry.getAddressByNullifier(worldIdNullifier1), user1, "Nullifier to address mapping mismatch for nullifier1");
        assertTrue(userRegistry.isNullifierRegistered(worldIdNullifier1), "Nullifier should be marked as registered");
    }

    function test_RevertIf_RegisterWithZeroAddress() public {
        vm.expectRevert("UserRegistry: Cannot register zero address");
        userRegistry.registerUser(address(0), worldIdNullifier1);
    }

    function test_RevertIf_RegisterWithZeroNullifier() public {
        vm.expectRevert("UserRegistry: World ID nullifier cannot be zero");
        userRegistry.registerUser(user1, 0);
    }

    function test_RevertIf_RegisterExistingNullifierToDifferentAddress() public {
        userRegistry.registerUser(user1, worldIdNullifier1);
        vm.expectRevert("UserRegistry: World ID already registered");
        userRegistry.registerUser(user2, worldIdNullifier1); // Attempt to register same nullifier to user2
    }

    function test_RevertIf_RegisterExistingAddressToDifferentNullifier() public {
        userRegistry.registerUser(user1, worldIdNullifier1);
        vm.expectRevert("UserRegistry: Address already has a World ID registered");
        userRegistry.registerUser(user1, worldIdNullifier2); // Attempt to register user1 with a new nullifier
    }

    function testRegisterMultipleUsers() public {
        userRegistry.registerUser(user1, worldIdNullifier1);
        userRegistry.registerUser(user2, worldIdNullifier2);

        assertTrue(userRegistry.isUserRegistered(user1), "User1 should be registered");
        assertEq(userRegistry.getWorldIdNullifier(user1), worldIdNullifier1, "Nullifier for user1 mismatch");
        
        assertTrue(userRegistry.isUserRegistered(user2), "User2 should be registered");
        assertEq(userRegistry.getWorldIdNullifier(user2), worldIdNullifier2, "Nullifier for user2 mismatch");

        assertEq(userRegistry.getAddressByNullifier(worldIdNullifier1), user1, "Address for nullifier1 mismatch");
        assertEq(userRegistry.getAddressByNullifier(worldIdNullifier2), user2, "Address for nullifier2 mismatch");
    }
    
    function testIsUserRegistered_NotRegistered() public {
        assertFalse(userRegistry.isUserRegistered(user1), "User should not be registered initially");
    }

    function testGetWorldIdNullifier_NotRegistered() public {
        assertEq(userRegistry.getWorldIdNullifier(user1), 0, "Should return 0 for non-registered user");
    }

    function testGetAddressByNullifier_NotRegistered() public {
        assertEq(userRegistry.getAddressByNullifier(worldIdNullifier1), address(0), "Should return address(0) for non-registered nullifier");
    }

    function testRemoveUser() public {
        userRegistry.registerUser(user1, worldIdNullifier1);
        assertTrue(userRegistry.isUserRegistered(user1), "User should be registered before removal");
        assertTrue(userRegistry.isNullifierRegistered(worldIdNullifier1), "Nullifier should be registered before removal");

        userRegistry.removeUser(user1);

        assertFalse(userRegistry.isUserRegistered(user1), "User should not be registered after removal");
        assertEq(userRegistry.getWorldIdNullifier(user1), 0, "Nullifier for user1 should be 0 after removal");
        assertEq(userRegistry.getAddressByNullifier(worldIdNullifier1), address(0), "Address for nullifier1 should be address(0) after removal");
        assertFalse(userRegistry.isNullifierRegistered(worldIdNullifier1), "Nullifier should not be marked as registered after removal");
    }

    function test_RevertIf_RemoveUnregisteredUser() public {
        vm.expectRevert("UserRegistry: User not registered");
        userRegistry.removeUser(user1);
    }

    // Test registering the same user and nullifier again (should ideally be idempotent or revert)
    // Current implementation reverts on registering an existing address or nullifier.
    function testRegisterExistingUserAndNullifierAgain() public {
        userRegistry.registerUser(user1, worldIdNullifier1);
        
        // Attempt to register the exact same mapping again
        // This will revert due to "UserRegistry: World ID already registered" 
        // or "UserRegistry: Address already has a World ID registered"
        // depending on the check order, which is fine.
        vm.expectRevert("UserRegistry: World ID already registered"); 
        userRegistry.registerUser(user1, worldIdNullifier1);
    }
} 