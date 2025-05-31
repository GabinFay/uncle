// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UserRegistry.sol";
import "../src/P2PLending.sol"; // Changed from LoanContract.sol
import "./mocks/MockERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract P2PLendingTest is Test { // Renamed from LoanContractTest
    UserRegistry public userRegistry;
    P2PLending public p2pLending; // Renamed from loanContract
    MockERC20 public mockDai;
    MockERC20 public mockUsdc;

    address owner; 
    address borrower = vm.addr(1); // Will be user1 or lender1
    address lender = vm.addr(4);   // New role for P2P
    address platformWallet = vm.addr(2); 
    address voucher1 = vm.addr(3);
    address reputationOAppMockAddress = vm.addr(8); 

    bytes32 borrowerNullifier = keccak256(abi.encodePacked("borrowerN"));
    bytes32 lenderNullifier = keccak256(abi.encodePacked("lenderN")); // For lender registration
    bytes32 voucherNullifier = keccak256(abi.encodePacked("voucherN"));

    uint256 constant ONE_DAY_SECONDS = 1 days;
    uint256 constant DEFAULT_INTEREST_RATE_P2P = 500; // 5.00%
    address[] emptyVoucherAddresses; 

    // Events will be updated for P2P model
    // event LoanApplied(bytes32 indexed loanId, address indexed borrower, uint256 amount, address token);
    // ... other old events ...
    event LoanOfferCreated(bytes32 indexed offerId, address indexed lender, uint256 amount, address token, uint256 interestRate, uint256 duration);
    event LoanRequestCreated(bytes32 indexed requestId, address indexed borrower, uint256 amount, address token, uint256 proposedInterestRate, uint256 proposedDuration);
    event LoanAgreementFormed(bytes32 indexed agreementId, address indexed lender, address indexed borrower, uint256 amount, address token);
    event LoanRepaymentMade(bytes32 indexed agreementId, uint256 amountPaid, uint256 totalPaid);
    event LoanAgreementRepaid(bytes32 indexed agreementId);
    event LoanAgreementDefaulted(bytes32 indexed agreementId);


    function setUp() public {
        owner = address(this);

        userRegistry = new UserRegistry(); 
        p2pLending = new P2PLending( // Renamed from loanContract
            address(userRegistry),
            address(0), // Placeholder for Reputation contract address
            payable(address(0)), // Treasury placeholder, not used in P2P
            reputationOAppMockAddress
        );
        
        // Register users
        vm.prank(owner); userRegistry.registerOrUpdateUser(borrower, borrowerNullifier);
        vm.prank(owner); userRegistry.registerOrUpdateUser(lender, lenderNullifier); // Register lender
        vm.prank(owner); userRegistry.registerOrUpdateUser(voucher1, voucherNullifier);

        mockDai = new MockERC20("Mock DAI", "mDAI", 18);
        mockUsdc = new MockERC20("Mock USDC", "mUSDC", 6); 

        // Mint tokens
        mockDai.mint(borrower, 2000 * 1e18);
        mockDai.mint(lender, 10000 * 1e18); // Lender gets DAI to offer
        mockDai.mint(voucher1, 1000 * 1e18);
        mockUsdc.mint(borrower, 500 * 1e6); // For collateral if offered
        mockUsdc.mint(lender, 500 * 1e6);   // For collateral if required
    }

    // --- OLD LoanContract Tests - To be removed or completely refactored for P2P ---
    /*
    function test_ApplyForLoan_Success_NoCollateral() public { ... }
    function test_ApplyForLoan_Success_WithCollateral() public { ... }
    function test_RevertIf_ApplyForLoan_BorrowerNotVerified() public { ... }
    // ... many other old tests ...
    function test_LiquidateLoan_Success_WithVouchSlashing() public { ... } // This logic moves to Reputation + P2PLending interaction
    */

    // --- P2P Lending Tests (New) ---

    // test_CreateLoanOffer_Success()
    // test_CreateLoanRequest_Success()
    // test_AcceptLoanOffer_Success() (forms agreement)
    // test_FundLoanRequest_Success() (forms agreement)
    // test_RepayP2PLoan_Full_Success()
    // test_HandleP2PDefault_NoCollateral()
    // test_HandleP2PDefault_WithCollateral()
    // test_RevertIf_CreateOffer_UserNotVerified()
    // test_RevertIf_CreateRequest_UserNotVerified()
    // ... etc.

    // Placeholder to make the file compile for now
    // function test_Placeholder() public {
    //     assertTrue(true);
    // }

    // --- P2P Lending Tests (New) ---

    function test_CreateLoanOffer_Success() public {
        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(
            1000 * 1e18, // offerAmount
            address(mockDai), // loanToken
            DEFAULT_INTEREST_RATE_P2P, // interestRate
            30 * ONE_DAY_SECONDS, // duration
            50 * 1e6, // collateralRequiredAmount (USDC has 6 decimals)
            address(mockUsdc) // collateralRequiredToken
        );
        vm.stopPrank();

        assertTrue(offerId != bytes32(0), "Offer ID should not be zero");
        P2PLending.LoanOffer memory offer = p2pLending.getLoanOfferDetails(offerId);
        assertEq(offer.lender, lender, "Offer lender mismatch");
        assertEq(offer.offerAmount, 1000 * 1e18, "Offer amount mismatch");
        assertEq(uint(offer.status), uint(P2PLending.LoanStatus.OfferOpen), "Offer status should be Open");

        bytes32[] memory lenderOffers = p2pLending.getUserLoanOfferIds(lender);
        assertEq(lenderOffers.length, 1, "Lender should have one offer");
        assertEq(lenderOffers[0], offerId, "Lender offer ID mismatch");
    }

    function test_RevertIf_CreateLoanOffer_InsufficientBalance() public {
        vm.startPrank(lender);
        // mockDai.burn(lender, mockDai.balanceOf(lender)); // Burn all lender's DAI
        mockDai.transfer(address(this), mockDai.balanceOf(lender)); // Transfer all lender's DAI to test contract

        vm.expectRevert(bytes("Insufficient balance to create offer"));
        p2pLending.createLoanOffer(
            1000 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 30 * ONE_DAY_SECONDS, 0, address(0)
        );
        vm.stopPrank();
    }

    function test_CreateLoanRequest_Success() public {
        vm.startPrank(borrower);
        bytes32 requestId = p2pLending.createLoanRequest(
            500 * 1e18, // requestAmount
            address(mockDai), // loanToken
            DEFAULT_INTEREST_RATE_P2P + 100, // proposedInterestRate
            15 * ONE_DAY_SECONDS, // proposedDuration
            20 * 1e6, // offeredCollateralAmount (USDC)
            address(mockUsdc) // offeredCollateralToken
        );
        vm.stopPrank();

        assertTrue(requestId != bytes32(0), "Request ID should not be zero");
        P2PLending.LoanRequest memory loanReq = p2pLending.getLoanRequestDetails(requestId);
        assertEq(loanReq.borrower, borrower, "Request borrower mismatch");
        assertEq(loanReq.requestAmount, 500 * 1e18, "Request amount mismatch");
        assertEq(uint(loanReq.status), uint(P2PLending.LoanStatus.RequestOpen), "Request status should be Open");

        bytes32[] memory borrowerRequests = p2pLending.getUserLoanRequestIds(borrower);
        assertEq(borrowerRequests.length, 1, "Borrower should have one request");
        assertEq(borrowerRequests[0], requestId, "Borrower request ID mismatch");
    }

    function test_RevertIf_CreateLoanRequest_InsufficientCollateralBalance() public {
        vm.startPrank(borrower);
        // mockUsdc.burn(borrower, mockUsdc.balanceOf(borrower)); // Burn all borrower's USDC
        mockUsdc.transfer(address(this), mockUsdc.balanceOf(borrower)); // Transfer all borrower's USDC to test contract

        vm.expectRevert(bytes("Insufficient collateral balance for request"));
        p2pLending.createLoanRequest(
            500 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 15 * ONE_DAY_SECONDS, 
            20 * 1e6, address(mockUsdc) // Requesting collateral but borrower has none
        );
        vm.stopPrank();
    }

    function test_AcceptLoanOffer_Success_NoCollateral() public {
        // 1. Lender creates an offer with no collateral requirement
        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(
            100 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 7 * ONE_DAY_SECONDS, 0, address(0)
        );
        // Lender approves P2PLending contract to spend their DAI
        mockDai.approve(address(p2pLending), 100 * 1e18);
        vm.stopPrank();

        uint256 lenderBalanceBefore = mockDai.balanceOf(lender);
        uint256 borrowerBalanceBefore = mockDai.balanceOf(borrower);

        // 2. Borrower accepts the offer
        vm.startPrank(borrower);
        vm.expectEmit(false, true, true, true, address(p2pLending)); // Don't check agreementId (topic1), check lender (topic2), borrower (topic3), and data.
        emit LoanAgreementFormed(bytes32(0), lender, borrower, 100 * 1e18, address(mockDai)); // Provide dummy agreementId for matching other params
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, 0, address(0));
        vm.stopPrank();

        assertTrue(agreementId != bytes32(0), "Agreement ID should not be zero");
        assertEq(mockDai.balanceOf(lender), lenderBalanceBefore - (100 * 1e18), "Lender balance incorrect");
        assertEq(mockDai.balanceOf(borrower), borrowerBalanceBefore + (100 * 1e18), "Borrower balance incorrect");

        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(agreement.lender, lender, "Agreement lender mismatch");
        assertEq(agreement.borrower, borrower, "Agreement borrower mismatch");
        assertEq(uint(agreement.status), uint(P2PLending.LoanStatus.Active), "Agreement status should be Active");

        P2PLending.LoanOffer memory offer = p2pLending.getLoanOfferDetails(offerId);
        assertEq(uint(offer.status), uint(P2PLending.LoanStatus.AgreementReached), "Offer status incorrect");
    }

    function test_AcceptLoanOffer_Success_WithCollateral() public {
        uint256 collateralAmount = 30 * 1e6; // USDC
        // 1. Lender creates an offer REQUIRING collateral
        vm.startPrank(lender);
        bytes32 offerId = p2pLending.createLoanOffer(
            150 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 10 * ONE_DAY_SECONDS, 
            collateralAmount, address(mockUsdc)
        );
        mockDai.approve(address(p2pLending), 150 * 1e18);
        vm.stopPrank();

        uint256 borrowerUsdcBefore = mockUsdc.balanceOf(borrower);
        uint256 contractUsdcBefore = mockUsdc.balanceOf(address(p2pLending));

        // 2. Borrower accepts the offer, providing collateral
        vm.startPrank(borrower);
        mockUsdc.approve(address(p2pLending), collateralAmount); // Borrower approves collateral transfer
        bytes32 agreementId = p2pLending.acceptLoanOffer(offerId, collateralAmount, address(mockUsdc));
        vm.stopPrank();

        assertTrue(agreementId != bytes32(0), "Agreement ID should not be zero (with collateral)");
        assertEq(mockUsdc.balanceOf(borrower), borrowerUsdcBefore - collateralAmount, "Borrower USDC balance incorrect");
        assertEq(mockUsdc.balanceOf(address(p2pLending)), contractUsdcBefore + collateralAmount, "Contract USDC balance incorrect");

        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(agreement.collateralAmount, collateralAmount, "Agreement collateral amount mismatch");
        assertEq(agreement.collateralToken, address(mockUsdc), "Agreement collateral token mismatch");
    }

    function test_FundLoanRequest_Success_NoCollateral() public {
        // 1. Borrower creates a request with no collateral offered
        vm.startPrank(borrower);
        bytes32 requestId = p2pLending.createLoanRequest(
            75 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 5 * ONE_DAY_SECONDS, 0, address(0)
        );
        vm.stopPrank();

        uint256 lenderBalanceBefore = mockDai.balanceOf(lender);
        uint256 borrowerBalanceBefore = mockDai.balanceOf(borrower);

        // 2. Lender funds the request
        vm.startPrank(lender);
        mockDai.approve(address(p2pLending), 75 * 1e18); // Lender approves P2PLending contract
        bytes32 agreementId = p2pLending.fundLoanRequest(requestId);
        vm.stopPrank();

        assertTrue(agreementId != bytes32(0), "Agreement ID should not be zero (fund request)");
        assertEq(mockDai.balanceOf(lender), lenderBalanceBefore - (75 * 1e18), "Lender balance incorrect (fund request)");
        assertEq(mockDai.balanceOf(borrower), borrowerBalanceBefore + (75 * 1e18), "Borrower balance incorrect (fund request)");

        P2PLending.LoanRequest memory loanReq = p2pLending.getLoanRequestDetails(requestId);
        assertEq(uint(loanReq.status), uint(P2PLending.LoanStatus.AgreementReached), "Request status incorrect");
    }

    function test_FundLoanRequest_Success_WithCollateral() public {
        uint256 collateralAmount = 40 * 1e6; // USDC
        // 1. Borrower creates a request OFFERING collateral
        vm.startPrank(borrower);
        bytes32 requestId = p2pLending.createLoanRequest(
            200 * 1e18, address(mockDai), DEFAULT_INTEREST_RATE_P2P, 12 * ONE_DAY_SECONDS, 
            collateralAmount, address(mockUsdc)
        );
        // Borrower approves P2PLending contract to spend their collateral
        mockUsdc.approve(address(p2pLending), collateralAmount); 
        vm.stopPrank();

        uint256 borrowerUsdcBefore = mockUsdc.balanceOf(borrower);
        uint256 contractUsdcBefore = mockUsdc.balanceOf(address(p2pLending));

        // 2. Lender funds the request
        vm.startPrank(lender);
        mockDai.approve(address(p2pLending), 200 * 1e18);
        bytes32 agreementId = p2pLending.fundLoanRequest(requestId);
        vm.stopPrank();

        assertTrue(agreementId != bytes32(0), "Agreement ID should not be zero (fund request with collateral)");
        assertEq(mockUsdc.balanceOf(borrower), borrowerUsdcBefore - collateralAmount, "Borrower USDC balance incorrect (fund request)");
        assertEq(mockUsdc.balanceOf(address(p2pLending)), contractUsdcBefore + collateralAmount, "Contract USDC balance incorrect (fund request)");

        P2PLending.LoanAgreement memory agreement = p2pLending.getLoanAgreementDetails(agreementId);
        assertEq(agreement.collateralAmount, collateralAmount, "Agreement collateral amount mismatch (fund request)");
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

    // test_RepayP2PLoan_Full_Success()
} 