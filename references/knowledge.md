# Knowledge Base

This document will store findings from research and analysis. 

## Research Findings

### Financial Inclusion in Brazil

*   **Current State:** Significant progress with ~84% of adults having bank accounts (up from 56% in 2011), largely due to initiatives like Pix.
*   **Remaining Challenges:**
    *   ~34 million unbanked/underbanked (21% of adults). 16.3M no account, 17.7M inactive accounts.
    *   **Financial Literacy:** Lack of knowledge to use financial products effectively.
    *   **Over-Indebtedness:** Rapid credit expansion led to unsustainable debt for many (84.7M with unpaid credit card debt in 2023).
    *   **Digital Divide:** Older adults and remote populations have less access to digital financial services.
    *   **Income Inequality:** Significant wealth disparity impacts access for lower-income individuals.

### Existing DeFi/Crypto Credit Projects

*   **Brazil:**
    *   **Moeda (MDA):** Microloans and banking for underserved communities (partnered with MasterCard).
    *   **impactMarket:** Microcredit pilot in Favela do Coroadinho.
    *   **Quipu Market:** Online platform for Latin American entrepreneurs, offering loans based on digitized business activity.
*   **Global:**
    *   **Celo:** Mobile-first blockchain for financial inclusion, local stablecoins.
    *   **Kiva Protocol:** Blockchain-based identity and credit history in Sierra Leone.
    *   **EthicHub:** P2P lending for small farmers.
*   **Common Models:** Blockchain-based, smart contracts for automation, digital identity, transaction history for creditworthiness.
*   **Common Challenges:**
    *   Regulatory hurdles.
    *   Technological barriers (internet access, digital literacy).
    *   Scalability and financing.

### Technology Deep Dive

*   **World ID (Worldcoin):**
    *   **Purpose:** Sybil resistance through proof-of-personhood (biometric Orb scan).
    *   **Mechanism:** Decentralized identity verification, zero-knowledge proofs to protect privacy.
    *   **Benefits for Credit Platform:** Ensures unique users, reduces fraud, enhances trust.
    *   **Limitations:** Scalability of Orb deployment, potential user intrusiveness, economic barriers to access Orb.
*   **"vLayer" (assumed to be Verifiable Credentials - VCs):**
    *   **Purpose:** Verifying employment and payment data.
    *   **Mechanism:** Digital attestations from trusted authorities, cryptographically signed. Verifier confirms info without direct issuer contact.
    *   **Technical Requirements:** Digital identity infrastructure, crypto standards, interoperability, data privacy compliance (GDPR, FCRA), user interface for credential management.
    *   **Challenges:** Data quality/accuracy, model performance/explainability when integrating into scoring, customer adoption, regulatory compliance.
*   **Hedera AI for Credit Risk:**
    *   **Purpose:** AI-driven credit risk assessment.
    *   **Mechanism:** Machine learning models on Hedera network.
    *   **Hedera Services:**
        *   **Hedera Consensus Service (HCS):** Decentralized, tamper-proof log for data integrity in AI models, real-time data recording.
        *   **Smart Contracts:** Automate loan agreements and risk assessment.
        *   **Tokenization & Digital ID:** Verifiable borrower profiles.
    *   **Example:** Sirio Finance uses ML with HCS to predict liquidations.
*   **Filecoin for User Data Sovereignty:**
    *   **Purpose:** Decentralized storage for user data.
    *   **Benefits:**
        *   **Data Sovereignty/Security:** Decentralized (no single point of failure), cryptographic proofs (PoRep, PoSt) for data integrity.
        *   **Cost Efficiency:** Competitive storage market.
        *   **Censorship Resistance:** Distributed network.
    *   **Drawbacks:**
        *   **Privacy:** Data not inherently private on Filecoin; requires client-side encryption. Miners announce hosted content.
        *   **Data Permanence:** Storage is "rented"; requires ongoing payment.
        *   **Technical Complexity:** Integration can be challenging.
        *   **Retrieval Speeds:** Can be slower than centralized storage.
        *   **Market Volatility:** Storage costs (FIL token) can fluctuate.
*   **LayerZero for Cross-Chain Reputation:**
    *   **Purpose:** Enable secure communication and data aggregation across multiple blockchains for a comprehensive reputation.
    *   **Technical Mechanisms:**
        *   **Immutable Endpoints:** Smart contracts on each chain for secure message transmission.
        *   **Decentralized Verifier Networks (DVNs):** Independent verifiers authenticate cross-chain messages.
        *   **CryptoEconomic Security:** Verifiers stake assets (slashed for misbehavior).
        *   **Configurable Security:** Apps can define their own security parameters.
    *   **Security Considerations:**
        *   **Verifier Collusion:** Mitigated by staking/slashing.
        *   **Smart Contract Vulnerabilities:** Require audits and testing.
        *   **Oracle/Relayer Risks:** Compromise could disrupt messaging.
        *   **Economic Attacks:** Potential manipulation of staking/slashing.

## Detailed Bounty Integration Strategies

### 1. World Mini App (Worldcoin)

*   **Bounty Goal:** Best Mini App using MiniKit SDK, deployed to World Chain, with World ID proof validation.
*   **Project Integration:** Our entire frontend can be a World App Mini App. User onboarding (4.1) will heavily rely on World ID via MiniKit.
*   **Technical Steps & Insights:**
    1.  **Scaffold App:** Use `npx @worldcoin/create-mini-app@latest`.
    2.  **MiniKit SDK:** Install `@worldcoin/minikit-js`. Wrap root component with `MiniKitProvider`.
    3.  **World ID Verification:** Use `MiniKit.commandsAsync.verify({ action: 'our_credit_app_action', signal: 'user_specific_data_hash', verification_level: 'orb' })` in the frontend.
        *   `our_credit_app_action` needs to be defined in the Worldcoin Developer Portal.
        *   `signal` can be a hash of user-provided data or a session identifier to prevent replay attacks.
    4.  **Proof Validation (Backend/Smart Contract):** The proof received from `verify` command needs to be sent to our backend. The backend will then verify this proof against Worldcoin's servers (or by interacting with a World ID verifier smart contract if available and suitable).
    5.  **World Chain Deployment:** If core smart contract logic (e.g., loan origination, reputation updates specific to World App users) is tied directly to the Mini App experience, these contracts should be deployed on World Chain. Other contracts (e.g., generic lending pools) might reside on other EVM chains.
    6.  **Testing:** Use `pnpm dev` for local testing and `ngrok` for mobile testing within the World App.

### 2. Flow Killer App (Flow Foundation)

*   **Bounty Goal:** Consumer-oriented app, deploy contracts/run transactions on Flow.
*   **Project Integration:** The platform's core smart contracts (lending pools, reputation, social vouching - section 4.5) can be deployed on Flow EVM. The Next.js frontend (4.7) will interact with these.
*   **Technical Steps & Insights:**
    1.  **Environment:** Flow CLI, Go, Node.js. Overflow (Go tool for Flow interaction) might be useful.
    2.  **Contracts:** Develop Solidity contracts as planned.
    3.  **Deployment:** Deploy compiled Solidity bytecode to Flow EVM. This involves creating a Cadence Owned Account (COA) on Flow and using Cadence transactions to deploy. The Flow Developer Portal has guides.
    4.  **Frontend Interaction (FCL):** Use the Flow Client Library (FCL) in our Next.js app to:
        *   Authenticate users with Flow wallets (e.g., Blocto, Lilico).
        *   Send transactions to and call view functions on our Solidity contracts deployed on Flow EVM.
    5.  **Flow EVM Considerations:** Understand any nuances of Flow EVM vs. standard EVM (gas model, precompiles, etc.).

### 3. vLayer Most Inspiring (vLayer Labs)

*   **Bounty Goal:** dApp using vLayer verifiable data (Email/Web Proofs, Time Travel, Teleport) with Prover and Verifier contracts.
*   **Project Integration:** Alternative Data Verification (4.2) using Email Proofs for employment/communication and Web Proofs for utility payments/online activity.
*   **Technical Steps & Insights:**
    1.  **Contracts:** Create `OurProver.sol` (inherits `vlayer-0.1.0/Prover.sol`) and `OurDataVerifier.sol` (inherits `vlayer-0.1.0/Verifier.sol`).
    2.  **Email Proofs in `OurProver.sol`:**
        *   Function like `verifyEmploymentEmail(UnverifiedEmail calldata email)`.
        *   Uses `email.verify()` from `EmailProofLib`.
        *   Returns `(proof(), email.from)` or other extracted data.
        *   Users might forward specific emails or connect accounts for vLayer to process.
    3.  **Web Proofs in `OurProver.sol`:**
        *   Function like `verifyUtilityBill(WebProof calldata webProof, string calldata expectedUrlPattern)`.
        *   Uses `webProof.verify(expectedUrlPattern)` from `WebProofLib`.
        *   Extracts relevant data using `web.jsonGetString("key")`.
        *   Users provide URLs to relevant pages (e.g., utility payment history if structure is parsable by vLayer).
    4.  **Verifier Contract `OurDataVerifier.sol`:**
        *   Function `validateDataProof(Proof calldata proof, bytes calldata relevantDataFromProver)`.
        *   Uses `onlyVerified(PROVER_CONTRACT_ADDRESS, PROVER_FUNCTION_SELECTOR)` modifier.
        *   On successful verification, this contract (or our backend triggered by an event from this contract) updates the user's credit profile on our primary chain.
    5.  **Off-chain Interaction:** Our backend will guide users to generate these proofs via vLayer's SDK/tools and then submit the generated `Proof` and `relevantDataFromProver` to `OurDataVerifier.sol`.

### 4. Hedera AI (Hedera)

*   **Bounty Goal:** Combine AI/ML with Hedera services (HCS, Smart Contracts, Token Service).
*   **Project Integration:** AI-Powered Credit Risk Assessment (4.4).
*   **Technical Steps & Insights:**
    1.  **HCS for AI Audit Trail:**
        *   Set up Hedera JS SDK (`@hashgraph/sdk`).
        *   Create an HCS Topic ID for our credit scoring model logs.
        *   Our Python AI backend, after calculating a score, will submit a message to this HCS topic containing:
            *   User identifier (e.g., anonymized ID or on-chain address).
            *   Hash of input data used for scoring (VCs, vouching info, loan history summary).
            *   The credit score generated.
            *   Timestamp, AI model version.
        *   This creates an immutable, verifiable log of scoring events.
    2.  **Hedera Smart Contracts for Decision Attestation/Logic:**
        *   Deploy a Solidity smart contract (`CreditDecisionContract.sol`) on Hedera.
        *   This contract could have a function `recordCreditDecision(userId, score, decisionDetails)` callable by our backend (owner/admin controlled).
        *   The decision (e.g., loan approved, limit set) becomes an on-chain event on Hedera.
        *   Simpler, deterministic rules (e.g., score thresholds for loan tiers) could be implemented directly in this smart contract, reading from HCS logs or other on-chain data if feasible.
    3.  **Hedera Token Service (HTS):** If reputation or loan shares are tokenized, HTS could be used to create and manage these tokens on Hedera.

### 5. Filecoin - Build Fair Data Economy (Protocol Labs)

*   **Bounty Goal:** Store data on Filecoin via on-chain storage deals (not just IPFS). FVM or EVM L2s bridging to Filecoin.
*   **Project Integration:** Decentralized storage for user-controlled alternative data (4.2).
*   **Technical Steps & Insights:**
    1.  **Environment:** Use FVM deal-making starter kit or FEVM Hardhat/Foundry kits.
    2.  **Client Contract:** Deploy `ClientContract.sol` (from starter kit) on FVM (e.g., Calibration testnet or mainnet).
    3.  **Data Preparation (Backend):**
        *   User uploads data (e.g., encrypted VCs, documents) to our backend.
        *   Backend encrypts data (if not already client-side encrypted).
        *   Backend converts encrypted data to `.car` format using tools like FVM Data Depot or libraries, obtaining Piece CID, Payload CID, CAR size, Piece size, CAR file URL.
    4.  **Proposing Deal (Backend):**
        *   Backend (with FVM wallet/private key) calls `makeDealProposal` on our deployed `ClientContract.sol` using the metadata from step 3.
        *   Parameters include piece CID, size, CAR URL, deal duration (start/end epoch), etc.
    5.  **Linking to User Profile:** Once a deal is active, the Filecoin Deal ID and relevant CIDs can be stored in our platform's main user profile contract (on Flow EVM or other primary chain) as a pointer to the user's sovereign data.
    6.  **Access Control:** Users grant access to their data (e.g., by sharing decryption keys for specific data with the platform or AI model when needed).

### 6. LayerZero (lzRead, Composability, or General Prize)

*   **Bounty Goal:** Cross-chain data query (lzRead), multi-step workflows (Composability), or general omnichain app (OApp, OFT, ONFT).
*   **Project Integration:** Cross-Chain Reputation (4.6).
*   **Technical Steps & Insights (Focusing on OApp for state sync):**
    1.  **OApp Contract:** Create `ReputationOApp.sol` inheriting from LayerZero V2's OApp standards.
        *   It will store a mapping `(userId => reputationScore)` or similar structure.
        *   Include a function `updateReputation(userId, newScore, targetChainEid)` callable on the source chain.
        *   Implement `_lzReceive(originEid, originAddress, messageNonce, payload)` to process incoming reputation updates.
    2.  **Deployment:** Deploy `ReputationOApp.sol` on our primary chain (e.g., Flow EVM) and on other target EVM chains where we want the reputation to be accessible (e.g., Ethereum, Polygon).
    3.  **Set Peers:** After deployment, call `setPeer(destinationEid, peerContractAddress)` on each OApp instance to link them together.
    4.  **Sending Updates:** When a user's reputation changes on the primary chain:
        *   Our backend (or a keeper) calls `updateReputation` on the primary chain's `ReputationOApp.sol`.
        *   This function constructs a `payload` (e.g., ABI encoded `userId` and `newScore`) and uses LayerZero's endpoint to send this message to the specified `targetChainEid`.
        *   Fees for LayerZero messaging need to be handled (paid by user or platform).
    5.  **Receiving Updates:** The `_lzReceive` function on the target chain's `ReputationOApp.sol` decodes the payload and updates the local reputation score mapping.
    6.  **Read Access:** Other dApps on any of the connected chains can then read the user's reputation score directly from the local `ReputationOApp.sol` instance on their chain.

### 7. Blockscout

*   **Bounty Goals:** Use APIs/SDK for data/feedback, Merits API for rewards, set as primary explorer.
*   **Project Integration:** Admin/user dashboards for transaction details, real-time feedback on loan ops, potential gamification with Merits, easy win by linking to Blockscout.
*   **Technical Steps & Insights:**
    1.  **Primary Explorer & Verification:** Update all dApp links to point to Blockscout for the relevant chain. Verify all deployed smart contracts on Blockscout instances. (Easiest win for "Big Blockscout Explorer Pool Prize").
    2.  **REST/GraphQL APIs:** Use Blockscout's APIs (e.g., `https://<chain_name>.blockscout.com/api?module=account&action=txlist&address={addressHash}`) to fetch transaction history for users or specific contracts. This can populate an advanced transaction view in user dashboards or an admin panel.
    3.  **SDK (`@settlemint/sdk-blockscout`):** Can be used in the frontend to provide real-time feedback on transaction status (e.g., loan disbursement, repayment confirmation) by querying transaction details via the SDK.
    4.  **Merits API:** If the specific API for Merits is available/documented for the hackathon, integrate it to award points for: 
        *   Timely loan repayments.
        *   Successful vouches that lead to repayment.
        *   Platform engagement (e.g., completing profile, educational modules if added).
        *   Backend would call Merits API upon these events.

### 8. 1inch

*   **Bounty Goal (Most Relevant):** Utilize 1inch APIs (swap or data).
*   **Project Integration:** Facilitate token swaps within the dApp if users need specific tokens for staking, collateral, or repayment.
*   **Technical Steps & Insights (Swap API):**
    1.  **API Key:** Register at 1inch Developer Portal for an API key.
    2.  **Get Quote:** Backend or frontend calls `https://api.1inch.io/v4.0/<chain_id>/quote?fromTokenAddress=...&toTokenAddress=...&amount=...` (with API key) to get swap details.
    3.  **Build Transaction:** Backend or frontend calls `https://api.1inch.io/v4.0/<chain_id>/swap?fromTokenAddress=...` with quote parameters to get unsigned transaction data.
    4.  **Execute Swap:** User signs and sends the transaction data via their wallet (e.g., MetaMask interaction from frontend).
    5.  **Use Cases:** Swapping to a required stablecoin for loan repayment, swapping to the platform's native token for staking/vouching if applicable, acquiring diverse collateral types.

### 9. Pyth Network

*   **Bounty Goal (Most Relevant):** Most Innovative use of Pyth pull oracle (Price Feeds).
*   **Project Integration:** Provide reliable price feeds for valuing collateral, LTV calculations, and liquidations if dealing with multiple or volatile assets.
*   **Technical Steps & Insights (Pull Oracle):**
    1.  **Install SDK:** `npm install @pythnetwork/pyth-sdk-solidity`.
    2.  **Smart Contract (`LoanContract.sol`, `VouchingContract.sol`):**
        *   Import `IPyth.sol` and `PythStructs.sol`.
        *   Store Pyth contract address: `IPyth pyth = IPyth(PYTH_CONTRACT_ADDRESS_ON_CHAIN);`
        *   Function `updateAndGetPrice(bytes32 priceId, bytes[] calldata priceUpdateData)`:
            *   `uint fee = pyth.getUpdateFee(priceUpdateData);`
            *   `pyth.updatePriceFeeds{value: fee}(priceUpdateData);`
            *   `return pyth.getPrice(priceId);`
    3.  **Backend/Keeper:**
        *   Periodically or on-demand, fetch `priceUpdateData` from Pyth's off-chain service (Hermes API) for relevant `priceId`s (e.g., ETH/USD, collateralToken/USD).
        *   Call `updateAndGetPrice` on our smart contract, passing the fetched `priceUpdateData`.
    4.  **Usage in Contracts:** When calculating LTV, checking liquidation thresholds, or valuing stakes, our contracts call `pyth.getPrice(priceId)` (assuming a recent update was pushed by the backend/keeper, or use the combined `updateAndGetPrice`).

### 10. Flare Network

*   **Bounty Goal (Most Relevant):** Use FDC (Flare Data Connector) for Web2 data, or FTSO for price feeds.
*   **Project Integration:** FDC for alternative data (employment, utility bills from Web2 APIs). FTSO as an alternative price oracle if on Flare.
*   **Technical Steps & Insights (FDC with `JsonApi`):**
    1.  **Smart Contract on Flare (`AlternativeDataFDC.sol`):**
        *   Interacts with `FdcHub` contract on Flare.
        *   Function `requestWeb2Data(string memory apiUrl, string memory jqFilter)`:
            *   Calls `FdcHub.requestAttestation(AttestationType.JsonApi, sourceId, requestBody)` where `requestBody` includes API URL and JQ filter.
    2.  **Attestation & Retrieval:**
        *   Attestation providers fetch data from `apiUrl`, apply `jqFilter`, and submit to DA layer.
        *   Our Flare contract (or backend) later retrieves attested data and Merkle proof.
    3.  **Verification & Usage:**
        *   Our Flare contract verifies the Merkle proof.
        *   Verified data is used to update user credit profile (either on Flare or bridged to primary chain via LayerZero/other bridge).
    4.  **Use Cases:** Verifying utility bill payments if utility company has an API, verifying income from gig economy platforms via their APIs.

### 11. Rootstock (RSK)

*   **Bounty Goals:** Everyday DeFi on RSK (Bitcoin yield), Freestyle dApps (AI bonus), RIF Economy.
*   **Project Integration:** Deploy core platform on RSK to leverage Bitcoin ecosystem (RBTC collateral/loans) or RIF token utility.
*   **Technical Steps & Insights:**
    1.  **EVM Compatibility:** Deploy existing Solidity contracts (loan pools, vouching, reputation) to RSK using Hardhat/Foundry.
        *   Ensure RPC URLs for RSK testnet/mainnet are configured.
        *   Use `--legacy --evm-version london` flags with Foundry if needed.
    2.  **RBTC Integration:** Accept RBTC as collateral or for loan denominations.
    3.  **RIF Token Utility:** 
        *   Allow RIF for staking in social vouching system.
        *   Use USDRIF (RIF-backed stablecoin) as a loan currency option.
    4.  **AI on RSK (Freestyle):** If parts of the AI scoring logic are simple enough, they could be on an RSK smart contract. More likely, an AI agent (off-chain) interacts with RSK contracts.

### 12. Yellow (Nitrolite Protocol - ERC-7824)

*   **Bounty Goal:** Best use of ERC-7824 / Nitrolite SDK for state channels.
*   **Project Integration:** Potential for optimizing frequent, low-value interactions like micro-repayment processing or incremental reputation updates (not MVP).
*   **Technical Steps & Insights (Conceptual):**
    1.  **SDK:** Use `@erc7824/nitrolite`.
    2.  **State Channel Setup:** Between user and platform for specific interactions (e.g., tracking micro-loan interest accrual or repayment installments off-chain).
    3.  **Off-chain Updates:** User and platform sign state updates within the channel.
    4.  **On-chain Settlement:** Periodically (or on dispute/channel close), the final state is settled on the main EVM chain.
    5.  **Complexity:** Requires an off-chain communication layer between participants; more suited for post-MVP optimization.

### 13. Beraborrow

*   **Bounty Goals:** Specific to Beraborrow's Liquid Stability Pool (LSP) and CDP management on Berachain.
*   **Project Integration:** Currently low direct relevance unless the platform's core is re-architected around Berachain CDPs and the Nectar stablecoin. Could be a future vertical if expanding into specific DeFi ecosystems heavily.

This completes the detailed research on the remaining bounties.

### Worldcoin Ecosystem & SocialFi Landscape (Further Research)

*   **Current State:** World ID is primarily used by existing SocialFi dApps (e.g., DSCVR, DRiP, Yay!) for Sybil resistance and human verification at the onboarding stage. This aligns with our planned use of World ID.
*   **Decentralized Reputation/Credit within Worldcoin:** No mature, dedicated dApps or protocols for decentralized reputation, credit scoring, or P2P lending specifically built *within* the Worldcoin ecosystem (that we can directly integrate as a pre-built module) were found. This presents an opportunity for our project.
*   **On-chain Social Graphs/Friend Lists with World ID:** Established decentralized social graph protocols (e.g., Lens, CyberConnect) have not yet announced specific integrations with World ID or deployments on World Chain. There isn't a readily available Worldcoin-native, on-chain social graph protocol for direct integration for our social vouching feature.
*   **Implications for Our Project's Social Vouching:**
    *   We will need to implement our own on-chain mechanism for users to declare vouches or "friend-like" connections within our application's smart contracts (e.g., in `UserRegistry.sol` or `SimpleVouch.sol`).
    *   The social aspect will stem from users coordinating off-chain to vouch for each other within our platform.
    *   World ID remains crucial for ensuring unique human participants in the vouching process.
    *   Our project can be a novel application showcasing a practical SocialFi use case (social vouching for credit) built with World ID, especially as a World App Mini App.

This detailed research should provide a much clearer path for integrating these technologies. I'll add this to `knowledge.md`. 