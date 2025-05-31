// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./UserRegistry.sol";
// import "./P2PLending.sol"; // Interface might be better if only enums/structs needed
import "forge-std/console.sol"; // For debugging, remove in production

interface IP2PLending { // Define an interface for P2PLending if needed for specific calls from Reputation
    // Declare functions from P2PLending that Reputation might need to call, if any.
    // Or, if P2PLending calls Reputation, Reputation might not need to call P2PLending directly.
}

/**
 * @title Reputation Contract
 * @author CreditInclusion Team
 * @notice Manages user reputation scores, social vouching, and stake slashing.
 */
contract Reputation is Ownable, ReentrancyGuard {
    UserRegistry public userRegistry;
    address public p2pLendingContractAddress; // Address of the P2PLending contract

    struct ReputationProfile {
        address userAddress;
        uint256 loansTaken;
        uint256 loansGiven;
        uint256 loansRepaidOnTime;
        uint256 loansDefaulted;
        uint256 totalValueBorrowed;
        uint256 totalValueLent;
        int256 currentReputationScore;
        uint256 vouchingStakeAmount; // Total amount user has actively staked for others
        uint256 timesVouchedForOthers;
        uint256 timesDefaultedAsVoucher; // Times a user they vouched for defaulted
    }

    struct Vouch {
        address voucher;
        address borrower;
        address tokenAddress;
        uint256 stakedAmount;
        bool isActive;
    }

    mapping(address => ReputationProfile) public userReputations;
    mapping(address => mapping(address => Vouch)) public activeVouches; // voucher => borrower => Vouch
    mapping(address => Vouch[]) public userVouchesGiven; // voucher => list of all vouches they made (active and inactive)
    mapping(address => Vouch[]) public userVouchesReceived; // borrower => list of all vouches they received (active and inactive)

    int256 public constant REPUTATION_POINTS_REPAID = 10;
    int256 public constant REPUTATION_POINTS_DEFAULTED = -50;
    int256 public constant REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER = -20;
    int256 public constant REPUTATION_POINTS_LENT_SUCCESSFULLY = 5;

    event ReputationUpdated(address indexed user, int256 newScore, string reason);
    event VouchAdded(address indexed voucher, address indexed borrower, address token, uint256 amount);
    event VouchRemoved(address indexed voucher, address indexed borrower, uint256 returnedAmount);
    event VouchSlashed(address indexed voucher, address indexed defaultingBorrower, uint256 slashedAmount, address indexed slashedToLender);

    modifier onlyVerifiedUser(address user) {
        require(userRegistry.isUserRegistered(user), "Reputation: User not World ID verified");
        _;
    }

    modifier onlyP2PLendingContract() {
        require(msg.sender == p2pLendingContractAddress, "Reputation: Caller is not P2PLending contract");
        _;
    }

    constructor(address _userRegistryAddress) Ownable(msg.sender) {
        require(_userRegistryAddress != address(0), "Invalid UserRegistry address");
        userRegistry = UserRegistry(_userRegistryAddress);
    }

    function setP2PLendingContractAddress(address _p2pLendingAddress) external onlyOwner {
        require(_p2pLendingAddress != address(0), "Invalid P2PLending contract address");
        p2pLendingContractAddress = _p2pLendingAddress;
    }

    function _initializeReputationProfileIfNotExists(address user) internal {
        if (userReputations[user].userAddress == address(0) && userRegistry.isUserRegistered(user)) {
            userReputations[user] = ReputationProfile({
                userAddress: user,
                loansTaken: 0,
                loansGiven: 0,
                loansRepaidOnTime: 0,
                loansDefaulted: 0,
                totalValueBorrowed: 0,
                totalValueLent: 0,
                currentReputationScore: 0,
                vouchingStakeAmount: 0,
                timesVouchedForOthers: 0,
                timesDefaultedAsVoucher: 0
            });
        }
    }

    function updateReputationOnLoanRepayment(
        address borrower,
        address lender,
        uint256 loanAmount
    ) external onlyP2PLendingContract {
        _initializeReputationProfileIfNotExists(borrower);
        _initializeReputationProfileIfNotExists(lender);

        ReputationProfile storage borrowerProfile = userReputations[borrower];
        borrowerProfile.loansTaken++;
        borrowerProfile.loansRepaidOnTime++;
        borrowerProfile.totalValueBorrowed += loanAmount;
        borrowerProfile.currentReputationScore += REPUTATION_POINTS_REPAID;
        emit ReputationUpdated(borrower, borrowerProfile.currentReputationScore, "Loan repaid");

        ReputationProfile storage lenderProfile = userReputations[lender];
        lenderProfile.loansGiven++;
        lenderProfile.totalValueLent += loanAmount;
        lenderProfile.currentReputationScore += REPUTATION_POINTS_LENT_SUCCESSFULLY;
        emit ReputationUpdated(lender, lenderProfile.currentReputationScore, "Loan lent and repaid");
    }

    function updateReputationOnLoanDefault(
        address borrower,
        address /*lender*/, // lender param not directly used here for score update
        uint256 /*loanAmount*/, // loanAmount not directly used here for score update
        bytes32[] calldata /*vouchesForThisLoan*/ // Not used here, P2PLending iterates active vouches
    ) external onlyP2PLendingContract {
        _initializeReputationProfileIfNotExists(borrower);
        ReputationProfile storage borrowerProfile = userReputations[borrower];
        borrowerProfile.loansTaken++; // Should this be incremented if it wasn't already via repayment path?
        borrowerProfile.loansDefaulted++;
        borrowerProfile.currentReputationScore += REPUTATION_POINTS_DEFAULTED;
        emit ReputationUpdated(borrower, borrowerProfile.currentReputationScore, "Loan defaulted");
    }

    function addVouch(
        address borrowerToVouchFor,
        uint256 amountToStake,
        address tokenAddress
    ) external nonReentrant onlyVerifiedUser(msg.sender) {
        require(borrowerToVouchFor != msg.sender, "Cannot vouch for yourself");
        require(userRegistry.isUserRegistered(borrowerToVouchFor), "Borrower not World ID verified");
        require(amountToStake > 0, "Stake amount must be positive");
        require(tokenAddress != address(0), "Invalid token address");
        require(!activeVouches[msg.sender][borrowerToVouchFor].isActive, "Already actively vouching for this borrower");

        _initializeReputationProfileIfNotExists(msg.sender);
        _initializeReputationProfileIfNotExists(borrowerToVouchFor);

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amountToStake);

        Vouch memory newVouch = Vouch({
            voucher: msg.sender,
            borrower: borrowerToVouchFor,
            tokenAddress: tokenAddress,
            stakedAmount: amountToStake,
            isActive: true
        });
        activeVouches[msg.sender][borrowerToVouchFor] = newVouch;
        userVouchesGiven[msg.sender].push(newVouch);
        userVouchesReceived[borrowerToVouchFor].push(newVouch);

        ReputationProfile storage voucherProfile = userReputations[msg.sender];
        voucherProfile.vouchingStakeAmount += amountToStake;
        voucherProfile.timesVouchedForOthers++;
        emit VouchAdded(msg.sender, borrowerToVouchFor, tokenAddress, amountToStake);
    }

    function removeVouch(address borrowerVouchedFor) external nonReentrant onlyVerifiedUser(msg.sender) {
        Vouch storage vouch = activeVouches[msg.sender][borrowerVouchedFor];
        require(vouch.isActive, "No active vouch for this borrower");
        // Add check: ensure borrowerVouchedFor does not have active loans that depend on this vouch

        vouch.isActive = false;
        uint256 stakedAmountToReturn = vouch.stakedAmount;
        // vouch.stakedAmount = 0; // Not strictly necessary as isActive is false

        ReputationProfile storage voucherProfile = userReputations[msg.sender];
        voucherProfile.vouchingStakeAmount -= stakedAmountToReturn;

        IERC20(vouch.tokenAddress).transfer(msg.sender, stakedAmountToReturn);
        emit VouchRemoved(msg.sender, borrowerVouchedFor, stakedAmountToReturn);
    }

    function slashVouchAndReputation(
        address voucher,
        address defaultingBorrower, // Kept for event clarity, though could be derived
        uint256 amountToSlash,
        address lenderToCompensate
    ) external onlyP2PLendingContract {
        Vouch storage vouch = activeVouches[voucher][defaultingBorrower];
        require(vouch.isActive, "Vouch not active or does not exist");
        require(amountToSlash <= vouch.stakedAmount, "Slash amount exceeds staked amount");
        require(amountToSlash > 0, "Slash amount must be positive");

        _initializeReputationProfileIfNotExists(voucher); // Ensure profile exists

        vouch.stakedAmount -= amountToSlash;

        ReputationProfile storage voucherProfile = userReputations[voucher];
        voucherProfile.currentReputationScore += REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER;
        voucherProfile.vouchingStakeAmount -= amountToSlash; 
        voucherProfile.timesDefaultedAsVoucher++;

        IERC20(vouch.tokenAddress).transfer(lenderToCompensate, amountToSlash);

        emit VouchSlashed(voucher, defaultingBorrower, amountToSlash, lenderToCompensate);
        emit ReputationUpdated(voucher, voucherProfile.currentReputationScore, "Vouched loan defaulted, stake slashed");

        if (vouch.stakedAmount == 0) {
            vouch.isActive = false;
        }
    }

    function getReputationProfile(address user) external view returns (ReputationProfile memory) {
        return userReputations[user];
    }

    function getVouchDetails(address voucher, address borrower) external view returns (Vouch memory) {
        return activeVouches[voucher][borrower];
    }

    function getUserVouchesGiven(address voucher) external view returns (Vouch[] memory) {
        return userVouchesGiven[voucher];
    }

    function getUserVouchesReceived(address borrower) external view returns (Vouch[] memory) {
        return userVouchesReceived[borrower];
    }

    function getActiveVouchesForBorrower(address borrower) external view returns (Vouch[] memory activeReceivedVouches) {
        Vouch[] memory allReceived = userVouchesReceived[borrower];
        uint activeCount = 0;
        for (uint i = 0; i < allReceived.length; i++) {
            // Check against the definitive source of active status
            if (activeVouches[allReceived[i].voucher][allReceived[i].borrower].isActive) {
                activeCount++;
            }
        }

        activeReceivedVouches = new Vouch[](activeCount);
        uint currentIndex = 0;
        for (uint i = 0; i < allReceived.length; i++) {
            // Retrieve the potentially updated state from activeVouches map
            Vouch storage currentVouchState = activeVouches[allReceived[i].voucher][allReceived[i].borrower];
            if (currentVouchState.isActive) {
                activeReceivedVouches[currentIndex] = currentVouchState;
                currentIndex++;
            }
        }
    }
} 