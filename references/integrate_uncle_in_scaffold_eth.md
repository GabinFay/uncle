# Integrating Uncle into Scaffold-ETH 2: Complete Guide

This guide documents the complete process of integrating the Uncle P2P lending application into Scaffold-ETH 2, including pitfalls to avoid, code examples, and best practices.

## Overview

**Uncle** is a P2P lending platform built on trust and verifiable reputation, anchored by World ID. The integration involved:
- Moving from a standalone Next.js app (`uncle/`) to Scaffold-ETH 2 structure (`uncle-scaff/`)
- Implementing smart contracts for lending, user registry, and reputation
- Creating API routes for blockchain interactions
- Setting up comprehensive testing with mocked blockchain providers

## Project Structure Transformation

### Before: Standalone Uncle App
```
uncle/
├── app/
├── components/
├── hooks/
├── lib/
├── public/
└── styles/
```

### After: Scaffold-ETH 2 Integration
```
uncle-scaff/
├── packages/
│   ├── foundry/           # Smart contracts (Solidity)
│   │   ├── contracts/     # Contract source files
│   │   ├── script/        # Deployment scripts
│   │   ├── test/          # Contract tests
│   │   └── deployments/   # Deployment artifacts
│   └── nextjs/            # Frontend application
│       ├── app/           # Next.js App Router
│       │   └── api/       # Backend API routes
│       ├── components/    # React components
│       ├── hooks/         # Custom hooks
│       ├── contracts/     # Contract type definitions
│       └── services/      # Web3 services
├── PRD.md                 # Product Requirements
├── status.md              # Development progress
└── SPRINT_PLAN.md         # Development roadmap
```

## Key Integration Points

### 1. Smart Contract Architecture

The Uncle system requires three main contracts:

```solidity
// Core contracts structure
contracts/
├── UserRegistry.sol    # World ID registration & user management
├── P2PLending.sol     # Loan offers, requests, agreements
└── Reputation.sol     # User reputation tracking
```

**Key Implementation Note:** Always use Foundry for Scaffold-ETH 2, not Hardhat.

### 2. API Routes Structure

```typescript
// API routes following SE-2 patterns
app/api/
├── register/
│   └── route.ts          # User registration with World ID
├── loans/
│   └── route.ts          # Create loan offers/requests
├── agreements/
│   └── route.ts          # Accept offers, fund requests
└── repayments/
    └── route.ts          # Loan repayment handling
```

### 3. Environment Configuration

```bash
# uncle-scaff/packages/foundry/.env
DEPLOYER_PRIVATE_KEY=your_private_key
FLOW_EVM_TESTNET_RPC_URL=https://testnet.evm.flowchain.com
P2P_LENDING_CONTRACT=0x...
WORLD_ID_APP_ID=your_world_id_app_id
WORLD_ID_ACTION=your_world_id_action
```

```bash
# uncle-scaff/packages/nextjs/.env
NEXT_PUBLIC_ALCHEMY_API_KEY=your_alchemy_key
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_walletconnect_id
P2P_LENDING_CONTRACT=0x...
FLOW_EVM_TESTNET_RPC_URL=https://testnet.evm.flowchain.com
DEPLOYER_PRIVATE_KEY=your_private_key
```

## Code Examples

### 1. Contract Deployment Script

```typescript
// packages/foundry/script/Deploy.s.sol
import {Script} from "forge-std/Script.sol";
import {UserRegistry} from "../contracts/UserRegistry.sol";
import {P2PLending} from "../contracts/P2PLending.sol";
import {Reputation} from "../contracts/Reputation.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        
        UserRegistry userRegistry = new UserRegistry();
        Reputation reputation = new Reputation();
        P2PLending p2pLending = new P2PLending(
            address(userRegistry),
            address(reputation)
        );
        
        vm.stopBroadcast();
    }
}
```

### 2. API Route with Ethers.js Integration

```typescript
// packages/nextjs/app/api/agreements/route.ts
import { NextResponse } from "next/server";
import { ethers, Contract } from "ethers";

const P2P_LENDING_ADDRESS = process.env.P2P_LENDING_CONTRACT;
const RPC_URL = process.env.FLOW_EVM_TESTNET_RPC_URL;
const SIGNER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY;

const p2pLendingAbi = [
  "function acceptLoanOffer(bytes32 offerId, uint256 collateralAmount, address collateralToken) returns (bytes32 agreementId)",
  "function fundLoanRequest(bytes32 requestId, uint256 collateralAmount, address collateralToken) returns (bytes32 agreementId)"
];

export async function POST(request: Request) {
  try {
    const { type, id, collateralAmount, collateralToken } = await request.json();
    
    const provider = new ethers.JsonRpcProvider(RPC_URL!);
    const wallet = new ethers.Wallet(SIGNER_PRIVATE_KEY!, provider);
    const contract = new ethers.Contract(P2P_LENDING_ADDRESS!, p2pLendingAbi, wallet);
    
    let tx;
    const parsedAmount = ethers.parseUnits(collateralAmount || "0", 18);
    
    if (type === 'acceptOffer') {
      tx = await contract.acceptLoanOffer(id, parsedAmount, collateralToken);
    } else {
      tx = await contract.fundLoanRequest(id, parsedAmount, collateralToken);
    }
    
    const receipt = await tx.wait();
    
    return NextResponse.json({
      message: `Loan agreement processed successfully`,
      transactionHash: receipt.hash,
    });
  } catch (error: any) {
    return NextResponse.json(
      { error: "Failed to process agreement", details: error.message },
      { status: 500 }
    );
  }
}
```

### 3. Frontend Component with SE-2 Hooks

```typescript
// packages/nextjs/components/LoanAgreement.tsx
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

export default function LoanAgreement() {
  const { writeContractAsync: writeP2PLendingAsync } = useScaffoldWriteContract({
    contractName: "P2PLending"
  });

  const acceptOffer = async (offerId: string, collateralAmount: string) => {
    try {
      await writeP2PLendingAsync({
        functionName: "acceptLoanOffer",
        args: [offerId, ethers.parseUnits(collateralAmount, 18), ethers.ZeroAddress],
      });
    } catch (error) {
      console.error("Error accepting offer:", error);
    }
  };

  return (
    // Your component JSX
  );
}
```

## Major Pitfalls and Solutions

### 1. Testing with Real Network Calls

**Problem:** Tests were making real network calls instead of using mocks.

**Solution:** Implement proper mocking strategy:

```typescript
// packages/nextjs/test/api/agreements.test.ts
import { jest } from '@jest/globals';

// Mock ethers.js at module level
jest.mock('ethers', () => ({
  ethers: {
    JsonRpcProvider: jest.fn(),
    Wallet: jest.fn(),
    Contract: jest.fn(),
    parseUnits: jest.fn(),
    ZeroAddress: '0x0000000000000000000000000000000000000000'
  }
}));

describe('/api/agreements', () => {
  beforeEach(() => {
    // Set up mocks before each test
    const mockContract = {
      acceptLoanOffer: jest.fn(),
      fundLoanRequest: jest.fn(),
    };
    
    require('ethers').ethers.Contract.mockImplementation(() => mockContract);
  });
});
```

### 2. Environment Variable Management

**Problem:** Hardcoded environment variables causing deployment issues.

**Solution:** 
- Always use `.env.example` files with placeholder values
- Never commit real private keys or API keys
- Use different `.env` files for different environments

```bash
# .env.example
DEPLOYER_PRIVATE_KEY=your_private_key_here
FLOW_EVM_TESTNET_RPC_URL=https://testnet.evm.flowchain.com
P2P_LENDING_CONTRACT=contract_address_after_deployment
```

### 3. Contract Event Parsing

**Problem:** Difficulty extracting return values from contract function calls.

**Solution:** Parse events from transaction receipts:

```typescript
// Extract agreementId from transaction events
let agreementIdFromEvent: string | undefined;
if (receipt.logs) {
  for (const log of receipt.logs as any[]) {
    try {
      const parsedLog = contract.interface.parseLog(log);
      if (parsedLog && parsedLog.name === "LoanAgreementFormed") {
        agreementIdFromEvent = parsedLog.args.agreementId;
        break;
      }
    } catch (e) {
      // Not an event from this contract's ABI
    }
  }
}
```

### 4. Git Strategy

**Problem:** Breaking the main branch with untested features.

**Solution:** Follow strict branching strategy:
- Create feature branches: `git checkout -b feature/loan-agreements`
- Test thoroughly before merging
- Tag working versions: `git tag v1.0.0-loan-basic`
- Never work directly on main

### 5. Foundry vs Hardhat

**Problem:** Trying to use Hardhat patterns in Scaffold-ETH 2.

**Solution:** Always use Foundry:
```bash
# Deploy contracts
yarn foundry:deploy

# Run tests
yarn foundry:test

# Compile contracts
yarn foundry:compile
```

## Development Workflow

### 1. Initial Setup
```bash
# Clone Scaffold-ETH 2
git clone https://github.com/scaffold-eth/scaffold-eth-2.git uncle-scaff
cd uncle-scaff

# Install dependencies
yarn install

# Start local blockchain
yarn chain

# Deploy contracts
yarn deploy

# Start frontend
yarn start
```

### 2. Development Cycle
1. Write smart contracts in `packages/foundry/contracts/`
2. Create deployment scripts in `packages/foundry/script/`
3. Test contracts with `yarn foundry:test`
4. Deploy to testnet
5. Create API routes in `packages/nextjs/app/api/`
6. Write comprehensive tests for API routes
7. Build frontend components using SE-2 hooks
8. Test end-to-end functionality

### 3. Testing Strategy

```typescript
// Test structure for API routes
describe('API Route Tests', () => {
  describe('Unit Tests', () => {
    // Test individual functions with mocked dependencies
  });
  
  describe('Integration Tests', () => {
    // Test API routes with mocked blockchain interactions
  });
  
  describe('E2E Tests', () => {
    // Test full user flows (optional, for critical paths)
  });
});
```

## Configuration Files

### scaffold.config.ts
```typescript
const scaffoldConfig = {
  targetNetworks: [chains.flowMainnet], // or chains.foundry for local
  pollingInterval: 30000,
  alchemyApiKey: process.env.NEXT_PUBLIC_ALCHEMY_API_KEY,
  walletConnectProjectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID,
  onlyLocalBurnerWallet: true,
} as const satisfies ScaffoldConfig;
```

### foundry.toml
```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
]

[rpc_endpoints]
flow_testnet = "${FLOW_EVM_TESTNET_RPC_URL}"
```

## Best Practices

1. **Always use environment variables for secrets**
2. **Write tests before implementing features**
3. **Use SE-2 hooks instead of raw ethers.js in components**
4. **Follow the monorepo structure strictly**
5. **Use Foundry for all smart contract operations**
6. **Mock external dependencies in tests**
7. **Create feature branches and test before merging**
8. **Document environment variables in `.env.example`**
9. **Use TypeScript for type safety**
10. **Follow the established API route patterns**

## Debugging Tips

1. **Check contract deployment addresses match environment variables**
2. **Verify RPC URL connectivity**
3. **Use `console.log` in API routes for debugging**
4. **Check transaction receipts for event logs**
5. **Ensure wallet has sufficient funds for transactions**
6. **Verify contract ABI matches deployed contract**

## Next Steps for Similar Integrations

1. Start with the Scaffold-ETH 2 template
2. Plan your smart contract architecture
3. Set up proper environment configuration
4. Implement contracts with comprehensive tests
5. Create API routes following the established patterns
6. Write frontend components using SE-2 hooks
7. Implement comprehensive testing strategy
8. Follow git branching best practices
9. Document everything for future reference

This integration serves as a template for building complex dApps on Scaffold-ETH 2 while maintaining clean architecture and comprehensive testing. 