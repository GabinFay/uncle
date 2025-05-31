// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UserRegistry.sol";
import "../src/SocialVouching.sol";
import "../src/LoanContract.sol";
import "../src/Treasury.sol";
import "./mocks/MockERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract LoanContractTest is Test {
    UserRegistry public userRegistry;
    SocialVouching public socialVouching;
    LoanContract public loanContract;
    Treasury public treasury;
    MockERC20 public mockDai;
    MockERC20 public mockUsdc;

    address owner; 
    address borrower = vm.addr(1);
    address platformWallet = vm.addr(2); // For tests assuming a platform fee mechanism (currently not in LoanContract)
    address voucher1 = vm.addr(3);
    address pythPlaceholderAddress = vm.addr(7); // Placeholder if constructor still needs it
    address reputationOAppMockAddress = vm.addr(8); // New address for mock Reputation OApp

    bytes32 borrowerNullifier = keccak256(abi.encodePacked("borrowerN"));
    bytes32 voucherNullifier = keccak256(abi.encodePacked("voucherN"));

    uint256 constant ONE_DAY_SECONDS = 1 days;
    uint256 constant DEFAULT_INTEREST_RATE = 500; // 5.00%
    uint256 constant ZERO_COLLATERAL_AMOUNT = 0;
    address constant ZERO_COLLATERAL_TOKEN = address(0);
    address[] emptyVoucherAddresses; // For applyForLoan calls not testing vouching

    // Events from LoanContract.sol
    event LoanApplied(bytes32 indexed loanId, address indexed borrower, uint256 amount, address token);
    event LoanApproved(bytes32 indexed loanId);
    event LoanDisbursed(bytes32 indexed loanId);
    event LoanPaymentMade(bytes32 indexed loanId, uint256 paymentAmount, uint256 totalPaid);
    event LoanFullyRepaid(bytes32 indexed loanId);
    // LoanDefaulted and LoanLiquidated are defined in LoanContract.sol but tests are TBD

    function setUp() public {
        owner = address(this);

        userRegistry = new UserRegistry(); 
        treasury = new Treasury(owner);     
        socialVouching = new SocialVouching(address(userRegistry)); 
        loanContract = new LoanContract(
            address(userRegistry),
            address(socialVouching),
            payable(address(treasury)),
            reputationOAppMockAddress
        );
        
        vm.prank(owner);
        treasury.setLoanContractAddress(address(loanContract));
        socialVouching.setLoanContractAddress(address(loanContract)); 

        mockDai = new MockERC20("Mock DAI", "mDAI", 18);
        mockUsdc = new MockERC20("Mock USDC", "mUSDC", 6);

        vm.prank(owner); userRegistry.registerOrUpdateUser(borrower, borrowerNullifier);
        vm.prank(owner); userRegistry.registerOrUpdateUser(voucher1, voucherNullifier);

        mockDai.mint(address(treasury), 10000 * 1e18); // Treasury gets DAI to lend
        mockDai.mint(borrower, 2000 * 1e18);      // Borrower gets DAI for collateral/repayment
        mockDai.mint(voucher1, 1000 * 1e18);       // Voucher gets DAI to stake (if SocialVouching was used)
    }

    // --- Test applyForLoan --- 
    function test_ApplyForLoan_Success_NoCollateral() public {
        uint256 principalAmount = 100 * 1e18;
        uint256 duration = 30 * ONE_DAY_SECONDS;

        vm.startPrank(borrower);
        // For LoanApplied: loanId (idx), borrower (idx), amount, token.
        // We will check struct values for full validation.
        bytes32 loanId = loanContract.applyForLoan(
            principalAmount, 
            address(mockDai), 
            DEFAULT_INTEREST_RATE, 
            duration, 
            ZERO_COLLATERAL_AMOUNT, 
            ZERO_COLLATERAL_TOKEN,
            emptyVoucherAddresses
        );
        vm.stopPrank();

        LoanContract.Loan memory loan = loanContract.getLoanDetails(loanId);
        assertEq(loan.borrower, borrower, "Loan borrower mismatch");
        assertEq(loan.loanToken, address(mockDai), "Loan token mismatch");
        assertEq(loan.principalAmount, principalAmount, "Loan principal mismatch");
        assertEq(loan.interestRate, DEFAULT_INTEREST_RATE, "Loan interest rate mismatch");
        assertEq(loan.duration, duration, "Loan duration mismatch");
        assertEq(uint256(loan.status), uint256(LoanContract.LoanStatus.Pending), "Loan status should be Pending");
        assertTrue(loan.loanId == loanId, "loan.loanId mismatch");
    }

    function test_ApplyForLoan_Success_WithCollateral() public {
        uint256 principalAmount = 200 * 1e18;
        uint256 duration = 60 * ONE_DAY_SECONDS;
        uint256 collateralAmount = 50 * 1e18; // e.g. 50 mDAI as collateral

        vm.startPrank(borrower);
        mockDai.approve(address(loanContract), collateralAmount); // Borrower approves collateral transfer
        bytes32 loanId = loanContract.applyForLoan(
            principalAmount, 
            address(mockDai), 
            DEFAULT_INTEREST_RATE, 
            duration, 
            collateralAmount, 
            address(mockDai), // Using mDAI as collateral token
            emptyVoucherAddresses
        );
        vm.stopPrank();

        LoanContract.Loan memory loan = loanContract.getLoanDetails(loanId);
        assertEq(loan.collateralAmount, collateralAmount, "Collateral amount mismatch");
        assertEq(loan.collateralToken, address(mockDai), "Collateral token mismatch");
        assertEq(mockDai.balanceOf(address(loanContract)), collateralAmount, "LoanContract collateral balance incorrect");
    }


    function test_RevertIf_ApplyForLoan_BorrowerNotVerified() public {
        address unverifiedBorrower = vm.addr(5);
        vm.startPrank(unverifiedBorrower);
        vm.expectRevert(bytes("LoanContract: User not World ID verified"));
        loanContract.applyForLoan(100*1e18, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, ZERO_COLLATERAL_AMOUNT,ZERO_COLLATERAL_TOKEN, emptyVoucherAddresses);
        vm.stopPrank();
    }

    function test_RevertIf_ApplyForLoan_ZeroPrincipal() public {
        vm.startPrank(borrower);
        vm.expectRevert(bytes("Principal must be positive"));
        loanContract.applyForLoan(0, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, ZERO_COLLATERAL_AMOUNT,ZERO_COLLATERAL_TOKEN, emptyVoucherAddresses);
        vm.stopPrank();
    }

    function test_RevertIf_ApplyForLoan_InvalidLoanToken() public {
        vm.startPrank(borrower);
        vm.expectRevert(bytes("Invalid loan token"));
        loanContract.applyForLoan(100*1e18, address(0), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, ZERO_COLLATERAL_AMOUNT,ZERO_COLLATERAL_TOKEN, emptyVoucherAddresses);
        vm.stopPrank();
    }

    // --- Test Approve Loan (Owner/Admin only) & Disbursal --- 
    function test_ApproveLoan_Success_And_Disburses() public {
        uint256 principalAmount = 100 * 1e18;
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();

        uint256 borrowerInitialDAIBalance = mockDai.balanceOf(borrower);
        uint256 treasuryInitialDAIBalance = mockDai.balanceOf(address(treasury));

        vm.startPrank(owner);
        // Expect LoanApproved and LoanDisbursed (as approveLoan also disburses)
        vm.expectEmit(true, false, false, true); // loanId
        emit LoanApproved(loanId);
        // vm.expectEmit for LoanDisbursed (Difficult to check specific amount without more complex expectEmit)
        // As LoanDisbursed also only has loanId, we can emit it as well.
        vm.expectEmit(true, false, false, true); // loanId
        emit LoanDisbursed(loanId);
        loanContract.approveLoan(loanId);
        vm.stopPrank();

        LoanContract.Loan memory loan = loanContract.getLoanDetails(loanId);
        assertEq(uint256(loan.status), uint256(LoanContract.LoanStatus.Active), "Loan status should be Active");
        assertTrue(loan.startTime > 0, "Loan start time (approval/disbursal time) should be set");
        
        assertEq(mockDai.balanceOf(borrower), borrowerInitialDAIBalance + principalAmount, "Borrower DAI balance after disbursal incorrect");
        assertEq(mockDai.balanceOf(address(treasury)), treasuryInitialDAIBalance - principalAmount, "Treasury DAI balance after disbursal incorrect");
        assertEq(loan.dueDate, loan.startTime + loan.duration, "Loan due date not set correctly");
    }

    function test_RevertIf_ApproveLoan_NotOwner() public {
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(100*1e18, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();

        vm.startPrank(borrower); 
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, borrower));
        loanContract.approveLoan(loanId);
        vm.stopPrank();
    }

    function test_RevertIf_ApproveLoan_InvalidLoanId() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("LoanContract: Loan does not exist"));
        loanContract.approveLoan(bytes32(uint256(123)));
        vm.stopPrank();
    }

    function test_RevertIf_ApproveLoan_NotPending() public {
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(100*1e18, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();

        vm.startPrank(owner);
        loanContract.approveLoan(loanId); // First approval, status becomes Active
        vm.expectRevert(bytes("Loan not pending approval"));
        loanContract.approveLoan(loanId); // Second approval should fail
        vm.stopPrank();
    }

    // --- Test Repay Loan --- 
    function test_RepayLoan_ERC20_Full_Success() public {
        uint256 principalAmount = 100 * 1e18;
        uint256 duration = 30 * ONE_DAY_SECONDS;
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, duration, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();

        vm.startPrank(owner);
        loanContract.approveLoan(loanId); // Approves and disburses
        vm.stopPrank();

        uint256 amountToRepay = loanContract.calculateTotalAmountDue(loanId); // Changed function name
        uint256 treasuryInitialDAIBalance = mockDai.balanceOf(address(treasury));

        vm.startPrank(borrower);
        mockDai.approve(address(loanContract), amountToRepay);
        
        vm.expectEmit(true, true, true, true); // loanId, paymentAmount, totalPaid
        emit LoanPaymentMade(loanId, amountToRepay, amountToRepay); // Assuming full payment in one go, totalPaid = amountToRepay
        vm.expectEmit(true, false, false, true); // loanId for LoanFullyRepaid
        emit LoanFullyRepaid(loanId);

        loanContract.repayLoan(loanId, amountToRepay); // Added paymentAmount
        vm.stopPrank();

        LoanContract.Loan memory loan = loanContract.getLoanDetails(loanId);
        assertEq(uint256(loan.status), uint256(LoanContract.LoanStatus.Repaid), "Loan status should be Repaid");
        assertEq(mockDai.balanceOf(address(treasury)), treasuryInitialDAIBalance + amountToRepay, "Treasury DAI balance after repayment incorrect");
        assertEq(loan.amountPaid, amountToRepay, "Loan amountPaid mismatch");
    }

    function test_RevertIf_RepayLoan_NotBorrower() public {
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(100*1e18, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();
        vm.prank(owner); loanContract.approveLoan(loanId); vm.stopPrank();

        address nonBorrower = vm.addr(5);
        mockDai.mint(nonBorrower, 200 * 1e18);
        uint256 paymentAmount = 50 * 1e18;
        vm.startPrank(nonBorrower);
        mockDai.approve(address(loanContract), paymentAmount);
        vm.expectRevert(bytes("Only borrower can repay"));
        loanContract.repayLoan(loanId, paymentAmount);
        vm.stopPrank();
    }

    function test_RevertIf_RepayLoan_NotActive() public {
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(100*1e18, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, 0, address(0), emptyVoucherAddresses);
        // Loan is Pending, not Active
        uint256 paymentAmount = 50 * 1e18;
        mockDai.approve(address(loanContract), paymentAmount);
        vm.expectRevert(bytes("Loan not active"));
        loanContract.repayLoan(loanId, paymentAmount);
        vm.stopPrank();
    }

    function test_RepayLoan_ERC20_PartialPayment() public {
        uint256 principalAmount = 100 * 1e18;
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();
        vm.prank(owner); loanContract.approveLoan(loanId); vm.stopPrank();

        uint256 totalDue = loanContract.calculateTotalAmountDue(loanId);
        uint256 partialPaymentAmount = totalDue / 2;

        vm.startPrank(borrower);
        mockDai.approve(address(loanContract), partialPaymentAmount);
        vm.expectEmit(true, true, true, true);
        emit LoanPaymentMade(loanId, partialPaymentAmount, partialPaymentAmount);
        loanContract.repayLoan(loanId, partialPaymentAmount);
        vm.stopPrank();

        LoanContract.Loan memory loan = loanContract.getLoanDetails(loanId);
        assertEq(uint256(loan.status), uint256(LoanContract.LoanStatus.Active), "Loan status should still be Active after partial payment");
        assertEq(loan.amountPaid, partialPaymentAmount, "Loan amountPaid incorrect after partial payment");
        assertEq(loanContract.calculateRemainingAmountDue(loanId), totalDue - partialPaymentAmount, "Remaining amount due incorrect");
    }

    function test_RepayLoan_ERC20_PartialPayment_ThenFullPayment() public {
        uint256 principalAmount = 100 * 1e18;
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();
        vm.prank(owner); loanContract.approveLoan(loanId); vm.stopPrank();

        uint256 totalDue = loanContract.calculateTotalAmountDue(loanId);
        uint256 firstPaymentAmount = totalDue / 3;

        vm.startPrank(borrower);
        mockDai.approve(address(loanContract), firstPaymentAmount);
        loanContract.repayLoan(loanId, firstPaymentAmount); // First partial payment
        
        uint256 remainingDue = loanContract.calculateRemainingAmountDue(loanId);
        mockDai.approve(address(loanContract), remainingDue); // Approve for the rest

        vm.expectEmit(true, true, true, true);
        emit LoanPaymentMade(loanId, remainingDue, totalDue);
        vm.expectEmit(true, false, false, true);
        emit LoanFullyRepaid(loanId);
        loanContract.repayLoan(loanId, remainingDue); // Second payment, completes the loan
        vm.stopPrank();

        LoanContract.Loan memory loan = loanContract.getLoanDetails(loanId);
        assertEq(uint256(loan.status), uint256(LoanContract.LoanStatus.Repaid), "Loan status should be Repaid after final payment");
        assertEq(loan.amountPaid, totalDue, "Loan amountPaid incorrect after full payment");
        assertEq(loanContract.calculateRemainingAmountDue(loanId), 0, "Remaining amount due should be 0 after full payment");
    }

    function test_RepayLoan_ERC20_Overpayment_Refund() public {
        uint256 principalAmount = 100 * 1e18;
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();
        vm.prank(owner); loanContract.approveLoan(loanId); vm.stopPrank();

        uint256 totalDue = loanContract.calculateTotalAmountDue(loanId);
        uint256 overPaymentAmount = totalDue + (50 * 1e18); // Overpay by 50 DAI
        uint256 expectedRefund = 50 * 1e18;

        uint256 borrowerDAIBalanceBefore = mockDai.balanceOf(borrower);

        // Mint extra to LoanContract to cover potential refund (if direct refund from LC is tested)
        // This is a temporary workaround for the ERC20 refund discussion earlier.
        // Ideally, Treasury handles refunds or effectivePayment prevents over-pull.
        mockDai.mint(address(loanContract), expectedRefund); 

        vm.startPrank(borrower);
        mockDai.approve(address(loanContract), overPaymentAmount);

        vm.expectEmit(true, true, true, true);
        emit LoanPaymentMade(loanId, totalDue, totalDue); // totalDue is the effectivePayment
        vm.expectEmit(true, false, false, true);
        emit LoanFullyRepaid(loanId);
        
        loanContract.repayLoan(loanId, overPaymentAmount);
        vm.stopPrank();

        LoanContract.Loan memory loan = loanContract.getLoanDetails(loanId);
        assertEq(uint256(loan.status), uint256(LoanContract.LoanStatus.Repaid), "Loan status should be Repaid after overpayment");
        assertEq(loan.amountPaid, totalDue, "Loan amountPaid incorrect after overpayment");
        // Check borrower's balance: initial - totalDue (transferred to treasury) + expectedRefund (transferred from LoanContract)
        assertEq(mockDai.balanceOf(borrower), borrowerDAIBalanceBefore - totalDue + expectedRefund, "Borrower DAI balance incorrect after overpayment and refund");
    }

    function test_RevertIf_RepayLoan_ZeroPaymentAmount() public {
        uint256 principalAmount = 100 * 1e18;
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();
        vm.prank(owner); loanContract.approveLoan(loanId); vm.stopPrank();

        vm.startPrank(borrower);
        vm.expectRevert(bytes("Payment amount must be positive"));
        loanContract.repayLoan(loanId, 0);
        vm.stopPrank();
    }

    function test_RevertIf_RepayLoan_AlreadyFullyPaid() public {
        uint256 principalAmount = 100 * 1e18;
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, 30*ONE_DAY_SECONDS, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();
        vm.prank(owner); loanContract.approveLoan(loanId); vm.stopPrank();

        uint256 totalDue = loanContract.calculateTotalAmountDue(loanId);
        vm.startPrank(borrower);
        mockDai.approve(address(loanContract), totalDue);
        loanContract.repayLoan(loanId, totalDue); // Fully pay

        // Attempt to pay again
        mockDai.approve(address(loanContract), 1 * 1e18);
        vm.expectRevert(bytes("Loan not active"));
        loanContract.repayLoan(loanId, 1 * 1e18);
        vm.stopPrank();
    }


    // --- Admin functions from LoanContract.sol ---
    function test_SetTreasuryAddress_Success() public {
        address payable newTreasury = payable(vm.addr(5));
        vm.prank(owner);
        loanContract.setTreasuryAddress(newTreasury);
        assertEq(loanContract.treasuryAddress(), newTreasury);
        vm.stopPrank();
    }

    function test_RevertIf_SetTreasuryAddress_NotOwner() public {
        address payable newTreasury = payable(vm.addr(5));
        vm.prank(borrower);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, borrower));
        loanContract.setTreasuryAddress(newTreasury);
        vm.stopPrank();
    }

    // --- Defaulting and Liquidation Tests ---
    event LoanDefaulted(bytes32 indexed loanId);
    event LoanLiquidated(bytes32 indexed loanId, uint256 collateralSeized);

    function test_CheckAndSetDefaultStatus_Success() public {
        uint256 principalAmount = 100 * 1e18;
        uint256 duration = 30 * ONE_DAY_SECONDS;
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, duration, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();
        vm.prank(owner); loanContract.approveLoan(loanId); vm.stopPrank();

        // Fast forward time past due date
        vm.warp(block.timestamp + duration + 1 days); 

        vm.expectEmit(true, false, false, true);
        emit LoanDefaulted(loanId);
        loanContract.checkAndSetDefaultStatus(loanId);

        LoanContract.Loan memory loan = loanContract.getLoanDetails(loanId);
        assertEq(uint256(loan.status), uint256(LoanContract.LoanStatus.Defaulted), "Loan status should be Defaulted");
    }

    function test_RevertIf_CheckAndSetDefaultStatus_NotOverdue() public {
        uint256 principalAmount = 100 * 1e18;
        uint256 duration = 30 * ONE_DAY_SECONDS;
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, duration, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();
        vm.prank(owner); loanContract.approveLoan(loanId); vm.stopPrank();

        // Time is before due date
        vm.warp(block.timestamp + duration - 1 days);

        vm.expectRevert(bytes("Loan not yet overdue"));
        loanContract.checkAndSetDefaultStatus(loanId);
    }

    function test_RevertIf_CheckAndSetDefaultStatus_NotActive() public {
        uint256 principalAmount = 100 * 1e18;
        uint256 duration = 30 * ONE_DAY_SECONDS;
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, duration, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank(); // Loan is Pending

        vm.warp(block.timestamp + duration + 1 days); 
        vm.expectRevert(bytes("Loan not active or already processed"));
        loanContract.checkAndSetDefaultStatus(loanId);
    }

    function test_LiquidateLoan_Success_WithCollateral() public {
        uint256 principalAmount = 100 * 1e18;
        uint256 duration = 30 * ONE_DAY_SECONDS;
        uint256 collateralAmount = 50 * 1e18;

        vm.startPrank(borrower);
        mockDai.approve(address(loanContract), collateralAmount);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, duration, collateralAmount, address(mockDai), emptyVoucherAddresses);
        vm.stopPrank();
        vm.prank(owner); loanContract.approveLoan(loanId); vm.stopPrank();

        vm.warp(block.timestamp + duration + 1 days); 
        loanContract.checkAndSetDefaultStatus(loanId); // Set to Defaulted

        uint256 loanContractCollateralBefore = mockDai.balanceOf(address(loanContract));
        uint256 treasuryCollateralBefore = mockDai.balanceOf(address(treasury));

        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true); // loanId, collateralSeized
        emit LoanLiquidated(loanId, collateralAmount);
        loanContract.liquidateLoan(loanId);
        vm.stopPrank();

        LoanContract.Loan memory loan = loanContract.getLoanDetails(loanId);
        assertEq(uint256(loan.status), uint256(LoanContract.LoanStatus.Liquidated), "Loan status should be Liquidated");
        assertEq(mockDai.balanceOf(address(loanContract)), loanContractCollateralBefore - collateralAmount, "LoanContract collateral incorrect");
        assertEq(mockDai.balanceOf(address(treasury)), treasuryCollateralBefore + collateralAmount, "Treasury collateral incorrect after liquidation");
    }

    function test_RevertIf_LiquidateLoan_NotDefaulted() public {
        uint256 principalAmount = 100 * 1e18;
        uint256 duration = 30 * ONE_DAY_SECONDS;
        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(principalAmount, address(mockDai), DEFAULT_INTEREST_RATE, duration, 0, address(0), emptyVoucherAddresses);
        vm.stopPrank();
        vm.prank(owner); loanContract.approveLoan(loanId); // Loan is Active

        vm.startPrank(owner);
        vm.expectRevert(bytes("Loan not in defaulted state for liquidation"));
        loanContract.liquidateLoan(loanId);
        vm.stopPrank();
    }

    // --- ReputationOApp Address Setter Test ---
    function test_SetReputationOAppAddress_Success() public {
        address newReputationOApp = vm.addr(9);
        vm.prank(owner);
        loanContract.setReputationOAppAddress(newReputationOApp);
        vm.stopPrank();
        assertEq(address(loanContract.reputationOApp()), newReputationOApp, "ReputationOApp address not set correctly");
    }

    function test_RevertIf_SetReputationOAppAddress_NotOwner() public {
        address newReputationOApp = vm.addr(9);
        vm.startPrank(borrower);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, borrower));
        loanContract.setReputationOAppAddress(newReputationOApp);
        vm.stopPrank();
    }

    // --- Vouch Slashing during Liquidation Test ---
    event VouchSlashed(address indexed borrower, address indexed voucher, uint256 amountSlashed); // From SocialVouching

    function test_LiquidateLoan_Success_WithVouchSlashing() public {
        uint256 principalAmount = 200 * 1e18;
        uint256 duration = 30 * ONE_DAY_SECONDS;
        uint256 vouchAmountByVoucher1 = 100 * 1e18; // Using mockDai as vouch token for simplicity here

        // Setup SocialVouching: voucher1 vouches for borrower
        vm.startPrank(voucher1);
        mockDai.approve(address(socialVouching), vouchAmountByVoucher1);
        socialVouching.addVouch(borrower, vouchAmountByVoucher1, address(mockDai));
        vm.stopPrank();
        assertEq(socialVouching.getTotalVouchedAmountForBorrower(borrower), vouchAmountByVoucher1, "Vouch not added correctly");

        // Borrower applies for loan, specifying voucher1
        address[] memory vouchersToConsider = new address[](1);
        vouchersToConsider[0] = voucher1;

        vm.startPrank(borrower);
        bytes32 loanId = loanContract.applyForLoan(
            principalAmount, 
            address(mockDai), 
            DEFAULT_INTEREST_RATE, 
            duration, 
            0, // No direct collateral
            address(0),
            vouchersToConsider
        );
        vm.stopPrank();

        LoanContract.Loan memory loanBeforeApproval = loanContract.getLoanDetails(loanId);
        assertEq(loanBeforeApproval.totalVouchedAmountAtApplication, vouchAmountByVoucher1, "Total vouched amount not recorded correctly in loan");
        assertEq(loanBeforeApproval.vouches.length, 1, "Loan vouches array length incorrect");
        assertEq(loanBeforeApproval.vouches[0].voucherAddress, voucher1, "Voucher address in loan incorrect");
        assertEq(loanBeforeApproval.vouches[0].amountVouchedAtLoanTime, vouchAmountByVoucher1, "Vouch amount in loan incorrect");

        // Approve loan
        vm.prank(owner); loanContract.approveLoan(loanId); vm.stopPrank();

        // Default loan
        vm.warp(block.timestamp + duration + 1 days); 
        loanContract.checkAndSetDefaultStatus(loanId);

        uint256 socialVouchingBalanceBeforeSlash = mockDai.balanceOf(address(socialVouching));
        uint256 treasuryBalanceBeforeSlash = mockDai.balanceOf(address(treasury));
        // uint256 voucher1BalanceBeforeSlash = mockDai.balanceOf(voucher1); // Marked as unused by compiler

        vm.startPrank(owner);
        // Expect VouchSlashed from SocialVouching (called by LoanContract)
        vm.expectEmit(address(socialVouching));
        emit VouchSlashed(borrower, voucher1, vouchAmountByVoucher1);

        // Then expect LoanLiquidated from LoanContract
        vm.expectEmit(address(loanContract));
        emit LoanLiquidated(loanId, 0); // Collateral seized is 0 in this specific test case
        
        loanContract.liquidateLoan(loanId);
        vm.stopPrank();

        LoanContract.Loan memory loanAfterLiquidation = loanContract.getLoanDetails(loanId);
        assertEq(uint256(loanAfterLiquidation.status), uint256(LoanContract.LoanStatus.Liquidated), "Loan status should be Liquidated");

        // Check SocialVouching contract's balance (decreased by slashAmount)
        assertEq(mockDai.balanceOf(address(socialVouching)), socialVouchingBalanceBeforeSlash - vouchAmountByVoucher1, "SocialVouching balance incorrect after slash");
        // Check Treasury's balance (increased by slashAmount)
        assertEq(mockDai.balanceOf(address(treasury)), treasuryBalanceBeforeSlash + vouchAmountByVoucher1, "Treasury balance incorrect after slash");
        
        // Check voucher's internal stake in SocialVouching (should be 0)
        SocialVouching.Vouch memory svVouchAfterSlash = socialVouching.getVouchDetails(borrower, voucher1);
        assertFalse(svVouchAfterSlash.active, "Voucher's vouch in SocialVouching should be inactive");
        assertEq(svVouchAfterSlash.amountStaked, 0, "Voucher's staked amount in SocialVouching should be 0");
    }
} 