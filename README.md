# Decentralized Credit Recovery Platform

## 🚧 Project Status: Actively In Development (Post-Sprint 3) 🚧

This project aims to build a **peer-to-peer lending platform anchored by verifiable reputation through World ID**. Our goal is to provide a transparent and accessible financial system, allowing individuals to build creditworthiness and access capital based on trust and on-chain activity.

We are developing this platform with a focus on hackathon bounties, integrating technologies like LayerZero for cross-chain functionality and Blockscout for enhanced analytics.

### Current State (as of v0.3.0-sprint3-complete):
*   **Core Smart Contracts Developed (`UserRegistry.sol`, `P2PLending.sol`, `Reputation.sol`):**
    *   Peer-to-peer lending logic (offers, requests, agreements, repayment, default handling).
    *   Reputation system with social vouching and slashing mechanisms.
    *   User registration linked to World ID (conceptual, with on-chain flags).
*   **Comprehensive NatSpec Documentation:** All core contracts are fully documented.
*   **Deployment Script (`script/Deploy.s.sol`):** A robust script for deploying all contracts and setting initial configurations on a local Anvil node is complete and tested.
*   **Unit Tests:** Extensive unit tests cover the core functionalities of all smart contracts.
*   **Frontend Scaffolding (Paused):** Initial Streamlit frontend setup was started but is currently on hold.

### Next Steps:
*   Refine and finalize the overall sprint plan.
*   Explore and implement LayerZero OApp for cross-chain reputation.
*   Further testing and integration.

## The Problem (from PRD.md)
Millions are excluded from traditional financial systems due to a lack of credit history or past defaults. Existing systems offer limited paths to recovery and don't easily recognize non-traditional forms of creditworthiness or the value of a unique, verifiable identity in mitigating risk.

## Our Solution (from PRD.md)
A peer-to-peer lending platform built on trust and verifiable reputation, anchored by World ID.

**Core Idea:** Individuals can lend to and borrow from each other. A user's reputation, tied to their unique World ID, is a key factor in loan terms and a strong incentive for repayment. Social vouching further strengthens this model.

---

*This README will be updated as the project progresses.*

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
