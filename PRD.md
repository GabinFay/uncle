# Final PRD - Decentralized Credit Recovery (Hackathon Scope)

## The Problem: Financial Exclusion & Reputation
Millions are excluded from traditional financial systems due to a lack of credit history or past defaults. Existing systems offer limited paths to recovery and don't easily recognize non-traditional forms of creditworthiness or the value of a unique, verifiable identity in mitigating risk.

## Our Solution: P2P Lending with World ID-Powered Reputation
A peer-to-peer lending platform built on trust and verifiable reputation, anchored by World ID.

**Core Idea:** Individuals can lend to and borrow from each other. A user's reputation, tied to their unique World ID, is a key factor in loan terms and a strong incentive for repayment. Social vouching further strengthens this model.

## Hackathon Scope & Features:

### MVP: Peer-to-Peer Lending & Reputation on World Chain
**Goal:** Demonstrate a functional P2P lending system with a robust reputation mechanism on a single chain (World Chain focus for the mini-app).

**Contracts & Features:**
1.  **`UserRegistry.sol` (or similar for World ID users):**
    *   Users sign in/register with their World ID. This ensures each on-chain identity is unique, making reputation meaningful.
2.  **`P2PLending.sol` (Peer-to-Peer Loan Contract):**
    *   **Loan Offers/Requests:** Users can create loan offers (lenders) or loan requests (borrowers).
    *   **Loan Agreements:** Mechanism for borrowers to accept offers or lenders to fund requests, forming a loan agreement.
    *   **Interest:** Simple interest calculation.
    *   **Repayment:** Borrowers repay loans by the due date.
    *   **Default Handling:** Logic for what happens on default.
3.  **`Reputation.sol` (Reputation & Vouching Contract):**
    *   **Reputation Scores/Metrics:** Each World ID-linked user has a reputation score/profile.
        *   Consider on-chain metrics: number of loans taken/given, repayment rates, default history, total value transacted, vouching strength.
    *   **Reputation Updates:**
        *   Successful loan repayment improves borrower's reputation (and potentially lender's if it was a "good" loan).
        *   Defaulting on a loan significantly damages borrower's reputation.
    *   **Social Vouching:**
        *   Users can stake tokens to vouch for their friends (borrowers).
        *   If a vouched borrower defaults, the voucher also loses a portion of their stake AND suffers a reputation hit. This aligns incentives.
    *   **Loan Extensions (Optional MVP, Core V1):**
        *   Borrowers can request a loan extension from the lender.
        *   Lenders can approve/deny.
        *   Extensions might come with a higher interest rate. Successfully repaying after an extension could have a nuanced impact on reputation (better than defaulting, but not as good as on-time).
4.  **World Chain Mini-App:**
    *   Frontend to interact with the contracts: view loan offers/requests, apply/fund loans, manage reputation, see user profiles.

### V1: Cross-Chain Lending with LayerZero
**Goal:** Enable cross-chain P2P lending, with reputation data read from World Chain.

**Contracts & Features:**
1.  **Lending Contracts on Flow:** Deploy versions of `P2PLending.sol` (and potentially a minimal `UserRegistry.sol` or World ID integration method for Flow) on the Flow blockchain.
2.  **LayerZero Integration (`LzCompose`):**
    *   Use LayerZero's `LzCompose` functionality for dApps on Flow to read reputation data from the `Reputation.sol` contract deployed on World Chain. This is crucial as `LzApp` (omnicahin contracts) might not directly support Flow for `lzReceive`. `LzCompose` allows a contract on one chain to call a contract on another and get a result back.
    *   When a user on Flow applies for/offers a loan, their reputation from World Chain is fetched to influence terms/trust.
    *   Potentially, significant events on Flow (like a loan default) could trigger a message back to World Chain via LayerZero to update the global reputation (this part needs careful design for security and atomicity if direct updates are attempted).

### V2: Blockscout Analytics Integration
**Goal:** Enhance user profiles with on-chain analytics derived from Blockscout.

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
    *   Primary Chain (for reputation & initial lending): World Chain compatible (e.g., Polygon PoS, Optimism, Arbitrum - whatever World Chain uses or is easiest for mini-app).
    *   Secondary Chain (for V1): Flow
*   **Frontend:** React/Next.js (or other suitable framework for World Chain Mini-App).
*   **Identity:** World ID.
*   **Cross-Chain:** LayerZero (specifically LzCompose).
*   **Explorer/Analytics (V2):** Blockscout. 