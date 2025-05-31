// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UserRegistry.sol";
import "../src/Reputation.sol";
import "../src/P2PLending.sol"; // For access to P2PLending contract if needed for setup
import "./mocks/MockERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ReputationTest is Test {
    UserRegistry public userRegistry;
    Reputation public reputation;
    P2PLending public p2pLendingInstanceForMocking; // Renamed for clarity
    MockERC20 public mockDai;

    address owner;
    address user1 = vm.addr(1); // Will act as borrower, lender, voucher
    address user2 = vm.addr(2);
    address user3 = vm.addr(3);
    address actualP2PLendingAddress; // Will hold the address of p2pLendingInstanceForMocking
    address reputationOAppMockAddress = vm.addr(8); // From P2PLending tests, keep consistent if used

    uint256 user1Nullifier = 77777;
    uint256 user2Nullifier = 88888;
    uint256 user3Nullifier = 99999;

    function setUp() public {
        owner = address(this);

        userRegistry = new UserRegistry();
        reputation = new Reputation(address(userRegistry));

        // Deploy a P2PLending instance. Its address will be used as the mock caller.
        // P2PLending constructor: UserRegistry, ReputationContract, Treasury (0), OApp
        p2pLendingInstanceForMocking = new P2PLending(
            address(userRegistry),
            address(reputation),         // P2PLending needs a Reputation address
            payable(address(0)),         // Treasury not used
            reputationOAppMockAddress    // OApp placeholder
        );
        actualP2PLendingAddress = address(p2pLendingInstanceForMocking);

        // Set the (mock) P2PLending address in the Reputation contract so it accepts calls
        vm.prank(owner);
        reputation.setP2PLendingContractAddress(actualP2PLendingAddress);

        // Register users
        vm.prank(owner); userRegistry.registerUser(user1, user1Nullifier);
        vm.prank(owner); userRegistry.registerUser(user2, user2Nullifier);
        vm.prank(owner); userRegistry.registerUser(user3, user3Nullifier);

        mockDai = new MockERC20("Mock DAI", "mDAI", 18);
        mockDai.mint(user1, 1000 * 1e18);
        mockDai.mint(user2, 1000 * 1e18);
        mockDai.mint(user3, 1000 * 1e18);
    }

    // --- Test: Set P2P Lending Contract Address ---
    function test_SetP2PLendingContractAddress_Success() public {
        address newP2PAddress = vm.addr(11);
        vm.prank(owner);
        reputation.setP2PLendingContractAddress(newP2PAddress);
        assertEq(reputation.p2pLendingContractAddress(), newP2PAddress, "P2P lending address mismatch");
    }

    function test_RevertIf_SetP2PLendingContractAddress_NotOwner() public {
        address newP2PAddress = vm.addr(11);
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        reputation.setP2PLendingContractAddress(newP2PAddress);
        vm.stopPrank();
    }

    function test_RevertIf_SetP2PLendingContractAddress_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Invalid P2PLending contract address"));
        reputation.setP2PLendingContractAddress(address(0));
    }

    // --- Test: Reputation Updates (called by P2P Lending Contract) ---
    function test_UpdateReputationOnLoanRepayment_Success() public {
        uint256 loanAmount = 100 * 1e18;

        vm.startPrank(actualP2PLendingAddress); // Simulate call from P2PLending contract
        reputation.updateReputationOnLoanRepayment(user1 /*borrower*/, user2 /*lender*/, loanAmount);
        vm.stopPrank();

        Reputation.ReputationProfile memory borrowerProfile = reputation.getReputationProfile(user1);
        Reputation.ReputationProfile memory lenderProfile = reputation.getReputationProfile(user2);

        assertEq(borrowerProfile.loansTaken, 1, "Borrower loans taken mismatch");
        assertEq(borrowerProfile.loansRepaidOnTime, 1, "Borrower loans repaid mismatch");
        assertEq(borrowerProfile.totalValueBorrowed, loanAmount, "Borrower total value borrowed mismatch");
        assertEq(borrowerProfile.currentReputationScore, reputation.REPUTATION_POINTS_REPAID(), "Borrower reputation score mismatch");

        assertEq(lenderProfile.loansGiven, 1, "Lender loans given mismatch");
        assertEq(lenderProfile.totalValueLent, loanAmount, "Lender total value lent mismatch");
        assertEq(lenderProfile.currentReputationScore, reputation.REPUTATION_POINTS_LENT_SUCCESSFULLY(), "Lender reputation score mismatch");
    }

    function test_RevertIf_UpdateReputationOnLoanRepayment_NotP2PContract() public {
        vm.startPrank(user1); // Any address other than P2PLending contract
        vm.expectRevert(bytes("Reputation: Caller is not P2PLending contract"));
        reputation.updateReputationOnLoanRepayment(user1, user2, 100e18);
        vm.stopPrank();
    }

    function test_UpdateReputationOnLoanDefault_Success() public {
        uint256 loanAmount = 200 * 1e18;
        bytes32[] memory emptyVouches; // Placeholder, actual vouch slashing needs more design

        vm.startPrank(actualP2PLendingAddress);
        reputation.updateReputationOnLoanDefault(user1 /*borrower*/, user2 /*lender*/, loanAmount, emptyVouches);
        vm.stopPrank();

        Reputation.ReputationProfile memory borrowerProfile = reputation.getReputationProfile(user1);
        assertEq(borrowerProfile.loansTaken, 1, "Default: Borrower loans taken mismatch");
        assertEq(borrowerProfile.loansDefaulted, 1, "Default: Borrower loans defaulted mismatch");
        assertEq(borrowerProfile.currentReputationScore, reputation.REPUTATION_POINTS_DEFAULTED(), "Default: Borrower reputation score mismatch");
        // Lender profile should ideally be unchanged by borrower default in this basic scenario
        Reputation.ReputationProfile memory lenderProfile = reputation.getReputationProfile(user2);
        assertEq(lenderProfile.currentReputationScore, 0, "Default: Lender reputation should be unaffected");
    }

    // --- Test: Vouching --- 
    function test_AddVouch_Success() public {
        uint256 stakeAmount = 50 * 1e18;
        vm.startPrank(user1); // user1 vouches for user2
        mockDai.approve(address(reputation), stakeAmount);
        reputation.addVouch(user2 /*borrowerToVouchFor*/, stakeAmount, address(mockDai));
        vm.stopPrank();

        Reputation.Vouch memory vouch = reputation.getVouchDetails(user1, user2);
        assertEq(vouch.voucher, user1, "Vouch voucher mismatch");
        assertEq(vouch.borrower, user2, "Vouch borrower mismatch");
        assertEq(vouch.stakedAmount, stakeAmount, "Vouch stake amount mismatch");
        assertTrue(vouch.isActive, "Vouch should be active");

        assertEq(mockDai.balanceOf(address(reputation)), stakeAmount, "Reputation contract DAI balance incorrect");

        Reputation.ReputationProfile memory voucherProfile = reputation.getReputationProfile(user1);
        assertEq(voucherProfile.vouchingStakeAmount, stakeAmount, "Voucher's total stake mismatch");
        assertEq(voucherProfile.timesVouchedForOthers, 1, "Voucher's times vouched mismatch");
    }

    function test_RevertIf_AddVouch_SelfVouch() public {
        vm.startPrank(user1);
        mockDai.approve(address(reputation), 50 * 1e18);
        vm.expectRevert(bytes("Cannot vouch for yourself"));
        reputation.addVouch(user1, 50 * 1e18, address(mockDai));
        vm.stopPrank();
    }

    function test_RevertIf_AddVouch_BorrowerNotVerified() public {
        address unverifiedUser = vm.addr(99);
        // DO NOT register unverifiedUser in userRegistry
        vm.startPrank(user1);
        mockDai.approve(address(reputation), 50 * 1e18);
        vm.expectRevert(bytes("Borrower not World ID verified"));
        reputation.addVouch(unverifiedUser, 50 * 1e18, address(mockDai));
        vm.stopPrank();
    }

    function test_RemoveVouch_Success() public {
        uint256 stakeAmount = 50 * 1e18;
        vm.startPrank(user1); // user1 vouches for user2
        mockDai.approve(address(reputation), stakeAmount);
        reputation.addVouch(user2, stakeAmount, address(mockDai));
        vm.stopPrank();

        uint256 user1DaiBalanceBeforeRemove = mockDai.balanceOf(user1);

        vm.startPrank(user1);
        reputation.removeVouch(user2);
        vm.stopPrank();

        Reputation.Vouch memory vouch = reputation.getVouchDetails(user1, user2);
        assertFalse(vouch.isActive, "Vouch should be inactive after removal");
        assertEq(mockDai.balanceOf(user1), user1DaiBalanceBeforeRemove + stakeAmount, "Voucher DAI balance incorrect after stake return");
        Reputation.ReputationProfile memory voucherProfile = reputation.getReputationProfile(user1);
        assertEq(voucherProfile.vouchingStakeAmount, 0, "Voucher's total stake should be zero after removal");
    }

    function test_SlashVouchAndReputation_Success() public {
        uint256 initialStake = 100 * 1e18;
        uint256 slashAmount = 40 * 1e18;

        // user1 (voucher) vouches for user2 (borrower)
        vm.startPrank(user1);
        mockDai.approve(address(reputation), initialStake);
        reputation.addVouch(user2, initialStake, address(mockDai));
        vm.stopPrank();

        uint256 lenderDaiBalanceBeforeSlash = mockDai.balanceOf(user3); // user3 is the lender to compensate
        Reputation.ReputationProfile memory voucherProfileBefore = reputation.getReputationProfile(user1);

        // Simulate call from P2PLending contract to slash the vouch
        vm.startPrank(actualP2PLendingAddress);
        reputation.slashVouchAndReputation(user1 /*voucher*/, user2 /*defaultingBorrower*/, slashAmount, user3 /*lenderToCompensate*/);
        vm.stopPrank();

        Reputation.Vouch memory vouchAfterSlash = reputation.getVouchDetails(user1, user2);
        assertTrue(vouchAfterSlash.isActive, "Vouch should still be active after partial slash");
        assertEq(vouchAfterSlash.stakedAmount, initialStake - slashAmount, "Vouch staked amount incorrect after slash");

        assertEq(mockDai.balanceOf(user3), lenderDaiBalanceBeforeSlash + slashAmount, "Lender DAI balance incorrect after compensation");
        assertEq(mockDai.balanceOf(address(reputation)), initialStake - slashAmount, "Reputation contract DAI balance incorrect after slash");

        Reputation.ReputationProfile memory voucherProfileAfter = reputation.getReputationProfile(user1);
        assertEq(voucherProfileAfter.currentReputationScore, voucherProfileBefore.currentReputationScore + reputation.REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER(), "Voucher reputation score incorrect after slash");
        assertEq(voucherProfileAfter.vouchingStakeAmount, initialStake - slashAmount, "Voucher total stake incorrect after slash");
        assertEq(voucherProfileAfter.timesDefaultedAsVoucher, 1, "Voucher times defaulted as voucher mismatch");
    }

    function test_SlashVouchAndReputation_FullSlashDeactivates() public {
        uint256 initialStake = 100 * 1e18;
        // user1 (voucher) vouches for user2 (borrower)
        vm.startPrank(user1);
        mockDai.approve(address(reputation), initialStake);
        reputation.addVouch(user2, initialStake, address(mockDai));
        vm.stopPrank();

        vm.startPrank(actualP2PLendingAddress);
        reputation.slashVouchAndReputation(user1, user2, initialStake, user3);
        vm.stopPrank();

        Reputation.Vouch memory vouchAfterSlash = reputation.getVouchDetails(user1, user2);
        assertFalse(vouchAfterSlash.isActive, "Vouch should be inactive after full slash");
        assertEq(vouchAfterSlash.stakedAmount, 0, "Vouch staked amount should be zero after full slash");
    }

    function test_GetActiveVouchesForBorrower() public {
        uint256 stakeAmount1 = 50 * 1e18;
        uint256 stakeAmount2 = 30 * 1e18;

        // User1 vouches for User3
        vm.startPrank(user1);
        mockDai.approve(address(reputation), stakeAmount1);
        reputation.addVouch(user3, stakeAmount1, address(mockDai));
        vm.stopPrank();

        // User2 vouches for User3
        vm.startPrank(user2);
        mockDai.approve(address(reputation), stakeAmount2);
        reputation.addVouch(user3, stakeAmount2, address(mockDai));
        vm.stopPrank();

        Reputation.Vouch[] memory activeVouches = reputation.getActiveVouchesForBorrower(user3);
        assertEq(activeVouches.length, 2, "Incorrect number of active vouches for user3");
        assertEq(activeVouches[0].voucher, user1);
        assertEq(activeVouches[0].stakedAmount, stakeAmount1);
        assertEq(activeVouches[1].voucher, user2);
        assertEq(activeVouches[1].stakedAmount, stakeAmount2);

        // User1 removes their vouch
        vm.startPrank(user1);
        reputation.removeVouch(user3);
        vm.stopPrank();

        activeVouches = reputation.getActiveVouchesForBorrower(user3);
        assertEq(activeVouches.length, 1, "Incorrect number of active vouches after one removal");
        assertEq(activeVouches[0].voucher, user2);

        // No active vouches for user1
        activeVouches = reputation.getActiveVouchesForBorrower(user1);
        assertEq(activeVouches.length, 0, "User1 should have no active vouches received");
    }
} 