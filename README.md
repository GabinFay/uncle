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

## 🚧 Roadmap

Uncle is more than a lending protocol. It’s a financial recovery and growth platform. Our roadmap expands scoring, liquidity access, cross-chain capability, and local integrations:

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

## 📂 Resources

* [Website]()
* [Demo Video]()
* [Figma File](https://www.figma.com/design/uYum04bGPBW9bVuqS045QZ/Uncle?node-id=0-1&t=qXRuUNkoQqHe436x-1)
* [Figma prototype](https://www.figma.com/proto/uYum04bGPBW9bVuqS045QZ/Uncle?page-id=0%3A1&node-id=14-161&p=f&viewport=335%2C165%2C0.11&t=iWm2Ft9EzXWVqJr2-1&scaling=min-zoom&content-scaling=fixed&starting-point-node-id=28%3A235)
* [Contract Code]()
* [Frontend Repo]()

---

## 🧠 Team

* [gabinfay](https://x.com/gabinfay) - Smart contracts/Backend
* [1uizeth](https://x.com/1uizeth) - UX/Frontend

---

> \_Built at ETHGlobal Prague 2024 to rethink what fair lending can look like in the onchain era. Like an uncle block, you can be valid even if you're left out.
