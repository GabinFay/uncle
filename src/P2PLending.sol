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
 * @author CreditInclusion Team
 * @notice Manages the peer-to-peer lending lifecycle, including loan offers, requests, agreements, repayments, and defaults.
 * @dev Interacts with UserRegistry for World ID verification and Reputation contract for scoring and vouching.
 *      This contract does not hold funds directly, except for collateral during active loan agreements.
 */
contract P2PLending is Ownable, ReentrancyGuard { // Renamed from LoanContract
    /**
     * @notice Reference to the UserRegistry contract for verifying user identities.
     */
    UserRegistry public userRegistry;
    // SocialVouching public socialVouching; // REMOVED
    // address payable public treasuryAddress; // REMOVED - P2P model
    /**
     * @notice Reference to the Reputation contract for managing user scores and vouching.
     */
    Reputation public reputationContract; // CHANGED from reputationOApp and socialVouching concept
    /**
     * @notice Reference to the (optional) IReputationOApp interface for cross-chain reputation (placeholder).
     */
    IReputationOApp public reputationOApp; // To be reviewed if still needed alongside direct Reputation.sol calls

    // LoanVoucherDetail struct removed as vouching details are fully managed within Reputation.sol
    // and P2PLending queries Reputation.sol for active vouches when needed (e.g., during default).

    /**
     * @notice Defines the possible states of a loan offer, request, or agreement.
     */
    enum LoanStatus { 
        Pending,    // Initial state for old loan model, potentially reusable
        Active,     // Loan agreement is active and funds disbursed
        Repaid,     // Loan agreement has been fully repaid
        Defaulted,  // Loan agreement is past due and marked as defaulted
        Liquidated, // Collateral seized (more relevant for old model, P2P default handles collateral transfer)
        OfferOpen,  // A loan offer is available to be accepted
        RequestOpen,// A loan request is available to be funded
        AgreementReached, // Offer/Request has been matched, prior to becoming Active (or during same tx)
        Cancelled   // Offer or Request has been cancelled before agreement
    }

    // This Loan struct is from the old model, will be replaced by P2P structs
    // struct Loan_OLD_MODEL { 
    //     bytes32 loanId;
    //     address borrower;
    //     uint256 principalAmount;
    //     address loanToken; 
    //     uint256 interestRate; 
    //     uint256 duration; 
    //     uint256 startTime;
    //     uint256 dueDate; 
    //     uint256 collateralAmount;
    //     address collateralToken;
    //     uint256 totalVouchedAmountAtApplication; 
    //     LoanVoucherDetail[] vouches; 
    //     uint256 amountPaid; 
    //     LoanStatus status;
    // }

    // mapping(bytes32 => Loan_OLD_MODEL) public loans; // Will be replaced
    // mapping(address => bytes32[]) public userLoans; // Will be replaced or adapted
    // uint256 public loanCounter; // For generating unique loan IDs - will need similar for P2P agreements

    // --- P2P Specific Structs ---
    /**
     * @notice Represents a loan offer created by a lender.
     * @param offerId Unique identifier for the loan offer.
     * @param lender Address of the user offering to lend funds.
     * @param offerAmount The principal amount offered.
     * @param loanToken The ERC20 token in which the loan is denominated.
     * @param interestRate The interest rate for the loan, in basis points (e.g., 500 for 5.00%).
     * @param duration The duration of the loan in seconds.
     * @param collateralRequiredAmount Amount of collateral required by the lender (0 if none).
     * @param collateralRequiredToken The ERC20 token for collateral (address(0) if none).
     * @param status Current status of the loan offer (e.g., OfferOpen, AgreementReached).
     */
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

    /**
     * @notice Represents a loan request created by a borrower.
     * @param requestId Unique identifier for the loan request.
     * @param borrower Address of the user requesting to borrow funds.
     * @param requestAmount The principal amount requested.
     * @param loanToken The ERC20 token in which the loan is requested.
     * @param proposedInterestRate The maximum interest rate the borrower is willing to pay, in basis points.
     * @param proposedDuration The desired duration of the loan in seconds.
     * @param offeredCollateralAmount Amount of collateral the borrower is offering (0 if none).
     * @param offeredCollateralToken The ERC20 token for collateral offered (address(0) if none).
     * @param status Current status of the loan request (e.g., RequestOpen, AgreementReached).
     */
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

    /**
     * @notice Represents an active loan agreement formed between a lender and a borrower.
     * @param agreementId Unique identifier for the loan agreement.
     * @param originalOfferId ID of the LoanOffer this agreement originated from (if applicable).
     * @param originalRequestId ID of the LoanRequest this agreement originated from (if applicable).
     * @param lender Address of the lender.
     * @param borrower Address of the borrower.
     * @param principalAmount The principal amount of the loan.
     * @param loanToken The ERC20 token of the loan principal.
     * @param interestRate The agreed interest rate in basis points.
     * @param duration The agreed duration of the loan in seconds.
     * @param collateralAmount The amount of collateral locked for this loan (0 if none).
     * @param collateralToken The ERC20 token of the collateral (address(0) if none).
     * @param startTime Timestamp when the loan agreement became active.
     * @param dueDate Timestamp when the loan is due for full repayment.
     * @param amountPaid Total amount repaid by the borrower so far.
     * @param status Current status of the loan agreement (e.g., Active, Repaid, Defaulted).
     */
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

    /**
     * @notice Maps loan offer IDs to LoanOffer structs.
     */
    mapping(bytes32 => LoanOffer) public loanOffers;
    /**
     * @notice Maps user addresses to an array of IDs of loan offers they created.
     */
    mapping(address => bytes32[]) public userLoanOffers; // lender => offer IDs
    /**
     * @notice Counter to help generate unique loan offer IDs.
     */
    uint256 public loanOfferCounter;

    /**
     * @notice Maps loan request IDs to LoanRequest structs.
     */
    mapping(bytes32 => LoanRequest) public loanRequests;
    /**
     * @notice Maps user addresses to an array of IDs of loan requests they created.
     */
    mapping(address => bytes32[]) public userLoanRequests; // borrower => request IDs
    /**
     * @notice Counter to help generate unique loan request IDs.
     */
    uint256 public loanRequestCounter;

    /**
     * @notice Maps loan agreement IDs to LoanAgreement structs.
     */
    mapping(bytes32 => LoanAgreement) public loanAgreements;
    /**
     * @notice Maps user addresses to an array of IDs of loan agreements where they are the lender.
     */
    mapping(address => bytes32[]) public userLoanAgreementsAsLender;   // lender => agreement IDs
    /**
     * @notice Maps user addresses to an array of IDs of loan agreements where they are the borrower.
     */
    mapping(address => bytes32[]) public userLoanAgreementsAsBorrower; // borrower => agreement IDs
    /**
     * @notice Counter to help generate unique loan agreement IDs.
     */
    uint256 public loanAgreementCounter;

    /**
     * @notice Constant representing 100.00% for basis points calculations (10000 = 100%).
     */
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

    /**
     * @notice Emitted when a new loan offer is created.
     * @param offerId Unique ID of the offer.
     * @param lender Address of the lender creating the offer.
     * @param amount Principal amount offered.
     * @param token Token of the principal amount.
     * @param interestRate Interest rate in basis points.
     * @param duration Duration of the loan in seconds.
     */
    event LoanOfferCreated(bytes32 indexed offerId, address indexed lender, uint256 amount, address token, uint256 interestRate, uint256 duration);
    /**
     * @notice Emitted when a new loan request is created.
     * @param requestId Unique ID of the request.
     * @param borrower Address of the borrower creating the request.
     * @param amount Principal amount requested.
     * @param token Token of the principal amount.
     * @param proposedInterestRate Proposed interest rate in basis points.
     * @param proposedDuration Proposed duration of the loan in seconds.
     */
    event LoanRequestCreated(bytes32 indexed requestId, address indexed borrower, uint256 amount, address token, uint256 proposedInterestRate, uint256 proposedDuration);
    /**
     * @notice Emitted when a loan offer is accepted or a loan request is funded, forming an agreement.
     * @param agreementId Unique ID of the newly formed loan agreement.
     * @param lender Address of the lender in the agreement.
     * @param borrower Address of the borrower in the agreement.
     * @param amount Principal amount of the loan.
     * @param token Token of the principal amount.
     */
    event LoanAgreementFormed(bytes32 indexed agreementId, address indexed lender, address indexed borrower, uint256 amount, address token);
    /**
     * @notice Emitted when a repayment is made on a loan agreement.
     * @param agreementId ID of the loan agreement.
     * @param amountPaid The amount paid in this transaction.
     * @param totalPaid The new total amount paid towards the loan so far.
     */
    event LoanRepaymentMade(bytes32 indexed agreementId, uint256 amountPaid, uint256 totalPaid);
    /**
     * @notice Emitted when a loan agreement is fully repaid.
     * @param agreementId ID of the fully repaid loan agreement.
     */
    event LoanAgreementRepaid(bytes32 indexed agreementId);
    /**
     * @notice Emitted when a loan agreement is marked as defaulted.
     * @param agreementId ID of the defaulted loan agreement.
     */
    event LoanAgreementDefaulted(bytes32 indexed agreementId);
    // Add events for collateral handling, extensions, etc.

    // --- Modifiers ---
    /**
     * @dev Modifier to ensure the calling user is verified in the UserRegistry.
     * @param user The address to check for World ID verification.
     */
    modifier onlyVerifiedUser(address user) {
        require(userRegistry.isUserWorldIdVerified(user), "P2PLending: User not World ID verified");
        _;
    }

    // modifier onlyLoanExists(bytes32 loanId) { // Will be agreementExists, offerExists, requestExists
    //     require(loans[loanId].borrower != address(0), "LoanContract: Loan does not exist");
    //     _;
    // }

    /**
     * @notice Contract constructor.
     * @param _userRegistryAddress Address of the deployed UserRegistry contract.
     * @param _reputationContractAddress Address of the deployed Reputation contract.
     * @param _treasuryAddressForOldLogic (Unused) Placeholder from previous contract version.
     * @param initialReputationOAppAddress Address of the (optional) Reputation OApp for cross-chain features. Can be address(0).
     */
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

    // --- Admin Functions (mostly for setters, Ownable ensures only owner) ---
    /**
     * @notice Sets the address of the main Reputation contract.
     * @dev Can only be called by the contract owner.
     *      Changing this address affects where reputation updates and vouch slashing calls are directed.
     * @param _newReputationContractAddress The address of the new Reputation contract.
     */
    function setReputationContractAddress(address _newReputationContractAddress) external onlyOwner {
        require(_newReputationContractAddress != address(0), "Invalid Reputation contract address");
        reputationContract = Reputation(_newReputationContractAddress);
    }
    
    /**
     * @notice Sets the address of the LayerZero Reputation OApp contract.
     * @dev Can only be called by the contract owner.
     *      This is for the optional cross-chain reputation functionality.
     *      Set to address(0) to disable OApp interactions.
     * @param newReputationOAppAddress The address of the new IReputationOApp contract, or address(0).
     */
    function setReputationOAppAddress(address newReputationOAppAddress) external onlyOwner {
        reputationOApp = IReputationOApp(newReputationOAppAddress);
    }
    
    /**
     * @notice Placeholder function for setting a Pyth Network address (feature removed).
     * @dev This function will always revert as Pyth Network integration has been removed from this contract.
     */
    function setPythAddress(address /* newPythAddress */) external onlyOwner {
        revert("Pyth integration removed"); 
    }

    // --- P2P Lending Core Functions ---

    /**
     * @notice Creates a new loan offer as a lender.
     * @dev The lender must have sufficient balance of `loanToken_` and must approve this contract
     *      to transfer `offerAmount_` if the offer is accepted. This approval should be done prior to calling.
     *      The offer becomes `OfferOpen`. Generates a unique offer ID.
     * @param offerAmount_ The principal amount the lender is offering.
     * @param loanToken_ The ERC20 token for the loan principal.
     * @param interestRate_ The interest rate in basis points (e.g., 500 for 5.00%).
     * @param duration_ The duration of the loan in seconds.
     * @param collateralRequiredAmount_ The amount of collateral required from the borrower (0 if none).
     * @param collateralRequiredToken_ The ERC20 token for collateral (address(0) if none).
     * @return offerId The unique ID of the newly created loan offer.
     */
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

    /**
     * @notice Creates a new loan request as a borrower.
     * @dev If collateral is offered, the borrower must have sufficient balance of `offeredCollateralToken_`
     *      and must approve this contract to transfer `offeredCollateralAmount_` if the request is funded.
     *      This collateral approval should be done prior to calling.
     *      The request becomes `RequestOpen`. Generates a unique request ID.
     * @param requestAmount_ The principal amount the borrower is requesting.
     * @param loanToken_ The ERC20 token for the loan principal.
     * @param proposedInterestRate_ The maximum interest rate the borrower is willing to pay, in basis points.
     * @param proposedDuration_ The desired duration of the loan in seconds.
     * @param offeredCollateralAmount_ The amount of collateral the borrower is offering (0 if none).
     * @param offeredCollateralToken_ The ERC20 token for collateral (address(0) if none).
     * @return requestId The unique ID of the newly created loan request.
     */
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

    /**
     * @notice Allows a borrower to accept an open loan offer, forming a loan agreement.
     * @dev Transfers loan principal from lender to borrower. If collateral is required by the offer,
     *      transfers collateral from borrower to this contract. Borrower must have approved collateral transfer.
     *      Lender must have approved principal transfer from their account by this contract.
     *      Marks the offer as `AgreementReached` and creates an `Active` loan agreement.
     * @param offerId_ The ID of the loan offer to accept.
     * @param collateralOfferedByBorrowerAmount_ Amount of collateral provided by borrower (must match offer requirement).
     * @param collateralOfferedByBorrowerToken_ Token of collateral provided by borrower (must match offer requirement).
     * @return agreementId The unique ID of the newly formed loan agreement.
     */
    function acceptLoanOffer(
        bytes32 offerId_,
        uint256 collateralOfferedByBorrowerAmount_,
        address collateralOfferedByBorrowerToken_
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

    /**
     * @notice Allows a lender to fund an open loan request, forming a loan agreement.
     * @dev Transfers loan principal from lender to borrower. If collateral was offered in the request,
     *      transfers collateral from borrower to this contract. Borrower must have approved collateral transfer.
     *      Lender must have approved principal transfer from their account by this contract.
     *      Marks the request as `AgreementReached` and creates an `Active` loan agreement.
     * @param requestId_ The ID of the loan request to fund.
     * @return agreementId The unique ID of the newly formed loan agreement.
     */
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
    /**
     * @notice Retrieves the details of a specific loan offer.
     * @param offerId The ID of the loan offer.
     * @return The LoanOffer struct for the given ID. Reverts if the offer does not exist.
     */
    function getLoanOfferDetails(bytes32 offerId) external view returns (LoanOffer memory) {
        require(loanOffers[offerId].lender != address(0), "Offer does not exist");
        return loanOffers[offerId];
    }

    /**
     * @notice Retrieves the details of a specific loan request.
     * @param requestId The ID of the loan request.
     * @return The LoanRequest struct for the given ID. Reverts if the request does not exist.
     */
    function getLoanRequestDetails(bytes32 requestId) external view returns (LoanRequest memory) {
        require(loanRequests[requestId].borrower != address(0), "Request does not exist");
        return loanRequests[requestId];
    }

    /**
     * @notice Retrieves the details of a specific loan agreement.
     * @param agreementId The ID of the loan agreement.
     * @return The LoanAgreement struct for the given ID. Reverts if the agreement does not exist.
     */
    function getLoanAgreementDetails(bytes32 agreementId) external view returns (LoanAgreement memory) {
        require(loanAgreements[agreementId].borrower != address(0), "Agreement does not exist");
        return loanAgreements[agreementId];
    }

    /**
     * @notice Retrieves an array of loan offer IDs created by a specific user.
     * @param user The address of the user (lender).
     * @return An array of bytes32 offer IDs.
     */
    function getUserLoanOfferIds(address user) external view returns (bytes32[] memory) {
        return userLoanOffers[user];
    }

    /**
     * @notice Retrieves an array of loan request IDs created by a specific user.
     * @param user The address of the user (borrower).
     * @return An array of bytes32 request IDs.
     */
    function getUserLoanRequestIds(address user) external view returns (bytes32[] memory) {
        return userLoanRequests[user];
    }

    /**
     * @notice Retrieves an array of loan agreement IDs where a specific user is the lender.
     * @param user The address of the user (lender).
     * @return An array of bytes32 agreement IDs.
     */
    function getUserLoanAgreementIdsAsLender(address user) external view returns (bytes32[] memory) {
        return userLoanAgreementsAsLender[user];
    }

    /**
     * @notice Retrieves an array of loan agreement IDs where a specific user is the borrower.
     * @param user The address of the user (borrower).
     * @return An array of bytes32 agreement IDs.
     */
    function getUserLoanAgreementIdsAsBorrower(address user) external view returns (bytes32[] memory) {
        return userLoanAgreementsAsBorrower[user];
    }

    // --- Internal Helper Functions & Loan Lifecycle Management ---
    /**
     * @dev Internal function to calculate simple interest for a loan.
     * @param principalAmount The principal amount of the loan.
     * @param interestRateBps The interest rate in basis points.
     * @return interest The calculated interest amount.
     */
    function _calculateInterest(
        uint256 principalAmount,
        uint256 interestRateBps
    ) internal pure returns (uint256 interest) {
        if (principalAmount == 0 || interestRateBps == 0) {
            return 0;
        }
        return (principalAmount * interestRateBps) / BASIS_POINTS;
    }

    /**
     * @dev Internal function to calculate the total amount due for a loan agreement (principal + interest).
     * @param agreement The LoanAgreement struct for which to calculate the total due.
     * @return totalDue The total amount due for the loan.
     */
    function _calculateTotalDue(LoanAgreement storage agreement) internal view returns (uint256 totalDue) {
        uint256 interest = _calculateInterest(
            agreement.principalAmount, 
            agreement.interestRate
        );
        return agreement.principalAmount + interest;
    }

    // --- Repayment and Default Handling ---
    /**
     * @notice Allows a borrower to make a payment towards an active loan agreement.
     * @dev Transfers `paymentAmount` of `loanToken` from borrower to lender.
     *      Updates `amountPaid`. If fully repaid, marks agreement as `Repaid`, returns collateral (if any)
     *      to borrower, and calls `reputationContract.updateReputationOnLoanRepayment`.
     *      Prevents overpayment. Borrower must have approved `paymentAmount` transfer to this contract.
     * @param agreementId The ID of the loan agreement to repay.
     * @param paymentAmount The amount of `loanToken` to repay.
     */
    function repayP2PLoan(bytes32 agreementId, uint256 paymentAmount) external nonReentrant {
        LoanAgreement storage agreement = loanAgreements[agreementId];
        require(agreement.borrower == msg.sender, "Only borrower can repay");
        require(agreement.status == LoanStatus.Active, "Loan not active");
        require(paymentAmount > 0, "Payment amount must be positive");

        uint256 totalDue = _calculateTotalDue(agreement);
        uint256 remainingDue = totalDue - agreement.amountPaid;
        require(paymentAmount <= remainingDue, "Payment exceeds remaining due");

        IERC20(agreement.loanToken).transferFrom(msg.sender, agreement.lender, paymentAmount);

        agreement.amountPaid += paymentAmount;
        emit LoanRepaymentMade(agreementId, paymentAmount, agreement.amountPaid);

        if (agreement.amountPaid >= totalDue) {
            agreement.status = LoanStatus.Repaid;
            emit LoanAgreementRepaid(agreementId);

            if (agreement.collateralAmount > 0 && agreement.collateralToken != address(0)) {
                IERC20(agreement.collateralToken).transfer(agreement.borrower, agreement.collateralAmount);
            }

            if (address(reputationContract) != address(0)) { 
                reputationContract.updateReputationOnLoanRepayment(agreement.borrower, agreement.lender, agreement.principalAmount);
            }
        }
    }

    /**
     * @notice Handles the default of an active loan agreement.
     * @dev Can be called by anyone if the loan is overdue and not fully repaid.
     *      Marks the agreement as `Defaulted`. Transfers collateral (if any) from this contract to the lender.
     *      Calls `reputationContract.updateReputationOnLoanDefault` for the borrower.
     *      Then, iterates through active vouches for the borrower (obtained from Reputation contract)
     *      and calls `reputationContract.slashVouchAndReputation` for each active vouch to slash a percentage
     *      of their stake, compensating the lender of the defaulted loan.
     * @param agreementId The ID of the loan agreement to handle for default.
     */
    function handleP2PDefault(bytes32 agreementId) external nonReentrant {
        LoanAgreement storage agreement = loanAgreements[agreementId];
        require(agreement.lender != address(0), "Agreement does not exist");
        require(agreement.status == LoanStatus.Active, "Loan not active for default");
        require(block.timestamp > agreement.dueDate, "Loan not yet overdue");

        uint256 totalDue = _calculateTotalDue(agreement);
        require(agreement.amountPaid < totalDue, "Loan already fully paid, cannot default");

        agreement.status = LoanStatus.Defaulted;
        emit LoanAgreementDefaulted(agreementId);

        if (agreement.collateralAmount > 0 && agreement.collateralToken != address(0)) {
            IERC20(agreement.collateralToken).transfer(agreement.lender, agreement.collateralAmount);
        }

        if (address(reputationContract) != address(0)) { 
            reputationContract.updateReputationOnLoanDefault(
                agreement.borrower, 
                agreement.lender, 
                agreement.principalAmount,
                new bytes32[](0) 
            );

            Reputation.Vouch[] memory activeVouches = reputationContract.getActiveVouchesForBorrower(agreement.borrower);
            uint256 tenPercentSlashBasis = 1000; // 10.00%

            for (uint i = 0; i < activeVouches.length; i++) {
                Reputation.Vouch memory currentVouch = activeVouches[i];
                if (currentVouch.isActive && currentVouch.stakedAmount > 0) { 
                    uint256 slashAmount = (currentVouch.stakedAmount * tenPercentSlashBasis) / BASIS_POINTS;
                    if (slashAmount == 0 && currentVouch.stakedAmount > 0) { 
                        slashAmount = 1; 
                    }
                    if (slashAmount > currentVouch.stakedAmount) { 
                        slashAmount = currentVouch.stakedAmount;
                    }

                    if (slashAmount > 0) {
                        reputationContract.slashVouchAndReputation(
                            currentVouch.voucher,
                            agreement.borrower,
                            slashAmount,
                            agreement.lender 
                        );
                    }
                }
            }
        }
    }

    // To be implemented based on PRD.md:
    // requestP2PLoanExtension(...)

} 