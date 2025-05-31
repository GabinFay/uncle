# Smart Contract Architecture (contracts.md)

This document outlines the smart contract architecture for the Decentralized Credit Recovery Platform, as derived from `PRD_v3.md`.

## Core Principles

*   **Modularity:** Contracts should be modular to allow for easier upgrades, testing, and integration of various sponsor technologies.
*   **Security:** Prioritize security with measures like input validation, reentrancy guards, and adherence to best practices. Plan for audits.
*   **Gas Efficiency:** While not the primary driver for MVP, keep gas costs in mind, especially for user-facing functions.
*   **Interoperability:** Design with potential cross-chain interactions in mind (LayerZero).
*   **Upgradability:** Use proxy patterns (e.g., UUPS) for core logic contracts where feasible.

## Primary EVM Chain Contracts (e.g., Flow EVM, Rootstock, Polygon)

These contracts will form the core logic of the platform on the chosen primary EVM-compatible chain.

### 1. `UserRegistry.sol`

*   **Purpose:** Manages user registration and core identity attributes.
*   **Key Features:**
    *   `registerUser(bytes worldIdProof)`: Registers a new user. Backend verifies `worldIdProof` and then calls this. Stores a link between user's wallet address and their verified World ID status (e.g., storing the World ID nullifier or a platform-specific unique ID derived from it).
    *   `isUserVerified(address userAddress)`: Returns true if the user has a verified World ID linked.
    *   `getUserProfile(address userAddress)`: Returns basic profile info, including pointers to data on Filecoin, reputation score, etc.
    *   Admin functions for managing contract state if necessary (e.g., pausing registration).
*   **Integrations:** World ID (via backend verification), potentially LayerZero for syncing key profile data.

### 2. `SocialVouching.sol`

*   **Purpose:** Manages the social vouching mechanism.
*   **Key Features:**
    *   `requestVouch(address targetUser)`: Allows a registered user to signal they are seeking vouches.
    *   `addVouch(address borrower, uint256 amount, address tokenAddress)`: Allows a World ID verified user (the voucher) to stake `amount` of `tokenAddress` for the `borrower`.
        *   Requires `msg.sender` (voucher) and `borrower` to be registered in `UserRegistry.sol` and World ID verified.
        *   Transfers tokens from voucher to this contract.
    *   `removeVouch(address borrower)`: Allows a voucher to unstake their tokens if the borrower has no active loan or the vouch is not locked.
    *   `slashVouch(address borrower, address voucher, uint256 amount)`: Called by the `LoanContract` upon default to seize staked tokens.
    *   `rewardVoucher(address voucher, uint256 amount)`: Called by the `LoanContract` or platform treasury to reward successful vouches.
    *   `getVouchDetails(address borrower, address voucher)`: Returns details of a specific vouch.
    *   `getTotalVouchedAmount(address borrower)`: Returns total value staked for a borrower (may need oracle for token valuation if multiple token types).
*   **Integrations:** `UserRegistry.sol`, `LoanContract.sol`, potentially Pyth/Price Oracles if vouching with various tokens.

### 3. `LoanContract.sol`

*   **Purpose:** Manages the complete micro-lending lifecycle.
*   **Key Features:**
    *   `applyForLoan(uint256 amount, address collateralToken, uint256 collateralAmount)`: User applies for a loan.
        *   Checks user registration (`UserRegistry.sol`).
        *   Checks AI credit score (read from an on-chain attestation or passed by backend after off-chain calculation).
        *   Checks total vouched amount (`SocialVouching.sol`).
        *   Uses Pyth/Price Oracle to value `collateralAmount` if provided.
    *   `approveLoan(bytes32 loanId)`: Admin/automated function to approve a loan based on checks.
    *   `disburseLoan(bytes32 loanId)`: Transfers loan funds (from a treasury/pool managed by this contract or a separate `Treasury.sol`) to the borrower.
    *   `repayLoan(bytes32 loanId, uint256 amount)`: Borrower repays the loan.
    *   `liquidateLoan(bytes32 loanId)`: Handles undercollateralized loans, seizing collateral and potentially slashing vouches via `SocialVouching.sol`.
    *   `getLoanDetails(bytes32 loanId)`.
    *   `getOutstandingLoans(address borrower)`.
*   **Integrations:** `UserRegistry.sol`, `SocialVouching.sol`, Pyth/Price Oracles, AI Score Attestation (potentially on Hedera, read via LayerZero or backend), `Treasury.sol`.

### 4. `Treasury.sol` (or LiquidityPool.sol)

*   **Purpose:** Manages funds for loan disbursal and receives repayments.
*   **Key Features:**
    *   `depositFunds()`: Allows investors/platform to deposit capital.
    *   `withdrawFunds(uint256 amount)`: Admin/investor withdrawal under specific conditions.
    *   Holds various tokens used for lending.
*   **Integrations:** `LoanContract.sol`.

### 5. `ReputationOApp.sol` (LayerZero Omnichain Application)

*   **Purpose:** Manages and synchronizes user reputation scores across multiple chains.
*   **Key Features (as per LayerZero OApp standard):**
    *   Stores mapping `(address user => uint256 reputationScore)`.
    *   `updateLocalReputation(address user, uint256 newScore)`: Called by other platform contracts (e.g., `LoanContract` on successful repayment) or backend to update reputation locally.
    *   `sendReputationUpdate(uint32 destinationEid, address user, uint256 newScore)`: Sends reputation update to other chains via LayerZero.
    *   `_lzReceive(originEid, originAddress, nonce, payload)`: Receives and applies reputation updates from other chains.
*   **Integrations:** LayerZero SDK, other platform contracts.

## Auxiliary Chain Contracts

### 1. Filecoin Virtual Machine (FVM)

*   **`FilecoinClientContract.sol` (from FVM starter kit or similar):**
    *   **Purpose:** To enable the backend to make on-chain storage deals on Filecoin for user data.
    *   **Key Features:** `makeDealProposal`.
    *   **Integration:** Called by the platform's backend.

### 2. Flare Network

*   **`AlternativeDataFDC.sol`:**
    *   **Purpose:** To request and verify Web2 data using Flare Data Connector.
    *   **Key Features:** Interacts with `FdcHub` to call `requestAttestation(AttestationType.JsonApi, ...)`.
    *   **Integration:** Backend triggers requests; this contract verifies Merkle proofs of attested data. Data can then be bridged/messaged to the primary chain.

### 3. Hedera Network

*   **`AIScoreAttestation.sol` (Hedera Smart Contract - Optional but recommended for Hedera bounty):**
    *   **Purpose:** To create an on-chain attestation of AI model versions or specific credit decisions/scores.
    *   **Key Features:** `attestScore(address user, uint256 score, bytes32 modelVersionHash)`.
    *   **Integration:** Called by the backend after AI processing. Data logged to HCS can serve as inputs/proofs for these attestations.

## Off-Chain Linkages

*   **Backend (Python/Node.js):** Crucial for orchestrating many processes:
    *   World ID proof verification.
    *   AI model execution.
    *   Interaction with Filecoin client for data prep and deal proposal.
    *   Interaction with Flare FDC for initiating requests and retrieving data.
    *   Pushing price updates to Pyth-integrated contracts.
    *   Calling HCS and Hedera Smart Contracts for AI logging/attestation.
    *   Triggering LayerZero messages.
*   **Frontend (React/Next.js - World App Mini App):** User interface, wallet interactions, submitting data to backend.

## Data Flow for Key Features (Simplified)

1.  **User Onboarding:** Frontend (Mini App) -> World ID SDK -> Backend (verifies proof) -> `UserRegistry.sol`.
2.  **Alternative Data (vLayer):** User -> Frontend -> Backend -> vLayer Prover (off-chain) -> `OurDataVerifier.sol` (on primary EVM) -> `UserRegistry.sol` (updates profile).
3.  **Alternative Data (Flare FDC):** User -> Frontend -> Backend -> `AlternativeDataFDC.sol` (on Flare) -> Attested Data -> Backend -> (Bridge/Message to Primary EVM) -> `UserRegistry.sol`.
4.  **AI Scoring:** Data (from UserRegistry, Vouching) -> Backend (Python AI Model) -> HCS Log (on Hedera) & `AIScoreAttestation.sol` (on Hedera).
5.  **Loan Application:** User -> Frontend -> Backend (gets AI score, vouches) -> `LoanContract.sol` (uses Pyth for collateral).
6.  **Reputation Update:** `LoanContract.sol` (on successful repayment) -> `ReputationOApp.sol` (local update) -> LayerZero -> `ReputationOApp.sol` (on other chains).

This architecture aims to be comprehensive yet modular, allowing different components to be developed and integrated systematically. The choice of primary EVM chain will influence some deployment details but the core Solidity logic should be largely portable. 