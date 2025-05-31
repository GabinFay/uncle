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

/**
 * @title P2PLending (Previously LoanContract)
 * @dev Manages the peer-to-peer lending lifecycle.
 */
contract P2PLending is Ownable, ReentrancyGuard { // Renamed from LoanContract
    UserRegistry public userRegistry;
    // SocialVouching public socialVouching; // REMOVED
    // address payable public treasuryAddress; // REMOVED - P2P model
    IReputationOApp public reputationOApp; // For now, will interact with a future Reputation.sol via this interface or direct calls

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
        address userRegistryAddress,
        address socialVouchingAddress, // Will become reputationContractAddress
        address payable treasuryAddressForOldLogic, // No longer directly used for P2P core
        address initialReputationOAppAddress 
    ) Ownable(msg.sender) {
        require(userRegistryAddress != address(0), "Invalid UserRegistry address");
        // require(socialVouchingAddress != address(0), "Invalid SocialVouching address"); // Temporarily allow 0 for refactor
        // require(initialTreasuryAddress != address(0), "Invalid Treasury address"); // No longer used
        require(initialReputationOAppAddress != address(0), "Invalid ReputationOApp address"); 
        userRegistry = UserRegistry(userRegistryAddress);
        // socialVouching = SocialVouching(socialVouchingAddress); // REMOVED
        // treasuryAddress = initialTreasuryAddress; // REMOVED
        reputationOApp = IReputationOApp(initialReputationOAppAddress); 
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
    function setReputationOAppAddress(address newReputationOAppAddress) external onlyOwner {
        require(newReputationOAppAddress != address(0), "Invalid ReputationOApp address");
        reputationOApp = IReputationOApp(newReputationOAppAddress);
    }
    
    // The setPythAddress function is removed/reverted as Pyth is not used
    function setPythAddress(address newPythAddress) external onlyOwner {
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
        // Placeholder: Call Reputation.sol to record loan initiation
        // if (address(reputationOApp) != address(0)) { 
        // reputationOApp.updateOnLoanAgreement(agreementId, offer.lender, msg.sender, offer.offerAmount);
        // }

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
        // Placeholder: Call Reputation.sol to record loan initiation
        // if (address(reputationOApp) != address(0)) { 
        //     reputationOApp.updateOnLoanAgreement(agreementId, msg.sender, request.borrower, request.requestAmount);
        // }

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

    // To be implemented based on PRD.md:
    // repayP2PLoan(...)
    // handleP2PDefault(...)
    // requestP2PLoanExtension(...)
    // approveP2PLoanExtension(...)
    // getLoanOfferDetails(...)
    // getLoanRequestDetails(...)
    // getLoanAgreementDetails(...)
    // getUserLoanOffers(...)
    // getUserLoanRequests(...)
    // getUserLoanAgreements(...)

} 