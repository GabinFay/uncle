# Product Requirements Document: Decentralized Credit Recovery Platform (v3)

## 1. Introduction

This document outlines the product requirements for a decentralized credit recovery platform aimed at addressing financial exclusion in Brazil. The platform will leverage blockchain technology, alternative data sources, and a rich ecosystem of sponsor technologies to enable blacklisted individuals to rebuild their creditworthiness and access financial services. This version incorporates findings from a broader review of potential technology integrations.

## 2. Goals

*   Provide a transparent and accessible path to credit recovery.
*   Reduce reliance on traditional credit scoring by incorporating diverse alternative data (Web2 APIs via FDC/vLayer, on-chain activity) and social vouching.
*   Foster financial inclusion and empower users with a portable, global, and multi-chain credit history (via LayerZero).
*   Create a sustainable and scalable micro-loan ecosystem, potentially leveraging various EVM chains (Flow, RSK, Hedera, general EVM).
*   Offer a user-friendly experience, potentially as a World App Mini App.

## 3. Target Users

*   **Primary:** Brazilians blacklisted from the traditional financial system.
*   **Secondary:** Friends/family as Vouchers; ethical investors; users of sponsor platforms (e.g., World App users).

## 4. Core Features & Functionality

### 4.1. User Onboarding & Identity

*   **World ID Integration (Primary):** Users prove unique personhood via World ID (Orb scan) as a World App Mini App or standalone app. (Targets World Mini App bounty)
*   **Profile Creation:** Basic profile, progressively enhanced with verified data.

### 4.2. Alternative Data Integration & Verification

*   **Verifiable Credentials (VCs) & Direct Web2 Data:**
    *   **vLayer Integration:** Use vLayer Email Proofs (employment, communications) and Web Proofs (utility payments, online activity) with Prover/Verifier contracts. (Targets vLayer bounties)
    *   **Flare Data Connector (FDC):** Use FDC to fetch data from Web2 APIs (utility bills, gig economy earnings) via `JsonApi` attestation, verified on Flare. (Targets Flare FDC bounty)
    *   Users submit data/proofs; platform initiates verification.
*   **Data Storage & Sovereignty:** Encrypted user data stored via Filecoin (on-chain deals via FVM `ClientContract.sol`). User controls access. (Targets Filecoin bounty)

### 4.3. Social Vouching System

*   **Vouching Mechanism:** Users (verified by World ID) request Vouchers (friends, family, community members, also verified by World ID) to stake tokens (e.g., stablecoins, RBTC on Rootstock, RIF, or platform native token if any) on their behalf as a form of social collateral. These vouching relationships and stakes will be recorded and managed within the platform's dedicated smart contracts (e.g., `SocialVouching.sol`). There is no reliance on external, pre-existing on-chain social graph protocols integrated with Worldcoin; the social connections for vouching are formed and managed endogenously within our application.
*   **Voucher Risk/Reward:** Vouchers share a small portion of the risk (loss of stake on default) but can also earn a return or reputation boost if the loanee repays successfully.
*   **Reputation Impact:** Successful vouches and repayments positively impact both the loanee's and the voucher's reputation score within the platform.

### 4.4. AI-Powered Credit Risk Assessment

*   **AI Engine (Off-chain Python, On-chain Attestation):**
    *   Analyzes: Verified alternative data (vLayer, FDC), social vouching, platform history, potentially on-chain transaction history via Blockscout APIs.
    *   **Hedera Integration:** Log AI model inputs/outputs to Hedera Consensus Service (HCS) for auditability. Attest AI decisions/model versions via Hedera Smart Contracts. (Targets Hedera AI bounty)
*   **Transparency:** Provide insights into score determination.

### 4.5. Graduated Micro-Lending

*   **Loan Origination:** Based on AI score and vouches.
*   **Multi-Chain Smart Contracts:** Core loan logic ( Solidity) deployed on a primary EVM chain (e.g., Flow EVM for consumer focus, or Rootstock for BTC ecosystem integration, or a general-purpose EVM like Polygon/Arbitrum). (Targets Flow Killer App / Rootstock bounties)
*   **Collateral & Repayment:** Support for stablecoins, potentially RBTC (on Rootstock), or other tokens. Use Pyth Price Feeds for valuing volatile collateral. (Targets Pyth Price Feeds bounty)
*   **Token Swaps:** Integrate 1inch API for users to swap tokens for collateral, staking, or repayment. (Targets 1inch API bounty)
*   **Progressive Lending:** Build track record for larger loans.

### 4.6. Cross-Chain Reputation & Platform Interaction

*   **LayerZero Integration:** User reputation (score, history) made portable across multiple EVM chains using LayerZero OApp pattern. (Targets LayerZero bounties)
*   **Blockscout Integration:**
    *   Use Blockscout as the primary explorer for all on-chain links.
    *   Verify all contracts on Blockscout.
    *   Optionally use Blockscout SDK for real-time tx feedback in-app.
    *   Optionally use Blockscout Merits API for rewarding positive user actions. (Targets Blockscout bounties)

### 4.7. Frontend Application

*   **Primary Interface:** World App Mini App (React/Next.js based) for seamless integration with World ID and World Chain users. (Targets World Mini App bounty)
*   **Alternative Interface:** Standard web app (React/Next.js) for broader accessibility.
*   **User Dashboard:** Score, loan status, vouching, data management, Blockscout transaction views, 1inch swap interface.

## 5. Technical Stack (Expanded Proposal)

*   **Smart Contracts:** Solidity.
    *   **Primary Logic Chains:** Flow EVM, Rootstock, Hedera (for specific services), or general EVM (Polygon, Arbitrum, BNB Chain).
    *   **FVM:** For Filecoin `ClientContract.sol`.
    *   **Flare:** For FDC `AlternativeDataFDC.sol`.
*   **Frontend:** React/Next.js (as World App Mini App and/or standalone).
*   **Identity:** World ID (MiniKit SDK).
*   **Alternative Data Verification:** vLayer (Prover/Verifier contracts, SDK), Flare Data Connector.
*   **AI Credit Scoring:** Python backend, Hedera Consensus Service, Hedera Smart Contracts.
*   **Decentralized Storage:** Filecoin (FVM, client-side encryption).
*   **Cross-Chain Communication:** LayerZero (OApp).
*   **Oracles:** Pyth Price Feeds (Pull Oracle), Flare Time Series Oracle (FTSO if on Flare).
*   **Token Swaps:** 1inch API.
*   **Blockchain Interaction/Exploration:** Blockscout (APIs, SDK, explorer links).
*   **Supporting Infrastructure:** Node providers, indexing services.

## 6. Success Metrics (Unchanged)

*   Active users, loan volume, repayment rates, vouching activity, user satisfaction, partnerships.

## 7. Future Considerations (Expanded)

*   Fiat on/off ramps.
*   Expansion to other regions.
*   More sophisticated AI/ML.
*   Gamification (Blockscout Merits, platform-specific rewards).
*   Governance token/DAO.
*   State channel optimizations (Nitrolite/Yellow) for micro-transactions.
*   Deeper integration with specific DeFi ecosystems (e.g., Beraborrow if strategy shifts to include Berachain CDPs).

## 8. Open Questions & Risks (Updated for new tech)

*   Regulatory landscape (crypto, financial, data privacy across multiple jurisdictions).
*   User adoption and digital literacy.
*   Scalability and accessibility of World ID Orb scanning.
*   Data quality and reliability from Web2 APIs via FDC/vLayer.
*   Security of multi-chain smart contract architecture and bridges/messaging (LayerZero).
*   Complexity of managing deployments and interactions across multiple chains/services (Flow, Hedera, FVM, Flare, Rootstock, etc.).
*   Cost and performance of Filecoin, Pyth, LayerZero, and other paid services.
*   Orchestration of off-chain (Python AI, backend logic) and on-chain components. 