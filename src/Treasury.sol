// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Treasury
 * @dev Manages funds for loan disbursal and receives repayments.
 *      Acts as a central pool for platform capital.
 */
contract Treasury is Ownable, ReentrancyGuard {
    address public loanContractAddress;

    event FundsDeposited(address indexed depositor, address indexed tokenAddress, uint256 amount);
    event FundsWithdrawn(address indexed recipient, address indexed tokenAddress, uint256 amount);
    event LoanContractAddressSet(address indexed newLoanContractAddress);

    modifier onlyLoanContract() {
        require(msg.sender == loanContractAddress, "Treasury: Caller is not the LoanContract");
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Allows anyone (e.g., investors, platform) to deposit ERC20 tokens into the treasury.
     * @param tokenAddress The address of the ERC20 token to deposit.
     * @param amount The amount of tokens to deposit.
     */
    function depositFunds(address tokenAddress, uint256 amount) external nonReentrant {
        require(tokenAddress != address(0), "Treasury: Invalid token address");
        require(amount > 0, "Treasury: Deposit amount must be positive");

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        emit FundsDeposited(msg.sender, tokenAddress, amount);
    }

    /**
     * @dev Allows anyone to deposit ETH into the treasury.
     */
    function depositETH() external payable nonReentrant {
        require(msg.value > 0, "Treasury: Deposit amount must be positive");
        emit FundsDeposited(msg.sender, address(0), msg.value); // address(0) for ETH
    }

    /**
     * @dev Allows the owner (platform admin) to withdraw ERC20 tokens from the treasury.
     * This is for administrative purposes, like managing overall liquidity or returning capital to major investors under specific agreements.
     * @param tokenAddress The address of the ERC20 token to withdraw.
     * @param amount The amount of tokens to withdraw.
     * @param recipient The address to receive the withdrawn tokens.
     */
    function withdrawFunds(address tokenAddress, uint256 amount, address recipient) external onlyOwner nonReentrant {
        require(tokenAddress != address(0), "Treasury: Invalid token address");
        require(amount > 0, "Treasury: Withdraw amount must be positive");
        require(recipient != address(0), "Treasury: Invalid recipient address");

        IERC20(tokenAddress).transfer(recipient, amount);
        emit FundsWithdrawn(recipient, tokenAddress, amount);
    }

    /**
     * @dev Allows the owner (platform admin) to withdraw ETH from the treasury.
     * @param amount The amount of ETH to withdraw.
     * @param recipient The address to receive the withdrawn ETH.
     */
    function withdrawETH(uint256 amount, address payable recipient) external onlyOwner nonReentrant {
        require(amount > 0, "Treasury: Withdraw amount must be positive");
        require(recipient != address(0), "Treasury: Invalid recipient address");
        require(address(this).balance >= amount, "Treasury: Insufficient ETH balance");

        recipient.transfer(amount);
        emit FundsWithdrawn(recipient, address(0), amount); // address(0) for ETH
    }

    /**
     * @dev Allows the LoanContract to pull funds for loan disbursal.
     * @param tokenAddress The address of the ERC20 token to transfer.
     * @param amount The amount of tokens to transfer.
     * @param recipient The address of the borrower.
     */
    function transferFundsToLoanContract(address tokenAddress, uint256 amount, address recipient) 
        external 
        onlyLoanContract 
        nonReentrant 
    {
        require(tokenAddress != address(0), "Treasury: Invalid token address");
        require(amount > 0, "Treasury: Transfer amount must be positive");
        require(recipient != address(0), "Treasury: Invalid recipient for loan");

        IERC20(tokenAddress).transfer(recipient, amount);
        // Event for this specific action can be added if needed, or rely on LoanContract's events.
    }

    /**
     * @dev Allows the LoanContract to pull ETH for loan disbursal.
     * @param amount The amount of ETH to transfer.
     * @param recipient The address of the borrower.
     */
    function transferETHToLoanContract(uint256 amount, address payable recipient)
        external
        onlyLoanContract
        nonReentrant
    {
        require(amount > 0, "Treasury: Transfer amount must be positive");
        require(recipient != address(0), "Treasury: Invalid recipient for loan");
        require(address(this).balance >= amount, "Treasury: Insufficient ETH balance for loan");

        recipient.transfer(amount);
    }


    /**
     * @dev Sets the address of the LoanContract. Can only be called by the owner.
     * This is important for the `onlyLoanContract` modifier.
     * @param newLoanContractAddress The address of the LoanContract.
     */
    function setLoanContractAddress(address newLoanContractAddress) external onlyOwner {
        require(newLoanContractAddress != address(0), "Treasury: Invalid LoanContract address");
        loanContractAddress = newLoanContractAddress;
        emit LoanContractAddressSet(newLoanContractAddress);
    }

    // Fallback function to receive ETH directly
    receive() external payable {
        emit FundsDeposited(msg.sender, address(0), msg.value);
    }
} 