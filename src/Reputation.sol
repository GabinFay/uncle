// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./UserRegistry.sol";
import "./P2PLending.sol"; // For enums like LoanStatus, or to be called by P2PLending
import "forge-std/console.sol";

/**
 * @title Reputation Contract
 * @author CreditInclusion Team
 * @notice Manages user reputation scores, social vouching, and stake slashing for the P2P lending platform.
 * @dev Interacts with UserRegistry for World ID verification and P2PLending for loan lifecycle events.
 * All vouch stakes are held within this contract.
 */
contract Reputation is Ownable, ReentrancyGuard {
    /**
     * @notice Reference to the UserRegistry contract for verifying user identities.
     */
    UserRegistry public userRegistry;

    /**
     * @notice Address of the P2PLending contract, authorized to call reputation update functions.
     */
    address public p2pLendingContractAddress; // Address of the P2PLending contract

    /**
     * @notice Stores detailed reputation metrics for a user.
     * @param userAddress The address of the user.
     * @param loansTaken Total number of loans the user has taken as a borrower.
     * @param loansGiven Total number of loans the user has funded as a lender.
     * @param loansRepaidOnTime Total number of loans repaid on time by the user (as borrower).
     * @param loansDefaulted Total number of loans defaulted by the user (as borrower).
     * @param totalValueBorrowed Total value (in underlying loan token terms, not USD) borrowed.
     * @param totalValueLent Total value (in underlying loan token terms, not USD) lent.
     * @param currentReputationScore The user's current numerical reputation score.
     * @param vouchingStakeAmount Total value of active stake the user has provided for others.
     * @param timesVouchedForOthers Number of times the user has actively vouched for others.
     * @param timesDefaultedAsVoucher Number of times a user they vouched for has defaulted.
     */
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

    /**
     * @notice Represents a social vouch, where one user stakes tokens to back another.
     * @param voucher Address of the user providing the vouch and stake.
     * @param borrower Address of the user being vouched for.
     * @param tokenAddress The ERC20 token used for staking this vouch.
     * @param stakedAmount The amount of `tokenAddress` staked for this vouch.
     * @param isActive True if the vouch is currently active and stake is locked.
     */
    struct Vouch {
        address voucher;        // Who is vouching
        address borrower;       // Who is being vouched for
        address tokenAddress;   // Token used for staking the vouch
        uint256 stakedAmount;   // Amount staked
        bool isActive;          // Is the vouch currently active
    }

    /**
     * @notice Maps a user's address to their detailed ReputationProfile.
     */
    mapping(address => ReputationProfile) public userReputations;

    /**
     * @notice Stores the active vouch between a specific voucher and borrower.
     * @dev Mapping: voucher address => borrower address => Vouch struct.
     */
    mapping(address => mapping(address => Vouch)) public activeVouches; // voucher => borrower => Vouch

    /**
     * @notice Tracks all vouches a user has given, including inactive ones.
     * @dev Mapping: voucher address => array of Vouch structs.
     * Useful for historical data; active status must be checked via `activeVouches` mapping.
     */
    mapping(address => Vouch[]) public userVouchesGiven; // voucher => list of vouches they made

    /**
     * @notice Tracks all vouches a user has received, including inactive ones.
     * @dev Mapping: borrower address => array of Vouch structs.
     * Useful for historical data; active status must be checked via `activeVouches` mapping.
     */
    mapping(address => Vouch[]) public userVouchesReceived; // borrower => list of vouches they received

    // --- Constants for reputation scoring ---
    /**
     * @notice Points awarded to borrower and lender when a loan is fully repaid.
     */
    int256 public constant REPUTATION_POINTS_REPAID = 10;
    /**
     * @notice Points deducted from borrower when a loan is defaulted.
     */
    int256 public constant REPUTATION_POINTS_DEFAULTED = -50;
    /**
     * @notice Points deducted from a voucher when a user they vouched for defaults.
     */
    int256 public constant REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER = -20; // Penalty for voucher when vouchee defaults
    /**
     * @notice Points awarded to a lender when a loan they funded is successfully repaid.
     */
    int256 public constant REPUTATION_POINTS_LENT_SUCCESSFULLY = 5; // Optional for lender

    /**
     * @notice Emitted when a user's reputation score is updated.
     * @param user The address of the user whose reputation changed.
     * @param newScore The new reputation score of the user.
     * @param reason A brief description of why the reputation was updated.
     */
    event ReputationUpdated(address indexed user, int256 newScore, string reason);
    /**
     * @notice Emitted when a new vouch is successfully added.
     * @param voucher The address of the user who provided the vouch.
     * @param borrower The address of the user who received the vouch.
     * @param token The address of the ERC20 token staked.
     * @param amount The amount of the token staked.
     */
    event VouchAdded(address indexed voucher, address indexed borrower, address token, uint256 amount);
    /**
     * @notice Emitted when a vouch is successfully removed and stake returned.
     * @param voucher The address of the user who removed their vouch.
     * @param borrower The address of the user they were vouching for.
     * @param returnedAmount The amount of stake returned to the voucher.
     */
    event VouchRemoved(address indexed voucher, address indexed borrower, uint256 returnedAmount);
    /**
     * @notice Emitted when a portion of a vouch's stake is slashed due to a borrower default.
     * @param voucher The address of the voucher whose stake was slashed.
     * @param defaultingBorrower The address of the borrower who defaulted, causing the slash.
     * @param slashedAmount The amount of stake slashed and transferred.
     * @param slashedToLender The address of the lender who received the slashed funds.
     */
    event VouchSlashed(address indexed voucher, address indexed defaultingBorrower, uint256 slashedAmount, address indexed slashedToLender);

    /**
     * @dev Modifier to ensure the calling user is verified in the UserRegistry.
     * @param user The address to check for World ID verification.
     */
    modifier onlyVerifiedUser(address user) {
        require(userRegistry.isUserWorldIdVerified(user), "Reputation: User not World ID verified");
        _;    
    }

    /**
     * @dev Modifier to ensure that the caller is the authorized P2PLending contract.
     */
    modifier onlyP2PLendingContract() {
        // console.log("Reputation: onlyP2PLendingContract check. msg.sender:", msg.sender);
        // console.log("Reputation: onlyP2PLendingContract check. p2pLendingContractAddress:", p2pLendingContractAddress);
        require(msg.sender == p2pLendingContractAddress, "Reputation: Caller is not the P2P lending contract");
        _;
    }

    /**
     * @notice Contract constructor.
     * @param _userRegistryAddress The address of the deployed UserRegistry contract.
     */
    constructor(address _userRegistryAddress) Ownable(msg.sender) {
        require(_userRegistryAddress != address(0), "Invalid UserRegistry address");
        userRegistry = UserRegistry(_userRegistryAddress);
        // p2pLendingContractAddress will be set by owner after deployment
    }

    /**
     * @notice Sets the address of the P2PLending contract.
     * @dev Can only be called by the contract owner. This address is required for core reputation update functions.
     * @param _p2pLendingAddress The address of the P2PLending contract.
     */
    function setP2PLendingContractAddress(address _p2pLendingAddress) external onlyOwner {
        require(_p2pLendingAddress != address(0), "Invalid P2P Lending contract address");
        p2pLendingContractAddress = _p2pLendingAddress;
    }

    // --- Core Reputation Update Functions (Called by P2PLending contract) ---
    /**
     * @notice Updates reputation scores for borrower and lender upon successful loan repayment.
     * @dev Called by the P2PLending contract. Initializes profiles if they don't exist.
     * @param borrower The address of the borrower who repaid the loan.
     * @param lender The address of the lender who was repaid.
     * @param loanAmount The principal amount of the repaid loan.
     */
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
        emit ReputationUpdated(borrower, borrowerProfile.currentReputationScore, "Loan repaid on time");

        ReputationProfile storage lenderProfile = userReputations[lender];
        lenderProfile.loansGiven++;
        lenderProfile.totalValueLent += loanAmount;
        lenderProfile.currentReputationScore += REPUTATION_POINTS_LENT_SUCCESSFULLY;
        emit ReputationUpdated(lender, lenderProfile.currentReputationScore, "Loan lent and repaid");
    }

    /**
     * @notice Updates reputation score for a borrower upon loan default.
     * @dev Called by the P2PLending contract. Initializes profile if it doesn't exist.
     * Parameters `lender`, `loanAmount`, `vouchesForThisLoan` are currently unused placeholders
     * but are kept for potential future expansion of this function's logic by the P2PLending contract.
     * The P2PLending contract currently handles vouch slashing separately after calling this function.
     * @param borrower The address of the borrower who defaulted.
     * @param lender (Currently unused) The address of the lender of the defaulted loan.
     * @param loanAmount (Currently unused) The principal amount of the defaulted loan.
     * @param vouchesForThisLoan (Currently unused) Placeholder for specific vouches tied to the loan.
     */
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
    /**
     * @notice Allows a verified user to stake tokens to vouch for another verified user.
     * @dev The voucher's tokens are transferred to and held by this contract.
     *      A user cannot vouch for themselves. 
     *      A user cannot add a new vouch for a borrower if they already have an active vouch for them.
     *      Initializes reputation profiles for voucher and borrower if they don't exist.
     * @param borrowerToVouchFor The address of the user to vouch for.
     * @param amountToStake The amount of `tokenAddress` to stake.
     * @param tokenAddress The ERC20 token to be used for staking.
     */
    function addVouch(
        address borrowerToVouchFor,
        uint256 amountToStake,
        address tokenAddress
    ) external nonReentrant onlyVerifiedUser(msg.sender) {
        require(borrowerToVouchFor != msg.sender, "Cannot vouch for yourself");
        require(userRegistry.isUserWorldIdVerified(borrowerToVouchFor), "Borrower not World ID verified");
        require(amountToStake > 0, "Stake amount must be positive");
        require(tokenAddress != address(0), "Invalid token address");
        require(!activeVouches[msg.sender][borrowerToVouchFor].isActive, "Already actively vouching for this borrower");

        _initializeReputationProfileIfNotExists(msg.sender); // Voucher
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

    /**
     * @notice Allows a voucher to remove their active vouch and reclaim their stake.
     * @dev The vouch is marked as inactive, and the staked tokens are returned to the voucher.
     *      Future enhancements might prevent vouch removal if the borrower has active loans that relied on this vouch.
     * @param borrowerVouchedFor The address of the user for whom the vouch is being removed.
     */
    function removeVouch(address borrowerVouchedFor) external nonReentrant onlyVerifiedUser(msg.sender) {
        Vouch storage vouch = activeVouches[msg.sender][borrowerVouchedFor];
        require(vouch.isActive, "No active vouch for this borrower");

        vouch.isActive = false;
        uint256 stakedAmountToReturn = vouch.stakedAmount; // Store before modifying
        // vouch.stakedAmount = 0; // Explicitly zero out after confirming return and before emit?

        IERC20(vouch.tokenAddress).transfer(msg.sender, stakedAmountToReturn); 

        ReputationProfile storage voucherProfile = userReputations[msg.sender];
        voucherProfile.vouchingStakeAmount -= stakedAmountToReturn;

        emit VouchRemoved(msg.sender, borrowerVouchedFor, stakedAmountToReturn);
    }
    
    /**
     * @notice Slashes a portion of a voucher's stake and updates their reputation when a vouched borrower defaults.
     * @dev Called by the P2PLending contract. The slashed stake is transferred to the lender of the defaulted loan.
     *      If the vouch's stake is fully depleted, it is marked as inactive.
     * @param voucher The address of the user whose vouch is being slashed.
     * @param defaultingBorrower The address of the borrower who defaulted.
     * @param amountToSlash The amount of stake to slash from the vouch.
     * @param lenderToCompensate The address of the lender who will receive the slashed funds.
     */
    function slashVouchAndReputation(
        address voucher,
        address defaultingBorrower,
        uint256 amountToSlash, 
        address lenderToCompensate 
    ) external onlyP2PLendingContract { 
        Vouch storage vouch = activeVouches[voucher][defaultingBorrower];
        require(vouch.isActive, "Vouch not active or does not exist");
        require(amountToSlash <= vouch.stakedAmount, "Slash amount exceeds staked amount");
        require(amountToSlash > 0, "Slash amount must be positive"); // Ensure non-zero slash

        _initializeReputationProfileIfNotExists(voucher);

        vouch.stakedAmount -= amountToSlash;
        IERC20(vouch.tokenAddress).transfer(lenderToCompensate, amountToSlash);

        ReputationProfile storage voucherProfile = userReputations[voucher];
        voucherProfile.currentReputationScore += REPUTATION_POINTS_VOUCH_DEFAULTED_VOUCHER;
        voucherProfile.vouchingStakeAmount -= amountToSlash; 
        voucherProfile.timesDefaultedAsVoucher++;

        emit VouchSlashed(voucher, defaultingBorrower, amountToSlash, lenderToCompensate);
        emit ReputationUpdated(voucher, voucherProfile.currentReputationScore, "Vouched loan defaulted");

        if (vouch.stakedAmount == 0) {
            vouch.isActive = false; 
        }
    }

    // --- Helper Functions ---
    /**
     * @dev Internal function to initialize a user's reputation profile if it doesn't exist and the user is World ID verified.
     * @param user The address of the user whose profile is to be initialized.
     */
    function _initializeReputationProfileIfNotExists(address user) internal {
        // Check if userAddress is zero (default for struct) AND if the user is actually verified in UserRegistry
        if (userReputations[user].userAddress == address(0) && userRegistry.isUserWorldIdVerified(user)) {
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

    // --- Getter Functions ---
    /**
     * @notice Retrieves the full reputation profile for a given user.
     * @param user The address of the user.
     * @return profile The ReputationProfile struct for the user. Returns a default/empty profile if the user is not found or not initialized.
     */
    function getReputationProfile(address user) external view returns (ReputationProfile memory profile) {
        return userReputations[user]; 
    }

    /**
     * @notice Retrieves the details of a specific active vouch between a voucher and a borrower.
     * @param voucher The address of the voucher.
     * @param borrower The address of the borrower.
     * @return vouch The Vouch struct. Returns a default/empty struct if no active vouch exists.
     */
    function getVouchDetails(address voucher, address borrower) external view returns (Vouch memory vouch) {
        return activeVouches[voucher][borrower];
    }

    /**
     * @notice Retrieves all vouches (active and inactive) a specific user has given.
     * @dev Client-side filtering may be needed to identify currently active vouches from this list.
     *      To get only active vouches, iterate and check `activeVouches[voucherAddress][borrowerAddress].isActive`.
     * @param voucher The address of the user who has given vouches.
     * @return vouchesGiven An array of Vouch structs.
     */
    function getUserVouchesGiven(address voucher) external view returns (Vouch[] memory vouchesGiven) {
        return userVouchesGiven[voucher]; 
    }

    /**
     * @notice Retrieves all vouches (active and inactive) a specific user has received.
     * @dev Client-side filtering may be needed to identify currently active vouches from this list.
     *      Use `getActiveVouchesForBorrower` for a pre-filtered list of active received vouches.
     * @param borrower The address of the user who has received vouches.
     * @return vouchesReceived An array of Vouch structs.
     */
    function getUserVouchesReceived(address borrower) external view returns (Vouch[] memory vouchesReceived) {
        return userVouchesReceived[borrower]; 
    }

    /**
     * @notice Retrieves all *active* vouches a specific borrower has received.
     * @dev This function iterates through the `userVouchesReceived` array for the borrower
     *      and checks the `isActive` status from the `activeVouches` mapping to ensure up-to-date information.
     * @param borrower The address of the user (borrower) whose active received vouches are being queried.
     * @return activeReceivedVouches An array of Vouch structs representing currently active vouches for the borrower.
     */
    function getActiveVouchesForBorrower(address borrower) external view returns (Vouch[] memory activeReceivedVouches) {
        Vouch[] memory allReceived = userVouchesReceived[borrower];
        uint activeCount = 0;
        for (uint i = 0; i < allReceived.length; i++) {
            if (activeVouches[allReceived[i].voucher][allReceived[i].borrower].isActive) {
                activeCount++;
            }
        }

        activeReceivedVouches = new Vouch[](activeCount); 
        uint currentIndex = 0;
        for (uint i = 0; i < allReceived.length; i++) {
            Vouch storage currentVouchState = activeVouches[allReceived[i].voucher][allReceived[i].borrower];
            if (currentVouchState.isActive) {
                activeReceivedVouches[currentIndex] = currentVouchState; 
                currentIndex++;
            }
        }
        // The return variable was already named activeReceivedVouches by the type declaration
    }
} 