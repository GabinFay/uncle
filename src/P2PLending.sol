// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol"; // No longer needed for Pyth
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserRegistry.sol";
// import "./SocialVouching.sol"; // Functionality to be in Reputation.sol
// import "./Treasury.sol"; // No longer used in P2P model
import "./interfaces/IReputationOApp.sol"; 
import "./Reputation.sol"; // IMPORT Reputation contract

/**
 * @title P2PLending (Previously LoanContract)
 * @dev Manages the peer-to-peer lending lifecycle.
 */
contract P2PLending is Ownable, ReentrancyGuard { // Renamed from LoanContract
    UserRegistry public userRegistry;
    // SocialVouching public socialVouching; // REMOVED
    // address payable public treasuryAddress; // REMOVED - P2P model
    Reputation public reputationContract; // CHANGED from reputationOApp and socialVouching concept
    IReputationOApp public reputationOApp; // To be reviewed if still needed alongside direct Reputation.sol calls

    struct LoanVoucherDetail { // This might be part of Reputation.sol or a shared struct
        address voucherAddress;
        address tokenAddress;
        uint256 amountVouchedAtLoanTime;
    }

    enum LoanStatus { Pending, Active, Repaid, Defaulted, Liquidated, OfferOpen, RequestOpen, AgreementReached, Cancelled }

    // This Loan struct is from the old model, will be replaced by P2P structs
    struct Loan_OLD_MODEL { 
        bytes32 loanId;
        address borrower;
        uint256 principalAmount;
        address loanToken; 
        uint256 interestRate; 
        uint256 duration; 
        uint256 startTime;
        uint256 dueDate; 
        uint256 collateralAmount;
        address collateralToken;
        uint256 totalVouchedAmountAtApplication; 
        LoanVoucherDetail[] vouches; 
        uint256 amountPaid; 
        LoanStatus status;
    }

    // mapping(bytes32 => Loan_OLD_MODEL) public loans; // Will be replaced
    // mapping(address => bytes32[]) public userLoans; // Will be replaced or adapted
    // uint256 public loanCounter; // For generating unique loan IDs - will need similar for P2P agreements

    // --- P2P Specific Structs ---
    struct LoanOffer {
        bytes32 offerId;
        address lender;
        uint256 offerAmount;
        address loanToken;
        uint256 interestRate; // Basis points
        uint256 duration; // Seconds
        uint256 collateralRequiredAmount; // 0 if no collateral required by lender
        address collateralRequiredToken;  // address(0) if no collateral
        LoanStatus status; // e.g., OfferOpen, AgreementReached, Cancelled
        // Add expiry for offer?
        // Link to borrower if accepted
    }

    struct LoanRequest {
        bytes32 requestId;
        address borrower;
        uint256 requestAmount;
        address loanToken;
        uint256 proposedInterestRate; // Max willing to pay
        uint256 proposedDuration;
        uint256 offeredCollateralAmount; // Amount borrower is willing to put up
        address offeredCollateralToken; // Token borrower is willing to use
        LoanStatus status; // e.g., RequestOpen, AgreementReached, Cancelled
        // Add expiry for request?
        // Link to lender if accepted
    }

    struct LoanAgreement {
        bytes32 agreementId;
        bytes32 originalOfferId; // if created from offer
        bytes32 originalRequestId; // if created from request
        address lender;
        address borrower;
        uint256 principalAmount;
        address loanToken;
        uint256 interestRate;
        uint256 duration;
        uint256 collateralAmount; // Actual collateral provided
        address collateralToken;  // Actual collateral token
        uint256 startTime;
        uint256 dueDate;
        uint256 amountPaid;
        LoanStatus status; // e.g., Active, Repaid, Defaulted
        // Link to vouches if applicable from Reputation.sol
    }

    mapping(bytes32 => LoanOffer) public loanOffers;
    mapping(address => bytes32[]) public userLoanOffers; // lender => offer IDs
    uint256 public loanOfferCounter;

    mapping(bytes32 => LoanRequest) public loanRequests;
    mapping(address => bytes32[]) public userLoanRequests; // borrower => request IDs
    uint256 public loanRequestCounter;

    mapping(bytes32 => LoanAgreement) public loanAgreements;
    mapping(address => bytes32[]) public userLoanAgreementsAsLender;   // lender => agreement IDs
    mapping(address => bytes32[]) public userLoanAgreementsAsBorrower; // borrower => agreement IDs
    uint256 public loanAgreementCounter;

    uint256 public constant BASIS_POINTS = 10000;

    // --- Events ---
    // Old events to be revised for P2P
    // event LoanApplied(bytes32 indexed loanId, address indexed borrower, uint256 amount, address token);
    // event LoanApproved(bytes32 indexed loanId);
    // event LoanDisbursed(bytes32 indexed loanId);
    // event LoanPaymentMade(bytes32 indexed loanId, uint256 paymentAmount, uint256 totalPaid);
    // event LoanFullyRepaid(bytes32 indexed loanId);
    // event LoanDefaulted(bytes32 indexed loanId);
    // event LoanLiquidated(bytes32 indexed loanId, uint256 collateralSeized);

    event LoanOfferCreated(bytes32 indexed offerId, address indexed lender, uint256 amount, address token, uint256 interestRate, uint256 duration);
    event LoanRequestCreated(bytes32 indexed requestId, address indexed borrower, uint256 amount, address token, uint256 proposedInterestRate, uint256 proposedDuration);
    event LoanAgreementFormed(bytes32 indexed agreementId, address indexed lender, address indexed borrower, uint256 amount, address token);
    event LoanRepaymentMade(bytes32 indexed agreementId, uint256 amountPaid, uint256 totalPaid);
    event LoanAgreementRepaid(bytes32 indexed agreementId);
    event LoanAgreementDefaulted(bytes32 indexed agreementId);
    // Add events for collateral handling, extensions, etc.

    // --- Modifiers ---
    modifier onlyVerifiedUser(address user) {
        require(userRegistry.isUserWorldIdVerified(user), "P2PLending: User not World ID verified");
        _;
    }

    // modifier onlyLoanExists(bytes32 loanId) { // Will be agreementExists, offerExists, requestExists
    //     require(loans[loanId].borrower != address(0), "LoanContract: Loan does not exist");
    //     _;
    // }

    constructor(
        address _userRegistryAddress,
        address _reputationContractAddress,
        address payable _treasuryAddressForOldLogic, // Marked as unused
        address initialReputationOAppAddress 
    ) Ownable(msg.sender) {
        require(_userRegistryAddress != address(0), "Invalid UserRegistry address");
        require(_reputationContractAddress != address(0), "Invalid Reputation contract address"); // ADDED check
        // require(initialTreasuryAddress != address(0), "Invalid Treasury address"); // No longer used
        // require(initialReputationOAppAddress != address(0), "Invalid ReputationOApp address"); // OApp is secondary now
        userRegistry = UserRegistry(_userRegistryAddress);
        reputationContract = Reputation(_reputationContractAddress); // SETTING reputationContract
        if (initialReputationOAppAddress != address(0)) { // Optional OApp
            reputationOApp = IReputationOApp(initialReputationOAppAddress);
        }
        // The socialVouchingAddress param will be repurposed for the Reputation.sol contract later
    }

    // --- Functions to be refactored/removed from OLD LoanContract model ---

    /*
    function applyForLoan_OLD(
        uint256 principalAmount_,
        address loanToken_,
        uint256 interestRate_,
        uint256 duration_,
        uint256 collateralAmount_,
        address collateralToken_,
        address[] calldata voucherAddressesToConsider 
    ) external nonReentrant onlyVerifiedUser(msg.sender) returns (bytes32 newLoanId) {
        // ... OLD LOGIC ...
    }

    function approveLoan_OLD(bytes32 loanId) external onlyOwner nonReentrant onlyLoanExists(loanId) {
        // ... OLD LOGIC ...
    }

    function repayLoan_OLD(bytes32 loanId, uint256 paymentAmount) external payable nonReentrant onlyLoanExists(loanId) {
        // ... OLD LOGIC ...
    }

    function checkAndSetDefaultStatus_OLD(bytes32 loanId) external nonReentrant onlyLoanExists(loanId) {
        // ... OLD LOGIC ...
    }

    function liquidateLoan_OLD(bytes32 loanId) external onlyOwner nonReentrant onlyLoanExists(loanId) {
        // ... OLD LOGIC ...
    }

    function getLoanDetails_OLD(bytes32 loanId) external view onlyLoanExists(loanId) returns (Loan_OLD_MODEL memory) {
        return loans[loanId];
    }

    function getUserLoanIds_OLD(address userAddress) external view returns (bytes32[] memory) {
        return userLoans[userAddress];
    }

    function calculateTotalAmountDue_OLD(bytes32 loanId) public view onlyLoanExists(loanId) returns (uint256) {
        // ... OLD LOGIC ...
    }

    function calculateRemainingAmountDue_OLD(bytes32 loanId) public view onlyLoanExists(loanId) returns (uint256) {
        // ... OLD LOGIC ...
    }
    
    function setTreasuryAddress_OLD(address payable newTreasuryAddress) external onlyOwner {
        revert("P2P model: Treasury not used directly");
    }
    */

    // --- Admin Functions (mostly for setters, Ownable ensures only owner) ---
    function setReputationContractAddress(address _newReputationContractAddress) external onlyOwner {
        require(_newReputationContractAddress != address(0), "Invalid Reputation contract address");
        reputationContract = Reputation(_newReputationContractAddress);
    }
    
    function setReputationOAppAddress(address newReputationOAppAddress) external onlyOwner {
        // Allow setting to address(0) if OApp is to be disabled
        reputationOApp = IReputationOApp(newReputationOAppAddress);
    }
    
    // The setPythAddress function is removed/reverted as Pyth is not used
    function setPythAddress(address /* newPythAddress */) external onlyOwner {
        revert("Pyth integration removed"); 
    }

    // --- P2P Lending Core Functions ---

    function createLoanOffer(
        uint256 offerAmount_,
        address loanToken_,
        uint256 interestRate_,
        uint256 duration_,
        uint256 collateralRequiredAmount_,
        address collateralRequiredToken_
    ) external nonReentrant onlyVerifiedUser(msg.sender) returns (bytes32 offerId) {
        require(offerAmount_ > 0, "Offer amount must be positive");
        require(loanToken_ != address(0), "Invalid loan token");
        require(duration_ > 0, "Duration must be positive");
        // require(interestRate_ < MAX_INTEREST_RATE, "Interest rate too high"); // Consider platform limits

        if (collateralRequiredAmount_ > 0) {
            require(collateralRequiredToken_ != address(0), "Invalid collateral token for non-zero amount");
        } else {
            require(collateralRequiredToken_ == address(0), "Collateral token must be zero for zero amount");
        }

        // Lender must have sufficient balance of the loan token
        require(IERC20(loanToken_).balanceOf(msg.sender) >= offerAmount_, "Insufficient balance to create offer");
        // Lender must approve this contract to transfer offerAmount_ if offer is accepted
        // This approval should ideally happen before calling, or be part of the acceptOffer flow.
        // For now, we assume the lender will approve separately.

        loanOfferCounter++;
        offerId = keccak256(abi.encodePacked(msg.sender, block.timestamp, loanOfferCounter));

        loanOffers[offerId] = LoanOffer({
            offerId: offerId,
            lender: msg.sender,
            offerAmount: offerAmount_,
            loanToken: loanToken_,
            interestRate: interestRate_,
            duration: duration_,
            collateralRequiredAmount: collateralRequiredAmount_,
            collateralRequiredToken: collateralRequiredToken_,
            status: LoanStatus.OfferOpen
            // borrower: address(0) // Not set until accepted
        });

        userLoanOffers[msg.sender].push(offerId);
        emit LoanOfferCreated(offerId, msg.sender, offerAmount_, loanToken_, interestRate_, duration_);
        return offerId;
    }

    function createLoanRequest(
        uint256 requestAmount_,
        address loanToken_,
        uint256 proposedInterestRate_,
        uint256 proposedDuration_,
        uint256 offeredCollateralAmount_,
        address offeredCollateralToken_
    ) external nonReentrant onlyVerifiedUser(msg.sender) returns (bytes32 requestId) {
        require(requestAmount_ > 0, "Request amount must be positive");
        require(loanToken_ != address(0), "Invalid loan token");
        require(proposedDuration_ > 0, "Duration must be positive");

        if (offeredCollateralAmount_ > 0) {
            require(offeredCollateralToken_ != address(0), "Invalid collateral token for non-zero amount");
            // Borrower must have and approve offeredCollateralAmount_ if request is funded.
            // This is handled during the funding stage.
            require(IERC20(offeredCollateralToken_).balanceOf(msg.sender) >= offeredCollateralAmount_, "Insufficient collateral balance for request");
        } else {
            require(offeredCollateralToken_ == address(0), "Collateral token must be zero for zero amount");
        }

        loanRequestCounter++;
        requestId = keccak256(abi.encodePacked(msg.sender, block.timestamp, loanRequestCounter));

        loanRequests[requestId] = LoanRequest({
            requestId: requestId,
            borrower: msg.sender,
            requestAmount: requestAmount_,
            loanToken: loanToken_,
            proposedInterestRate: proposedInterestRate_,
            proposedDuration: proposedDuration_,
            offeredCollateralAmount: offeredCollateralAmount_,
            offeredCollateralToken: offeredCollateralToken_,
            status: LoanStatus.RequestOpen
            // lender: address(0) // Not set until funded
        });

        userLoanRequests[msg.sender].push(requestId);
        emit LoanRequestCreated(requestId, msg.sender, requestAmount_, loanToken_, proposedInterestRate_, proposedDuration_);
        return requestId;
    }

    function acceptLoanOffer(
        bytes32 offerId_,
        uint256 collateralOfferedByBorrowerAmount_, // If offer requires collateral, borrower must provide this amount
        address collateralOfferedByBorrowerToken_  // Token for the collateral
    ) external nonReentrant onlyVerifiedUser(msg.sender) returns (bytes32 agreementId) {
        require(loanOffers[offerId_].lender != address(0), "Offer does not exist");
        LoanOffer storage offer = loanOffers[offerId_];
        require(offer.status == LoanStatus.OfferOpen, "Offer not open");
        require(offer.lender != msg.sender, "Cannot accept your own offer");

        // Check collateral requirements
        if (offer.collateralRequiredAmount > 0) {
            require(collateralOfferedByBorrowerToken_ == offer.collateralRequiredToken, "Collateral token mismatch");
            require(collateralOfferedByBorrowerAmount_ == offer.collateralRequiredAmount, "Collateral amount mismatch");
            require(IERC20(collateralOfferedByBorrowerToken_).balanceOf(msg.sender) >= collateralOfferedByBorrowerAmount_, "Insufficient collateral balance");
            // Borrower approves this contract to take collateral
            IERC20(collateralOfferedByBorrowerToken_).transferFrom(msg.sender, address(this), collateralOfferedByBorrowerAmount_);
        } else {
            require(collateralOfferedByBorrowerAmount_ == 0, "Collateral not required by offer");
            require(collateralOfferedByBorrowerToken_ == address(0), "Collateral not required by offer");
        }

        // Lender must have approved this contract to transfer the loan amount
        // This is a critical step. If not approved, transferFrom will fail.
        // Consider adding a check for allowance: require(IERC20(offer.loanToken).allowance(offer.lender, address(this)) >= offer.offerAmount, "Lender has not approved transfer");
        IERC20(offer.loanToken).transferFrom(offer.lender, msg.sender, offer.offerAmount);

        offer.status = LoanStatus.AgreementReached; // Mark offer as fulfilled

        loanAgreementCounter++;
        agreementId = keccak256(abi.encodePacked(offer.lender, msg.sender, block.timestamp, loanAgreementCounter));

        loanAgreements[agreementId] = LoanAgreement({
            agreementId: agreementId,
            originalOfferId: offerId_,
            originalRequestId: bytes32(0), // Not from a request
            lender: offer.lender,
            borrower: msg.sender,
            principalAmount: offer.offerAmount,
            loanToken: offer.loanToken,
            interestRate: offer.interestRate,
            duration: offer.duration,
            collateralAmount: collateralOfferedByBorrowerAmount_, // Actual collateral locked
            collateralToken: collateralOfferedByBorrowerToken_,
            startTime: block.timestamp,
            dueDate: block.timestamp + offer.duration,
            amountPaid: 0,
            status: LoanStatus.Active
        });

        userLoanAgreementsAsLender[offer.lender].push(agreementId);
        userLoanAgreementsAsBorrower[msg.sender].push(agreementId);

        emit LoanAgreementFormed(agreementId, offer.lender, msg.sender, offer.offerAmount, offer.loanToken);
        // Call Reputation.sol - details to be added if loan formation affects reputation immediately
        // For now, reputation is primarily affected by repayment/default events.

        return agreementId;
    }

    function fundLoanRequest(
        bytes32 requestId_
        // Potentially allow lender to specify slightly different terms if request is flexible,
        // but for now, assume lender funds the request as-is.
    ) external nonReentrant onlyVerifiedUser(msg.sender) returns (bytes32 agreementId) {
        require(loanRequests[requestId_].borrower != address(0), "Request does not exist");
        LoanRequest storage request = loanRequests[requestId_];
        require(request.status == LoanStatus.RequestOpen, "Request not open");
        require(request.borrower != msg.sender, "Cannot fund your own request");

        // Lender must have enough funds and approve this contract to transfer them
        require(IERC20(request.loanToken).balanceOf(msg.sender) >= request.requestAmount, "Insufficient balance to fund request");
        // Critical: Lender must have approved this contract to transfer loanToken
        // require(IERC20(request.loanToken).allowance(msg.sender, address(this)) >= request.requestAmount, "Lender has not approved transfer for funding");
        IERC20(request.loanToken).transferFrom(msg.sender, request.borrower, request.requestAmount);

        // Handle collateral offered by borrower
        if (request.offeredCollateralAmount > 0) {
            // Borrower must have approved this contract to take their collateral
            // This was checked at request creation for balance, now for transfer.
            // require(IERC20(request.offeredCollateralToken).allowance(request.borrower, address(this)) >= request.offeredCollateralAmount, "Borrower has not approved collateral transfer");
            IERC20(request.offeredCollateralToken).transferFrom(request.borrower, address(this), request.offeredCollateralAmount);
        }

        request.status = LoanStatus.AgreementReached; // Mark request as fulfilled

        loanAgreementCounter++;
        agreementId = keccak256(abi.encodePacked(msg.sender, request.borrower, block.timestamp, loanAgreementCounter));

        loanAgreements[agreementId] = LoanAgreement({
            agreementId: agreementId,
            originalOfferId: bytes32(0), // Not from an offer
            originalRequestId: requestId_,
            lender: msg.sender,
            borrower: request.borrower,
            principalAmount: request.requestAmount,
            loanToken: request.loanToken,
            interestRate: request.proposedInterestRate, // Use borrower's proposed rate
            duration: request.proposedDuration,       // Use borrower's proposed duration
            collateralAmount: request.offeredCollateralAmount,
            collateralToken: request.offeredCollateralToken,
            startTime: block.timestamp,
            dueDate: block.timestamp + request.proposedDuration,
            amountPaid: 0,
            status: LoanStatus.Active
        });

        userLoanAgreementsAsLender[msg.sender].push(agreementId);
        userLoanAgreementsAsBorrower[request.borrower].push(agreementId);

        emit LoanAgreementFormed(agreementId, msg.sender, request.borrower, request.requestAmount, request.loanToken);
        // Call Reputation.sol - similar to acceptLoanOffer

        return agreementId;
    }

    // --- Getter Functions ---
    function getLoanOfferDetails(bytes32 offerId) external view returns (LoanOffer memory) {
        require(loanOffers[offerId].lender != address(0), "Offer does not exist");
        return loanOffers[offerId];
    }

    function getLoanRequestDetails(bytes32 requestId) external view returns (LoanRequest memory) {
        require(loanRequests[requestId].borrower != address(0), "Request does not exist");
        return loanRequests[requestId];
    }

    function getLoanAgreementDetails(bytes32 agreementId) external view returns (LoanAgreement memory) {
        require(loanAgreements[agreementId].borrower != address(0), "Agreement does not exist"); // Check borrower or lender
        return loanAgreements[agreementId];
    }

    function getUserLoanOfferIds(address user) external view returns (bytes32[] memory) {
        return userLoanOffers[user];
    }

    function getUserLoanRequestIds(address user) external view returns (bytes32[] memory) {
        return userLoanRequests[user];
    }

    function getUserLoanAgreementIdsAsLender(address user) external view returns (bytes32[] memory) {
        return userLoanAgreementsAsLender[user];
    }

    function getUserLoanAgreementIdsAsBorrower(address user) external view returns (bytes32[] memory) {
        return userLoanAgreementsAsBorrower[user];
    }

    function _calculateInterest(
        uint256 principalAmount,
        uint256 interestRateBps,
        uint256 /* durationSeconds */, // Not directly used in this simple model
        uint256 /* loanTermSeconds */  // Not directly used if rate is flat for the term
    ) internal pure returns (uint256 interest) {
        if (principalAmount == 0 || interestRateBps == 0) {
            return 0;
        }
        return (principalAmount * interestRateBps) / BASIS_POINTS;
    }

    function _calculateTotalDue(LoanAgreement storage agreement) internal view returns (uint256 totalDue) {
        uint256 interest = _calculateInterest(
            agreement.principalAmount, 
            agreement.interestRate, 
            agreement.duration, // Pass agreement duration
            agreement.duration  // Rate is for this loan term
        );
        return agreement.principalAmount + interest;
    }

    function repayP2PLoan(bytes32 agreementId, uint256 paymentAmount) external nonReentrant {
        LoanAgreement storage agreement = loanAgreements[agreementId];
        require(agreement.borrower == msg.sender, "Only borrower can repay");
        require(agreement.status == LoanStatus.Active, "Loan not active");
        require(paymentAmount > 0, "Payment amount must be positive");

        uint256 totalDue = _calculateTotalDue(agreement);
        uint256 remainingDue = totalDue - agreement.amountPaid;
        require(paymentAmount <= remainingDue, "Payment exceeds remaining due"); // Prevent overpayment complexity for now

        // Borrower must have approved this contract to transfer paymentAmount of loanToken
        IERC20(agreement.loanToken).transferFrom(msg.sender, agreement.lender, paymentAmount);

        agreement.amountPaid += paymentAmount;
        emit LoanRepaymentMade(agreementId, paymentAmount, agreement.amountPaid);

        if (agreement.amountPaid >= totalDue) {
            agreement.status = LoanStatus.Repaid;
            emit LoanAgreementRepaid(agreementId);

            // Return collateral if any
            if (agreement.collateralAmount > 0 && agreement.collateralToken != address(0)) {
                IERC20(agreement.collateralToken).transfer(agreement.borrower, agreement.collateralAmount);
            }

            // Call Reputation.sol to update reputation for borrower and lender
            if (address(reputationContract) != address(0)) { 
                reputationContract.updateReputationOnLoanRepayment(agreement.borrower, agreement.lender, agreement.principalAmount);
            }
        }
    }

    function handleP2PDefault(bytes32 agreementId) external nonReentrant {
        LoanAgreement storage agreement = loanAgreements[agreementId];
        require(agreement.lender != address(0), "Agreement does not exist"); // Check agreement exists
        require(agreement.status == LoanStatus.Active, "Loan not active for default");
        require(block.timestamp > agreement.dueDate, "Loan not yet overdue");

        uint256 totalDue = _calculateTotalDue(agreement);
        require(agreement.amountPaid < totalDue, "Loan already fully paid, cannot default");

        agreement.status = LoanStatus.Defaulted;
        emit LoanAgreementDefaulted(agreementId);

        // Transfer collateral, if any, to the lender
        if (agreement.collateralAmount > 0 && agreement.collateralToken != address(0)) {
            IERC20(agreement.collateralToken).transfer(agreement.lender, agreement.collateralAmount);
        }

        // Call Reputation.sol to update reputation and potentially slash vouches
        if (address(reputationContract) != address(0)) { 
            // First, update the borrower's direct reputation for the default
            reputationContract.updateReputationOnLoanDefault(
                agreement.borrower, 
                agreement.lender, 
                agreement.principalAmount,
                new bytes32[](0) // Pass empty array explicitly 
            );

            // Now, handle slashing of vouches for the defaulting borrower
            Reputation.Vouch[] memory activeVouches = reputationContract.getActiveVouchesForBorrower(agreement.borrower);
            uint256 tenPercentSlashBasis = 1000; // 10.00%

            for (uint i = 0; i < activeVouches.length; i++) {
                Reputation.Vouch memory currentVouch = activeVouches[i];
                if (currentVouch.isActive && currentVouch.stakedAmount > 0) { // Double check, though getActive should ensure this
                    uint256 slashAmount = (currentVouch.stakedAmount * tenPercentSlashBasis) / BASIS_POINTS; // 10% of current stake
                    if (slashAmount == 0 && currentVouch.stakedAmount > 0) { // Ensure at least 1 unit is slashed if stake > 0 and 10% is < 1
                        slashAmount = 1; 
                    }
                    if (slashAmount > currentVouch.stakedAmount) { // Cap at staked amount
                        slashAmount = currentVouch.stakedAmount;
                    }

                    if (slashAmount > 0) {
                        // P2PLending tells Reputation to slash this specific vouch
                        reputationContract.slashVouchAndReputation(
                            currentVouch.voucher,
                            agreement.borrower,
                            slashAmount,
                            agreement.lender // Lender of the defaulted loan receives the slashed funds
                        );
                    }
                }
            }
        }
    }

    // To be implemented based on PRD.md:
    // requestP2PLoanExtension(...)

} 