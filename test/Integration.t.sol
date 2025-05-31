// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {UserRegistry} from "../src/UserRegistry.sol";
// import {SocialVouching} from "../src/SocialVouching.sol"; // REMOVED
import {P2PLending} from "../src/P2PLending.sol"; // UPDATED from LoanContract.sol
// import {Treasury} from "../src/Treasury.sol"; // REMOVED
import {MockERC20} from "./mocks/MockERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Reputation} from "../src/Reputation.sol"; // ADDED
import {MockWorldIdRouter} from "./mocks/MockWorldIdRouter.sol"; // Import mock router

// Re-declare events from LoanContract for type-safe emit checks
// Will need to update these for P2PLending events
// event LoanPaymentMade(bytes32 indexed loanId, uint256 paymentAmount, uint256 totalPaid);
// event LoanFullyRepaid(bytes32 indexed loanId);
// event LoanApproved(bytes32 indexed loanId); 
// event LoanDisbursed(bytes32 indexed loanId); 

// New P2P Events
event LoanOfferCreated(bytes32 indexed offerId, address indexed lender, uint256 amount, address token, uint256 interestRate, uint256 duration);
event LoanRequestCreated(bytes32 indexed requestId, address indexed borrower, uint256 amount, address token, uint256 proposedInterestRate, uint256 proposedDuration);
event LoanAgreementFormed(bytes32 indexed agreementId, address indexed lender, address indexed borrower, uint256 amount, address token);

contract IntegrationTest is Test {
    UserRegistry userRegistry;
    // SocialVouching socialVouching; // REMOVED
    P2PLending p2pLending; // UPDATED from loanContract
    // Treasury treasury; // REMOVED
    MockERC20 mockDAI; 
    MockERC20 mockUSDC; 
    Reputation reputation; // ADDED
    MockWorldIdRouter mockWorldIdRouter; // Mock router instance

    address owner = address(this); 
    address user1 = vm.addr(1);
    address user2 = vm.addr(2);
    address platformWallet = vm.addr(3); // For platform fees (not currently used by LoanContract)
    address reputationOAppIntegrationMockAddress = vm.addr(12); // For Reputation OApp

    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000 * 1e18; // For DAI (18 decimals)
    uint256 constant USER1_NULLIFIER = 11111; // Changed to uint256
    uint256 constant USER2_NULLIFIER = 22222; // Changed to uint256
    uint256 constant VOUCHER_NULLIFIER = 33333; // Added for voucher
    address[] emptyVoucherAddresses; // For applyForLoan calls not testing vouching

    // Dummy proof data for tests
    uint256 private constant DUMMY_ROOT = 987654321;
    uint256[8] private DUMMY_PROOF; // Assign in setUp

    // App and action IDs for testing
    string testAppIdString = "test-app-integration";
    string testActionIdRegisterUserString = "test-register-integration";

    function setUp() public {
        DUMMY_PROOF = [uint256(1), 2, 3, 4, 5, 6, 7, 8]; // Assign DUMMY_PROOF

        // Deploy contracts
        mockWorldIdRouter = new MockWorldIdRouter();
        userRegistry = new UserRegistry(address(mockWorldIdRouter), testAppIdString, testActionIdRegisterUserString);
        reputation = new Reputation(address(userRegistry)); // Deploy Reputation
        // socialVouching = new SocialVouching(address(userRegistry)); // REMOVED
        // treasury = new Treasury(owner); // REMOVED
        p2pLending = new P2PLending( // UPDATED from loanContract
            address(userRegistry),
            address(reputation),                 // Pass Reputation address
            payable(address(0)),                 // Treasury placeholder
            reputationOAppIntegrationMockAddress // OApp placeholder
        );

        // Set P2PLending address in Reputation contract
        vm.startPrank(owner);
        reputation.setP2PLendingContractAddress(address(p2pLending));
        vm.stopPrank();

        // console.log("IntegrationSetup: address(p2pLending) set in Reputation:", address(p2pLending));
        // console.log("IntegrationSetup: reputation.p2pLendingContractAddress():", reputation.p2pLendingContractAddress());

        // Deploy mock tokens
        mockDAI = new MockERC20("MockDAI", "mDAI", 18);
        mockUSDC = new MockERC20("MockUSDC", "mUSDC", 6); // USDC typically has 6 decimals

        // Set up contract addresses
        vm.startPrank(owner);
        // treasury.setLoanContractAddress(address(loanContract)); // REMOVED
        // socialVouching.setLoanContractAddress(address(loanContract)); // REMOVED
        // loanContract.setPlatformWallet(platformWallet); // Assuming this exists for fees
        // loanContract.setPlatformFeePercentage(100); // 1% fee (100 / 10000)
        vm.stopPrank();

        // Register users (assuming proof verification will pass)
        mockWorldIdRouter.setShouldProofSucceed(true);
        vm.prank(owner); userRegistry.registerUser(user1, DUMMY_ROOT, USER1_NULLIFIER, DUMMY_PROOF);
        vm.prank(owner); userRegistry.registerUser(user2, DUMMY_ROOT, USER2_NULLIFIER, DUMMY_PROOF);

        // Mint tokens to users and treasury
        mockDAI.mint(user1, INITIAL_MINT_AMOUNT);
        // mockDAI.mint(address(treasury), INITIAL_MINT_AMOUNT * 10); // REMOVED Treasury minting
        mockDAI.mint(owner, INITIAL_MINT_AMOUNT * 10); // Mint to owner for P2P lending for now
        mockDAI.mint(user2, INITIAL_MINT_AMOUNT * 2); // Lender (user2) gets more
        mockUSDC.mint(user1, INITIAL_MINT_AMOUNT); 
        mockUSDC.mint(user2, INITIAL_MINT_AMOUNT); 
    }

    function test_P2P_FullCycle_Offer_Accept_Repay_NoCollateral_NoVouch() public {
        // 1. User2 (lender) creates a loan offer
        uint256 offerAmount = 100 * 1e18; // 100 mDAI
        uint256 interestRate = 500; // 5%
        uint256 duration = 30 days;
        vm.startPrank(user2);
        mockDAI.approve(address(p2pLending), offerAmount);
        bytes32 offerId = p2pLending.createLoanOffer(offerAmount, address(mockDAI), interestRate, duration, 0, address(0));
        vm.stopPrank();

        // 2. User1 (borrower) accepts the loan offer
        vm.startPrank(user1);
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, 0, address(0));
        vm.stopPrank();

        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(agreement.borrower, user1);
        assertEq(agreement.lender, user2);
        assertEq(agreement.principalAmount, offerAmount);

        // 3. Fast forward time (e.g., half duration) - optional partial repayment could be tested here
        vm.warp(block.timestamp + (duration / 2));

        // 4. User1 (borrower) repays the loan fully
        uint256 totalDue = (agreement.principalAmount * (p2pLending.BASIS_POINTS() + agreement.interestRate)) / p2pLending.BASIS_POINTS();
        vm.startPrank(user1);
        mockDAI.approve(address(p2pLending), totalDue);
        p2pLending.repayP2PLoan(agreementId, totalDue);
        vm.stopPrank();

        P2PLending.LoanAgreement memory agreementAfterRepay = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(uint(agreementAfterRepay.status), uint(P2PLending.LoanStatus.Repaid));

        // Check reputation scores
        Reputation.ReputationProfile memory borrowerProfile = reputation.getReputationProfile(user1);
        Reputation.ReputationProfile memory lenderProfile = reputation.getReputationProfile(user2);
        assertEq(borrowerProfile.currentReputationScore, reputation.REPUTATION_POINTS_REPAID());
        assertEq(lenderProfile.currentReputationScore, reputation.REPUTATION_POINTS_LENT_SUCCESSFULLY());
    }

    function test_P2P_FullCycle_Request_Fund_Default_WithCollateral_WithVouch() public {
        // 1. User3 (voucher) vouches for User1 (borrower)
        address voucher = vm.addr(4); 
        // uint256 voucherNullifier = 33333; // Already defined as VOUCHER_NULLIFIER
        mockWorldIdRouter.setShouldProofSucceed(true); // Ensure registration works
        vm.prank(owner); userRegistry.registerUser(voucher, DUMMY_ROOT, VOUCHER_NULLIFIER, DUMMY_PROOF);
        mockDAI.mint(voucher, 200 * 1e18); 

        uint256 vouchAmount = 50 * 1e18; 
        vm.startPrank(voucher); 
        mockDAI.approve(address(reputation), vouchAmount);
        reputation.addVouch(user1 /*borrowerToVouchFor*/, vouchAmount, address(mockDAI));
        vm.stopPrank();

        // 2. User1 (borrower) creates a loan request with collateral
        uint256 requestAmount = 200 * 1e18; // 200 mDAI
        uint256 collateralAmountUSDC = 100 * 1e6; // 100 mUSDC
        uint256 proposedInterest = 600; // 6%
        uint256 proposedDuration = 60 days;
        vm.startPrank(user1);
        mockUSDC.approve(address(p2pLending), collateralAmountUSDC);
        bytes32 requestId = p2pLending.createLoanRequest(requestAmount, address(mockDAI), proposedInterest, proposedDuration, collateralAmountUSDC, address(mockUSDC));
        vm.stopPrank();

        // 3. User2 (lender) funds the loan request 
        vm.startPrank(user2); // user2 as lender
        mockDAI.approve(address(p2pLending), requestAmount);
        bytes32 agreementId = p2pLending.fundLoanRequest(requestId);
        vm.stopPrank();

        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(agreement.collateralAmount, collateralAmountUSDC);

        // Capture balances/state before default
        Reputation.ReputationProfile memory voucherProfileBefore = reputation.getReputationProfile(voucher);
        uint256 lenderDaiBalanceBeforeDefault = mockDAI.balanceOf(user2);
        uint256 reputationDaiBalanceBeforeDefault = mockDAI.balanceOf(address(reputation));

        // 4. Fast forward time past due date
        vm.warp(block.timestamp + proposedDuration + 1 days);

        // 5. Handle P2P Default (called by anyone, e.g. lender user2)
        vm.startPrank(user2);
        p2pLending.handleP2PDefault(agreementId);
        vm.stopPrank();

        P2PLending.LoanAgreement memory agreementAfterDefault = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(uint(agreementAfterDefault.status), uint(P2PLending.LoanStatus.Defaulted));

        // Check borrower's reputation
        Reputation.ReputationProfile memory borrowerProfileAfterDefault = reputation.getReputationProfile(user1);
        assertEq(borrowerProfileAfterDefault.currentReputationScore, reputation.REPUTATION_POINTS_DEFAULTED());

        // Check voucher's reputation and stake
        uint256 expectedSlashAmount = (vouchAmount * 1000) / p2pLending.BASIS_POINTS(); // 10% of original vouch
        Reputation.ReputationProfile memory voucherProfileAfter = reputation.getReputationProfile(voucher);
        assertEq(voucherProfileAfter.currentReputationScore, voucherProfileBefore.currentReputationScore + reputation.REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER(), "Voucher reputation score incorrect");
        Reputation.Vouch memory vouchAfter = reputation.getVouchDetails(voucher, user1);
        assertEq(vouchAfter.stakedAmount, vouchAmount - expectedSlashAmount, "Voucher stake incorrect after slash");

        // Check lender (user2) received the slashed vouch amount (DAI)
        assertEq(mockDAI.balanceOf(user2), lenderDaiBalanceBeforeDefault + expectedSlashAmount, "Lender DAI balance incorrect after slash");

        // Check Reputation contract DAI balance
        assertEq(mockDAI.balanceOf(address(reputation)), reputationDaiBalanceBeforeDefault - expectedSlashAmount, "Reputation contract DAI balance incorrect after slash");
    }

    // Remove old placeholder tests
    // function test_FullLoanCycle_WithCollateral_NoVouching() public { ... }
    // function test_FullLoanCycle_WithSocialVouching() public { ... }
} 