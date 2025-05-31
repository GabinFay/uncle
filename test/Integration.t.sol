// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {UserRegistry} from "../src/UserRegistry.sol";
// import {SocialVouching} from "../src/SocialVouching.sol"; // REMOVED
import {P2PLending} from "../src/P2PLending.sol"; // UPDATED from LoanContract.sol
// import {Treasury} from "../src/Treasury.sol"; // REMOVED
import {MockERC20} from "./mocks/MockERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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

    address owner = address(this); 
    address user1 = vm.addr(1);
    address voucher1 = vm.addr(2);
    address platformWallet = vm.addr(3); // For platform fees (not currently used by LoanContract)
    address reputationOAppIntegrationMockAddress = vm.addr(12); // For Reputation OApp

    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000 * 1e18; // For DAI (18 decimals)
    bytes32 constant DUMMY_WORLD_ID_HASH = keccak256(abi.encodePacked("verified_user1"));
    bytes32 constant DUMMY_VOUCHER_WORLD_ID_HASH = keccak256(abi.encodePacked("verified_voucher1"));
    address[] emptyVoucherAddresses; // For applyForLoan calls not testing vouching

    function setUp() public {
        // Deploy contracts
        userRegistry = new UserRegistry();
        // socialVouching = new SocialVouching(address(userRegistry)); // REMOVED
        // treasury = new Treasury(owner); // REMOVED
        p2pLending = new P2PLending( // UPDATED from loanContract
            address(userRegistry),
            address(0), // Placeholder for SocialVouching address - will be Reputation address
            payable(address(0)), // Placeholder for Treasury address - P2P won't use it
            reputationOAppIntegrationMockAddress 
        );

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

        // Mint tokens to users and treasury
        mockDAI.mint(user1, INITIAL_MINT_AMOUNT);
        // mockDAI.mint(address(treasury), INITIAL_MINT_AMOUNT * 10); // REMOVED Treasury minting
        mockDAI.mint(owner, INITIAL_MINT_AMOUNT * 10); // Mint to owner for P2P lending for now

        mockUSDC.mint(user1, INITIAL_MINT_AMOUNT); 
        mockUSDC.mint(voucher1, INITIAL_MINT_AMOUNT); 
    }

    function test_FullLoanCycle_WithCollateral_NoVouching() public {
        // ... This test will need complete rewrite for P2P model ...
        vm.expectRevert(bytes("P2P Test Not Implemented"));
        assertTrue(false); 
    }

    function test_FullLoanCycle_WithSocialVouching() public {
        // ... This test will need complete rewrite for P2P model ...
        vm.expectRevert(bytes("P2P Test Not Implemented"));
        assertTrue(false);
    }

} 