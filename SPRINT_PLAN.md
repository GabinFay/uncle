# SPRINT_PLAN_v3.md

This document outlines a revised sprint plan for the Decentralized Credit Recovery Platform, incorporating a wider range of sponsor technologies and aiming for a multi-faceted MVP.

**Overarching Strategy:** Prioritize features that offer significant bounty potential with manageable MVP complexity. Build foundational elements first, then layer on integrations. Some integrations can be developed in parallel by different team members/focus areas.

## Sprint 0: Core Platform Foundation & Identity (4 Weeks)

*   **Goal:** Establish basic platform structure, user identity, and a simple on-chain presence. This sprint targets high-value, foundational bounties.
*   **Key Bounties Targeted:** World Mini App, Flow Killer App (or other primary EVM chain), Blockscout (Pool Prize).
*   **Tasks:**
    1.  **Project Setup (Parallel with other tasks):**
        *   [X] Git repo, .gitignore, initial docs (PRD, Knowledge, Status).
        *   [X] Basic folder structure (backend, contracts, frontend).
        *   [ ] Basic CI/CD (linting, contract compilation tests).
    2.  **World ID & Mini App Shell (Frontend Team - Parallel):**
        *   Scaffold World App Mini App using MiniKit (`@worldcoin/create-mini-app`).
        *   Implement basic World ID verification flow (`MiniKit.commandsAsync.verify`).
        *   Basic UI shell: registration, placeholder dashboard.
        *   **Backend:** Endpoint to receive and (initially mock) validate World ID proof.
    3.  **Core Smart Contracts (Solidity - EVM Focus - Contracts Team - Parallel):**
        *   Choose primary EVM chain for initial deployment (e.g., Flow EVM, Polygon, or RSK if BTC focus is immediate).
        *   `UserRegistry.sol`: Simple registration linked to wallet address (and later World ID).
        *   `BasicLoan.sol`: Minimal loan functions (request, disburse mock funds, repay).
        *   `SimpleVouch.sol`: Minimal vouching (stake placeholder tokens).
        *   Deploy to chosen testnet.
    4.  **Basic Backend API (Backend Team - Parallel):**
        *   Endpoints for: user registration (linking wallet to World ID proof), basic loan interaction, basic vouch interaction (initially mock logic, connecting to contracts later).
        *   Python (Flask/FastAPI).
    5.  **Blockscout Integration (Easy Wins - Parallel/Any Team):**
        *   Identify Blockscout instance for chosen primary EVM chain.
        *   Ensure any early contract deployments are verified on Blockscout.
        *   Plan to use Blockscout links in UI later.
    6.  **Initial Documentation & Status Update:** Update `status.md`, basic tech docs.
*   **Deliverables:**
    *   Basic World App Mini App with World ID login.
    *   Core contracts deployed on one EVM testnet, verified on Blockscout.
    *   Basic backend capable of mock user registration and interactions.

## Sprint 1: First End-to-End Flow & Alternative Data PoC (4 Weeks)

*   **Goal:** Connect frontend to backend and smart contracts for a basic user flow. Implement PoC for one alternative data source.
*   **Key Bounties Targeted:** vLayer or Flare (one chosen for PoC), continuing World/Flow/Blockscout.
*   **Tasks:**
    1.  **Frontend-Backend-Contract Integration (Full Stack Flow):**
        *   Connect Mini App to backend for actual user registration (storing World ID validated status).
        *   Frontend calls backend, backend interacts with `UserRegistry.sol`.
        *   Basic loan request flow from frontend to `BasicLoan.sol` via backend.
    2.  **Alternative Data PoC - Choose ONE (Backend/Contracts Team - Parallel with UI work):
        *   **Option A: vLayer Email/Web Proof PoC:**
            *   Develop `OurProver.sol` & `OurDataVerifier.sol` for one simple case (e.g., prove ownership of a specific email via subject line, or presence of text on a public webpage).
            *   Backend guides user (mockup initially) to generate proof (simulated), calls `OurDataVerifier.sol`.
            *   **Target Bounty:** vLayer.
        *   **Option B: Flare Data Connector (FDC) PoC:**
            *   Develop `AlternativeDataFDC.sol` on Flare testnet.
            *   Request data from a public test API via `JsonApi` attestation.
            *   Backend triggers request, retrieves/verifies data from DA layer.
            *   **Target Bounty:** Flare FDC.
    3.  **AI Credit Scoring - Basic Stub (Backend Team):**
        *   Rudimentary Python script: `score = basic_logic(world_id_verified, alt_data_poc_verified)`.
        *   No Hedera yet.
    4.  **UI Enhancements (Frontend Team):**
        *   Display submitted/verified PoC alternative data.
        *   Display mock credit score.
*   **Deliverables:**
    *   User can register via World ID, see a mock score.
    *   PoC for one alternative data verification method (vLayer or Flare) integrated.
    *   Basic loan request flow functional (mock funds, simple logic).

## Sprint 2: Core Lending Logic & First Sponsor Integrations (4-6 Weeks)

*   **Goal:** Implement full micro-lending cycle, social vouching, and integrate key sponsor tech for data and oracles.
*   **Key Bounties Targeted:** Hedera AI, Pyth Price Feeds, Filecoin, continuing previous.
*   **Tasks:**
    1.  **Full Social Vouching (Contracts & Backend Teams - Parallel):**
        *   Enhance `SimpleVouch.sol` for actual staking/unstaking of ERC20s (e.g., a test stablecoin).
        *   Backend logic for managing vouch requests, status, stake amounts.
        *   UI for requesting and making vouches (Frontend Team).
    2.  **Full Micro-Loan Cycle (Contracts & Backend Teams - Parallel):**
        *   Enhance `BasicLoan.sol`: actual fund disbursal/repayment (using test ERC20s), interest (simple), LTV (if collateral).
        *   **Pyth Price Feed Integration:** If loans involve volatile collateral, integrate Pyth into `BasicLoan.sol` for price data. Backend/keeper to push `priceUpdateData`. (Targets Pyth bounty)
    3.  **AI Scoring with Hedera (Backend & Hedera Specialist - Parallel):**
        *   Python AI model refinement (still can be simple rules).
        *   Integrate HCS: Log AI inputs (hash of data) and output scores to HCS topic.
        *   (Optional) Hedera Smart Contract to attest AI model version or decision.
        *   (Targets Hedera AI bounty).
    4.  **Filecoin for User Data Storage PoC (Backend/Contracts Team - Parallel):**
        *   User uploads a document (mock sensitive data for PoC).
        *   Backend encrypts, prepares CAR file, calls `ClientContract.sol` (deployed on FVM) to make deal proposal.
        *   Store Deal ID/CID with user profile (on primary chain).
        *   (Targets Filecoin bounty).
    5.  **UI for Vouching, Loans, Data Upload (Frontend Team).**
*   **Deliverables:**
    *   Functional social vouching with test tokens.
    *   Micro-loans with test tokens, LTV checks (if using Pyth).
    *   AI scores logged to HCS.
    *   PoC for storing a user document hash on Filecoin.

## Sprint 3: Cross-Chain & Advanced Features (4-6 Weeks)

*   **Goal:** Implement cross-chain reputation and integrate more bounty features.
*   **Key Bounties Targeted:** LayerZero, Blockscout (SDK/Merits), 1inch API, Rootstock/Flare (if not primary).
*   **Tasks:**
    1.  **LayerZero Cross-Chain Reputation (Contracts & Backend Teams - Parallel):**
        *   Develop `ReputationOApp.sol`.
        *   Deploy on primary chain and at least one other EVM testnet.
        *   Backend triggers reputation updates across chains via LayerZero.
        *   (Targets LayerZero bounty).
    2.  **Blockscout Enhancements (Frontend/Backend - Parallel with other tasks):**
        *   Integrate Blockscout SDK for real-time transaction feedback in UI.
        *   If Merits API is usable, integrate for rewarding user actions.
        *   (Targets Blockscout SDK/Merits).
    3.  **1inch Token Swap Integration (Frontend/Backend - Parallel):**
        *   UI for users to select tokens and swap amounts.
        *   Backend/Frontend calls 1inch API for quotes and transaction data.
        *   (Targets 1inch API bounty).
    4.  **Expand to Secondary Chain/Tech (If applicable, e.g., Rootstock or Flare - Dedicated Teamlet):
        *   If Flow was primary, deploy contracts to Rootstock testnet, enable RBTC/RIF features.
        *   If another EVM was primary, deploy FDC contracts to Flare and integrate verified Web2 data flow.
        *   This depends on initial choices and team capacity.
    5.  **Refine AI Model & Explainability (Backend Team).**
    6.  **Comprehensive Testing & UI Polish (All Teams).**
*   **Deliverables:**
    *   Reputation score synchronized across at least two chains via LayerZero.
    *   Enhanced UI with Blockscout SDK feedback and 1inch swaps.
    *   (Potentially) Second alternative data source live (vLayer or FDC, whichever wasn't PoC).
    *   (Potentially) Platform functional on a second type of chain (e.g., Rootstock).

## Subsequent Sprints (High-Level)

*   **Security Audits & Optimization:** Formal audits for all core contracts. Gas optimization. Nitrolite (Yellow) state channels for micro-transactions if feasible.
*   **Mainnet Preparation & Launch:** Deploy to mainnets of chosen chains. Robust monitoring.
*   **Community Building & Governance:** DAO, governance token if planned.

## Parallel Work & Team Structure Notes:

*   **Frontend Team:** Can work largely in parallel on UI for World Mini App, dashboards, forms, once API specs are defined.
*   **Contracts Team (Solidity):** Focus on core EVM contracts, then LayerZero OApp, Filecoin ClientContract, vLayer/Flare Verifiers.
*   **Backend Team (Python/Node.js):** API development, AI model, integrations with HCS, Filecoin SDK, vLayer/Flare SDKs, Pyth data fetching, 1inch API calls.
*   **DevOps/Infra:** CI/CD, testnet deployments, FVM node access, keeper bots (for Pyth updates, etc.).
*   **Specialists:** Could have a dedicated person for Hedera, another for Filecoin/FVM, another for LayerZero during their respective integration sprints if complexity is high.

This plan is ambitious and assumes a well-coordinated team. Adjust timelines and task bundling based on actual resources and hackathon duration. 