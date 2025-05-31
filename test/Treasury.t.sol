// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Treasury.sol";
import "./mocks/MockERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract TreasuryTest is Test {
    Treasury public treasury;
    MockERC20 public mockToken;

    address owner;
    address user1 = vm.addr(1);
    address user2 = vm.addr(2);
    address loanContractMock = vm.addr(3); // Mock address for LoanContract

    uint256 constant ONE_ETH = 1 ether;
    uint256 constant ONE_HUNDRED_TOKENS = 100 * 1e18;

    // Re-declare events here for type-safe emit checks if not directly visible
    event FundsDeposited(address indexed depositor, address indexed tokenAddress, uint256 amount);
    event FundsWithdrawn(address indexed recipient, address indexed tokenAddress, uint256 amount);
    event LoanContractAddressSet(address indexed newAddress);

    function setUp() public {
        owner = address(this); // Test contract is the owner of Treasury & MockToken
        treasury = new Treasury(owner);
        mockToken = new MockERC20("Mock Token", "MTK", 18);

        // Mint some tokens to user1 for testing deposits
        mockToken.mint(user1, 1000 * 1e18);

        // Set the loan contract address for permissioned functions
        vm.prank(owner);
        treasury.setLoanContractAddress(loanContractMock);
    }

    // --- Test ETH Deposits --- 
    function test_DepositETH_Success() public {
        vm.prank(user1);
        vm.deal(user1, 2 * ONE_ETH); // Give user1 some ETH
        uint256 initialBalance = address(treasury).balance;
        
        vm.expectEmit(true, true, false, true); // Check depositor, tokenAddress, amount, and emitter address
        emit FundsDeposited(user1, address(0), ONE_ETH); // Describe the expected event
        treasury.depositETH{value: ONE_ETH}();
        assertEq(address(treasury).balance, initialBalance + ONE_ETH, "Treasury ETH balance mismatch");
    }

    function test_RevertIf_DepositETH_ZeroAmount() public {
        vm.prank(user1);
        vm.deal(user1, ONE_ETH);
        vm.expectRevert(bytes("Treasury: Deposit amount must be positive"));
        treasury.depositETH{value: 0}();
    }

    // --- Test ERC20 Deposits --- 
    function test_DepositFunds_ERC20_Success() public {
        vm.startPrank(user1);
        mockToken.approve(address(treasury), ONE_HUNDRED_TOKENS);
        uint256 initialContractTokenBalance = mockToken.balanceOf(address(treasury));
        
        vm.expectEmit(true, true, true, true); // Check depositor, tokenAddress, amount, and emitter address
        emit FundsDeposited(user1, address(mockToken), ONE_HUNDRED_TOKENS); // Describe expected event
        treasury.depositFunds(address(mockToken), ONE_HUNDRED_TOKENS);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(address(treasury)), initialContractTokenBalance + ONE_HUNDRED_TOKENS, "Treasury token balance mismatch");
    }

    function test_RevertIf_DepositFunds_ERC20_ZeroAmount() public {
        vm.startPrank(user1);
        mockToken.approve(address(treasury), ONE_HUNDRED_TOKENS);
        vm.expectRevert(bytes("Treasury: Deposit amount must be positive"));
        treasury.depositFunds(address(mockToken), 0);
        vm.stopPrank();
    }

    function test_RevertIf_DepositFunds_ERC20_InvalidTokenAddress() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes("Treasury: Invalid token address"));
        treasury.depositFunds(address(0), ONE_HUNDRED_TOKENS);
        vm.stopPrank();
    }

    // --- Test ETH Withdrawals (Owner only) --- 
    function test_WithdrawETH_Owner_Success() public {
        // Deposit ETH first
        vm.prank(user1);
        vm.deal(user1, 2 * ONE_ETH);
        treasury.depositETH{value: ONE_ETH}();

        vm.startPrank(owner);
        uint256 treasuryInitialBalance = address(treasury).balance;

        vm.expectEmit(true, true, false, true); 
        emit FundsWithdrawn(user2, address(0), ONE_ETH); 
        treasury.withdrawETH(ONE_ETH, payable(user2));
        vm.stopPrank();

        assertEq(address(treasury).balance, treasuryInitialBalance - ONE_ETH, "Treasury ETH balance after withdrawal mismatch");
    }

    function test_RevertIf_WithdrawETH_NonOwner() public {
        assertEq(treasury.owner(), owner, "Initial owner check failed. Treasury owner should be test contract.");
        assertNotEq(user1, owner, "user1 should not be the same as owner (test contract).");

        // Ensure treasury has funds to attempt withdrawal
        vm.deal(address(treasury), 2 * ONE_ETH);

        vm.prank(user1); // Set msg.sender to user1 (who is not the owner)
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        treasury.withdrawETH(ONE_ETH, payable(user2)); // This call should be from user1 and revert
    }

    function test_RevertIf_WithdrawETH_InsufficientBalance() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Treasury: Insufficient ETH balance"));
        treasury.withdrawETH(ONE_ETH, payable(user2));
        vm.stopPrank();
    }

    // --- Test ERC20 Withdrawals (Owner only) --- 
    function test_WithdrawFunds_ERC20_Owner_Success() public {
        // Deposit ERC20 first
        vm.startPrank(user1);
        mockToken.approve(address(treasury), ONE_HUNDRED_TOKENS);
        treasury.depositFunds(address(mockToken), ONE_HUNDRED_TOKENS);
        vm.stopPrank();

        vm.startPrank(owner);
        uint256 recipientInitialBalance = mockToken.balanceOf(user2);
        vm.expectEmit(true, true, true, true);
        emit FundsWithdrawn(user2, address(mockToken), ONE_HUNDRED_TOKENS);
        treasury.withdrawFunds(address(mockToken), ONE_HUNDRED_TOKENS, user2);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(user2), recipientInitialBalance + ONE_HUNDRED_TOKENS, "Recipient token balance mismatch");
    }

    function test_RevertIf_WithdrawFunds_ERC20_NonOwner() public {
        // Ensure treasury has some mockToken funds, deposited by anyone (e.g., user1)
        vm.startPrank(user1);
        mockToken.approve(address(treasury), ONE_HUNDRED_TOKENS);
        treasury.depositFunds(address(mockToken), ONE_HUNDRED_TOKENS);
        vm.stopPrank();

        vm.prank(user1); // Set msg.sender to user1 (who is not the owner)
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        treasury.withdrawFunds(address(mockToken), ONE_HUNDRED_TOKENS, user2);
    }

    // --- Test ETH Transfers to LoanContract --- 
    function test_TransferETHToLoanContract_Success() public {
        // Deposit ETH first
        vm.prank(user1); vm.deal(user1, 2 * ONE_ETH); treasury.depositETH{value: ONE_ETH}();

        vm.startPrank(loanContractMock);
        uint256 recipientInitialBalance = user2.balance;
        treasury.transferETHToLoanContract(ONE_ETH, payable(user2));
        vm.stopPrank();
        assertEq(user2.balance, recipientInitialBalance + ONE_ETH, "Recipient ETH balance mismatch");
    }

    function test_RevertIf_TransferETHToLoanContract_NotLoanContract() public {
        vm.prank(user1); // Not LoanContract
        vm.expectRevert(bytes("Treasury: Caller is not the LoanContract"));
        treasury.transferETHToLoanContract(ONE_ETH, payable(user2));
    }

    // --- Test ERC20 Transfers to LoanContract --- 
    function test_TransferFundsToLoanContract_ERC20_Success() public {
        // Deposit ERC20 first
        vm.startPrank(user1); 
        mockToken.approve(address(treasury), ONE_HUNDRED_TOKENS); 
        treasury.depositFunds(address(mockToken), ONE_HUNDRED_TOKENS);
        vm.stopPrank();

        vm.startPrank(loanContractMock);
        uint256 recipientInitialBalance = mockToken.balanceOf(user2);
        treasury.transferFundsToLoanContract(address(mockToken), ONE_HUNDRED_TOKENS, user2);
        vm.stopPrank();
        assertEq(mockToken.balanceOf(user2), recipientInitialBalance + ONE_HUNDRED_TOKENS, "Recipient token balance mismatch");
    }

    function test_RevertIf_TransferFundsToLoanContract_ERC20_NotLoanContract() public {
        vm.prank(user1); // Not LoanContract
        vm.expectRevert(bytes("Treasury: Caller is not the LoanContract"));
        treasury.transferFundsToLoanContract(address(mockToken), ONE_HUNDRED_TOKENS, user2);
    }

    // --- Test setLoanContractAddress --- 
    function test_SetLoanContractAddress_Success() public {
        address newLoanContract = vm.addr(4);
        vm.prank(owner);
        vm.expectEmit(true, false, false, true); // Check newAddress (indexed) and emitter
        emit LoanContractAddressSet(newLoanContract);
        treasury.setLoanContractAddress(newLoanContract);
        assertEq(treasury.loanContractAddress(), newLoanContract, "LoanContract address not updated");
    }

    function test_RevertIf_SetLoanContractAddress_NonOwner() public {
        address newLoanContract = vm.addr(4);
        vm.prank(user1); // Non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        treasury.setLoanContractAddress(newLoanContract);
    }

    function test_RevertIf_SetLoanContractAddress_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Treasury: Invalid LoanContract address"));
        treasury.setLoanContractAddress(address(0));
    }

    // --- Test receive() fallback --- 
    function test_ReceiveETH_Fallback_Success() public {
        vm.deal(user1, ONE_ETH);
        uint256 initialBalance = address(treasury).balance;
        vm.expectEmit(true, true, false, true);
        emit FundsDeposited(user1, address(0), ONE_ETH); // msg.sender will be user1 if pranked
        
        vm.prank(user1); // Prank as user1 for the .call to make msg.sender user1 in receive()
        (bool success, ) = address(treasury).call{value: ONE_ETH}("");
        vm.stopPrank();
        assertTrue(success, "ETH transfer via fallback failed");
        assertEq(address(treasury).balance, initialBalance + ONE_ETH, "Treasury ETH balance mismatch after fallback deposit");
    }
} 