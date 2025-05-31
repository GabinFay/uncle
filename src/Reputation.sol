// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./UserRegistry.sol";
import "./P2PLending.sol"; // For enums like LoanStatus, or to be called by P2PLending
import "forge-std/console.sol";

contract Reputation is Ownable, ReentrancyGuard {
    UserRegistry public userRegistry;
    address public p2pLendingContractAddress; // Address of the P2PLending contract

    struct ReputationProfile {
        address userAddress; // Linked to World ID via UserRegistry
        uint256 loansTaken;
        uint256 loansGiven; // If lenders also get reputation
        uint256 loansRepaidOnTime;
        uint256 loansDefaulted;
        uint256 totalValueBorrowed;
        uint256 totalValueLent;
        int256 currentReputationScore; // Can be positive or negative
        uint256 vouchingStakeAmount; // Total amount user has staked for others
        uint256 timesVouchedForOthers;
        uint256 timesDefaultedAsVoucher;
    }

    struct Vouch {
        address voucher;        // Who is vouching
        address borrower;       // Who is being vouched for
        address tokenAddress;   // Token used for staking the vouch
        uint256 stakedAmount;   // Amount staked
        bool isActive;          // Is the vouch currently active
    }

    mapping(address => ReputationProfile) public userReputations;
    mapping(address => mapping(address => Vouch)) public activeVouches; // voucher => borrower => Vouch
    mapping(address => Vouch[]) public userVouchesGiven; // voucher => list of vouches they made
    mapping(address => Vouch[]) public userVouchesReceived; // borrower => list of vouches they received

    // --- Constants for reputation scoring ---
    int256 public constant REPUTATION_POINTS_REPAID = 10;
    int256 public constant REPUTATION_POINTS_DEFAULTED = -50;
    int256 public constant REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER = -20; // Penalty for voucher when vouchee defaults
    int256 public constant REPUTATION_POINTS_LENT_SUCCESSFULLY = 5; // Optional for lender

    event ReputationUpdated(address indexed user, int256 newScore, string reason);
    event VouchAdded(address indexed voucher, address indexed borrower, address token, uint256 amount);
    event VouchRemoved(address indexed voucher, address indexed borrower, uint256 returnedAmount);
    event VouchSlashed(address indexed voucher, address indexed defaultingBorrower, uint256 slashedAmount, address indexed slashedToLender);

    modifier onlyVerifiedUser(address user) {
        require(userRegistry.isUserWorldIdVerified(user), "Reputation: User not World ID verified");
        _;    
    }

    modifier onlyP2PLendingContract() {
        // console.log("Reputation: onlyP2PLendingContract check. msg.sender:", msg.sender);
        // console.log("Reputation: onlyP2PLendingContract check. p2pLendingContractAddress:", p2pLendingContractAddress);
        require(msg.sender == p2pLendingContractAddress, "Reputation: Caller is not the P2P lending contract");
        _;
    }

    constructor(address _userRegistryAddress) Ownable(msg.sender) {
        require(_userRegistryAddress != address(0), "Invalid UserRegistry address");
        userRegistry = UserRegistry(_userRegistryAddress);
        // p2pLendingContractAddress will be set by owner after deployment
    }

    function setP2PLendingContractAddress(address _p2pLendingAddress) external onlyOwner {
        require(_p2pLendingAddress != address(0), "Invalid P2P Lending contract address");
        p2pLendingContractAddress = _p2pLendingAddress;
    }

    // --- Core Reputation Update Functions (Called by P2PLending contract) ---
    function updateReputationOnLoanRepayment(
        address borrower,
        address lender, // For potential lender reputation
        uint256 loanAmount
    ) external onlyP2PLendingContract {
        // Ensure profiles exist (or create them if user is verified)
        _initializeReputationProfileIfNotExists(borrower);
        _initializeReputationProfileIfNotExists(lender);

        ReputationProfile storage borrowerProfile = userReputations[borrower];
        borrowerProfile.loansTaken++;
        borrowerProfile.loansRepaidOnTime++;
        borrowerProfile.totalValueBorrowed += loanAmount;
        borrowerProfile.currentReputationScore += REPUTATION_POINTS_REPAID;
        emit ReputationUpdated(borrower, borrowerProfile.currentReputationScore, "Loan repaid on time");

        ReputationProfile storage lenderProfile = userReputations[lender];
        lenderProfile.loansGiven++;
        // lenderProfile.loansRepaidOnTime++; // This might be double counting or specific to lender's view
        lenderProfile.totalValueLent += loanAmount;
        lenderProfile.currentReputationScore += REPUTATION_POINTS_LENT_SUCCESSFULLY;
        emit ReputationUpdated(lender, lenderProfile.currentReputationScore, "Loan lent and repaid");
    }

    function updateReputationOnLoanDefault(
        address borrower,
        address lender, // Unused for now
        uint256 loanAmount, // Unused for now
        bytes32[] calldata vouchesForThisLoan // Unused for now, placeholder
    ) external onlyP2PLendingContract {
        _initializeReputationProfileIfNotExists(borrower);

        ReputationProfile storage borrowerProfile = userReputations[borrower];
        borrowerProfile.loansTaken++;
        borrowerProfile.loansDefaulted++;
        borrowerProfile.currentReputationScore += REPUTATION_POINTS_DEFAULTED;
        emit ReputationUpdated(borrower, borrowerProfile.currentReputationScore, "Loan defaulted");
    }

    // --- Vouching Functions ---
    function addVouch(
        address borrowerToVouchFor,
        uint256 amountToStake,
        address tokenAddress
    ) external nonReentrant onlyVerifiedUser(msg.sender) {
        require(borrowerToVouchFor != msg.sender, "Cannot vouch for yourself");
        require(userRegistry.isUserWorldIdVerified(borrowerToVouchFor), "Borrower not World ID verified");
        require(amountToStake > 0, "Stake amount must be positive");
        require(tokenAddress != address(0), "Invalid token address");
        // Check if already vouched? Or allow multiple vouches/updates?
        // For now, assume one active vouch per voucher-borrower pair.
        require(!activeVouches[msg.sender][borrowerToVouchFor].isActive, "Already actively vouching for this borrower");

        _initializeReputationProfileIfNotExists(msg.sender);
        _initializeReputationProfileIfNotExists(borrowerToVouchFor);

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amountToStake); // Contract holds the stake

        Vouch memory newVouch = Vouch({
            voucher: msg.sender,
            borrower: borrowerToVouchFor,
            tokenAddress: tokenAddress,
            stakedAmount: amountToStake,
            isActive: true
        });
        activeVouches[msg.sender][borrowerToVouchFor] = newVouch;
        userVouchesGiven[msg.sender].push(newVouch); // Careful, storing full struct copies
        userVouchesReceived[borrowerToVouchFor].push(newVouch);

        ReputationProfile storage voucherProfile = userReputations[msg.sender];
        voucherProfile.vouchingStakeAmount += amountToStake;
        voucherProfile.timesVouchedForOthers++;

        emit VouchAdded(msg.sender, borrowerToVouchFor, tokenAddress, amountToStake);
    }

    function removeVouch(address borrowerVouchedFor) external nonReentrant onlyVerifiedUser(msg.sender) {
        Vouch storage vouch = activeVouches[msg.sender][borrowerVouchedFor];
        require(vouch.isActive, "No active vouch for this borrower");
        // Add condition: Cannot remove vouch if borrower has active, vouched loans? This is complex.
        // For now, simple removal.

        vouch.isActive = false;
        uint256 stakedAmount = vouch.stakedAmount;
        IERC20(vouch.tokenAddress).transfer(msg.sender, stakedAmount); // Return stake

        // Clean up from arrays is hard. Better to mark inactive and filter off-chain or during specific reads.
        // Or use EnumerableSet for managing active vouches per user if on-chain iteration is needed.

        ReputationProfile storage voucherProfile = userReputations[msg.sender];
        voucherProfile.vouchingStakeAmount -= stakedAmount;

        emit VouchRemoved(msg.sender, borrowerVouchedFor, stakedAmount);
        // Consider resetting vouch.stakedAmount = 0; ?
    }
    
    // This function needs to be callable by P2PLending during default handling
    // if a specific loan agreement (which used vouches) defaults.
    function slashVouchAndReputation(
        address voucher,
        address defaultingBorrower,
        uint256 amountToSlash, // This should be <= vouch.stakedAmount for that specific vouch
        address lenderToCompensate // Lender of the defaulted loan
    ) external onlyP2PLendingContract { // Or specialized permission
        Vouch storage vouch = activeVouches[voucher][defaultingBorrower];
        require(vouch.isActive, "Vouch not active or does not exist");
        require(amountToSlash <= vouch.stakedAmount, "Slash amount exceeds staked amount");

        _initializeReputationProfileIfNotExists(voucher);

        vouch.stakedAmount -= amountToSlash;
        // Transfer slashed amount from this contract (where stake is held) to the lender
        IERC20(vouch.tokenAddress).transfer(lenderToCompensate, amountToSlash);

        ReputationProfile storage voucherProfile = userReputations[voucher];
        voucherProfile.currentReputationScore += REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER;
        voucherProfile.vouchingStakeAmount -= amountToSlash; // Reflected in actual stake
        voucherProfile.timesDefaultedAsVoucher++;

        emit VouchSlashed(voucher, defaultingBorrower, amountToSlash, lenderToCompensate);
        emit ReputationUpdated(voucher, voucherProfile.currentReputationScore, "Vouched loan defaulted");

        if (vouch.stakedAmount == 0) {
            vouch.isActive = false; // Deactivate if fully slashed
        }
    }

    // --- Helper Functions ---
    function _initializeReputationProfileIfNotExists(address user) internal {
        if (userReputations[user].userAddress == address(0) && userRegistry.isUserWorldIdVerified(user)) {
            userReputations[user] = ReputationProfile({
                userAddress: user,
                loansTaken: 0,
                loansGiven: 0,
                loansRepaidOnTime: 0,
                loansDefaulted: 0,
                totalValueBorrowed: 0,
                totalValueLent: 0,
                currentReputationScore: 0, // Start with neutral score
                vouchingStakeAmount: 0,
                timesVouchedForOthers: 0,
                timesDefaultedAsVoucher: 0
            });
        }
    }

    // --- Getter Functions ---
    function getReputationProfile(address user) external view returns (ReputationProfile memory) {
        // require(userReputations[user].userAddress != address(0), "Profile not found"); // Or return empty/default
        return userReputations[user]; // Returns default struct if not initialized
    }

    function getVouchDetails(address voucher, address borrower) external view returns (Vouch memory) {
        return activeVouches[voucher][borrower];
    }

    // Consider EnumerableSet for these if on-chain iteration over active vouches is needed without full array scans.
    function getUserVouchesGiven(address voucher) external view returns (Vouch[] memory) {
        return userVouchesGiven[voucher]; // Includes inactive ones unless filtered by client
    }

    function getUserVouchesReceived(address borrower) external view returns (Vouch[] memory) {
        return userVouchesReceived[borrower]; // Includes inactive ones unless filtered by client
    }

    function getActiveVouchesForBorrower(address borrower) external view returns (Vouch[] memory) {
        Vouch[] memory allReceived = userVouchesReceived[borrower];
        uint activeCount = 0;
        for (uint i = 0; i < allReceived.length; i++) {
            // Check the definitive source of truth for isActive status
            if (activeVouches[allReceived[i].voucher][allReceived[i].borrower].isActive) {
                activeCount++;
            }
        }

        Vouch[] memory currentActiveVouches = new Vouch[](activeCount); // Renamed to avoid shadowing
        uint currentIndex = 0;
        for (uint i = 0; i < allReceived.length; i++) {
            // Re-fetch the vouch from the mapping to get its current state
            Vouch storage currentVouchState = activeVouches[allReceived[i].voucher][allReceived[i].borrower];
            if (currentVouchState.isActive) {
                currentActiveVouches[currentIndex] = currentVouchState; // Store the up-to-date vouch
                currentIndex++;
            }
        }
        return currentActiveVouches;
    }
} 