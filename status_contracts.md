# Smart Contract Implementation Status (status_contracts.md)

This document tracks the development progress of the smart contracts outlined in `contracts.md`.

## Sprint 0: Core Contracts Foundation (Primary EVM Chain)

**Goal:** Establish the fundamental contracts for user identity and basic loan operations.

*   **Task 0.1: `UserRegistry.sol` - Initial Version**
    *   [X] Define basic struct for UserProfile (World ID status, reputation, Filecoin pointer).
    *   [X] Implement `registerOrUpdateUser(address userAddress, bytes32 worldIdNullifierHash_)` (owner-only, handles World ID uniqueness).
    *   [X] Implement `isUserWorldIdVerified(address userAddress)`.
    *   [X] Implement `getUserProfile(address userAddress)`.
    *   [X] Implement `updateFilecoinDataPointer` and `updateReputationScore` (owner-only placeholders).
    *   [X] Basic Ownable/Admin functions (inherits from OpenZeppelin's Ownable).
    *   [ ] Unit tests for all functions.
    *   **Status:** Initial Draft Complete

*   **Task 0.2: `SocialVouching.sol` - Initial Version**
    *   [X] Define struct for Vouch.
    *   [X] Implement `addVouch(address borrower, uint256 amount, address tokenAddress)` (requires `UserRegistry` integration, token transfer).
    *   [X] Implement `removeVouch(address borrower)` (basic withdrawal, token transfer).
    *   [X] Implement `slashVouch` (callable by trusted entity, token transfer).
    *   [X] Implement `rewardVoucher` (placeholder).
    *   [X] Implement `getTotalVouchedAmountForBorrower(address borrower)` (simplified sum).
    *   [X] Basic ERC20 token transfer logic for stakes.
    *   [X] `onlyVerifiedUser` modifier using `UserRegistry`.
    *   [X] ReentrancyGuard.
    *   [ ] Unit tests for all functions.
    *   **Status:** Initial Draft Complete

*   **Task 0.3: `LoanContract.sol` - Initial Version (Simplified)**
    *   [X] Define struct for Loan and LoanStatus enum.
    *   [X] Implement `applyForLoan(...)` (simplified, basic checks, collateral transfer).
    *   [X] Implement `approveLoan(bytes32 loanId)` (owner-only, disburses funds from Treasury).
    *   [X] Implement `repayLoan(bytes32 loanId)` (handles ERC20/ETH, transfers to Treasury).
    *   [X] Implement `liquidateLoan(bytes32 loanId)` (owner-only, placeholder for collateral seizure/vouch slashing).
    *   [X] Basic loan ID generation and tracking (`loanCounter`, `userLoans` mapping).
    *   [X] `onlyVerifiedUser` and `onlyLoanExists` modifiers.
    *   [X] Ownable and ReentrancyGuard.
    *   [X] Constructor with `UserRegistry`, `SocialVouching`, `Treasury` addresses.
    *   [X] Placeholders for Pyth and ReputationOApp integration.
    *   [ ] Unit tests for all functions.
    *   **Status:** Initial Draft Complete

*   **Task 0.4: `Treasury.sol` - Basic Version**
    *   [X] Implement `depositFunds(address tokenAddress, uint256 amount)` and `depositETH()`.
    *   [X] Implement `withdrawFunds(...)` and `withdrawETH(...)` (owner-only).
    *   [X] Implement `transferFundsToLoanContract` and `transferETHToLoanContract` (callable only by `loanContractAddress`).
    *   [X] `setLoanContractAddress` (owner-only).
    *   [X] Ownable and ReentrancyGuard.
    *   [X] receive() fallback for ETH deposits.
    *   [ ] Unit tests.
    *   **Status:** Initial Draft Complete

*   **Task 0.5: Initial Integration Test**
    *   [ ] Test flow: Register User -> Add Vouch -> Apply Loan -> Approve -> Disburse -> Repay.
    *   **Status:** Not Started (Blocked by Dev Environment Setup)

## Sprint 1: Reputation & Auxiliary Contract Stubs

**Goal:** Introduce reputation and lay groundwork for auxiliary chain integrations.

*   **Task 1.1: `ReputationOApp.sol` - Basic Local Functionality**
    *   [ ] Implement local `updateLocalReputation(address user, uint256 newScore)`.
    *   [ ] Implement local `getReputation(address user)`.
    *   [ ] Integrate reputation updates in `LoanContract.sol` (e.g., on successful repayment).
    *   [ ] Unit tests.
    *   **Status:** Not Started

*   **Task 1.2: Interface Definitions for Auxiliary Contracts**
    *   [ ] Define interfaces in Solidity for `FilecoinClientContract.sol`, `AlternativeDataFDC.sol`, `AIScoreAttestation.sol` to allow primary chain contracts to anticipate these interactions even if full implementation is later.
    *   **Status:** Not Started

*   **Task 1.3: `LoanContract.sol` - Vouching Integration**
    *   [ ] Integrate check for `getTotalVouchedAmount` in `applyForLoan` more robustly.
    *   [ ] Fully implement `slashVouch` call logic in `SocialVouching.sol` and call it from `liquidateLoan` in `LoanContract.sol`.
    *   [ ] Fully implement `rewardVoucher` call logic.
    *   [ ] Unit tests.
    *   **Status:** Not Started

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