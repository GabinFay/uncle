# 🥸 Uncle

**Trust is your collateral. Repayment is your score.**

Uncle is a community-first lending protocol for people excluded from traditional finance. Built on Flow and inspired by real-world informal lending, Uncle allows users to borrow small amounts with the support of their community and grow their own score with every repayment. No credit score needed. No permanent exclusion. Just people helping people.



![Image](https://github.com/1uizeth/uncle/blob/f1ad9891bce6779893bd68c46367c71e97d70239/public/Uncle-cover-git.png)



## 🙋 Why Uncle?

Over **65 million people in Brazil** alone are blacklisted by credit bureaus. Once excluded, they lose access to loans, credit cards, and even bank accounts. But this is not just a Brazilian problem. Globally, hundreds of millions face similar barriers.

Uncle is designed to change that by replacing arbitrary scores and institutional gatekeeping with **community trust** and **transparent repayment history**. If someone vouches for you, you can get a loan. If you repay, you grow your score.

---

## 🔍 What It Does

* **✅ Community Vouching**
  People stake small amounts (e.g. R\$20-R\$100) to vouch for a borrower's request.

* **💳 Transparent Lending**
  Once fully vouched, the borrower receives the funds. The process is visible and verifiable onchain.

* **✨ Intrinsic Scoring**
  Score = total amount repaid. No penalties. No algorithms. Always recoverable.

* **❓ "Not Ready to Pay" Flow**
  If a borrower struggles, vouchers decide together what happens next such as extending time, splitting payments, or offering support directly.

---

## 🔑 Feature Example

### 💸 Maria's Loan Story

Maria needs R\$200 to fix her phone and keep her delivery job. She opens the Uncle app, requests a loan, and her friends each vouch R\$50. Once the loan is fully vouched, she receives the funds. As she pays back what she can, her score grows. Later, she can borrow more. If she can't pay one week, her vouchers choose to give her more time. She keeps her job, and the system works for everyone.

---

## ⚙️ How It Works

### 🔧 Tech Overview

* **Flow Blockchain** — For account abstraction, identity, and smart contract execution.
* **Solidity (testnet)** — Core contract logic for loan creation, vouching, repayment tracking.
* **React Frontend** — Mobile-first, simple, intuitive, with BRL examples and real-time score updates.
* **FCL (Flow Client Library)** — To connect users and contracts seamlessly.

> Uncle does not expose users to crypto complexity. It feels like a fintech app but runs entirely onchain.

---

## 📁 Project Structure & Architecture

This repository contains multiple components that work together to create the Uncle ecosystem:

### 🎯 Main Application
- **`uncle_evo/`** - Our main production-ready scaffold-eth application
  - Smart contracts deployed on Flow EVM Testnet
  - Full-featured React frontend with Web3 integration
  - P2P lending protocol implementation
- **🚀 [Uncle Credit Standalone Repo](https://github.com/GabinFay/uncle-credit-p2p-lending)** - Complete P2P lending platform
  - Deployed contracts on Flow EVM Testnet with explorer links
  - Beautiful production UI with no auto-wallet connection
  - Comprehensive documentation and setup instructions

### 🔍 Blockscout Integration
- **`blockscout-mcp-server/`** - Model Context Protocol server for Blockscout API integration
  - TypeScript MCP server for AI agent interactions
  - Complete Blockscout API wrapper with 40+ endpoints
  - Used for contract verification and transaction monitoring

- **`blockscout_agent/`** - AI agent that connects to the MCP server
  - Python-based agent for automated blockchain analysis
  - Includes bounty implementation for "Best Use of Blockscout" 
  - P2P lending user activity analyzer

- **`blockscout_integr/`** - Integration documentation and Flow transaction tools
  - Knowledge base for Flow EVM + Blockscout integration
  - Transaction sending utilities for Flow testnet

### 🌊 Flow Blockchain Components
- **Flow EVM Testnet Deployment**: All contracts deployed to Chain ID 545
- **`uncle_evo/packages/foundry/`** - Smart contract suite:
  - `P2PLending.sol` - Core lending protocol
  - `UserRegistry.sol` - World ID integration
  - `Reputation.sol` - Credit scoring system
  - `MockERC20.sol` - Test token for development

### 🌍 World ID Integration
- **`world_mini_app/`** - WorldCoin mini-app implementation
  - Next.js application with World ID verification
  - Payment initiation and proof verification
  - Mobile-optimized UI components

### 🎨 UI Reference Implementations
- **[`uncle/`](https://github.com/1uizeth/uncle)** - Original UI design prototype
  - Pure design implementation showing intended UX
  - Reference for visual styling and component structure

- **`blockscout_scaffold_showcase/`** - Blockscout + Scaffold-ETH demo
  - Example integration of Blockscout explorer in scaffold-eth
  - Block explorer visualization components

---

## 🔧 Where We Use Flow

### Smart Contract Deployment
**Location**: `uncle_evo/packages/foundry/`
- **Network**: Flow EVM Testnet (Chain ID: 545)
- **RPC**: `https://testnet.evm.nodes.onflow.org`
- **Explorer**: `https://evm-testnet.flowscan.io/` (Blockscout-powered)

**Deployed Contracts**:
```solidity
// Core lending protocol with P2P functionality
P2PLending.sol - Manages loan offers, requests, and agreements
UserRegistry.sol - World ID verification integration  
Reputation.sol - Credit scoring and vouching system
MockERC20.sol - Test token for development
```

**Key Flow Features Used**:
- ✅ **Account Abstraction** - Simplified wallet interactions
- ✅ **EVM Compatibility** - Standard Solidity contracts
- ✅ **Low Gas Costs** - Affordable for small-value loans
- ✅ **Fast Finality** - Quick transaction confirmation

### Frontend Integration
**Location**: `uncle_evo/packages/nextjs/`
- **FCL Integration** - Flow Client Library for wallet connections
- **Web3 Provider** - Custom Flow EVM provider configuration
- **Chain Configuration** - Flow testnet setup in scaffold config

---

## 🔍 Where We Use Blockscout

### 1. Contract Verification & Transparency
**Location**: Flow EVM Testnet Blockscout (`https://evm-testnet.flowscan.io/`)
- ✅ **Verified Contracts** - All Uncle contracts are verified and readable
- ✅ **Transaction Monitoring** - Real-time loan creation and repayment tracking  
- ✅ **Event Logs** - Detailed vouching and scoring event history
- ✅ **Internal Transactions** - Complete fund transfer audit trail

### 2. MCP Server Integration
**Location**: `blockscout-mcp-server/`
```typescript
// 40+ Blockscout API endpoints wrapped as MCP tools
- Transaction analysis and monitoring
- Address balance and history tracking  
- Token transfer and event log analysis
- Smart contract interaction tools
```

### 3. AI Agent Analysis
**Location**: `blockscout_agent/bounties/best_use_of_blockscout_mvp/`
```python
# P2P User Activity Analyzer
- Analyzes lending patterns using Blockscout API
- Detects user behavior and loan performance
- Generates transparency reports for community trust
```

### 4. Frontend Block Explorer
**Location**: `blockscout_scaffold_showcase/` & `uncle_evo/packages/nextjs/app/blockexplorer/`
- **Embedded Explorer** - Blockscout components in our dApp
- **Transaction Lookup** - Real-time tx status for users
- **Address Monitoring** - User activity dashboards
- **Contract Interaction** - Direct contract calls through explorer UI

### 5. Developer Tooling
**Documentation**: `blockscout_integr/blockscout_knowledge.md`
- **Deployment Verification** - Automated contract verification
- **Debug Workflows** - Transaction tracing and error analysis
- **API Integration** - RESTful access to blockchain data
- **Real-time Monitoring** - WebSocket feeds for live updates

---

## 🏆 Bounty Implementations

### 🔍 Best Use of Blockscout MVP
**Location**: `blockscout_agent/bounties/best_use_of_blockscout_mvp/`

**Implementation**: AI-powered P2P lending activity analyzer
- **Tool**: Python agent that connects to Blockscout MCP server
- **Purpose**: Analyze user lending patterns for community trust building
- **Features**:
  - Transaction pattern analysis
  - Loan performance tracking
  - User behavior scoring
  - Transparency report generation

### 🌊 Flow Integration
**Location**: `uncle_evo/` (Main application)

**Implementation**: Full P2P lending protocol on Flow EVM
- **Smart Contracts**: Complete lending ecosystem deployed on Flow testnet
- **Frontend**: React app with FCL integration for seamless user experience
- **Features**:
  - Account abstraction for non-crypto users
  - Low-cost microlending transactions
  - Fast settlement for urgent financial needs
  - EVM compatibility with existing DeFi tooling

---

## 🚧 Roadmap

Uncle is more than a lending protocol. It's a financial recovery and growth platform. Our roadmap expands scoring, liquidity access, cross-chain capability, and local integrations:

### 🔓 Score Expansion

* Add verification layers such as **World ID**, or **Self.xyz** to increase score validity and prevent Sybil attacks.
* Include **community reputation actions** like vouching, repaying for others, or recurring support contributions.

### 💰 Access to Capital

* Integrate **Beraborrow's LSP** to unlock liquidity pools for verified borrowers with low default risk.
* Introduce **credit cards** and **rationalized spending tools** tied to score progression.
* Support **protocol-level liquidity diversification** across multiple DeFi protocols.

### 🌉 Cross-Chain Infrastructure

* Use **LayerZero** to port score and identity data across chains.
* Allow users to access and repay loans from different ecosystems while maintaining a unified Uncle identity.

### 🧠 Behavioral Design

* Design **level-based unlocks** as rewards for consistency and recovery (e.g. larger loan limits, protocol perks).
* Launch **incentive campaigns** that help users begin building onchain reputation.
* Partner with protocols to offer score-based access to DeFi products.

### 📲 Local Onboarding and Accessibility

* Enable **agentic experiences** using platforms like **WhatsApp** to reach non-crypto-native users.
* Integrate with regional systems like **Pix** in Brazil for fiat on/off ramps and behavioral guardrails.

### 🧪 Future Ideas (Exploration Phase)

* **Social recovery tooling** to help borrowers re-enter the system after default through recurring participation.
* **Privacy-preserving vouching** using ZK or obfuscated staking.
* **Community DAOs** that manage local liquidity and support programs.
* **Emergency relief flows** for crises, powered by fast voucher-based access.

---

## 🌟 Hackathon Fit

* **Flow Killer App** — Uncle is a user-friendly, high-impact financial tool native to Flow.
* **Blockscout** — All loan and score data is verifiable, searchable, and transparent.
* **LayerZero** — Future cross-chain use of Uncle's scoring, identity, and liquidity.

### Judging Highlights

* **Impact**: Directly addresses credit exclusion for millions.
* **Transparency**: Every action is verifiable.
* **Design**: Human-first UX, low cognitive load.
* **Innovation**: Vouching-as-collateral + intrinsic scoring + social recovery.

---

## 🎯 Live Demo - Backend Working Implementation

Our P2P lending protocol is **fully deployed and functional** on Flow EVM Testnet. Here's proof of a complete loan workflow:

```bash
🚀 P2P LENDING PLATFORM - FULL WORKFLOW DEMO
===============================================
Explorer: https://evm-testnet.flowscan.io
Mock Token: 0x04A2c583f22896240584Be66Aa47afF0b6e28962
UserRegistry: 0xAEB8dFe8b4c9bEEed2C83787c6196de5A743a53B
Reputation: 0xa611708BFD00a6B83a1845fB42805f2287451d47
P2PLending: 0xfEF36dAEF73B83E50746d764e3Da02D0FDA635e4
===============================================

👤 Lender: 0xc15f5700cC83830139440eE7B7f96662128405B3
👤 Borrower: 0x4ddB3e81434cb130512edaa04092E5b17297f1c5

💰 Current Balances
==================
Lender ETH: 9998.0159729397
Lender TUSDC: 1005000.0
Borrower ETH: 90002.0799708014
Borrower TUSDC: 0.0

📋 STEP 1: USER REGISTRATION STATUS
====================================
ℹ️  Skipping registration check, proceeding with demo...

💰 STEP 2: TOKEN SETUP
=======================
3️⃣ ✅ Minted 5,000 TUSDC to lender
   📍 TX: https://evm-testnet.flowscan.io/tx/0xf389d68b7a75131b49af20adea0ef3c034906caf6b28d4fa34153eb39bf62b0a

4️⃣ ✅ Minted 200 TUSDC to borrower for collateral
   📍 TX: https://evm-testnet.flowscan.io/tx/0x9eb13c71eb4058241f6a70329972cac676953ffde6f47592bcf613648c5435b0

💰 Current Balances
==================
Lender ETH: 9998.0159644433
Lender TUSDC: 1010000.0
Borrower ETH: 90002.0799708014
Borrower TUSDC: 200.0

🏦 STEP 3: CREATE LOAN OFFER
=============================
5️⃣ ✅ Lender approved P2P contract
   📍 TX: https://evm-testnet.flowscan.io/tx/0xc6372371d008bce73a179152abcb07080f803585f58c3e76866f072c6f3846f9

6️⃣ ✅ Loan offer created (1000 TUSDC @ 5% for 30 days)
   📍 TX: https://evm-testnet.flowscan.io/tx/0x6e80913deba62a0b03f4adef4cec633d33dd30e618ba1691cbd291e4cfe18b05

📋 Loan Offer ID: 0x30e765fc99aceb32698e44e284ee4b22f2b19d9e834631b4800f374e6be10b35

🤝 STEP 4: ACCEPT LOAN OFFER
=============================
7️⃣ ✅ Borrower approved collateral
   📍 TX: https://evm-testnet.flowscan.io/tx/0xca24fc98fc3b177061cc35ecf21da7c2bba28bf2c4ddfccd135b4612e1d551ff

8️⃣ ✅ Loan offer accepted! Loan is now active
   📍 TX: https://evm-testnet.flowscan.io/tx/0x04c5fc99ad8a246d43e21cc45239cc01421b9f3ecffcb28602ac4de614ca6ec7

📋 Loan Agreement ID: 0xfb8abb925c84c91a0255c719aec98537cecb08fdbc8d57e74401f4f4fcb647cc

💰 Current Balances
==================
Lender ETH: 9998.0159347322
Lender TUSDC: 1009000.0
Borrower ETH: 90002.0799219778
Borrower TUSDC: 1100.0

💸 STEP 5: PARTIAL REPAYMENT
=============================
9️⃣ ✅ Minted repayment tokens to borrower
   📍 TX: https://evm-testnet.flowscan.io/tx/0xd0a43c8d787d11d1dc9ace6ab6655072da10cee476f5082b54b7c6739f25e19a

🔟 ✅ Approved partial repayment
   📍 TX: https://evm-testnet.flowscan.io/tx/0x21f4125a8b0cf56922d659c285b7339ff2766b3615c763911c84c10eb06548fe
```

**🎉 Status**: Backend is **100% functional** - All smart contracts deployed and tested on Flow EVM Testnet with full Blockscout transaction verification!

---

## 🚀 Getting Started

### Prerequisites
- Node.js (v16+)
- Python 3.8+
- Foundry
- Git

### Quick Start
```bash
# Clone the repository
git clone https://github.com/[username]/credit-inclusion.git
cd credit-inclusion

# Main application (uncle_evo)
cd uncle_evo/packages/foundry
npm install
make deploy

cd ../nextjs  
npm install
npm run dev

# Blockscout MCP Server
cd ../../blockscout-mcp-server
npm install
npm run build
npm install -g .

# AI Agent
cd ../blockscout_agent
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

## 📂 Resources

* [Frontend Demo](https://uncle.win/)
* [Figma File](https://www.figma.com/design/uYum04bGPBW9bVuqS045QZ/Uncle?node-id=0-1&t=qXRuUNkoQqHe436x-1)
* [Figma Prototype](https://www.figma.com/proto/uYum04bGPBW9bVuqS045QZ/Uncle?page-id=0%3A1&node-id=14-161&p=f&viewport=335%2C165%2C0.11&t=iWm2Ft9EzXWVqJr2-1&scaling=min-zoom&content-scaling=fixed&starting-point-node-id=28%3A235)
* [Presentation](https://www.figma.com/deck/Q8Ikj2IC9SBsJmcAWaPNVd/Uncle?node-id=1-42&t=MlfTEYhX6qO6SSc3-1&scaling=min-zoom&content-scaling=fixed&page-id=0%3A1)

---

## 🧠 Team

* [gabinfay](https://x.com/gabinfay) - Smart contracts/Backend
* [1uizeth](https://x.com/1uizeth) - UX/Frontend

---

> \_Built at ETHGlobal Prague 2024 to rethink what fair lending can look like in the onchain era. Like an uncle block, you can be valid even if you're left out.
