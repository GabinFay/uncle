// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./UserRegistry.sol"; // Assumes UserRegistry.sol is in the same directory

/**
 * @title SocialVouching
 * @dev Manages social vouching mechanism where users stake tokens for others.
 */
contract SocialVouching is ReentrancyGuard {
    UserRegistry public userRegistry;

    struct Vouch {
        address voucher;
        address tokenAddress;
        uint256 amountStaked;
        bool active;
    }

    // borrower => voucher => Vouch
    mapping(address => mapping(address => Vouch)) public vouches;
    // borrower => total amount vouched (can be an aggregation if multiple tokens, simplified for now)
    mapping(address => uint256) public totalVouchedAmount;

    event VouchAdded(address indexed borrower, address indexed voucher, address indexed tokenAddress, uint256 amount);
    event VouchRemoved(address indexed borrower, address indexed voucher, uint256 amountReturned);
    event VouchSlashed(address indexed borrower, address indexed voucher, uint256 amountSlashed);
    event VouchRewarded(address indexed borrower, address indexed voucher, uint256 amountRewarded); // Placeholder

    modifier onlyVerifiedUser(address user) {
        require(userRegistry.isUserWorldIdVerified(user), "SocialVouching: User not World ID verified");
        _;
    }

    constructor(address userRegistryAddress) {
        require(userRegistryAddress != address(0), "SocialVouching: Invalid UserRegistry address");
        userRegistry = UserRegistry(userRegistryAddress);
    }

    /**
     * @dev Allows a verified user (voucher) to stake tokens for a borrower.
     * @param borrower The address of the user being vouched for.
     * @param amount The amount of tokens to stake.
     * @param tokenAddress The address of the ERC20 token being staked.
     */
    function addVouch(address borrower, uint256 amount, address tokenAddress) 
        external 
        nonReentrant 
        onlyVerifiedUser(msg.sender) // Voucher must be verified
        onlyVerifiedUser(borrower)   // Borrower must be verified
    {
        require(borrower != msg.sender, "SocialVouching: Cannot vouch for oneself");
        require(amount > 0, "SocialVouching: Stake amount must be positive");
        require(tokenAddress != address(0), "SocialVouching: Invalid token address");

        Vouch storage existingVouch = vouches[borrower][msg.sender];
        require(!existingVouch.active, "SocialVouching: Vouch already active for this pair"); // Can extend to allow top-ups

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);

        vouches[borrower][msg.sender] = Vouch({
            voucher: msg.sender,
            tokenAddress: tokenAddress,
            amountStaked: amount,
            active: true
        });

        totalVouchedAmount[borrower] += amount; // Simplification: assumes all tokens have same value or are base denomination

        emit VouchAdded(borrower, msg.sender, tokenAddress, amount);
    }

    /**
     * @dev Allows a voucher to remove their stake if conditions are met (e.g., borrower has no active loan).
     * Conditions for removal (e.g., loan status) would be checked by LoanContract or an orchestrator.
     * This function currently allows unconditional removal for simplicity of this contract.
     * @param borrower The address of the user for whom the vouch was made.
     */
    function removeVouch(address borrower) external nonReentrant {
        Vouch storage vouchDetails = vouches[borrower][msg.sender];
        require(vouchDetails.active, "SocialVouching: No active vouch to remove");
        require(vouchDetails.voucher == msg.sender, "SocialVouching: Only voucher can remove");

        // Add checks here: e.g., require(!loanContract.hasActiveLoanUsingVouch(borrower, msg.sender));

        uint256 amountToReturn = vouchDetails.amountStaked;
        vouchDetails.active = false;
        vouchDetails.amountStaked = 0;

        totalVouchedAmount[borrower] -= amountToReturn; // Simplification

        IERC20(vouchDetails.tokenAddress).transfer(msg.sender, amountToReturn);

        emit VouchRemoved(borrower, msg.sender, amountToReturn);
    }

    /**
     * @dev Slashes a voucher's stake. Only callable by a trusted contract (e.g., LoanContract).
     * @param borrower The address of the borrower whose default led to slashing.
     * @param voucher The address of the voucher whose stake is being slashed.
     * @param amountToSlash The amount to slash from the voucher's stake.
     * @param recipient The address to send the slashed funds to (e.g., treasury or affected lender).
     */
    function slashVouch(address borrower, address voucher, uint256 amountToSlash, address recipient) external nonReentrant { // Consider adding onlyLoanContract modifier
        // require(msg.sender == loanContractAddress, "SocialVouching: Only LoanContract can slash");
        Vouch storage vouchDetails = vouches[borrower][voucher];
        require(vouchDetails.active, "SocialVouching: No active vouch to slash");
        require(amountToSlash <= vouchDetails.amountStaked, "SocialVouching: Slash amount exceeds staked amount");

        vouchDetails.amountStaked -= amountToSlash;
        totalVouchedAmount[borrower] -= amountToSlash; // Simplification

        if (vouchDetails.amountStaked == 0) {
            vouchDetails.active = false;
        }

        IERC20(vouchDetails.tokenAddress).transfer(recipient, amountToSlash);

        emit VouchSlashed(borrower, voucher, amountToSlash);
    }
    
    /**
     * @dev Placeholder for rewarding a voucher. Logic to be defined based on platform tokenomics.
     * Only callable by a trusted contract (e.g., LoanContract or Treasury).
     */
    function rewardVoucher(address borrower, address voucher, uint256 rewardAmount, address rewardToken) external nonReentrant { // Consider adding onlyPlatformManaged modifier
        // require(msg.sender == trustedContractAddress, "SocialVouching: Caller not authorized");
        Vouch storage vouchDetails = vouches[borrower][voucher];
        require(vouchDetails.active || vouchDetails.amountStaked == 0, "SocialVouching: Vouch must have been active or successfully completed"); // Allow reward after successful completion
        // Transfer rewardToken from treasury/reward pool to voucher
        // IERC20(rewardToken).transferFrom(rewardPoolAddress, voucher, rewardAmount);
        emit VouchRewarded(borrower, voucher, rewardAmount);
    }

    function getVouchDetails(address borrower, address voucher) external view returns (Vouch memory) {
        return vouches[borrower][voucher];
    }

    function getTotalVouchedAmountForBorrower(address borrower) external view returns (uint256) {
        return totalVouchedAmount[borrower]; // This is a simplified sum; real value might need oracle price feeds
    }
} 