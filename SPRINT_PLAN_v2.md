# SPRINT_PLAN_v2.md

This document outlines the initial sprints for developing the Decentralized Credit Recovery Platform.

## Sprint 0: Foundation & Core Logic (Proof of Concept)

*   **Goal:** Build a minimal viable PoC focusing on core backend logic and smart contracts.
*   **Duration:** 4 Weeks
*   **Tasks:**
    1.  **Project Setup:** Git repo, basic folder structure, CI/CD pipeline (basic).
    2.  **Smart Contract Development (Initial - EVM):**
        *   User registration (simple, address-based for PoC).
        *   Basic social vouching contract (stake tokens, link to vouchee).
        *   Simple loan contract (disburse, repay functionality).
        *   Test on a local development network (e.g., Hardhat/Foundry).
    3.  **Alternative Data - Conceptualization:**
        *   Research and define initial simple methods for users to submit employment/payment data (e.g., self-attestation for PoC).
        *   Design data structures for storing this information off-chain (initially, a simple database or even JSON files for PoC).
    4.  **AI Credit Scoring - Basic Model:**
        *   Develop a rudimentary Python script that takes mock user data (self-attested info, vouching info) and outputs a simple risk score.
        *   No Hedera integration at this stage; focus on the scoring logic itself.
    5.  **Backend API (Minimal):**
        *   Develop simple API endpoints (e.g., using Flask/FastAPI) to:
            *   Interact with smart contracts (register user, initiate vouch, request loan).
            *   Submit alternative data.
            *   Get a credit score from the basic AI model.
    6.  **World ID - Research & Mock Integration:**
        *   Thoroughly research World ID SDK and integration process.
        *   Create a mock integration point in the backend (simulate receiving a World ID proof).
    7.  **Testing:** Basic unit tests for smart contracts and backend logic.
    8.  **Documentation:** Initial technical documentation for PoC components.
*   **Deliverables:**
    *   Functioning smart contracts for user registration, vouching, and loans on a testnet.
    *   Basic backend API to interact with contracts and a rudimentary credit scoring model.
    *   Documentation of the PoC architecture and components.

## Sprint 1: Frontend, World ID & Basic Data Flow

*   **Goal:** Develop a basic frontend, integrate World ID, and establish an end-to-end flow for user onboarding and data submission.
*   **Duration:** 4 Weeks
*   **Tasks:**
    1.  **Frontend Development (React/Next.js - Basic UI):**
        *   User registration/login flow (integrating with World ID).
        *   Dashboard to display user status (mock score, loan eligibility).
        *   Form to submit basic alternative data (as defined in Sprint 0).
        *   Interface to request a vouch.
    2.  **World ID Integration (Actual):**
        *   Integrate World ID SDK into the frontend and backend for actual user verification.
    3.  **Backend Enhancements:**
        *   Connect backend to actual World ID verification.
        *   Store submitted alternative data (linked to World ID verified user).
        *   Refine API endpoints for frontend consumption.
    4.  **Smart Contract Refinements:** Minor adjustments based on frontend needs.
    5.  **Basic Data Flow Testing:** Test user onboarding with World ID, alternative data submission, and mock score display.
*   **Deliverables:**
    *   Web application with World ID-based user registration.
    *   Users can submit basic alternative data.
    *   A basic dashboard displaying user information.

## Sprint 2: Social Vouching & Micro-Loan Alpha

*   **Goal:** Implement the social vouching mechanism fully and enable the first micro-loans on a testnet.
*   **Duration:** 4 Weeks
*   **Tasks:**
    1.  **Frontend - Social Vouching UI:**
        *   Interface for users to request vouches from others (e.g., by sharing a link or inviting via platform ID).
        *   Interface for Vouchers to see requests, stake tokens, and manage their vouches.
    2.  **Backend - Social Vouching Logic:**
        *   Manage vouching requests and status.
        *   Integrate with smart contracts for staking and un-staking by Vouchers.
    3.  **AI Credit Scoring - Vouching Integration:**
        *   Incorporate social vouching data (number of Vouchers, total stake, Vouchers' reputation if available) into the credit scoring model.
    4.  **Smart Contracts - Loan Cycle:**
        *   Implement full loan cycle: application (based on score), approval (can be auto for PoC based on threshold), disbursal, repayment, default handling (basic).
    5.  **Frontend - Loan Application & Management:**
        *   Interface to apply for a loan (if eligible).
        *   Display loan terms, status, and repayment schedule.
    6.  **Testnet Deployment & Alpha Testing:**
        *   Deploy all components to a public testnet.
        *   Conduct internal alpha testing of the complete vouching and micro-loan flow.
*   **Deliverables:**
    *   Functional social vouching system (request, stake, manage).
    *   Users can apply for and receive micro-loans on a testnet, based on their score (which includes vouching data).
    *   Repayment functionality.

## Subsequent Sprints (High-Level Themes)

*   **Sprint 3: Hedera Integration & Advanced AI Scoring:**
    *   Explore migrating parts of the logic or data logging to Hedera (HCS, Smart Contracts).
    *   Develop a more sophisticated AI model for credit risk.
    *   Integrate explainable AI features.
*   **Sprint 4: Verifiable Credentials & Filecoin:**
    *   Implement a PoC for Verifiable Credentials for employment/payment data.
    *   Integrate Filecoin for user-controlled data storage (PoC).
*   **Sprint 5: LayerZero & Cross-Chain Reputation PoC:**
    *   Develop a PoC for making user reputation (score, history) portable using LayerZero.
*   **Sprint 6: Security Audits, UX Refinements & Mainnet Prep:**
    *   Conduct security audits of smart contracts.
    *   Refine UI/UX based on feedback.
    *   Prepare for a potential mainnet launch (beta).

## Testing Strategy (General)

*   **Unit Tests:** For smart contracts (Foundry/Hardhat), backend modules (pytest), frontend components (Jest/React Testing Library).
*   **Integration Tests:** Test interactions between frontend, backend, and smart contracts.
*   **End-to-End Tests:** Simulate user flows (e.g., using Cypress or Playwright).
*   **Logging & Monitoring:** Implement comprehensive logging. For testing, logs will be reviewed to ensure coherence and identify bugs. The `status.md` file will track test descriptions and outcomes for each feature.

## Git Strategy

*   **Main Branch:** Always stable and deployable (after rigorous testing).
*   **Feature Branches:** All new development occurs on feature branches (e.g., `feature/world-id-integration`, `feature/social-vouching`).
*   **Pull Requests (PRs):** Code reviews and automated checks (linters, tests) on PRs before merging to `develop` (or an integration branch) and then to `main`.
*   **Tagging:** Tag main branch commits for significant milestones/releases (e.g., `v0.1.0-alpha`, `v0.2.0-beta`). `status.md` will not be committed (.gitignored). 