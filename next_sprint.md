# Uncle Credit MVP Sprint Plan

## 🎯 Goal: Simple P2P Lending Platform with Address-Based Reputation

### Sprint Overview
Build a minimal viable product for peer-to-peer lending without World ID integration. Focus on core lending functionality with simple reputation system tied to wallet addresses.

## Phase 1: Contract Simplification ⏳ Current Phase
### ✅ Tasks to Complete Now
- [x] Remove World ID integration from all contracts
- [x] Simplify UserRegistry to just track addresses and basic info
- [x] Streamline P2PLending contract for core functionality only
- [x] Update Reputation contract for address-based scoring
- [x] Update all tests to match simplified contracts
- [x] Verify everything compiles and tests pass

### Core Functionalities per Role:
**Borrower Actions:**
- Ask for a loan (amount, purpose, deadline)
- Repay the loan 
- Request deadline extension

**Lender Actions:**
- Provide money for loans
- Accept/decline extension requests
- Receive repayment + interest

**Reputation Logic:**
- Both parties lose reputation if borrower defaults
- Both parties gain reputation on successful repayment
- Reputation affects loan terms and trust scores

## Phase 2: Scaffold-ETH Integration
### Tasks:
- [ ] Copy simplified contracts to uncle_evo/packages/foundry/contracts/
- [ ] Copy updated tests to uncle_evo/packages/foundry/test/
- [ ] Create hybrid deployment script inheriting ScaffoldETHDeploy
- [ ] Merge foundry.toml configurations (add Flow testnet)
- [ ] Test deployment exports to frontend
- [ ] Verify contract addresses auto-update in frontend

## Phase 3: Frontend Development  
### Tasks:
- [ ] Test scaffold-eth default UI with our contracts
- [ ] Create loan request form component
- [ ] Create loan browsing/funding interface
- [ ] Add reputation display components
- [ ] Implement loan repayment interface
- [ ] Add deadline extension request system

## Phase 4: Flow Testnet Integration
### Tasks:
- [ ] Configure scaffold-eth for Flow EVM Testnet
- [ ] Update wagmi config for Flow network
- [ ] Deploy contracts to Flow testnet
- [ ] Test full user flow on testnet
- [ ] Add Flow-specific UI elements (network switcher)

## Phase 5: UX Polish & Testing
### Tasks:
- [ ] Add loading states for all transactions
- [ ] Implement error handling and user feedback
- [ ] Add transaction history dashboard
- [ ] Create user reputation dashboard
- [ ] Mobile responsiveness testing
- [ ] End-to-end user journey testing

## Phase 6: Production Ready
### Tasks:
- [ ] Security audit preparation
- [ ] Gas optimization review
- [ ] Frontend deployment setup
- [ ] Documentation writing
- [ ] Demo preparation

## Success Criteria
- ✅ Simplified contracts compile and test successfully
- [ ] P2P lending works end-to-end locally
- [ ] Reputation system functions correctly
- [ ] Frontend integrates seamlessly with contracts
- [ ] Flow testnet deployment successful
- [ ] User can complete full loan cycle in browser

## Technical Notes
- **No World ID**: Address-based reputation only
- **Simple MVP**: Focus on core lending, avoid complex features
- **Flow Integration**: Maintain Flow EVM Testnet as target deployment
- **Scaffold-ETH**: Leverage auto frontend updates and deployment tools 