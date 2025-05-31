# Final PRD - Decentralized Credit Recovery (Hackathon Scope)

## The Problem: Financial Exclusion & Reputation
Millions are excluded from traditional financial systems due to a lack of credit history or past defaults. Existing systems offer limited paths to recovery and don't easily recognize non-traditional forms of creditworthiness or the value of a unique, verifiable identity in mitigating risk.

## Our Solution: P2P Lending with World ID-Powered Reputation
A peer-to-peer lending platform built on trust and verifiable reputation, anchored by World ID.

**Core Idea:** Individuals can lend to and borrow from each other. A user's reputation, tied to their unique World ID, is a key factor in loan terms and a strong incentive for repayment. Social vouching further strengthens this model.

## Hackathon Scope & Features:

*For a detailed breakdown of tasks, sprint-by-sprint goals, and specific bounty targets, please refer to `SPRINT_PLAN.md`.*

The overall development is structured in phases, aiming to incorporate various sponsor technologies:

### Phase 1: Core Contract Enhancement & Flow Blockchain Deployment
**Goal:** Ensure core smart contracts (`UserRegistry.sol`, `P2PLending.sol`, `Reputation.sol`) are robust and support the user flows defined in the latest `uncle` Next.js application (including loan lifecycle management like repayment, extensions, defaults). Deploy and thoroughly test these contracts on the Flow blockchain.
**Key Technologies/Bounties:** World ID (for user identity), Core EVM (Flow Killer App or similar), Flow Blockchain, Ethers.js for testing.

**Contracts & Features (Recap & Enhancements):**
1.  **`UserRegistry.sol`:**
    *   Users sign in/register with their World ID.
    *   Ensure compatibility with frontend identity management.
2.  **`P2PLending.sol`:**
    *   **Loan Offers/Requests:** Users can create loan offers (lenders) or loan requests (borrowers).
    *   **Loan Agreements:** Mechanism for borrowers to accept offers or lenders to fund requests.
    *   **Interest:** Simple interest calculation.
    *   **Repayment:** Borrowers repay loans.
    *   **Default Handling:** Logic for defaults.
    *   **Loan Extensions:** (Crucial for `uncle` app flow)
        *   Mechanism for borrowers to request extensions.
        *   Mechanism for lenders to approve/deny extensions.
        *   Potential adjustments to terms (e.g., interest) upon extension.
3.  **`Reputation.sol`:**
    *   **Reputation Metrics:** Based on loan performance (repayments, defaults), vouching.
    *   **Reputation Updates:** Triggered by loan events (repayment, default, extension outcomes).
    *   **Social Vouching:** Users stake to vouch; impacts reputation of both voucher and vouchee.

**Development & Testing:**
1.  **Contract Refinement:** Review and update existing Solidity contracts to fully support all user interaction flows present in the `uncle` application. This includes handling loan repayment schedules, requests for payment extensions, and the consequences of such actions on loan status and reputation.
2.  **Flow Deployment:** Deploy the refined contracts to the Flow blockchain (testnet).
3.  **Ethers.js Testing:** Develop comprehensive test scripts using Ethers.js to interact with the deployed contracts on Flow (testnet), verifying all functionalities, especially the new loan management flows.

### Phase 2: Frontend Integration & dApp Functionality
**Goal:** Connect the `uncle` Next.js frontend to the smart contracts deployed on Flow, enabling full dApp functionality, including wallet connection.
**Key Technologies/Bounties:** Next.js, RainbowKit (for wallet connection), Ethers.js (for frontend-contract interaction).

**Features & Tasks:**
1.  **Wallet Integration:** Implement wallet connection using RainbowKit in the `uncle` app.
2.  **Contract Interaction:** Integrate frontend components with the deployed smart contracts to perform all actions:
    *   User registration (World ID).
    *   Creating/viewing/accepting loan offers/requests.
    *   Managing active loans (viewing status, making repayments, requesting extensions).
    *   Vouching for others.
    *   Viewing reputation profiles.
3.  **Debugging & Testing:** Thoroughly debug the frontend-backend (smart contract) interactions to ensure a seamless user experience.

### Phase 3 (Optional - Stretch Goal): WorldChain & Cross-Chain Reputation via LayerZero
**Goal:** Explore deploying the reputation system to WorldChain and using LayerZero's `LzCompose` to read this reputation from the Flow-based lending application. This is a stretch goal if time permits after primary objectives are met.
**Key Technologies/Bounties:** WorldChain, LayerZero (`LzCompose`).

**Features & Tasks (Conditional):**
1.  **WorldChain Deployment:** Deploy `Reputation.sol` (and potentially `UserRegistry.sol`) to WorldChain.
2.  **LayerZero `LzCompose` Integration:**
    *   If proceeding, develop a mechanism on Flow (within `P2PLending.sol` or a new contract) to use `LzCompose` to read a user's reputation from `Reputation.sol` on WorldChain.
    *   This fetched reputation would then inform loan terms or trust levels on the Flow application.

### V2: Blockscout Analytics Integration & Further Sponsor Tech (Corresponds to elements of Sprint 2-3 in `SPRINT_PLAN.md` - *Currently Lower Priority*)
**Goal:** Enhance user profiles with on-chain analytics and integrate other relevant sponsor technologies.
**Key Technologies/Bounties:** Blockscout (SDK/Merits), vLayer/Flare (alternative data), Hedera (AI/HCS), Pyth (oracles), Filecoin (storage), 1inch (swaps).

**Features:**
1.  **Backend Service/Integration:**
    *   Use Blockscout APIs to parse historical transactions and chain activity for registered users.
2.  **Frontend Display:**
    *   Display these analytics in the user's profile within the app (e.g., transaction frequency, common interaction patterns, gas spent, types of dApps used) to provide a richer, more holistic view of their on-chain footprint, potentially complementing their direct lending reputation.

## Non-Goals (for Hackathon Scope):
*   Complex DeFi integrations (e.g., yield farming on treasury, advanced collateral types beyond direct P2P agreement).
*   vLayer, Hedera AI, Filecoin specific integrations (unless a very simple, direct use case emerges for reputation/identity that fits the core P2P model).
*   1inch, Flare, Rootstock, Yellow/Nitrolite specific contract deployments/features.
*   Pyth Network or other dedicated price oracles for LTV calculations (P2P terms are set between users, collateral (if any) is agreed upon directly).
*   Automated Market Makers (AMMs) for loan pools.
*   Governance tokens or complex DAO structures.
*   Formal audits (beyond standard good practices and testing).

## Tech Stack (Hackathon Focus):
*   **Smart Contracts:** Solidity
    *   Primary Chain (for lending & initial reputation): Flow Blockchain.
    *   (Optional Stretch) Reputation Chain: World Chain compatible.
*   **Frontend:** Next.js (`uncle` app).
*   **Wallet Connection:** RainbowKit.
*   **Blockchain Interaction:** Ethers.js.
*   **Identity:** World ID.
*   **(Optional Stretch) Cross-Chain:** LayerZero (`LzCompose`).
*   **Explorer/Analytics (Lower Priority):** Blockscout.
*   **Other Sponsor Technologies (as per `SPRINT_PLAN.md` - *Currently Lower Priority*):** vLayer, Flare, Hedera, Pyth, Filecoin, 1inch. 