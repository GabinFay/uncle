# Smart Contract Implementation Status (status_contracts.md)

This document tracks the development progress of the smart contracts outlined in `contracts.md`.

## Sprint 0: Core Contracts Foundation (Primary EVM Chain)

**Goal:** Establish the fundamental contracts for user identity and basic loan operations.

*   **Task 0.1: `UserRegistry.sol` - Initial Version & Unit Tests**
    *   [X] Define basic struct for UserProfile (World ID status, reputation, Filecoin pointer).
    *   [X] Implement `registerOrUpdateUser(address userAddress, bytes32 worldIdNullifierHash_)` (owner-only, handles World ID uniqueness).
    *   [X] Implement `isUserWorldIdVerified(address userAddress)`.
    *   [X] Implement `getUserProfile(address userAddress)`.
    *   [X] Implement `updateFilecoinDataPointer` and `updateReputationScore` (owner-only placeholders).
    *   [X] Basic Ownable/Admin functions (inherits from OpenZeppelin's Ownable).
    *   [X] Unit tests for all functions (16 tests passing in `test/UserRegistry.t.sol`).
    *   **Status:** Completed

*   **Task 0.2: `SocialVouching.sol` - Initial Version & Unit Tests**
    *   [X] Define struct for Vouch.
    *   [X] Implement `addVouch(address borrower, uint256 amount, address tokenAddress)`.
    *   [X] Implement `removeVouch(address borrower)`.
    *   [X] Implement `slashVouch(address borrower, address voucher, uint256 amount, address recipient)` (placeholder logic, owner callable).
    *   [X] Implement `rewardVoucher(address borrower, address voucher, uint256 rewardAmount, address rewardToken)` (placeholder logic).
    *   [X] Implement `getVouchDetails(address borrower, address voucher)`.
    *   [X] Implement `getTotalVouchedAmountForBorrower(address borrower)`.
    *   [X] Integrate with `UserRegistry` for user verification.
    *   [X] Use ReentrancyGuard.
    *   [X] Unit tests for all functions (17 tests passing in `test/SocialVouching.t.sol`).
    *   **Status:** Completed

*   **Task 0.3: `LoanContract.sol` - Initial Version & Unit Tests**
    *   [X] Define Loan struct (borrower, principal, token, interest, duration, status, etc.).
    *   [X] Implement `applyForLoan(...)` including basic checks and collateral handling.
    *   [X] Implement `approveLoan(...)` (owner/admin only) which also handles disbursal from Treasury.
    *   [X] Implement `repayLoan(...)` for ERC20 loans.
    *   [X] Implement `calculateAmountDue(...)` (simplified interest).
    *   [X] Implement `liquidateLoan(...)` (placeholder logic, owner callable).
    *   [X] Implement `getLoanDetails(...)` and `getUserLoanIds(...)`.
    *   [X] Integrate with `UserRegistry` (borrower verification) and `Treasury` (fund movements).
    *   [X] Basic Ownable/Admin functions (e.g., `setTreasuryAddress`).
    *   [X] Use ReentrancyGuard.
    *   [X] Initial unit tests for core flows (apply, approve/disburse, repay, admin setters) (14 tests passing in `test/LoanContract.t.sol`).
    *   **Status:** Completed (Initial Version)

*   **Task 0.4: `Treasury.sol` - Initial Version & Unit Tests**
    *   [X] Implement ETH and ERC20 deposit functions (`depositETH`, `depositFunds`).
    *   [X] Implement ETH and ERC20 withdrawal functions for owner (`withdrawETH`, `withdrawFunds`).
    *   [X] Implement ETH and ERC20 transfer functions callable by `LoanContract` (`transferETHToLoanContract`, `transferFundsToLoanContract`).
    *   [X] Implement `setLoanContractAddress` (owner only).
    *   [X] Use Ownable and ReentrancyGuard.
    *   [X] Unit tests for all functions (18 tests passing in `test/Treasury.t.sol`).
    *   **Status:** Completed

*   **Task 0.5: Initial Integration Tests (Inter-contract)**
    *   [X] Test full loan lifecycle: User registers -> User applies for loan -> Admin approves (funds move from Treasury to User) -> User repays (funds move from User to Treasury).
    *   [X] Test loan application with collateral.
    *   [X] Test loan application with social vouching (vouch amount recorded at application, vouch remains after repayment).
    *   **Status:** Completed (2 tests passing in `test/Integration.t.sol`)

## Sprint 1: Advanced Loan Features & First Integrations

*   **Task 1.1: `LoanContract.sol` - Advanced Repayment & Default**
    *   [X] Implement partial repayments.
    *   [X] Handle overpayments (refund or credit).
    *   [X] Logic for `LoanStatus.Defaulted` based on `dueDate` (via `checkAndSetDefaultStatus`).
    *   [X] More detailed `liquidateLoan` logic for `Defaulted` loans (collateral seizure confirmed).
    *   [ ] Vouch slashing interaction within `liquidateLoan` (Deferred: pending `LoanContract` storing individual voucher details).
    *   [X] Unit tests for these scenarios (24 tests passing in `test/LoanContract.t.sol`).
    *   **Status:** Mostly Completed (Vouch Slashing call deferred)

*   **Task 1.2: `SocialVouching.sol` - Vouch Slashing & Rewards Integration**
    *   [X] Refined `slashVouch` and `rewardVoucher` to be callable only by `LoanContract` (via `onlyLoanContract` modifier and `setLoanContractAddress`).
    *   [X] `SocialVouching.slashVouch` transfers slashed funds to a specified `recipient` (e.g., Treasury).
    *   [ ] `LoanContract.liquidateLoan` to call `SocialVouching.slashVouch` (Deferred: requires `LoanContract` to track specific vouchers per loan).
    *   [ ] Implement full logic for distributing rewards via `rewardVoucher` (currently placeholder, callable by `LoanContract`).
    *   [X] Unit tests for `SocialVouching` access control (19 tests passing in `test/SocialVouching.t.sol`).
    *   **Status:** Partially Completed (`SocialVouching` prepared, `LoanContract` integration for calling slash/reward deferred)

*   **Task 1.3: Pyth Network Integration (Placeholder)**
    *   [X] Define an `IPyth.sol` interface.
    *   [X] Add `pythAddress` and `setPythAddress` to `LoanContract.sol` (and constructor).
    *   [X] Modify `LoanContract.sol` with placeholder comments for LTV checks and collateral valuation using Pyth.
    *   [X] Unit tests for `setPythAddress`.
    *   [ ] Unit tests mocking Pyth responses and LTV logic (Deferred: Pyth price feed logic not yet implemented in `LoanContract`).
    *   **Status:** Mostly Completed (Core setup done, detailed logic deferred)

*   **Task 1.4: LayerZero OApp Integration (Placeholder for Reputation)**
    *   [X] Define `IReputationOApp.sol` interface (similar to `ILayerZeroEndpointV2.sol` + app-specific functions).
    *   [X] Add `reputationOAppAddress` and `setReputationOAppAddress` to `LoanContract.sol` (and constructor).
    *   [X] Modify `LoanContract.sol` with placeholder calls to `reputationOApp` (e.g., on loan repayment, default, liquidation).
    *   [X] Unit tests for `setReputationOAppAddress`.
    *   [ ] Unit tests mocking `IReputationOApp` calls (Deferred: Reputation update logic not yet implemented in `LoanContract`).
    *   **Status:** Mostly Completed (Core setup done, detailed logic deferred)

## Future Sprints (Outline)

*   **ReputationOApp.sol (LayerZero OApp for cross-chain reputation)**
*   **Filecoin Integration (User Data via FVM/bacalhau)**
*   **Hedera AI Integration (Credit Scoring via HCS/Smart Contracts)**
*   **1inch Integration (Token Swaps)**
*   **Flare Integration (FDC for alternative data)**
*   **Rootstock Deployment & RBTC/RIF specific features**
*   **Blockscout API/SDK integration for frontend**
*   **Advanced security considerations (audits, formal verification placeholders)**
*   **Gas optimizations**
*   **Upgradability strategy implementation (e.g., UUPS proxies)**

## Sprint 2: Advanced Features & Cross-Chain Prep

**Goal:** Implement price oracle integration, prepare for actual cross-chain functionality.

*   **Task 2.1: `LoanContract.sol` - Pyth Oracle Integration**
    *   [ ] Integrate Pyth SDK (`IPyth.sol`, `PythStructs.sol`).
    *   [ ] Implement `updateAndGetPrice` logic (may require backend interaction stub for `priceUpdateData`).
    *   [ ] Use price feeds for collateral valuation in `applyForLoan` and `liquidateLoan`.
    *   [ ] Unit tests.
    *   **Status:** Not Started

*   **Task 2.2: `ReputationOApp.sol` - LayerZero Messaging Stubs**
    *   [ ] Implement `sendReputationUpdate(uint32 destinationEid, ...)` to prepare payload and call LayerZero endpoint (actual messaging depends on LayerZero setup).
    *   [ ] Implement `_lzReceive(...)` to decode payload (stub for applying update).
    *   [ ] Unit tests for payload encoding/decoding.
    *   **Status:** Not Started

*   **Task 2.3: `UserRegistry.sol` - Filecoin Pointer**
    *   [X] Add field in UserProfile to store Filecoin data pointer.
    *   [X] Function to update this pointer (admin/backend called).
    *   **Status:** Initial Draft Complete

## Sprint 3+: Full Auxiliary & Sponsor Integrations (Details TBD based on backend progress)

*   **Task 3.1: Full `FilecoinClientContract.sol` on FVM** (Requires FVM environment setup)
    *   **Status:** Not Started
*   **Task 3.2: Full `AlternativeDataFDC.sol` on Flare** (Requires Flare environment setup)
    *   **Status:** Not Started
*   **Task 3.3: Full `AIScoreAttestation.sol` on Hedera** (Requires Hedera environment setup)
    *   **Status:** Not Started
*   **Task 3.4: vLayer Integration (Prover/Verifier)**
    *   `OurDataVerifier.sol` on primary chain.
    *   Requires off-chain Prover logic in backend.
    *   **Status:** Not Started
*   **Task 3.5: Complete LayerZero Integration for `ReputationOApp.sol`**
    *   Full deployment and peer setup across chains.
    *   End-to-end testing of cross-chain reputation updates.
    *   **Status:** Not Started

## Security & Audits

*   [ ] Slither/Static Analysis on all contracts (Ongoing).
*   [ ] Comprehensive unit test coverage (Ongoing).
*   [ ] Formal Audit (Post-MVP, before mainnet launch).
    *   **Status:** Not Started

## Notes
*   This plan assumes Solidity and an EVM-compatible primary chain. Adjustments needed for non-EVM chains if chosen.
*   Dependencies on backend development for certain triggers/data feeds are noted.
*   Bounty-specific contract features (e.g., unique aspects for Blockscout Merits, 1inch swap integration if on-chain) to be woven in as specific contracts solidify. 