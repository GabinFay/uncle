// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UserRegistry.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol"; // Import Ownable to access its error

contract UserRegistryTest is Test {
    UserRegistry public userRegistry;
    address owner = address(this); // Test contract itself can be the owner for simplicity
    address user1 = address(0x1);
    address user2 = address(0x2);
    bytes32 worldIdNullifier1 = keccak256(abi.encodePacked("nullifier1"));
    bytes32 worldIdNullifier2 = keccak256(abi.encodePacked("nullifier2"));

    function setUp() public {
        // userRegistry = new UserRegistry(owner);
        // For Ownable contracts, the deployer (this test contract) is automatically the owner.
        userRegistry = new UserRegistry(); 
    }

    function testRegisterNewUser() public {
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(user1, worldIdNullifier1);
        UserRegistry.UserProfile memory profile = userRegistry.getUserProfile(user1);
        assertTrue(profile.isWorldIdVerified, "User should be World ID verified");
        assertEq(profile.worldIdNullifierHash, worldIdNullifier1, "World ID nullifier hash mismatch");
        assertEq(userRegistry.worldIdNullifierToAddress(worldIdNullifier1), user1, "Nullifier to address mapping mismatch");
    }

    function test_RevertIf_RegisterWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(bytes("UserRegistry: Invalid user address"));
        userRegistry.registerOrUpdateUser(address(0), worldIdNullifier1);
    }

    function test_RevertIf_RegisterWithZeroNullifier() public {
        vm.prank(owner);
        vm.expectRevert(bytes("UserRegistry: Invalid World ID nullifier hash"));
        userRegistry.registerOrUpdateUser(user1, bytes32(0));
    }

    function test_RevertIf_RegisterExistingNullifierToDifferentAddress() public {
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(user1, worldIdNullifier1);
        vm.expectRevert(bytes("UserRegistry: World ID already registered to another address"));
        userRegistry.registerOrUpdateUser(user2, worldIdNullifier1);
    }

    function test_RevertIf_RegisterExistingAddressToDifferentNullifier() public {
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(user1, worldIdNullifier1);
        vm.expectRevert(bytes("UserRegistry: Address already registered with a different World ID"));
        userRegistry.registerOrUpdateUser(user1, worldIdNullifier2);
    }
    
    function testUpdateUserWithSameNullifier() public {
        //This should effectively re-register/confirm the user
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(user1, worldIdNullifier1);
        UserRegistry.UserProfile memory profileBefore = userRegistry.getUserProfile(user1);
        assertTrue(profileBefore.isWorldIdVerified, "User should be initially verified");

        // e.g. if some profile data changed and backend re-confirms, it calls again
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(user1, worldIdNullifier1); 
        UserRegistry.UserProfile memory profileAfter = userRegistry.getUserProfile(user1);
        assertTrue(profileAfter.isWorldIdVerified, "User should remain verified");
        assertEq(profileAfter.worldIdNullifierHash, worldIdNullifier1, "Nullifier should remain the same");
    }

    function testIsUserWorldIdVerified() public {
        assertFalse(userRegistry.isUserWorldIdVerified(user1), "User should not be verified initially");
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(user1, worldIdNullifier1);
        assertTrue(userRegistry.isUserWorldIdVerified(user1), "User should be verified after registration");
    }

    function testGetUserProfileTest() public {
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(user1, worldIdNullifier1);
        UserRegistry.UserProfile memory profile = userRegistry.getUserProfile(user1);
        assertTrue(profile.isWorldIdVerified);
        assertEq(profile.worldIdNullifierHash, worldIdNullifier1);
    }

    function testUpdateFilecoinDataPointer() public {
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(user1, worldIdNullifier1);
        string memory cid = "QmSomeFilecoinCID";
        vm.prank(owner);
        userRegistry.updateFilecoinDataPointer(user1, cid);
        UserRegistry.UserProfile memory profile = userRegistry.getUserProfile(user1);
        assertEq(profile.filecoinDataPointer, cid, "Filecoin data pointer mismatch");
    }

    function test_RevertIf_UpdateFilecoinDataPointerUnregisteredUser() public {
        string memory cid = "QmSomeFilecoinCID";
        vm.prank(owner);
        vm.expectRevert(bytes("UserRegistry: User not registered/verified"));
        userRegistry.updateFilecoinDataPointer(user1, cid);
    }

    function testUpdateReputationScore() public {
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(user1, worldIdNullifier1);
        uint256 newScore = 100;
        vm.prank(owner);
        userRegistry.updateReputationScore(user1, newScore);
        UserRegistry.UserProfile memory profile = userRegistry.getUserProfile(user1);
        assertEq(profile.reputationScore, newScore, "Reputation score mismatch");
    }

    function test_RevertIf_UpdateReputationScoreUnregisteredUser() public {
        uint256 newScore = 100;
        vm.prank(owner);
        vm.expectRevert(bytes("UserRegistry: User not registered/verified"));
        userRegistry.updateReputationScore(user1, newScore);
    }

    // Test Ownable functions (transferOwnership, renounceOwnership)
    function testTransferOwnership() public {
        address newOwner = address(0x3);
        assertEq(userRegistry.owner(), owner, "Initial owner should be test contract");
        vm.prank(owner);
        userRegistry.transferOwnership(newOwner);
        assertEq(userRegistry.owner(), newOwner, "Ownership should be transferred");
    }

    function test_RevertIf_TransferOwnershipNonOwner() public {
        address newOwner = address(0x3);
        address nonOwner = address(0x4);
        vm.prank(nonOwner);
        // Expect OpenZeppelin's OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        userRegistry.transferOwnership(newOwner);
    }

    function testRenounceOwnership() public {
        assertEq(userRegistry.owner(), owner, "Initial owner should be test contract");
        vm.prank(owner);
        userRegistry.renounceOwnership();
        assertEq(userRegistry.owner(), address(0), "Owner should be zero address after renouncing");
    }

    function test_RevertIf_RenounceOwnershipNonOwner() public {
        address nonOwner = address(0x4);
        vm.prank(nonOwner);
        // Expect OpenZeppelin's OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        userRegistry.renounceOwnership();
    }
} 