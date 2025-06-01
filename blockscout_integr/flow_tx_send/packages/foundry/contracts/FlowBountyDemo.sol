// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FlowBountyDemo
 * @notice Comprehensive contract demonstrating Blockscout features for bounty submission
 * @dev This contract focuses on events, analytics, and complex interactions for maximum Blockscout integration
 */
contract FlowBountyDemo is ERC20, Ownable, ReentrancyGuard {
    uint256 private _activityCounter;
    uint256 private _userCounter;
    
    // State variables for various features
    mapping(address => uint256) public userRewards;
    mapping(address => uint256) public userActivity;
    mapping(address => bool) public premiumUsers;
    mapping(address => uint256) public userJoinDate;
    
    uint256 public constant REWARD_AMOUNT = 100 * 10**18; // 100 tokens
    uint256 public constant ACTIVITY_THRESHOLD = 5;
    uint256 public totalRewardsDistributed;
    uint256 public totalActiveUsers;
    
    // Events for comprehensive Blockscout tracking
    event TokensRewarded(address indexed user, uint256 amount, string reason);
    event ActivityTracked(address indexed user, string activityType, uint256 activityCount);
    event PremiumUpgrade(address indexed user, uint256 fee);
    event ContractInteraction(address indexed user, string functionName, bytes data);
    event RewardClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event BatchTransfer(address indexed from, address[] to, uint256[] amounts);
    event EmergencyWithdraw(address indexed owner, uint256 amount);
    event UserOnboarded(address indexed user, string username, uint256 timestamp);
    event ComplexDataProcessed(address indexed user, bytes data, uint256 gasUsed);
    
    constructor() 
        ERC20("FlowBountyToken", "FBT") 
        Ownable(msg.sender)
    {
        // Mint initial supply to deployer
        _mint(msg.sender, 1000000 * 10**18); // 1M tokens
        emit TokensRewarded(msg.sender, 1000000 * 10**18, "Initial Supply");
    }
    
    /**
     * @notice Comprehensive user onboarding with multiple interactions
     * @dev Demonstrates complex transaction with multiple events
     */
    function completeOnboarding(string memory username) external payable {
        require(bytes(username).length > 0, "Username required");
        require(msg.value >= 0.0001 ether, "Minimum fee required");
        require(userJoinDate[msg.sender] == 0, "Already onboarded");
        
        // Track new user
        _userCounter++;
        userJoinDate[msg.sender] = block.timestamp;
        userActivity[msg.sender]++;
        _activityCounter++;
        totalActiveUsers++;
        
        // Reward tokens for onboarding
        _mint(msg.sender, REWARD_AMOUNT);
        userRewards[msg.sender] += REWARD_AMOUNT;
        totalRewardsDistributed += REWARD_AMOUNT;
        
        // Emit comprehensive events
        emit UserOnboarded(msg.sender, username, block.timestamp);
        emit ActivityTracked(msg.sender, "onboarding", userActivity[msg.sender]);
        emit TokensRewarded(msg.sender, REWARD_AMOUNT, "Onboarding Reward");
        emit ContractInteraction(msg.sender, "completeOnboarding", abi.encode(username));
    }
    
    /**
     * @notice Upgrade to premium with special benefits
     */
    function upgradeToPremium() external payable {
        require(msg.value >= 0.01 ether, "Premium upgrade fee required");
        require(!premiumUsers[msg.sender], "Already premium user");
        require(userJoinDate[msg.sender] > 0, "Must be onboarded first");
        
        premiumUsers[msg.sender] = true;
        userActivity[msg.sender] += 3; // Bonus activity
        
        // Premium reward
        uint256 premiumReward = 500 * 10**18; // 500 tokens
        _mint(msg.sender, premiumReward);
        userRewards[msg.sender] += premiumReward;
        totalRewardsDistributed += premiumReward;
        
        emit PremiumUpgrade(msg.sender, msg.value);
        emit TokensRewarded(msg.sender, premiumReward, "Premium Upgrade");
        emit ActivityTracked(msg.sender, "premium_upgrade", userActivity[msg.sender]);
    }
    
    /**
     * @notice Batch transfer tokens to multiple recipients
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to transfer
     */
    function batchTransfer(address[] memory recipients, uint256[] memory amounts) external {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length <= 20, "Too many recipients");
        require(recipients.length > 0, "No recipients");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        require(balanceOf(msg.sender) >= totalAmount, "Insufficient balance");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
            userActivity[recipients[i]]++;
            emit ActivityTracked(recipients[i], "token_received", userActivity[recipients[i]]);
        }
        
        userActivity[msg.sender]++;
        emit BatchTransfer(msg.sender, recipients, amounts);
        emit ActivityTracked(msg.sender, "batch_transfer", userActivity[msg.sender]);
        emit ContractInteraction(msg.sender, "batchTransfer", abi.encode(recipients, amounts));
    }
    
    /**
     * @notice Claim accumulated rewards based on activity
     */
    function claimActivityRewards() external nonReentrant {
        require(userActivity[msg.sender] >= ACTIVITY_THRESHOLD, "Insufficient activity");
        require(userJoinDate[msg.sender] > 0, "Must be onboarded first");
        
        uint256 rewardMultiplier = userActivity[msg.sender] / ACTIVITY_THRESHOLD;
        uint256 reward = rewardMultiplier * 25 * 10**18; // 25 tokens per threshold
        
        if (premiumUsers[msg.sender]) {
            reward = reward * 2; // Premium users get 2x rewards
        }
        
        _mint(msg.sender, reward);
        userRewards[msg.sender] += reward;
        totalRewardsDistributed += reward;
        
        emit RewardClaimed(msg.sender, reward, block.timestamp);
        emit TokensRewarded(msg.sender, reward, "Activity Reward");
        emit ContractInteraction(msg.sender, "claimActivityRewards", "");
    }
    
    /**
     * @notice Complex multi-step transaction for advanced analytics
     * @param data Arbitrary data for interaction tracking
     */
    function complexInteraction(bytes memory data) external payable {
        require(msg.value >= 0.0001 ether, "Minimum fee required");
        
        uint256 gasStart = gasleft();
        
        // Multiple state changes for complex analytics
        userActivity[msg.sender] += 2;
        _activityCounter++;
        
        // Conditional logic based on user status
        if (premiumUsers[msg.sender]) {
            uint256 bonus = 10 * 10**18;
            _mint(msg.sender, bonus);
            userRewards[msg.sender] += bonus;
            emit TokensRewarded(msg.sender, bonus, "Premium Complex Interaction");
        }
        
        // Process data (simulate complex computation)
        uint256 dataHash = uint256(keccak256(data));
        if (dataHash % 2 == 0) {
            // Even hash gets bonus
            uint256 bonus = 5 * 10**18;
            _mint(msg.sender, bonus);
            userRewards[msg.sender] += bonus;
            emit TokensRewarded(msg.sender, bonus, "Complex Data Bonus");
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        emit ComplexDataProcessed(msg.sender, data, gasUsed);
        emit ContractInteraction(msg.sender, "complexInteraction", data);
        emit ActivityTracked(msg.sender, "complex_interaction", userActivity[msg.sender]);
    }
    
    /**
     * @notice Simulate a high-gas operation for analytics
     */
    function performHeavyComputation() external payable {
        require(msg.value >= 0.001 ether, "Heavy computation fee required");
        
        uint256 gasStart = gasleft();
        
        // Simulate heavy computation with multiple storage writes
        for (uint256 i = 0; i < 10; i++) {
            userActivity[msg.sender]++;
            _activityCounter++;
            
            if (i % 3 == 0) {
                uint256 bonus = 1 * 10**18;
                _mint(msg.sender, bonus);
                userRewards[msg.sender] += bonus;
                emit TokensRewarded(msg.sender, bonus, "Heavy Computation Step");
            }
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        emit ComplexDataProcessed(msg.sender, abi.encodePacked("heavy_computation"), gasUsed);
        emit ActivityTracked(msg.sender, "heavy_computation", userActivity[msg.sender]);
    }
    
    /**
     * @notice Emergency withdraw function for owner
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        payable(owner()).transfer(balance);
        emit EmergencyWithdraw(owner(), balance);
    }
    
    // View functions for analytics
    function getUserStats(address user) external view returns (
        uint256 activity,
        uint256 rewards,
        bool isPremium,
        uint256 tokenBalance,
        uint256 joinDate
    ) {
        return (
            userActivity[user],
            userRewards[user],
            premiumUsers[user],
            balanceOf(user),
            userJoinDate[user]
        );
    }
    
    function getContractStats() external view returns (
        uint256 totalUsers,
        uint256 totalActivities,
        uint256 totalRewards,
        uint256 contractBalance
    ) {
        return (
            _userCounter,
            _activityCounter,
            totalRewardsDistributed,
            address(this).balance
        );
    }
    
    function getAdvancedStats() external view returns (
        uint256 totalSupply,
        uint256 activeUsers,
        uint256 premiumUserCount,
        uint256 averageActivity
    ) {
        uint256 premiumCount = 0;
        uint256 totalActivity = 0;
        
        // Note: In production, you'd want to avoid loops over all users
        // This is just for demo purposes
        
        return (
            super.totalSupply(),
            totalActiveUsers,
            premiumCount,
            _userCounter > 0 ? _activityCounter / _userCounter : 0
        );
    }
    
    // Fallback to accept ETH
    receive() external payable {
        emit ContractInteraction(msg.sender, "receive", "");
    }
} 