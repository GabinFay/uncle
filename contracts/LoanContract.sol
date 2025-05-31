// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserRegistry.sol";
import "./SocialVouching.sol";
// import "./interfaces/IPyth.sol"; // Placeholder for Pyth integration
// import "./interfaces/IReputationOApp.sol"; // Placeholder for Reputation integration

/**
 * @title LoanContract
 * @dev Manages the micro-lending lifecycle.
 */
contract LoanContract is Ownable, ReentrancyGuard {
    UserRegistry public userRegistry;
    SocialVouching public socialVouching;
    address public treasuryAddress; // Address of the Treasury.sol contract
    // IReputationOApp public reputationOApp; // Placeholder
    // IPyth public pyth; // Placeholder

    enum LoanStatus { Pending, Active, Repaid, Defaulted, Liquidated }

    struct Loan {
        bytes32 loanId;
        address borrower;
        uint256 principalAmount;
        address loanToken; // Token in which loan is denominated
        uint256 interestRate; // Basis points, e.g., 500 = 5%
        uint256 duration; // Seconds
        uint256 startTime;
        uint256 collateralAmount;
        address collateralToken;
        uint256 totalVouchedAmountAtApplication; // Vouched amount snapshotted at loan application
        LoanStatus status;
    }

    mapping(bytes32 => Loan) public loans;
    mapping(address => bytes32[]) public userLoans; // Borrower => array of their loan IDs
    uint256 public loanCounter; // For generating unique loan IDs

    // --- Events ---
    event LoanApplied(bytes32 indexed loanId, address indexed borrower, uint256 amount, address token);
    event LoanApproved(bytes32 indexed loanId);
    event LoanDisbursed(bytes32 indexed loanId);
    event LoanRepaid(bytes32 indexed loanId, uint256 amountPaid);
    event LoanDefaulted(bytes32 indexed loanId);
    event LoanLiquidated(bytes32 indexed loanId, uint256 collateralSeized);

    // --- Modifiers ---
    modifier onlyVerifiedUser(address user) {
        require(userRegistry.isUserWorldIdVerified(user), "LoanContract: User not World ID verified");
        _;
    }

    modifier onlyLoanExists(bytes32 loanId) {
        require(loans[loanId].borrower != address(0), "LoanContract: Loan does not exist");
        _;
    }

    constructor(
        address userRegistryAddress,
        address socialVouchingAddress,
        address initialTreasuryAddress
        // address reputationOAppAddress, // Placeholder
        // address pythAddress // Placeholder
    ) Ownable(msg.sender) {
        require(userRegistryAddress != address(0), "Invalid UserRegistry address");
        require(socialVouchingAddress != address(0), "Invalid SocialVouching address");
        require(initialTreasuryAddress != address(0), "Invalid Treasury address");
        userRegistry = UserRegistry(userRegistryAddress);
        socialVouching = SocialVouching(socialVouchingAddress);
        treasuryAddress = initialTreasuryAddress;
        // reputationOApp = IReputationOApp(reputationOAppAddress); // Placeholder
        // pyth = IPyth(pythAddress); // Placeholder
    }

    function applyForLoan(
        uint256 principalAmount_,
        address loanToken_,
        uint256 interestRate_,
        uint256 duration_,
        uint256 collateralAmount_,
        address collateralToken_
    ) external nonReentrant onlyVerifiedUser(msg.sender) {
        require(principalAmount_ > 0, "Principal must be positive");
        require(loanToken_ != address(0), "Invalid loan token");
        // Further checks: interestRate_, duration_ within platform limits

        // Placeholder: AI Credit Score Check (would come from backend or on-chain attestation)
        // uint256 aiScore = getAIScore(msg.sender);
        // require(aiScore >= MIN_AI_SCORE_FOR_LOAN, "AI score too low");

        uint256 currentVouchedAmount = socialVouching.getTotalVouchedAmountForBorrower(msg.sender);
        // require(currentVouchedAmount >= requiredVouchAmount(principalAmount_), "Insufficient vouched amount");

        // Placeholder: LTV Check with Pyth if collateral is provided
        if (collateralAmount_ > 0 && collateralToken_ != address(0)) {
            // uint256 collateralValue = getCollateralValueInUSD(collateralAmount_, collateralToken_);
            // uint256 loanValueInUSD = getLoanValueInUSD(principalAmount_, loanToken_);
            // require(calculateLTV(loanValueInUSD, collateralValue) <= MAX_LTV, "LTV too high");
            IERC20(collateralToken_).transferFrom(msg.sender, address(this), collateralAmount_);
        }

        loanCounter++;
        bytes32 newLoanId = keccak256(abi.encodePacked(msg.sender, block.timestamp, loanCounter));

        loans[newLoanId] = Loan({
            loanId: newLoanId,
            borrower: msg.sender,
            principalAmount: principalAmount_,
            loanToken: loanToken_,
            interestRate: interestRate_,
            duration: duration_,
            startTime: 0, // Set when loan is disbursed
            collateralAmount: collateralAmount_,
            collateralToken: collateralToken_,
            totalVouchedAmountAtApplication: currentVouchedAmount,
            status: LoanStatus.Pending
        });

        userLoans[msg.sender].push(newLoanId);
        emit LoanApplied(newLoanId, msg.sender, principalAmount_, loanToken_);
    }

    function approveLoan(bytes32 loanId) external onlyOwner nonReentrant onlyLoanExists(loanId) {
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.Pending, "Loan not pending approval");

        loan.status = LoanStatus.Active; // Simplified: directly to Active, could have an "Approved" state first
        loan.startTime = block.timestamp;

        // Transfer loan principal from Treasury to borrower
        IERC20(loan.loanToken).transferFrom(treasuryAddress, loan.borrower, loan.principalAmount);

        emit LoanApproved(loanId);
        emit LoanDisbursed(loanId); // Assuming approval leads to immediate disbursal for simplicity
    }

    function repayLoan(bytes32 loanId) external payable nonReentrant onlyLoanExists(loanId) {
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender, "Only borrower can repay");
        require(loan.status == LoanStatus.Active, "Loan not active");

        uint256 amountDue = calculateAmountDue(loanId);
        // For ETH denominated loans, msg.value should cover amountDue
        // For ERC20 loans, transferFrom borrower to treasuryAddress
        if (loan.loanToken == address(0)) { // Assuming address(0) means ETH for simplicity
            require(msg.value >= amountDue, "Insufficient ETH sent for repayment");
            payable(treasuryAddress).transfer(amountDue);
            if (msg.value > amountDue) {
                payable(msg.sender).transfer(msg.value - amountDue); // Refund excess
            }
        } else {
            require(msg.value == 0, "ETH sent for ERC20 loan repayment");
            IERC20(loan.loanToken).transferFrom(msg.sender, treasuryAddress, amountDue);
        }

        loan.status = LoanStatus.Repaid;
        // Placeholder: Update reputation
        // reputationOApp.updateLocalReputation(loan.borrower, calculateReputationBoost(loanId));

        // Placeholder: Reward vouchers (if applicable for this loan type/platform rules)
        // socialVouching.rewardVoucher(loan.borrower, ...);

        emit LoanRepaid(loanId, amountDue);
    }

    function liquidateLoan(bytes32 loanId) external onlyOwner nonReentrant onlyLoanExists(loanId) {
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.Active, "Loan not active"); // Or a specific "Overdue" status
        require(block.timestamp > loan.startTime + loan.duration, "Loan not yet overdue");
        // Add more complex liquidation conditions (e.g., LTV breach from oracle)

        uint256 seizedCollateralValue = 0;
        if (loan.collateralAmount > 0 && loan.collateralToken != address(0)) {
            // Transfer collateral from this contract to treasury or liquidator
            IERC20(loan.collateralToken).transfer(treasuryAddress, loan.collateralAmount);
            seizedCollateralValue = loan.collateralAmount; // Simplification, actual value depends on token
        }

        // Slash vouches
        // This is a simplified call. A more robust system would determine how much each voucher loses.
        // socialVouching.slashVouch(loan.borrower, voucherAddress, amountToSlash, treasuryAddress);
        // Need a way to iterate over vouchers or have SocialVouching manage the distribution of slashes.
        
        loan.status = LoanStatus.Liquidated;
        emit LoanLiquidated(loanId, seizedCollateralValue);
    }

    // --- View Functions ---
    function getLoanDetails(bytes32 loanId) external view onlyLoanExists(loanId) returns (Loan memory) {
        return loans[loanId];
    }

    function getUserLoanIds(address userAddress) external view returns (bytes32[] memory) {
        return userLoans[userAddress];
    }

    function calculateAmountDue(bytes32 loanId) public view onlyLoanExists(loanId) returns (uint256) {
        Loan memory loan = loans[loanId];
        if (loan.status == LoanStatus.Repaid) return 0;
        // Simplified interest calculation: Principal + (Principal * InterestRate / 10000)
        // Ignores compounding and actual time passed for overdue loans for simplicity in this initial version.
        uint256 interest = (loan.principalAmount * loan.interestRate) / 10000;
        return loan.principalAmount + interest;
    }
    
    // --- Admin Functions ---
    function setTreasuryAddress(address newTreasuryAddress) external onlyOwner {
        require(newTreasuryAddress != address(0), "Invalid new treasury address");
        treasuryAddress = newTreasuryAddress;
    }

    // Placeholder for Pyth/ReputationApp address setters if needed
    // function setReputationOAppAddress(address newReputationOAppAddress) external onlyOwner { ... }
    // function setPythAddress(address newPythAddress) external onlyOwner { ... }
} 