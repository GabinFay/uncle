// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UserRegistry.sol";
import "./mocks/MockWorldIdRouter.sol"; // Import the mock router

contract UserRegistryTest is Test {
    UserRegistry public userRegistry;
    MockWorldIdRouter public mockWorldIdRouter; // Mock router instance

    address user1 = address(0x1);
    address user2 = address(0x2);
    uint256 worldIdNullifier1 = 12345; 
    uint256 worldIdNullifier2 = 67890;

    // Dummy proof data for tests
    uint256 private constant DUMMY_ROOT = 987654321;
    uint256[8] private DUMMY_PROOF; // Regular state variable

    // App and action IDs for testing
    string testAppIdString = "test-app";
    string testActionIdRegisterUserString = "test-register";

    function setUp() public {
        mockWorldIdRouter = new MockWorldIdRouter();
        userRegistry = new UserRegistry(address(mockWorldIdRouter), testAppIdString, testActionIdRegisterUserString);
        DUMMY_PROOF = [uint256(1), 2, 3, 4, 5, 6, 7, 8]; // Assign in setUp
    }

    function testRegisterNewUser() public {
        mockWorldIdRouter.setShouldProofSucceed(true);
        userRegistry.registerUser(user1, DUMMY_ROOT, worldIdNullifier1, DUMMY_PROOF);
        assertTrue(userRegistry.isUserRegistered(user1), "User should be registered");
        assertEq(userRegistry.getWorldIdNullifier(user1), worldIdNullifier1, "World ID nullifier mismatch for user1");
        assertEq(userRegistry.getAddressByNullifier(worldIdNullifier1), user1, "Nullifier to address mapping mismatch for nullifier1");
        assertTrue(userRegistry.isNullifierRegistered(worldIdNullifier1), "Nullifier should be marked as registered");
    }

    function test_RevertIf_Register_ProofVerificationFails() public {
        mockWorldIdRouter.setShouldProofSucceed(false);
        mockWorldIdRouter.setRevertMessage("Proof Invalid");

        vm.expectRevert("Proof Invalid");
        userRegistry.registerUser(user1, DUMMY_ROOT, worldIdNullifier1, DUMMY_PROOF);
    }

    function test_RevertIf_RegisterWithZeroAddress() public {
        mockWorldIdRouter.setShouldProofSucceed(true);
        vm.expectRevert("UserRegistry: Cannot register zero address");
        userRegistry.registerUser(address(0), DUMMY_ROOT, worldIdNullifier1, DUMMY_PROOF);
    }

    function test_RevertIf_RegisterWithZeroNullifier() public {
        mockWorldIdRouter.setShouldProofSucceed(true);
        vm.expectRevert("UserRegistry: World ID nullifier hash cannot be zero");
        userRegistry.registerUser(user1, DUMMY_ROOT, 0, DUMMY_PROOF);
    }

    function test_RevertIf_RegisterExistingNullifierToDifferentAddress() public {
        mockWorldIdRouter.setShouldProofSucceed(true);
        userRegistry.registerUser(user1, DUMMY_ROOT, worldIdNullifier1, DUMMY_PROOF);
        
        // Attempt to register same nullifier to user2
        // Proof for user2 with nullifier1 would be invalid in reality, but mock passes if set to true.
        // The UserRegistry's internal check should catch this.
        vm.expectRevert("UserRegistry: World ID nullifier hash already registered");
        userRegistry.registerUser(user2, DUMMY_ROOT, worldIdNullifier1, DUMMY_PROOF);
    }

    function test_RevertIf_RegisterExistingAddressToDifferentNullifier() public {
        mockWorldIdRouter.setShouldProofSucceed(true);
        userRegistry.registerUser(user1, DUMMY_ROOT, worldIdNullifier1, DUMMY_PROOF);

        // Attempt to register user1 with a new nullifier
        // Mock will pass proof for (user1, worldIdNullifier2) if set to true.
        // The UserRegistry's internal check should catch this.
        vm.expectRevert("UserRegistry: Address already has a World ID registered");
        userRegistry.registerUser(user1, DUMMY_ROOT, worldIdNullifier2, DUMMY_PROOF);
    }

    function testRegisterMultipleUsers() public {
        mockWorldIdRouter.setShouldProofSucceed(true);
        userRegistry.registerUser(user1, DUMMY_ROOT, worldIdNullifier1, DUMMY_PROOF);
        userRegistry.registerUser(user2, DUMMY_ROOT, worldIdNullifier2, DUMMY_PROOF);

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

    function testRemoveUser_KeepsNullifierRegistered() public {
        mockWorldIdRouter.setShouldProofSucceed(true);
        userRegistry.registerUser(user1, DUMMY_ROOT, worldIdNullifier1, DUMMY_PROOF);
        assertTrue(userRegistry.isUserRegistered(user1), "User should be registered before removal");
        assertTrue(userRegistry.isNullifierRegistered(worldIdNullifier1), "Nullifier should be registered before removal");

        userRegistry.removeUser(user1);

        assertFalse(userRegistry.isUserRegistered(user1), "User should not be registered after removal");
        assertEq(userRegistry.getWorldIdNullifier(user1), 0, "Nullifier for user1 should be 0 after removal");
        assertEq(userRegistry.getAddressByNullifier(worldIdNullifier1), address(0), "Address for nullifier1 should be address(0) after removal");
        
        // Crucially, the nullifier itself is still marked as having been used for this app/action
        assertTrue(userRegistry.isNullifierRegistered(worldIdNullifier1), "Nullifier should STILL be marked as registered to prevent reuse");
    }

    function test_RevertIf_RemoveUnregisteredUser() public {
        vm.expectRevert("UserRegistry: User not registered");
        userRegistry.removeUser(user1);
    }

    // Test that attempting to re-register a user (same address, same nullifier)
    // after they have been removed, but their nullifier is still marked as used for sybil resistance.
    function test_RevertIf_ReRegisterRemovedUser_DueToUsedNullifier() public {
        mockWorldIdRouter.setShouldProofSucceed(true);
        userRegistry.registerUser(user1, DUMMY_ROOT, worldIdNullifier1, DUMMY_PROOF);
        userRegistry.removeUser(user1);

        assertTrue(userRegistry.isNullifierRegistered(worldIdNullifier1), "Nullifier should still be marked as registered");
        assertFalse(userRegistry.isUserRegistered(user1), "User should be removed");

        // Attempt to re-register with the same nullifier that is still marked as used.
        // The mock router will allow the proof through, but UserRegistry should block it.
        vm.expectRevert("UserRegistry: World ID nullifier hash already registered");
        userRegistry.registerUser(user1, DUMMY_ROOT, worldIdNullifier1, DUMMY_PROOF);
    }

} 