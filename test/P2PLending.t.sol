// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UserRegistry.sol";
import "../src/P2PLending.sol";
import "../src/Reputation.sol";
import "./mocks/MockERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract P2PLendingTest is Test {
    UserRegistry public userRegistry;
    P2PLending public p2pLending;
    Reputation public reputation;
    MockERC20 public mockDai;
    MockERC20 public mockUsdc;

    address owner;
    address borrower = vm.addr(1);
    address lender = vm.addr(4);
    address platformWallet = vm.addr(2);
    address voucher1 = vm.addr(3);
    address reputationOAppMockAddress = vm.addr(8);

    uint256 borrowerNullifier = 44444;
    uint256 lenderNullifier = 55555;
    uint256 voucherNullifier = 66666;

    uint256 constant ONE_DAY_SECONDS = 1 days;
    uint256 constant DEFAULT_INTEREST_RATE_P2P = 500; // 5.00%
    uint256 constant BASIS_POINTS_TEST = 10000; // For test calculations
    address[] emptyVoucherAddresses;

    event LoanOfferCreated(bytes32 indexed offerId, address indexed lender, uint256 amount, address token, uint256 interestRate, uint256 duration);
    event LoanRequestCreated(bytes32 indexed requestId, address indexed borrower, uint256 amount, address token, uint256 proposedInterestRate, uint256 proposedDuration);
    event LoanAgreementFormed(bytes32 indexed agreementId, address indexed lender, address indexed borrower, uint256 amount, address token);
    event LoanRepaymentMade(bytes32 indexed agreementId, uint256 amountPaid, uint256 totalPaid);
    event LoanAgreementRepaid(bytes32 indexed agreementId);
    event LoanAgreementDefaulted(bytes32 indexed agreementId);
    event VouchSlashed(address indexed voucher, address indexed borrower, uint256 amount, address indexed lender);

    event ReputationUpdated(address indexed user, int256 newScore, string reason);

    function setUp() public {
        owner = address(this);
        userRegistry = new UserRegistry();
        reputation = new Reputation(address(userRegistry));
        
        p2pLending = new P2PLending(
            address(userRegistry),
            address(reputation),
            payable(address(0)),
            reputationOAppMockAddress
        );
        
        vm.prank(owner);
        reputation.setP2PLendingContractAddress(address(p2pLending));

        vm.prank(owner); userRegistry.registerUser(borrower, borrowerNullifier);
        vm.prank(owner); userRegistry.registerUser(lender, lenderNullifier);
        vm.prank(owner); userRegistry.registerUser(voucher1, voucherNullifier);
        mockDai = new MockERC20("Mock DAI", "mDAI", 18);
        mockUsdc = new MockERC20("Mock USDC", "mUSDC", 6);
        mockDai.mint(borrower, 2000 * 1e18);
        mockDai.mint(lender, 10000 * 1e18);
        mockDai.mint(voucher1, 1000 * 1e18);
        mockUsdc.mint(borrower, 500 * 1e6);
        mockUsdc.mint(lender, 500 * 1e6);
    }

    function test_CreateLoanOffer_Success() public {
        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(1000 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 30 * ONE_DAY_SECONDS, 50 * 1e6, address(mockUsdc));
        vm.stopPrank();
        assertTrue(offerId != bytes32(0));
        P2PLending.LoanOffer memory offer = p2pLending.getLoanOfferDetails(offerId);
        assertEq(offer.lender, lender);
        assertEq(offer.offerAmount, 1000 * 1e18);
        assertEq(uint(offer.status), uint(P2PLending.LoanStatus.OfferOpen));
        bytes32[] memory lenderOffers = p2pLending.getUserLoanOfferIds(lender);
        assertEq(lenderOffers.length, 1);
        assertEq(lenderOffers[0], offerId);
    }

    function test_RevertIf_CreateLoanOffer_InsufficientBalance() public {
        vm.startPrank(lender);
        mockDai.transfer(address(this), mockDai.balanceOf(lender));
        vm.expectRevert(bytes("Insufficient balance to create offer"));
        p2pLending.createLoanOffer(1000 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 30 * ONE_DAY_SECONDS, 0, address(0));
        vm.stopPrank();
    }

    function test_CreateLoanRequest_Success() public {
        vm.startPrank(borrower);
        bytes32 requestId = p2pLending.createLoanRequest(500 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P + 100, 15 * ONE_DAY_SECONDS, 20 * 1e6, address(mockUsdc));
        vm.stopPrank();
        assertTrue(requestId != bytes32(0));
        P2PLending.LoanRequest memory loanReq = p2pLending.getLoanRequestDetails(requestId);
        assertEq(loanReq.borrower, borrower);
        assertEq(loanReq.requestAmount, 500 * 1e18);
        assertEq(uint(loanReq.status), uint(P2PLending.LoanStatus.RequestOpen));
        bytes32[] memory borrowerRequests = p2pLending.getUserLoanRequestIds(borrower);
        assertEq(borrowerRequests.length, 1);
        assertEq(borrowerRequests[0], requestId);
    }

    function test_RevertIf_CreateLoanRequest_InsufficientCollateralBalance() public {
        vm.startPrank(borrower);
        mockUsdc.transfer(address(this), mockUsdc.balanceOf(borrower));
        vm.expectRevert(bytes("Insufficient collateral balance for request"));
        p2pLending.createLoanRequest(500 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 15 * ONE_DAY_SECONDS, 20 * 1e6, address(mockUsdc));
        vm.stopPrank();
    }

    function test_AcceptLoanOffer_Success_NoCollateral() public {
        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(100 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 7 * ONE_DAY_SECONDS, 0, address(0));
        mockDai.approve(address(p2pLending), 100 * 1e18);
        vm.stopPrank();
        uint256 lenderBalanceBefore = mockDai.balanceOf(lender);
        uint256 borrowerBalanceBefore = mockDai.balanceOf(borrower);
        vm.startPrank(borrower);
        vm.expectEmit(false, true, true, true, address(p2pLending));
        emit LoanAgreementFormed(bytes32(0), lender, borrower, 100 * 1e18, address(mockDai));
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, 0, address(0));
        vm.stopPrank();
        assertTrue(agreementId != bytes32(0));
        assertEq(mockDai.balanceOf(lender), lenderBalanceBefore - (100 * 1e18));
        assertEq(mockDai.balanceOf(borrower), borrowerBalanceBefore + (100 * 1e18));
        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(agreement.lender, lender);
        assertEq(agreement.borrower, borrower);
        assertEq(uint(agreement.status), uint(P2PLending.LoanStatus.Active));
        P2PLending.LoanOffer memory offer = p2pLending.getLoanOfferDetails(offerId);
        assertEq(uint(offer.status), uint(P2PLending.LoanStatus.AgreementReached));
    }

    function test_AcceptLoanOffer_Success_WithCollateral() public {
        uint256 collateralAmount = 30 * 1e6;
        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(150 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 10 * ONE_DAY_SECONDS, collateralAmount, address(mockUsdc));
        mockDai.approve(address(p2pLending), 150 * 1e18);
        vm.stopPrank();
        uint256 borrowerUsdcBefore = mockUsdc.balanceOf(borrower);
        uint256 contractUsdcBefore = mockUsdc.balanceOf(address(p2pLending));
        vm.startPrank(borrower);
        mockUsdc.approve(address(p2pLending), collateralAmount);
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, collateralAmount, address(mockUsdc));
        vm.stopPrank();
        assertTrue(agreementId != bytes32(0));
        assertEq(mockUsdc.balanceOf(borrower), borrowerUsdcBefore - collateralAmount);
        assertEq(mockUsdc.balanceOf(address(p2pLending)), contractUsdcBefore + collateralAmount);
        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(agreement.collateralAmount, collateralAmount);
        assertEq(agreement.collateralToken, address(mockUsdc));
    }

    function test_FundLoanRequest_Success_NoCollateral() public {
        vm.startPrank(borrower);
        bytes32 requestId = p2pLending.createLoanRequest(75 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 5 * ONE_DAY_SECONDS, 0, address(0));
        vm.stopPrank();
        uint256 lenderBalanceBefore = mockDai.balanceOf(lender);
        uint256 borrowerBalanceBefore = mockDai.balanceOf(borrower);
        vm.startPrank(lender);
        mockDai.approve(address(p2pLending), 75 * 1e18);
        bytes32 agreementId = p2pLending.fundLoanRequest(requestId);
        vm.stopPrank();
        assertTrue(agreementId != bytes32(0));
        assertEq(mockDai.balanceOf(lender), lenderBalanceBefore - (75 * 1e18));
        assertEq(mockDai.balanceOf(borrower), borrowerBalanceBefore + (75 * 1e18));
        P2PLending.LoanRequest memory loanReq = p2pLending.getLoanRequestDetails(requestId);
        assertEq(uint(loanReq.status), uint(P2PLending.LoanStatus.AgreementReached));
    }

    function test_FundLoanRequest_Success_WithCollateral() public {
        uint256 collateralAmount = 40 * 1e6;
        vm.startPrank(borrower);
        bytes32 requestId = p2pLending.createLoanRequest(200 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 12 * ONE_DAY_SECONDS, collateralAmount, address(mockUsdc));
        mockUsdc.approve(address(p2pLending), collateralAmount);
        vm.stopPrank();
        uint256 borrowerUsdcBefore = mockUsdc.balanceOf(borrower);
        uint256 contractUsdcBefore = mockUsdc.balanceOf(address(p2pLending));
        vm.startPrank(lender);
        mockDai.approve(address(p2pLending), 200 * 1e18);
        bytes32 agreementId = p2pLending.fundLoanRequest(requestId);
        vm.stopPrank();
        assertTrue(agreementId != bytes32(0));
        assertEq(mockUsdc.balanceOf(borrower), borrowerUsdcBefore - collateralAmount);
        assertEq(mockUsdc.balanceOf(address(p2pLending)), contractUsdcBefore + collateralAmount);
        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(agreement.collateralAmount, collateralAmount);
    }

    function test_RevertIf_AcceptOwnOffer() public {
        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(100e18, address(mockDai), 500, 30 days, 0, address(0));
        mockDai.approve(address(p2pLending), 100e18);
        vm.expectRevert(bytes("Cannot accept your own offer"));
        p2pLending.acceptLoanOffer(offerId, 0, address(0));
        vm.stopPrank();
    }

    function test_RevertIf_FundOwnRequest() public {
        vm.startPrank(borrower);
        bytes32 requestId = p2pLending.createLoanRequest(100e18, address(mockDai), 500, 30 days, 0, address(0));
        mockDai.approve(address(p2pLending), 100e18);
        vm.expectRevert(bytes("Cannot fund your own request"));
        p2pLending.fundLoanRequest(requestId);
        vm.stopPrank();
    }

    function test_RepayP2PLoan_Full_Success_NoCollateral() public {
        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(100e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 7 days, 0, address(0));
        mockDai.approve(address(p2pLending), 100e18);
        vm.stopPrank();
        vm.startPrank(borrower);
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, 0, address(0));
        vm.stopPrank();
        P2PLending.LoanAgreement memory agreementBeforeRepay = p2pLending.getLoanAgreementDetails(agreementId);
        uint256 totalDue = (agreementBeforeRepay.principalAmount * (BASIS_POINTS_TEST + agreementBeforeRepay.interestRate)) / BASIS_POINTS_TEST;
        uint256 borrowerDaiBeforeRepay = mockDai.balanceOf(borrower);
        uint256 lenderDaiBeforeRepay = mockDai.balanceOf(lender);
        
        vm.startPrank(borrower);
        mockDai.approve(address(p2pLending), totalDue);
        vm.expectEmit(false, true, true, true, address(p2pLending));
        emit LoanRepaymentMade(agreementId, totalDue, totalDue);
        vm.expectEmit(false, false, false, true, address(p2pLending));
        emit LoanAgreementRepaid(agreementId);
        vm.expectEmit(true, true, false, true, address(reputation));
        emit ReputationUpdated(borrower, reputation.REPUTATION_POINTS_REPAID(), "Loan repaid");
        vm.expectEmit(true, true, false, true, address(reputation));
        emit ReputationUpdated(lender, reputation.REPUTATION_POINTS_LENT_SUCCESSFULLY(), "Loan lent and repaid");

        p2pLending.repayP2PLoan(agreementId, totalDue);
        vm.stopPrank();

        assertEq(mockDai.balanceOf(borrower), borrowerDaiBeforeRepay - totalDue);
        assertEq(mockDai.balanceOf(lender), lenderDaiBeforeRepay + totalDue);
        P2PLending.LoanAgreement memory agreementAfterRepay = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(uint(agreementAfterRepay.status), uint(P2PLending.LoanStatus.Repaid));
        assertEq(agreementAfterRepay.amountPaid, totalDue);

        Reputation.ReputationProfile memory borrowerProfile = reputation.getReputationProfile(borrower);
        assertEq(borrowerProfile.currentReputationScore, reputation.REPUTATION_POINTS_REPAID());
    }

    function test_RepayP2PLoan_Partial_Then_Full_Success_WithCollateral() public {
        uint256 collateralAmount = 25 * 1e6;
        uint256 loanPrincipal = 50e18;
        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(loanPrincipal, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 14 days, collateralAmount, address(mockUsdc));
        mockDai.approve(address(p2pLending), loanPrincipal);
        vm.stopPrank();
        vm.startPrank(borrower);
        mockUsdc.approve(address(p2pLending), collateralAmount);
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, collateralAmount, address(mockUsdc));
        vm.stopPrank();
        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        uint256 totalDue = (agreement.principalAmount * (BASIS_POINTS_TEST + agreement.interestRate)) / BASIS_POINTS_TEST;
        uint256 partialPayment = totalDue / 2;
        uint256 borrowerUsdcBeforeReturn = mockUsdc.balanceOf(borrower);
        uint256 contractUsdcBeforeReturn = mockUsdc.balanceOf(address(p2pLending));
        
        vm.startPrank(borrower);
        mockDai.approve(address(p2pLending), partialPayment);
        p2pLending.repayP2PLoan(agreementId, partialPayment);
        vm.stopPrank();

        agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(agreement.amountPaid, partialPayment);
        assertEq(uint(agreement.status), uint(P2PLending.LoanStatus.Active));
        
        uint256 remainingPayment = totalDue - partialPayment;
        vm.startPrank(borrower);
        mockDai.approve(address(p2pLending), remainingPayment);
        vm.expectEmit(true, true, false, true, address(reputation));
        emit ReputationUpdated(borrower, reputation.REPUTATION_POINTS_REPAID(), "Loan repaid"); 
        vm.expectEmit(true, true, false, true, address(reputation));
        emit ReputationUpdated(lender, reputation.REPUTATION_POINTS_LENT_SUCCESSFULLY(), "Loan lent and repaid");
        p2pLending.repayP2PLoan(agreementId, remainingPayment);
        vm.stopPrank();

        agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(uint(agreement.status), uint(P2PLending.LoanStatus.Repaid));
        assertEq(agreement.amountPaid, totalDue);
        assertEq(mockUsdc.balanceOf(borrower), borrowerUsdcBeforeReturn + collateralAmount);
        assertEq(mockUsdc.balanceOf(address(p2pLending)), contractUsdcBeforeReturn - collateralAmount);
    }

    function test_RevertIf_RepayP2PLoan_NotBorrower() public {
        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(10e18, address(mockDai), 500, 7 days, 0, address(0));
        mockDai.approve(address(p2pLending), 10e18);
        vm.stopPrank();
        vm.startPrank(borrower);
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, 0, address(0));
        vm.stopPrank();
        vm.startPrank(lender);
        mockDai.approve(address(p2pLending), 1e18);
        vm.expectRevert(bytes("Only borrower can repay"));
        p2pLending.repayP2PLoan(agreementId, 1e18);
        vm.stopPrank();
    }

    function test_RevertIf_RepayP2PLoan_Overpayment() public {
        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(10e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 7 days, 0, address(0));
        mockDai.approve(address(p2pLending), 10e18);
        vm.stopPrank();
        vm.startPrank(borrower);
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, 0, address(0));
        vm.stopPrank();
        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        uint256 totalDue = (agreement.principalAmount * (BASIS_POINTS_TEST + agreement.interestRate)) / BASIS_POINTS_TEST;
        uint256 overPayment = totalDue + 1e18;
        vm.startPrank(borrower);
        mockDai.approve(address(p2pLending), overPayment);
        vm.expectRevert(bytes("Payment exceeds remaining due"));
        p2pLending.repayP2PLoan(agreementId, overPayment);
        vm.stopPrank();
    }

    function test_HandleP2PDefault_Success_WithCollateral() public {
        uint256 collateralAmount = 25 * 1e6;
        uint256 loanPrincipal = 50e18;
        uint256 loanDuration = 3 * ONE_DAY_SECONDS;

        // VOUCH SETUP: voucher1 vouches for borrower
        uint256 vouchStakeAmount = 200e18; // 200 DAI
        vm.startPrank(voucher1);
        mockDai.approve(address(reputation), vouchStakeAmount);
        reputation.addVouch(borrower, vouchStakeAmount, address(mockDai));
        vm.stopPrank();
        Reputation.ReputationProfile memory voucherProfileBefore = reputation.getReputationProfile(voucher1);
        uint256 voucherDaiBalanceBefore = mockDai.balanceOf(voucher1); // Should be unchanged by P2P default

        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(loanPrincipal, address(mockDai), DEFAULT_INTEREST_RATE_P2P, loanDuration, collateralAmount, address(mockUsdc));
        mockDai.approve(address(p2pLending), loanPrincipal);
        vm.stopPrank();
        vm.startPrank(borrower);
        mockUsdc.approve(address(p2pLending), collateralAmount);
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, collateralAmount, address(mockUsdc));
        vm.stopPrank();

        // Capture lender's DAI balance AFTER loan disbursal, before default
        uint256 lenderDaiBalanceBeforeSlash = mockDai.balanceOf(lender);

        vm.warp(block.timestamp + loanDuration + ONE_DAY_SECONDS);
        uint256 lenderUsdcBefore = mockUsdc.balanceOf(lender);
        uint256 contractUsdcBalanceBefore = mockUsdc.balanceOf(address(p2pLending));

        vm.expectEmit(false, false, false, true, address(p2pLending));
        emit LoanAgreementDefaulted(agreementId);

        vm.expectEmit(true, true, false, true, address(reputation));
        emit ReputationUpdated(borrower, reputation.REPUTATION_POINTS_DEFAULTED(), "Loan defaulted");
        
        uint256 expectedSlashAmount = (vouchStakeAmount * 1000) / BASIS_POINTS_TEST; // 10%
        vm.expectEmit(true, true, true, true, address(reputation));
        emit VouchSlashed(voucher1, borrower, expectedSlashAmount, lender);

        vm.expectEmit(true, true, false, true, address(reputation));
        emit ReputationUpdated(voucher1, voucherProfileBefore.currentReputationScore + reputation.REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER(), "Vouched loan defaulted, stake slashed");

        p2pLending.handleP2PDefault(agreementId);

        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(uint(agreement.status), uint(P2PLending.LoanStatus.Defaulted));
        assertEq(mockUsdc.balanceOf(lender), lenderUsdcBefore + collateralAmount);
        assertEq(mockUsdc.balanceOf(address(p2pLending)), contractUsdcBalanceBefore - collateralAmount);

        Reputation.ReputationProfile memory borrowerProfile = reputation.getReputationProfile(borrower);
        assertEq(borrowerProfile.currentReputationScore, reputation.REPUTATION_POINTS_DEFAULTED());

        // Check voucher state
        Reputation.ReputationProfile memory voucherProfileAfter = reputation.getReputationProfile(voucher1);
        assertEq(voucherProfileAfter.currentReputationScore, voucherProfileBefore.currentReputationScore + reputation.REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER(), "Voucher reputation incorrect");
        Reputation.Vouch memory vouchAfter = reputation.getVouchDetails(voucher1, borrower);
        assertEq(vouchAfter.stakedAmount, vouchStakeAmount - expectedSlashAmount, "Voucher stake incorrect");
        assertEq(mockDai.balanceOf(lender), lenderDaiBalanceBeforeSlash + expectedSlashAmount, "Lender DAI incorrect after slash");
        assertEq(mockDai.balanceOf(voucher1), voucherDaiBalanceBefore, "Voucher DAI balance should be unchanged directly");
        assertEq(mockDai.balanceOf(address(reputation)), vouchStakeAmount - expectedSlashAmount, "Reputation contract DAI after slash");
    }

    function test_HandleP2PDefault_Success_NoCollateral() public {
        uint256 loanPrincipal = 70e18;
        uint256 loanDuration = 2 * ONE_DAY_SECONDS;

        // VOUCH SETUP: voucher1 vouches for borrower
        uint256 vouchStakeAmount = 100e18; // 100 DAI
        vm.startPrank(voucher1);
        mockDai.approve(address(reputation), vouchStakeAmount);
        reputation.addVouch(borrower, vouchStakeAmount, address(mockDai));
        vm.stopPrank();
        Reputation.ReputationProfile memory voucherProfileBefore = reputation.getReputationProfile(voucher1);

        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(loanPrincipal, address(mockDai), DEFAULT_INTEREST_RATE_P2P, loanDuration, 0, address(0));
        mockDai.approve(address(p2pLending), loanPrincipal);
        vm.stopPrank();
        vm.startPrank(borrower);
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, 0, address(0));
        vm.stopPrank();

        // Capture lender's DAI balance AFTER loan disbursal, before default
        uint256 lenderDaiBalanceBeforeSlash = mockDai.balanceOf(lender);

        vm.warp(block.timestamp + loanDuration + ONE_DAY_SECONDS);

        vm.expectEmit(false, false, false, true, address(p2pLending));
        emit LoanAgreementDefaulted(agreementId);

        vm.expectEmit(true, true, false, true, address(reputation)); 
        emit ReputationUpdated(borrower, reputation.REPUTATION_POINTS_DEFAULTED(), "Loan defaulted");
        
        uint256 expectedSlashAmount = (vouchStakeAmount * 1000) / BASIS_POINTS_TEST; // 10%
        vm.expectEmit(true, true, true, true, address(reputation)); 
        emit VouchSlashed(voucher1, borrower, expectedSlashAmount, lender);
        
        vm.expectEmit(true, true, false, true, address(reputation)); 
        emit ReputationUpdated(voucher1, voucherProfileBefore.currentReputationScore + reputation.REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER(), "Vouched loan defaulted, stake slashed");

        p2pLending.handleP2PDefault(agreementId);

        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(uint(agreement.status), uint(P2PLending.LoanStatus.Defaulted));
        Reputation.ReputationProfile memory borrowerProfile = reputation.getReputationProfile(borrower);
        assertEq(borrowerProfile.currentReputationScore, reputation.REPUTATION_POINTS_DEFAULTED());

        // Check voucher state
        Reputation.ReputationProfile memory voucherProfileAfter = reputation.getReputationProfile(voucher1);
        assertEq(voucherProfileAfter.currentReputationScore, voucherProfileBefore.currentReputationScore + reputation.REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER(), "Voucher reputation incorrect no collateral");
        Reputation.Vouch memory vouchAfter = reputation.getVouchDetails(voucher1, borrower);
        assertEq(vouchAfter.stakedAmount, vouchStakeAmount - expectedSlashAmount, "Voucher stake incorrect no collateral");
        assertEq(mockDai.balanceOf(lender), lenderDaiBalanceBeforeSlash + expectedSlashAmount, "Lender DAI incorrect after slash no collateral");
    }

    function test_RevertIf_HandleP2PDefault_NotOverdue() public {
        vm.startPrank(lender); 
        bytes32 offerId = p2pLending.createLoanOffer(10e18, address(mockDai), 500, 7 days, 0, address(0));
        mockDai.approve(address(p2pLending), 10e18);
        vm.stopPrank();
        vm.startPrank(borrower); 
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, 0, address(0));
        vm.stopPrank();
        vm.expectRevert(bytes("Loan not yet overdue"));
        p2pLending.handleP2PDefault(agreementId);
    }

    function test_RevertIf_HandleP2PDefault_AlreadyRepaid() public {
        vm.startPrank(lender); 
        bytes32 offerId = p2pLending.createLoanOffer(10e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 7 days, 0, address(0));
        mockDai.approve(address(p2pLending), 10e18);
        vm.stopPrank();
        vm.startPrank(borrower); 
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, 0, address(0));
        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        uint256 totalDue = (agreement.principalAmount * (BASIS_POINTS_TEST + agreement.interestRate)) / BASIS_POINTS_TEST;
        mockDai.approve(address(p2pLending), totalDue);
        p2pLending.repayP2PLoan(agreementId, totalDue);
        vm.stopPrank();
        vm.warp(block.timestamp + 8 days);
        vm.expectRevert(bytes("Loan not active for default"));
        p2pLending.handleP2PDefault(agreementId);
    }
} 