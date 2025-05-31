# Sprint Plan: Decentralized Credit Recovery

## Guiding Principles:

*   **Iterative Development:** Start with the simplest viable product and add features incrementally.
*   **Targeted Bounties:** Each sprint or combination of sprints should aim to fulfill the requirements of specific hackathon bounties.
*   **Rapid Prototyping (Frontend):** Use Streamlit for initial frontend development to quickly build and test user flows with smart contracts. A more polished React/Next.js frontend can be developed later if time permits or for a post-hackathon version.
*   **Test-Driven (Simulated):** While full TDD might be slow for a hackathon, each feature should have clear test criteria (logged events, UI state changes, contract state changes).

## Sprint Breakdown:

### Sprint 0: Foundation & MVP - Basic Lending & Reputation (Target: 1-2 days)
*   **Goal:** Create the absolute simplest version of a lending pool and on-chain reputation. Qualify for a basic DeFi/usability bounty (e.g., Flow Killer App if focused on ease of use, or a generic EVM bounty).
*   **Core Features:**
    *   Smart Contracts (Solidity on a testnet like Sepolia or local Hardhat/Foundry):
        *   LendingPool.sol: `deposit()`, `borrow()`, `repay()`. Fixed interest for simplicity. Minimal safety checks for MVP.
        *   Reputation.sol: Mint a simple reputation token (ERC721 or just an on-chain counter) upon successful loan repayment.
    *   Frontend (Streamlit):
        *   Wallet connection (MetaMask).
        *   Display user balance.
        *   UI to call `deposit()`, `borrow()`, `repay()`.
        *   Display basic reputation score/token.
*   **Tech Stack Focus:** Solidity, Streamlit, Web3.py/ethers.js (via Streamlit components or backend logic).
*   **Testing:** Manual E2E flow: connect, deposit, borrow, repay, check reputation. Log contract interactions.
*   **Bounty Focus:** Aim for bounties rewarding functional dApps, smart contract deployment, or user interaction with DeFi primitives. (Example: Flow Killer App - focusing on a smooth, simple user experience even with basic features).

### Sprint 1: Social Vouching (Target: +1-2 days)
*   **Goal:** Integrate a basic social vouching mechanism.
*   **Core Features:**
    *   Smart Contracts:
        *   Extend/add Vouching.sol: `addVouch()`, `removeVouch()`. Vouchers lock collateral (e.g., the pool's native token or stablecoin).
        *   Modify LendingPool.sol: Borrowing power influenced by vouched amount.
    *   Frontend:
        *   UI for users to see vouches, request vouches.
        *   UI for vouchers to stake for others.
*   **Testing:** Vouching affects borrowing capacity. Log events.
*   **Bounty Focus:** Could enhance appeal for general dApp bounties or those focused on novel economic mechanisms.

### Sprint 2: Alternative Data Input & Simplified Scoring (Target: +1 day)
*   **Goal:** Simulate alternative data input and a very basic off-chain scoring influencing on-chain actions. This sprint focuses on the *concept* for bounties like vlayer or Hedera AI, without full backend complexity yet.
*   **Core Features:**
    *   Backend (Python script callable by Streamlit):
        *   Simulate receiving data (e.g., a mock vlayer proof, user uploads a dummy doc for "employment").
        *   Extremely simple scoring: `if data_received: score_boost = X`.
    *   Smart Contracts:
        *   Oracle/Admin function in Reputation.sol or LendingPool.sol to update a user's score component based on this "off-chain" signal.
    *   Frontend:
        *   UI to simulate data submission.
        *   Display updated score and its impact (e.g., better loan terms).
*   **Testing:** Submitting (mock) data changes the on-chain accessible score and loan conditions.
*   **Bounty Focus:** vlayer (showcasing intent to use alternative data), Hedera AI (showcasing intent for AI-driven scoring, even if AI is basic/simulated initially).

### Sprint 3: World ID Integration (Target: +1 day)
*   **Goal:** Add Sybil resistance using World ID.
*   **Core Features:**
    *   Frontend/Backend:
        *   Integrate World ID SDK for verification.
    *   Smart Contracts:
        *   Store/link verification status on-chain (e.g., in Reputation.sol).
        *   Potentially gate certain features based on verification.
*   **Testing:** User can verify with World ID; status reflected and potentially used by contracts.
*   **Bounty Focus:** World Mini App.

### Sprint 4: Basic Cross-Chain Reputation (Conceptual) (Target: +1 day)
*   **Goal:** Demonstrate the concept of a portable reputation using LayerZero (or similar).
*   **Core Features:**
    *   Smart Contracts:
        *   Simple contract on two testnets (e.g., Sepolia and Polygon Mumbai).
        *   Use LayerZero (or a mock) to send a message updating reputation from one chain to another.
    *   Frontend/Tooling:
        *   Scripts or minimal UI to trigger the cross-chain update and verify.
*   **Testing:** Reputation change on chain A is reflected on chain B.
*   **Bounty Focus:** LayerZero.

### Sprint 5: User Data Sovereignty (Conceptual) (Target: +0.5 day)
*   **Goal:** Show intent for user data control using Filecoin/IPFS.
*   **Core Features:**
    *   Backend/Tooling:
        *   Script to upload a dummy file to IPFS (via a gateway or local node) and get its CID.
        *   Conceptually, this CID could be linked to the user's on-chain profile.
*   **Testing:** File uploaded to IPFS, CID retrieved.
*   **Bounty Focus:** Filecoin.

## Post-Hackathon / Advanced Features (If time allows or for future development):
*   Full AI/ML model for credit scoring.
*   More sophisticated lending pool mechanics (variable interest, collateralization ratios).
*   DAO for governance.
*   Mobile-native React/Next.js frontend.
*   Formal security audits.

This SPRINT_PLAN.md provides a roadmap. We will update `status.md` as we complete tasks within each sprint. 