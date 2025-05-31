// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol"; // No longer needed for Pyth
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserRegistry.sol";
import "./SocialVouching.sol";
import "./Treasury.sol"; 
// import "./interfaces/IPyth.sol"; // No longer needed
import "./interfaces/IReputationOApp.sol"; 
// import "forge-std/console.sol"; // For debugging, removed

/**
 * @title LoanContract
 * @dev Manages the micro-lending lifecycle.
 */
contract LoanContract is Ownable, ReentrancyGuard {
    UserRegistry public userRegistry;
    SocialVouching public socialVouching;
    address payable public treasuryAddress; 
    // IPyth public pyth; // Pyth address - REMOVED
    IReputationOApp public reputationOApp; 

    // mapping(address => bytes32) public tokenToPythPriceId; // REMOVED
    // uint256 public constant MAX_LTV = 8000; // REMOVED
    // uint256 public constant PRICE_PRECISION = 1e8; // REMOVED

    struct LoanVoucherDetail {
        address voucherAddress;
        address tokenAddress;
        uint256 amountVouchedAtLoanTime;
    }

    enum LoanStatus { Pending, Active, Repaid, Defaulted, Liquidated }

    struct Loan {
        bytes32 loanId;
        address borrower;
        uint256 principalAmount;
        address loanToken; // Token in which loan is denominated
        uint256 interestRate; // Basis points, e.g., 500 = 5%
        uint256 duration; // Seconds
        uint256 startTime;
        uint256 dueDate; // Calculated when loan starts
        uint256 collateralAmount;
        address collateralToken;
        uint256 totalVouchedAmountAtApplication; // Vouched amount snapshotted at loan application
        LoanVoucherDetail[] vouches; // << NEW: Array to store individual vouches active at loan time
        uint256 amountPaid; // To track repayments
        LoanStatus status;
    }

    mapping(bytes32 => Loan) public loans;
    mapping(address => bytes32[]) public userLoans; // Borrower => array of their loan IDs
    uint256 public loanCounter; // For generating unique loan IDs

    // --- Events ---
    event LoanApplied(bytes32 indexed loanId, address indexed borrower, uint256 amount, address token);
    event LoanApproved(bytes32 indexed loanId);
    event LoanDisbursed(bytes32 indexed loanId);
    event LoanPaymentMade(bytes32 indexed loanId, uint256 paymentAmount, uint256 totalPaid);
    event LoanFullyRepaid(bytes32 indexed loanId);
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
        address payable initialTreasuryAddress,
        // address initialPythAddress, // REMOVED
        address initialReputationOAppAddress 
    ) Ownable(msg.sender) {
        require(userRegistryAddress != address(0), "Invalid UserRegistry address");
        require(socialVouchingAddress != address(0), "Invalid SocialVouching address");
        require(initialTreasuryAddress != address(0), "Invalid Treasury address");
        // require(initialPythAddress != address(0), "Invalid Pyth address"); // REMOVED
        require(initialReputationOAppAddress != address(0), "Invalid ReputationOApp address"); 
        userRegistry = UserRegistry(userRegistryAddress);
        socialVouching = SocialVouching(socialVouchingAddress);
        treasuryAddress = initialTreasuryAddress;
        // pyth = IPyth(initialPythAddress); // REMOVED
        reputationOApp = IReputationOApp(initialReputationOAppAddress); 
    }

    function applyForLoan(
        uint256 principalAmount_,
        address loanToken_,
        uint256 interestRate_,
        uint256 duration_,
        uint256 collateralAmount_,
        address collateralToken_,
        address[] calldata voucherAddressesToConsider // << NEW: Array of voucher addresses to consider for this loan
    ) external nonReentrant onlyVerifiedUser(msg.sender) returns (bytes32 newLoanId) {
        require(principalAmount_ > 0, "Principal must be positive");
        require(loanToken_ != address(0), "Invalid loan token");
        // Further checks: interestRate_, duration_ within platform limits

        // Placeholder: AI Credit Score Check (would come from backend or on-chain attestation)
        // uint256 aiScore = getAIScore(msg.sender);
        // require(aiScore >= MIN_AI_SCORE_FOR_LOAN, "AI score too low");

        uint256 calculatedTotalVouchedAmount = 0;
        LoanVoucherDetail[] memory activeLoanVouches = new LoanVoucherDetail[](voucherAddressesToConsider.length);
        uint256 activeVouchesCount = 0;

        for (uint i = 0; i < voucherAddressesToConsider.length; i++) {
            address voucherAddr = voucherAddressesToConsider[i];
            if (voucherAddr != address(0) && voucherAddr != msg.sender) { // Basic checks
                SocialVouching.Vouch memory svVouch = socialVouching.getVouchDetails(msg.sender, voucherAddr);
                if (svVouch.active && svVouch.amountStaked > 0) {
                    activeLoanVouches[activeVouchesCount] = LoanVoucherDetail({
                        voucherAddress: svVouch.voucher, // Should be voucherAddr
                        tokenAddress: svVouch.tokenAddress,
                        amountVouchedAtLoanTime: svVouch.amountStaked
                    });
                    calculatedTotalVouchedAmount += svVouch.amountStaked;
                    activeVouchesCount++;
                }
            }
        }
        
        // Resize activeLoanVouches to actual count if necessary
        LoanVoucherDetail[] memory finalActiveLoanVouches = new LoanVoucherDetail[](activeVouchesCount);
        for (uint i = 0; i < activeVouchesCount; i++) {
            finalActiveLoanVouches[i] = activeLoanVouches[i];
        }

        // Placeholder: LTV Check with Pyth if collateral is provided - REMOVED
        // if (collateralAmount_ > 0 && collateralToken_ != address(0)) {
        //     require(tokenToPythPriceId[collateralToken_] != bytes32(0), "Collateral token price ID not set");
        //     require(tokenToPythPriceId[loanToken_] != bytes32(0), "Loan token price ID not set");

        //     uint256 collateralValue = _getOraclePriceInUSD(collateralToken_, collateralAmount_);
        //     uint256 loanValue = _getOraclePriceInUSD(loanToken_, principalAmount_);

        //     require(loanValue > 0, "Loan value must be positive"); 
        //     require(collateralValue > 0, "Collateral value must be positive");
            
        //     uint256 currentLTV = (loanValue * 10000) / collateralValue;
        //     require(currentLTV <= MAX_LTV, "LTV too high");

        //     IERC20(collateralToken_).transferFrom(msg.sender, address(this), collateralAmount_);
        // }

        // Original simple collateral transfer (if any)
        if (collateralAmount_ > 0 && collateralToken_ != address(0)) {
            IERC20(collateralToken_).transferFrom(msg.sender, address(this), collateralAmount_);
        }

        loanCounter++;
        newLoanId = keccak256(abi.encodePacked(msg.sender, block.timestamp, loanCounter));

        loans[newLoanId] = Loan({
            loanId: newLoanId,
            borrower: msg.sender,
            principalAmount: principalAmount_,
            loanToken: loanToken_,
            interestRate: interestRate_,
            duration: duration_,
            startTime: 0, // Set when loan is disbursed
            dueDate: 0, // Initialized to 0, set upon approval
            collateralAmount: collateralAmount_,
            collateralToken: collateralToken_,
            totalVouchedAmountAtApplication: calculatedTotalVouchedAmount, // Use calculated amount
            vouches: finalActiveLoanVouches, // Store the collected active vouches
            amountPaid: 0,
            status: LoanStatus.Pending
        });

        userLoans[msg.sender].push(newLoanId);
        emit LoanApplied(newLoanId, msg.sender, principalAmount_, loanToken_);
    }

    function approveLoan(bytes32 loanId) external onlyOwner nonReentrant onlyLoanExists(loanId) {
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.Pending, "Loan not pending approval");

        loan.status = LoanStatus.Active;
        loan.startTime = block.timestamp;
        loan.dueDate = block.timestamp + loan.duration; // Set dueDate
        // loan.amountPaid = 0; // amountPaid is already initialized to 0 in applyForLoan and reset upon approval if needed

        // Call Treasury to transfer funds
        Treasury(treasuryAddress).transferFundsToLoanContract(loan.loanToken, loan.principalAmount, loan.borrower);

        emit LoanApproved(loanId);
        emit LoanDisbursed(loanId); // Assuming approval leads to immediate disbursal for simplicity
    }

    function repayLoan(bytes32 loanId, uint256 paymentAmount) external payable nonReentrant onlyLoanExists(loanId) {
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender, "Only borrower can repay");
        require(loan.status == LoanStatus.Active, "Loan not active");
        require(paymentAmount > 0, "Payment amount must be positive");

        uint256 totalAmountDue = calculateTotalAmountDue(loanId);
        uint256 remainingAmountDue = totalAmountDue - loan.amountPaid;
        
        require(remainingAmountDue > 0, "Loan already fully paid");

        uint256 effectivePayment = paymentAmount;
        uint256 refundAmount = 0;

        if (paymentAmount > remainingAmountDue) {
            effectivePayment = remainingAmountDue;
            refundAmount = paymentAmount - remainingAmountDue;
        }

        // For ETH denominated loans, msg.value should cover paymentAmount
        // For ERC20 loans, transferFrom borrower to treasuryAddress
        if (loan.loanToken == address(0)) { // ETH loan
            require(msg.value == paymentAmount, "Incorrect ETH sent for payment amount");
            payable(treasuryAddress).transfer(effectivePayment);
            if (refundAmount > 0) {
                payable(msg.sender).transfer(refundAmount); // Refund excess ETH
            }
        } else { // ERC20 loan
            require(msg.value == 0, "ETH sent for ERC20 loan repayment");
            IERC20(loan.loanToken).transferFrom(msg.sender, treasuryAddress, effectivePayment);
            if (refundAmount > 0) {
                // For ERC20, refund means not taking the full paymentAmount from allowance
                // This is implicitly handled if transferFrom takes paymentAmount and only effectivePayment is used by Treasury.
                // Better: transfer 'effectivePayment' and if ERC20 overpayment needs refund, Treasury should send it back.
                // For simplicity now: we assume user sent exact 'paymentAmount' or 'effectivePayment' is pulled.
                // The current IERC20().transferFrom pulls 'effectivePayment', so no direct ERC20 refund logic here for over-allowance.
                // If user over-approves and sends 'paymentAmount' in call, and we only use 'effectivePayment',
                // their allowance reduces by 'effectivePayment'. If they intended to send more, that's an external issue.
                // To handle ERC20 refund directly, loan contract would need tokens or approval from treasury.
                 IERC20(loan.loanToken).transfer(msg.sender, refundAmount); // Requires LoanContract to have funds or approval from treasury
            }
        }

        loan.amountPaid += effectivePayment;
        emit LoanPaymentMade(loanId, effectivePayment, loan.amountPaid);

        if (loan.amountPaid >= totalAmountDue) {
            loan.status = LoanStatus.Repaid;
            emit LoanFullyRepaid(loanId);

            // Return collateral if any
            if (loan.collateralAmount > 0 && loan.collateralToken != address(0)) {
                IERC20(loan.collateralToken).transfer(loan.borrower, loan.collateralAmount);
            }
            // Placeholder: Update reputation for fully repaid loan
            // if (address(reputationOApp) != address(0)) {
            //     reputationOApp.updateReputation(loan.borrower, POSITIVE_REPUTATION_CHANGE_ON_REPAY, 0); // 0 for local chainId
            // }
        }
    }

    function checkAndSetDefaultStatus(bytes32 loanId) external nonReentrant onlyLoanExists(loanId) {
        // Could be restricted further (e.g., onlyOwner or specific keeper role)
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.Active, "Loan not active or already processed");
        require(block.timestamp > loan.dueDate, "Loan not yet overdue");
        // Could add a grace period if desired

        loan.status = LoanStatus.Defaulted;
        emit LoanDefaulted(loanId);
        // Placeholder: Update reputation for defaulted loan (negative change)
        // if (address(reputationOApp) != address(0)) {
        //     reputationOApp.updateReputation(loan.borrower, NEGATIVE_REPUTATION_CHANGE_ON_DEFAULT, 0);
        // }
    }

    function liquidateLoan(bytes32 loanId) external onlyOwner nonReentrant onlyLoanExists(loanId) {
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.Defaulted, "Loan not in defaulted state for liquidation");

        uint256 seizedCollateralValue = 0;
        if (loan.collateralAmount > 0 && loan.collateralToken != address(0)) {
            // Potentially use Pyth to get current value of collateral before seizing
            // bytes32 collateralPriceId = getPriceIdForToken(loan.collateralToken);
            // IPyth.Price memory price = pyth.getPrice(collateralPriceId);
            // seizedCollateralValue = (loan.collateralAmount * uint256(price.price)) / (10**uint256(-price.expo));
            seizedCollateralValue = loan.collateralAmount; 
            IERC20(loan.collateralToken).transfer(treasuryAddress, loan.collateralAmount);
        }

        // Slash vouches recorded at the time of loan application
        if (address(socialVouching) != address(0)) {
            for (uint i = 0; i < loan.vouches.length; i++) {
                LoanVoucherDetail memory vouchDetail = loan.vouches[i];
                // Check if the vouch might still be active in SocialVouching before attempting to slash.
                // This is a defensive check; SocialVouching.slashVouch will also check.
                SocialVouching.Vouch memory currentSVVouch = socialVouching.getVouchDetails(loan.borrower, vouchDetail.voucherAddress);
                if (currentSVVouch.active && currentSVVouch.amountStaked > 0) {
                    uint256 amountToAttemptSlash = vouchDetail.amountVouchedAtLoanTime; // For now, attempt to slash the original amount
                    if (amountToAttemptSlash > currentSVVouch.amountStaked) {
                        amountToAttemptSlash = currentSVVouch.amountStaked; // Don't slash more than currently available
                    }
                    if (amountToAttemptSlash > 0) {
                        // socialVouching.slashVouch expects: borrower, voucher, amountToSlash, recipient
                        socialVouching.slashVouch(loan.borrower, vouchDetail.voucherAddress, amountToAttemptSlash, treasuryAddress);
                    }
                }
            }
        }
        
        loan.status = LoanStatus.Liquidated;
        emit LoanLiquidated(loanId, seizedCollateralValue);
        // Placeholder: Update reputation for liquidated loan (can be same or different from default)
        // if (address(reputationOApp) != address(0) && loan.status != LoanStatus.Defaulted) { // Avoid double penalizing if already defaulted
        //     // This check might be redundant if liquidate only called on Defaulted loans that haven't had reputation hit yet
        //     reputationOApp.updateReputation(loan.borrower, NEGATIVE_REPUTATION_CHANGE_ON_LIQUIDATION, 0);
        // }
    }

    // --- View Functions ---
    function getLoanDetails(bytes32 loanId) external view onlyLoanExists(loanId) returns (Loan memory) {
        return loans[loanId];
    }

    function getUserLoanIds(address userAddress) external view returns (bytes32[] memory) {
        return userLoans[userAddress];
    }

    function calculateTotalAmountDue(bytes32 loanId) public view onlyLoanExists(loanId) returns (uint256) {
        Loan memory loan = loans[loanId];
        // If already marked as Repaid by full payment logic, effective due is 0, but this func shows total obligation.
        // uint256 interest = (loan.principalAmount * loan.interestRate) / 10000;
        // More accurate interest if loan is active or overdue:
        uint256 interest = 0;
        if (loan.status == LoanStatus.Active || loan.status == LoanStatus.Defaulted) {
            // Simple interest, not compounded, assumes full duration for now if not repaid early
            // A more complex model would calculate interest based on time elapsed for partial payments.
            // Current model: total interest is fixed at loan inception for simplicity.
            interest = (loan.principalAmount * loan.interestRate) / 10000;
        }
        return loan.principalAmount + interest;
    }

    function calculateRemainingAmountDue(bytes32 loanId) public view onlyLoanExists(loanId) returns (uint256) {
        Loan memory loan = loans[loanId];
        if (loan.status == LoanStatus.Repaid) return 0;
        uint256 totalDue = calculateTotalAmountDue(loanId);
        return totalDue - loan.amountPaid;
    }
    
    // --- Admin Functions ---
    function setTreasuryAddress(address payable newTreasuryAddress) external onlyOwner {
        require(newTreasuryAddress != address(0), "Invalid new treasury address");
        treasuryAddress = newTreasuryAddress;
    }

    function setPythAddress(address newPythAddress) external onlyOwner {
        // require(newPythAddress != address(0), "Invalid Pyth address"); // REMOVED
        // pyth = IPyth(newPythAddress); // REMOVED
        revert("Pyth integration removed"); // Indicate function is no longer active
    }

    function setReputationOAppAddress(address newReputationOAppAddress) external onlyOwner {
        require(newReputationOAppAddress != address(0), "Invalid ReputationOApp address");
        reputationOApp = IReputationOApp(newReputationOAppAddress);
    }

    // function setTokenPythPriceId(address tokenAddress, bytes32 priceId) external onlyOwner { // REMOVED
    //     revert("Pyth integration removed");
    // }

    // function _getOraclePriceInUSD(address tokenAddress, uint256 amount) internal view returns (uint256 value) { // REMOVED
    //     revert("Pyth integration removed");
    // }

    // Placeholder for Pyth/ReputationApp address setters if needed
    // function setReputationOAppAddress(address newReputationOAppAddress) external onlyOwner { ... }
} 