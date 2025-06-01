// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {UserRegistry} from "src/UserRegistry.sol";
import {P2PLending} from "src/P2PLending.sol";
import {Reputation} from "src/Reputation.sol";
import {MockWorldIdRouter} from "./mocks/MockWorldIdRouter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {PackedBytesToField} from "src/PackedBytesToField.sol";
// IVoucherManagement and VoucherManagement are not used with current Reputation.sol, can be removed if not needed for other tests
// import {IVoucherManagement} from "src/interfaces/IVoucherManagement.sol";
// import {VoucherManagement} from "src/VoucherManagement.sol";

contract IntegrationTest is Test {
    UserRegistry userRegistry;
    P2PLending p2pLending;
    Reputation reputation;
    MockWorldIdRouter mockWorldIdRouter;
    MockERC20 mockDai;
    // VoucherManagement voucherManagement; // Not used

    address deployer;
    address user1; // Borrower
    address user2; // Lender
    address user3; // Another user

    uint256 constant ONE_DAY_SECONDS = 1 days;

    // World ID related variables for testing
    uint256 DUMMY_ROOT = 12345; // Dummy root as registerUser expects it
    uint256 user1Nullifier = 111; // Test nullifier for user1
    uint256 user2Nullifier = 222; // Test nullifier for user2
    uint256 user3Nullifier = 333; // Test nullifier for user3
    // uint256 worldIdGroup = 1; // This is set internally in UserRegistry constructor
    // bytes32 worldIdSignal = keccak256(abi.encodePacked("test_signal")); // Signal is derived from user address in UserRegistry

    uint256[8] internal proof; // Default proof (can remain empty or be a dummy array)

    function setUp() public {
        deployer = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);
        user3 = vm.addr(4);

        vm.startPrank(deployer);
        mockWorldIdRouter = new MockWorldIdRouter();
        userRegistry = new UserRegistry(address(mockWorldIdRouter), "test_app_id_integration", "test_action_register_integration");
        reputation = new Reputation(address(userRegistry));
        p2pLending = new P2PLending(address(userRegistry), address(reputation), payable(deployer), address(0));
        
        // Set P2PLending address in Reputation contract
        reputation.setP2PLendingContractAddress(address(p2pLending));

        // voucherManagement = new VoucherManagement(address(userRegistry)); // Not used
        // reputation.setVoucherManagementContract(address(voucherManagement)); // Not used
        
        mockDai = new MockERC20("MockDAI", "mDAI", 18);
        mockWorldIdRouter.setShouldProofSucceed(true);
        vm.stopPrank();

        // Register users
        vm.prank(user1);
        userRegistry.registerUser(user1, DUMMY_ROOT, user1Nullifier, proof);
        vm.prank(user2);
        userRegistry.registerUser(user2, DUMMY_ROOT, user2Nullifier, proof);
        vm.prank(user3);
        userRegistry.registerUser(user3, DUMMY_ROOT, user3Nullifier, proof);
        vm.stopPrank(); // Explicitly stop user3 prank before starting deployer prank for minting

        // Mint DAI for users
        vm.startPrank(deployer); // Start prank for deployer
        mockDai.mint(user1, 1000e18);
        mockDai.mint(user2, 1000e18);
        vm.stopPrank(); // Stop deployer prank
    }

    function test_FullLoanCycle_OnTimeRepayment_NoCollateral() public {
        // 1. Lender (user2) creates a loan offer
        uint256 offerPrincipal = 100e18;
        uint16 offerInterestBPS = 500; // 5%
        uint256 offerDurationSeconds = 30 * ONE_DAY_SECONDS;
        address loanToken = address(mockDai); // Define loan token

        vm.startPrank(user2);
        mockDai.approve(address(p2pLending), offerPrincipal);

        // Test that createLoanOffer executes successfully
        bytes32 offerId = p2pLending.createLoanOffer(
            offerPrincipal,           // amount_
            loanToken,                // token_
            offerInterestBPS,         // interestRateBPS_
            offerDurationSeconds,     // durationSeconds_
            0,                        // requiredCollateralAmount_
            address(0)                // collateralToken_
        );
        vm.stopPrank();

        // Verify offerId is not zero
        assertTrue(offerId != bytes32(0), "offerId should not be zero");

        P2PLending.LoanOffer memory createdOffer = p2pLending.getLoanOfferDetails(offerId);
        assertEq(createdOffer.lender, user2, "Offer lender mismatch");
        assertEq(createdOffer.amount, offerPrincipal, "Offer principal mismatch");

        // 2. Borrower (user1) accepts the loan offer
        vm.startPrank(user1);
        // Borrower doesn't need to approve DAI for collateral as there's none.
        
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, 0, address(0));
        vm.stopPrank();

        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(agreement.borrower, user1, "Agreement borrower mismatch");
        assertEq(agreement.lender, user2, "Agreement lender mismatch");
        uint256 totalDue = agreement.principalAmount + (agreement.principalAmount * uint256(agreement.interestRateBPS) / 10000);

        // 3. Borrower (user1) repays the loan on time
        vm.warp(agreement.dueDate - 1 * ONE_DAY_SECONDS); // Warp to just before due date

        vm.startPrank(user1);
        mockDai.approve(address(p2pLending), totalDue);
        
        p2pLending.repayLoan(agreementId, totalDue);
        vm.stopPrank();

        assertEq(uint(p2pLending.getLoanAgreementDetails(agreementId).status), uint(P2PLending.LoanStatus.Repaid), "Loan not repaid");
        
        // Check reputation scores
        Reputation.ReputationProfile memory borrowerProfile = reputation.getReputationProfile(user1);
        Reputation.ReputationProfile memory lenderProfile = reputation.getReputationProfile(user2);
        
        // The initial reputation should be 0, and after successful repayment:
        // - Borrower gets REPUTATION_POINTS_REPAID_ON_TIME_ORIGINAL
        // - Lender gets REPUTATION_POINTS_LENT_SUCCESSFULLY_ON_TIME_ORIGINAL
        assertEq(borrowerProfile.currentReputationScore, reputation.REPUTATION_POINTS_REPAID_ON_TIME_ORIGINAL(), "Borrower reputation incorrect after on-time repayment");
        assertEq(lenderProfile.currentReputationScore, reputation.REPUTATION_POINTS_LENT_SUCCESSFULLY_ON_TIME_ORIGINAL(), "Lender reputation incorrect after on-time repayment");
    }

    function test_FullLoanCycle_Default_WithCollateral() public {
        // 1. Lender (user2) creates a loan offer with collateral
        uint256 offerPrincipal = 50e18; // Loan 50 DAI
        uint16 offerInterestBPS = 1000; // 10%
        uint256 offerDurationSeconds = 15 * ONE_DAY_SECONDS;
        address loanTokenDefault = address(mockDai);
        address offerCollateralToken = address(mockDai); // Using DAI as collateral for simplicity
        uint256 offerCollateralAmount = 60e18; // 60 DAI collateral

        vm.startPrank(user2);
        mockDai.approve(address(p2pLending), offerPrincipal); // Approve principal for lending

        bytes32 offerId = p2pLending.createLoanOffer(
            offerPrincipal, 
            loanTokenDefault, 
            offerInterestBPS, 
            offerDurationSeconds, 
            offerCollateralAmount, 
            offerCollateralToken
        );
        vm.stopPrank();

        // 2. Borrower (user1) accepts the loan offer
        vm.startPrank(user1);
        mockDai.approve(address(p2pLending), offerCollateralAmount); // Approve DAI for collateral deposit
        
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, offerCollateralAmount, offerCollateralToken);
        vm.stopPrank();

        // Check balances after loan acceptance
        // Borrower: starts 1000, deposits 60 collateral, receives 50 loan = 1000 - 60 + 50 = 990
        assertEq(mockDai.balanceOf(user1), 1000e18 - offerCollateralAmount + offerPrincipal, "Borrower DAI balance incorrect after loan with collateral");
        // P2P contract: holds collateral 60
        assertEq(mockDai.balanceOf(address(p2pLending)), offerCollateralAmount, "P2P contract should hold collateral");
        // Lender: starts 1000, lends 50 = 950
        assertEq(mockDai.balanceOf(user2), 1000e18 - offerPrincipal, "Lender DAI balance incorrect after loan with collateral");

        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        
        // 3. Time passes, loan becomes overdue and defaults
        vm.warp(agreement.dueDate + 2 * ONE_DAY_SECONDS); // Warp 2 days past due date

        // 4. Lender (user2) handles the default
        vm.startPrank(user2);
        
        p2pLending.handleP2PDefault(agreementId);
        vm.stopPrank();

        agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(uint(agreement.status), uint(P2PLending.LoanStatus.Defaulted), "Loan status not Defaulted");

        // Check balances after default handling
        // Borrower: no change from 990, collateral is lost
        assertEq(mockDai.balanceOf(user1), 1000e18 - offerCollateralAmount + offerPrincipal, "Borrower DAI balance incorrect after default");
        // P2P Contract: collateral should be gone
        assertEq(mockDai.balanceOf(address(p2pLending)), 0, "P2P contract DAI balance should be 0 after default");
        // Lender: starts 950, receives collateral 60 = 1010
        assertEq(mockDai.balanceOf(user2), 1000e18 - offerPrincipal + offerCollateralAmount, "Lender DAI balance incorrect after default (collateral transfer)");

        // Check reputation
        Reputation.ReputationProfile memory borrowerProfile = reputation.getReputationProfile(user1);
        assertEq(borrowerProfile.currentReputationScore, reputation.REPUTATION_POINTS_DEFAULTED(), "Borrower reputation score for default incorrect");
    }
    
    // TODO: Add more integration tests:
    // - Loan request flow
    // - Partial repayment
    // - Payment modification requests and responses
    // - Vouching integration (if VoucherManagement is re-introduced and integrated with P2PLending/Reputation)
} 