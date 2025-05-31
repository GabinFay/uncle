// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {UserRegistry} from "../src/UserRegistry.sol";
import {SocialVouching} from "../src/SocialVouching.sol";
import {LoanContract} from "../src/LoanContract.sol";
import {Treasury} from "../src/Treasury.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Re-declare events from LoanContract for type-safe emit checks
event LoanPaymentMade(bytes32 indexed loanId, uint256 paymentAmount, uint256 totalPaid);
event LoanFullyRepaid(bytes32 indexed loanId);
event LoanApproved(bytes32 indexed loanId); // Already used, good to have explicitly for clarity
event LoanDisbursed(bytes32 indexed loanId); // Already used

contract IntegrationTest is Test {
    UserRegistry userRegistry;
    SocialVouching socialVouching;
    LoanContract loanContract;
    Treasury treasury;
    MockERC20 mockDAI; // For loan principal and repayments
    MockERC20 mockUSDC; // For collateral and vouching

    address owner = address(this); // Contract deployer and admin
    address user1 = vm.addr(1);
    address voucher1 = vm.addr(2);
    address platformWallet = vm.addr(3); // For platform fees (not currently used by LoanContract)
    address pythIntegrationMockAddress = vm.addr(11); // For Pyth in integration tests
    address reputationOAppIntegrationMockAddress = vm.addr(12); // For Reputation OApp

    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000 * 1e18; // For DAI (18 decimals)
    bytes32 constant DUMMY_WORLD_ID_HASH = keccak256(abi.encodePacked("verified_user1"));
    bytes32 constant DUMMY_VOUCHER_WORLD_ID_HASH = keccak256(abi.encodePacked("verified_voucher1"));


    function setUp() public {
        // Deploy contracts
        userRegistry = new UserRegistry();
        socialVouching = new SocialVouching(address(userRegistry));
        treasury = new Treasury(owner); // Pass owner to Treasury constructor
        loanContract = new LoanContract(
            address(userRegistry),
            address(socialVouching),
            payable(address(treasury)),
            pythIntegrationMockAddress, // Pass Pyth mock address
            reputationOAppIntegrationMockAddress // Pass ReputationOApp mock address
        );

        // Deploy mock tokens
        mockDAI = new MockERC20("MockDAI", "mDAI", 18);
        mockUSDC = new MockERC20("MockUSDC", "mUSDC", 6); // USDC typically has 6 decimals

        // Set up contract addresses
        vm.startPrank(owner);
        treasury.setLoanContractAddress(address(loanContract));
        // socialVouching.setLoanContractAddress(address(loanContract)); // Removed: SocialVouching does not have this setter
        // loanContract.setPlatformWallet(platformWallet); // Assuming this exists for fees
        // loanContract.setPlatformFeePercentage(100); // 1% fee (100 / 10000)
        vm.stopPrank();

        // Mint tokens to users and treasury
        mockDAI.mint(user1, INITIAL_MINT_AMOUNT);
        mockDAI.mint(address(treasury), INITIAL_MINT_AMOUNT * 10); // Treasury has ample funds

        mockUSDC.mint(user1, INITIAL_MINT_AMOUNT); // For collateral
        mockUSDC.mint(voucher1, INITIAL_MINT_AMOUNT); // For vouching
    }

    function test_FullLoanCycle_WithCollateral_NoVouching() public {
        // 1. Register User
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(user1, DUMMY_WORLD_ID_HASH);
        assertTrue(userRegistry.isUserWorldIdVerified(user1), "User1 should be World ID verified");

        // 2. User Deposits Collateral (not directly part of LoanContract flow, but user needs tokens)
        // User already has mockUSDC from setup

        // 3. User Applies for Loan
        uint256 loanAmount = 1000 * 1e18; // 1000 mDAI
        uint256 collateralAmount = 500 * 1e6; // 500 mUSDC (6 decimals)
        uint256 interestRate = 500; // 5% (500 / 10000)
        uint256 loanDuration = 30 days;

        vm.startPrank(user1);
        // User approves LoanContract to spend their collateral
        mockUSDC.approve(address(loanContract), collateralAmount);
        
        bytes32 loanId = loanContract.applyForLoan(
            loanAmount,        // principalAmount_
            address(mockDAI),  // loanToken_
            interestRate,      // interestRate_
            loanDuration,      // duration_
            collateralAmount,  // collateralAmount_
            address(mockUSDC)  // collateralToken_
        );
        vm.stopPrank();
        assertTrue(loanId != 0, "Loan ID should not be zero");

        // Check collateral was transferred to LoanContract
        assertEq(mockUSDC.balanceOf(user1), INITIAL_MINT_AMOUNT - collateralAmount, "User1 USDC balance incorrect after collateral transfer");
        assertEq(mockUSDC.balanceOf(address(loanContract)), collateralAmount, "LoanContract USDC balance incorrect after collateral transfer");


        // 4. Admin Approves Loan (Disburses Funds)
        uint256 treasuryDAIBalanceBeforeDisburse = mockDAI.balanceOf(address(treasury));
        uint256 user1DAIBalanceBeforeDisburse = mockDAI.balanceOf(user1);

        vm.prank(owner);
        loanContract.approveLoan(loanId);

        assertEq(mockDAI.balanceOf(address(treasury)), treasuryDAIBalanceBeforeDisburse - loanAmount, "Treasury DAI balance incorrect after disbursal");
        assertEq(mockDAI.balanceOf(user1), user1DAIBalanceBeforeDisburse + loanAmount, "User1 DAI balance incorrect after disbursal");
        
        LoanContract.Loan memory loan = loanContract.getLoanDetails(loanId);
        assertEq(uint(loan.status), uint(LoanContract.LoanStatus.Active), "Loan status should be Active");

        // 5. User Repays Loan
        // Fast forward time to near due date (but before)
        vm.warp(block.timestamp + loanDuration - 1 days);

        uint256 amountDue = loanContract.calculateTotalAmountDue(loanId);
        assertTrue(amountDue > loanAmount, "Amount due should be greater than loan amount (includes interest)");

        uint256 user1DAIBalanceBeforeRepay = mockDAI.balanceOf(user1);
        uint256 treasuryDAIBalanceBeforeRepay = mockDAI.balanceOf(address(treasury));
        uint256 loanContractCollateralBalanceBeforeRepay = mockUSDC.balanceOf(address(loanContract));
        uint256 user1CollateralBalanceBeforeRepay = mockUSDC.balanceOf(user1);


        vm.startPrank(user1);
        mockDAI.approve(address(loanContract), amountDue);

        vm.expectEmit(true, true, true, true); // For LoanPaymentMade
        emit LoanPaymentMade(loanId, amountDue, amountDue);
        vm.expectEmit(true, false, false, true); // For LoanFullyRepaid
        emit LoanFullyRepaid(loanId);

        loanContract.repayLoan(loanId, amountDue);
        vm.stopPrank();

        loan = loanContract.getLoanDetails(loanId);
        assertEq(uint(loan.status), uint(LoanContract.LoanStatus.Repaid), "Loan status should be Repaid");
        assertEq(mockDAI.balanceOf(user1), user1DAIBalanceBeforeRepay - amountDue, "User1 DAI balance incorrect after repayment");
        assertEq(mockDAI.balanceOf(address(treasury)), treasuryDAIBalanceBeforeRepay + amountDue, "Treasury DAI balance incorrect after repayment");
        
        // Check collateral is returned
        assertEq(mockUSDC.balanceOf(address(loanContract)), loanContractCollateralBalanceBeforeRepay - collateralAmount, "LoanContract collateral balance not zero after repayment");
        assertEq(mockUSDC.balanceOf(user1), user1CollateralBalanceBeforeRepay + collateralAmount, "User1 collateral not returned after repayment");

        // Optional: Check platform fee was collected if that logic exists and is enabled
        // uint256 expectedFee = (loanAmount * loanContract.platformFeePercentage()) / 10000;
        // assertEq(mockDAI.balanceOf(platformWallet), expectedFee, "Platform fee not collected correctly");
    }

    function test_FullLoanCycle_WithSocialVouching() public {
        // 1. Register Borrower & Voucher
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(user1, DUMMY_WORLD_ID_HASH); // Borrower
        assertTrue(userRegistry.isUserWorldIdVerified(user1), "User1 should be World ID verified");
        vm.prank(owner);
        userRegistry.registerOrUpdateUser(voucher1, DUMMY_VOUCHER_WORLD_ID_HASH); // Voucher
        assertTrue(userRegistry.isUserWorldIdVerified(voucher1), "Voucher1 should be World ID verified");

        // 2. Voucher adds a vouch for User1
        uint256 vouchAmount = 200 * 1e6; // 200 mUSDC (6 decimals for vouching token)
        vm.startPrank(voucher1);
        mockUSDC.approve(address(socialVouching), vouchAmount);
        socialVouching.addVouch(user1, vouchAmount, address(mockUSDC));
        vm.stopPrank();

        assertEq(socialVouching.getTotalVouchedAmountForBorrower(user1), vouchAmount, "Vouch amount incorrect");

        // 3. User1 Applies for Loan (no additional collateral for this test)
        uint256 loanAmount = 500 * 1e18; // 500 mDAI
        uint256 interestRate = 600; // 6%
        uint256 loanDuration = 45 days;

        vm.startPrank(user1);
        // No direct collateral approval needed as we are testing vouching as primary support
        bytes32 loanId = loanContract.applyForLoan(
            loanAmount,
            address(mockDAI),  // Loan token
            interestRate,
            loanDuration,
            0,                 // No direct collateral amount
            address(0)         // No direct collateral token
        );
        vm.stopPrank();
        assertTrue(loanId != 0, "Loan ID should not be zero for vouched loan");

        LoanContract.Loan memory loan = loanContract.getLoanDetails(loanId);
        assertEq(loan.borrower, user1, "Loan borrower mismatch");
        assertEq(loan.totalVouchedAmountAtApplication, vouchAmount, "Vouched amount not recorded in loan details");

        // 4. Admin Approves Loan
        uint256 user1DAIBalanceBeforeDisburse = mockDAI.balanceOf(user1);
        vm.prank(owner);
        // Add event emits for approveLoan if they changed (they did not, still LoanApproved, LoanDisbursed)
        vm.expectEmit(true, false, false, true); emit LoanApproved(loanId);
        vm.expectEmit(true, false, false, true); emit LoanDisbursed(loanId);
        loanContract.approveLoan(loanId);
        assertEq(mockDAI.balanceOf(user1), user1DAIBalanceBeforeDisburse + loanAmount, "User1 DAI balance incorrect after vouched loan disbursal");

        // 5. User Repays Loan
        vm.warp(block.timestamp + loanDuration - 1 days);
        uint256 amountDueVouched = loanContract.calculateTotalAmountDue(loanId);

        vm.startPrank(user1);
        mockDAI.approve(address(loanContract), amountDueVouched);

        vm.expectEmit(true, true, true, true); // For LoanPaymentMade
        emit LoanPaymentMade(loanId, amountDueVouched, amountDueVouched);
        vm.expectEmit(true, false, false, true); // For LoanFullyRepaid
        emit LoanFullyRepaid(loanId);

        loanContract.repayLoan(loanId, amountDueVouched);
        vm.stopPrank();

        loan = loanContract.getLoanDetails(loanId);
        assertEq(uint(loan.status), uint(LoanContract.LoanStatus.Repaid), "Vouched loan status should be Repaid");

        // Optional: Verify vouch is still intact or if any reward/release logic needs testing later
        SocialVouching.Vouch memory vouchDetails = socialVouching.getVouchDetails(user1, voucher1);
        assertTrue(vouchDetails.active, "Vouch should remain active after successful loan repayment");
        assertEq(vouchDetails.amountStaked, vouchAmount, "Vouch amount should remain unchanged");
    }

} 