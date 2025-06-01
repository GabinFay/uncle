import { ethers } from 'ethers';
import dotenv from 'dotenv';
import fs from 'fs';

dotenv.config();

// Flow testnet configuration
const FLOW_RPC_URL = process.env.FLOW_EVM_TESTNET_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const BORROWER_PRIVATE_KEY = process.env.BORROWER_PRIVATE_KEY;

// Contract addresses
const MOCK_TOKEN_ADDRESS = process.env.MOCK_TOKEN_CONTRACT;
const USER_REGISTRY_ADDRESS = process.env.USER_REGISTRY_CONTRACT;
const REPUTATION_ADDRESS = process.env.REPUTATION_CONTRACT;
const P2P_LENDING_ADDRESS = process.env.P2P_LENDING_CONTRACT;

// Flow Explorer URL
const FLOW_EXPLORER_BASE = "https://evm-testnet.flowscan.io";

console.log("🚀 P2P LENDING PLATFORM - FULL WORKFLOW DEMO");
console.log("===============================================");
console.log(`Explorer: ${FLOW_EXPLORER_BASE}`);
console.log(`Mock Token: ${MOCK_TOKEN_ADDRESS}`);
console.log(`UserRegistry: ${USER_REGISTRY_ADDRESS}`);
console.log(`Reputation: ${REPUTATION_ADDRESS}`);
console.log(`P2PLending: ${P2P_LENDING_ADDRESS}`);
console.log("===============================================\n");

// Setup provider and wallets
const provider = new ethers.JsonRpcProvider(FLOW_RPC_URL);
const lenderWallet = new ethers.Wallet(PRIVATE_KEY, provider);
const borrowerWallet = new ethers.Wallet(BORROWER_PRIVATE_KEY, provider);

console.log(`👤 Lender: ${lenderWallet.address}`);
console.log(`👤 Borrower: ${borrowerWallet.address}\n`);

// Load contract ABIs
function loadContractABI(contractName) {
    const artifactPath = `./out/${contractName}.sol/${contractName}.json`;
    const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
    return artifact.abi;
}

// Contract instances
const mockTokenABI = loadContractABI('MockERC20');
const userRegistryABI = loadContractABI('UserRegistry');
const reputationABI = loadContractABI('Reputation');
const p2pLendingABI = loadContractABI('P2PLending');

const mockToken = new ethers.Contract(MOCK_TOKEN_ADDRESS, mockTokenABI, lenderWallet);
const userRegistry = new ethers.Contract(USER_REGISTRY_ADDRESS, userRegistryABI, lenderWallet);
const reputation = new ethers.Contract(REPUTATION_ADDRESS, reputationABI, lenderWallet);
const p2pLending = new ethers.Contract(P2P_LENDING_ADDRESS, p2pLendingABI, lenderWallet);

// Helper function to log transaction details
function logTransaction(description, txHash, step = "") {
    console.log(`${step}✅ ${description}`);
    console.log(`   📍 TX: ${FLOW_EXPLORER_BASE}/tx/${txHash}`);
    console.log("");
}

async function checkBalances() {
    console.log("💰 Current Balances");
    console.log("==================");
    
    const lenderEth = await provider.getBalance(lenderWallet.address);
    const borrowerEth = await provider.getBalance(borrowerWallet.address);
    const lenderTokens = await mockToken.balanceOf(lenderWallet.address);
    const borrowerTokens = await mockToken.balanceOf(borrowerWallet.address);
    
    console.log(`Lender ETH: ${ethers.formatEther(lenderEth)}`);
    console.log(`Lender TUSDC: ${ethers.formatUnits(lenderTokens, 18)}`);
    console.log(`Borrower ETH: ${ethers.formatEther(borrowerEth)}`);
    console.log(`Borrower TUSDC: ${ethers.formatUnits(borrowerTokens, 18)}\n`);
}

async function fullWorkflowDemo() {
    try {
        await checkBalances();

        // Step 1: Check User Registration (Skip if already registered)
        console.log("📋 STEP 1: USER REGISTRATION STATUS");
        console.log("====================================");
        
        try {
            const lenderRegistered = await userRegistry.isRegistered(lenderWallet.address);
            const borrowerRegistered = await userRegistry.isRegistered(borrowerWallet.address);
            
            console.log(`1️⃣ ✅ Lender registration status: ${lenderRegistered ? 'REGISTERED' : 'NOT REGISTERED'}`);
            console.log(`2️⃣ ✅ Borrower registration status: ${borrowerRegistered ? 'REGISTERED' : 'NOT REGISTERED'}`);
            console.log("");
            
            if (!lenderRegistered || !borrowerRegistered) {
                console.log("❌ Users need to be registered first!");
                return;
            }
        } catch (error) {
            console.log("ℹ️  Skipping registration check, proceeding with demo...\n");
        }

        // Step 2: Setup Token Balances
        console.log("💰 STEP 2: TOKEN SETUP");
        console.log("=======================");
        
        // Mint tokens to lender for lending
        const mintToLenderTx = await mockToken.mint(lenderWallet.address, ethers.parseUnits("5000", 18));
        await mintToLenderTx.wait();
        logTransaction("Minted 5,000 TUSDC to lender", mintToLenderTx.hash, "3️⃣ ");
        
        // Mint some collateral tokens to borrower
        const mintToBorrowerTx = await mockToken.mint(borrowerWallet.address, ethers.parseUnits("200", 18));
        await mintToBorrowerTx.wait();
        logTransaction("Minted 200 TUSDC to borrower for collateral", mintToBorrowerTx.hash, "4️⃣ ");
        
        await checkBalances();

        // Step 3: Create Loan Offer
        console.log("🏦 STEP 3: CREATE LOAN OFFER");
        console.log("=============================");
        
        const loanAmount = ethers.parseUnits("1000", 18); // 1000 TUSDC
        const interestRateBPS = 500; // 5%
        const duration = 30 * 24 * 60 * 60; // 30 days
        const requiredCollateralAmount = ethers.parseUnits("100", 18); // 100 TUSDC collateral
        
        // Approve P2P lending contract to spend lender's tokens
        const approveLenderTx = await mockToken.approve(P2P_LENDING_ADDRESS, loanAmount);
        await approveLenderTx.wait();
        logTransaction("Lender approved P2P contract", approveLenderTx.hash, "5️⃣ ");
        
        const createOfferTx = await p2pLending.createLoanOffer(
            loanAmount,
            MOCK_TOKEN_ADDRESS,
            interestRateBPS,
            duration,
            requiredCollateralAmount,
            MOCK_TOKEN_ADDRESS
        );
        const createOfferReceipt = await createOfferTx.wait();
        logTransaction("Loan offer created (1000 TUSDC @ 5% for 30 days)", createOfferTx.hash, "6️⃣ ");

        // Get the offer ID from the transaction logs
        const offerCreatedEvent = createOfferReceipt.logs.find(log => {
            try {
                const parsed = p2pLending.interface.parseLog(log);
                return parsed.name === 'LoanOfferCreated';
            } catch {
                return false;
            }
        });
        
        let offerId;
        if (offerCreatedEvent) {
            const parsed = p2pLending.interface.parseLog(offerCreatedEvent);
            offerId = parsed.args.offerId;
            console.log(`📋 Loan Offer ID: ${offerId}`);
        }

        // Step 4: Accept Loan Offer (Borrower side)
        console.log("🤝 STEP 4: ACCEPT LOAN OFFER");
        console.log("=============================");
        
        const borrowerMockToken = mockToken.connect(borrowerWallet);
        const borrowerP2PLending = p2pLending.connect(borrowerWallet);
        
        // Approve collateral
        const approveCollateralTx = await borrowerMockToken.approve(P2P_LENDING_ADDRESS, requiredCollateralAmount);
        await approveCollateralTx.wait();
        logTransaction("Borrower approved collateral", approveCollateralTx.hash, "7️⃣ ");
        
        const acceptOfferTx = await borrowerP2PLending.acceptLoanOffer(
            offerId,
            requiredCollateralAmount, 
            MOCK_TOKEN_ADDRESS
        );
        const acceptOfferReceipt = await acceptOfferTx.wait();
        logTransaction("Loan offer accepted! Loan is now active", acceptOfferTx.hash, "8️⃣ ");

        // Get the agreement ID from the transaction logs
        const agreementCreatedEvent = acceptOfferReceipt.logs.find(log => {
            try {
                const parsed = p2pLending.interface.parseLog(log);
                return parsed.name === 'LoanAgreementCreated';
            } catch {
                return false;
            }
        });
        
        let agreementId;
        if (agreementCreatedEvent) {
            const parsed = p2pLending.interface.parseLog(agreementCreatedEvent);
            agreementId = parsed.args.agreementId;
            console.log(`📋 Loan Agreement ID: ${agreementId}`);
        }

        await checkBalances();

        // Step 5: Make Partial Repayment
        console.log("💸 STEP 5: PARTIAL REPAYMENT");
        console.log("=============================");
        
        const partialPayment = ethers.parseUnits("500", 18); // Pay back 500 TUSDC
        
        // Mint some tokens to borrower for repayment
        const mintForRepaymentTx = await mockToken.mint(borrowerWallet.address, partialPayment);
        await mintForRepaymentTx.wait();
        logTransaction("Minted repayment tokens to borrower", mintForRepaymentTx.hash, "9️⃣ ");
        
        // Approve repayment amount
        const approveRepaymentTx = await borrowerMockToken.approve(P2P_LENDING_ADDRESS, partialPayment);
        await approveRepaymentTx.wait();
        logTransaction("Approved partial repayment", approveRepaymentTx.hash, "🔟 ");
        
        const repaymentTx = await borrowerP2PLending.repayLoan(agreementId, partialPayment);
        await repaymentTx.wait();
        logTransaction("Partial repayment made (500 TUSDC)", repaymentTx.hash, "1️⃣1️⃣ ");

        // Step 6: Get Loan Status
        console.log("📊 STEP 6: LOAN STATUS CHECK");
        console.log("=============================");
        
        const loanDetails = await p2pLending.getLoanAgreement(agreementId);
        console.log("🔍 Current Loan Status:");
        console.log(`   💰 Original Amount: ${ethers.formatUnits(loanDetails.principalAmount, 18)} TUSDC`);
        console.log(`   📈 Interest Rate: ${loanDetails.interestRateBPS / 100}%`);
        console.log(`   ⏰ Duration: ${loanDetails.durationSeconds / 86400} days`);
        console.log(`   🔒 Collateral: ${ethers.formatUnits(loanDetails.collateralAmount, 18)} TUSDC`);
        console.log(`   💸 Amount Paid: ${ethers.formatUnits(loanDetails.amountPaid, 18)} TUSDC`);
        console.log(`   📅 Start Date: ${new Date(Number(loanDetails.startTime) * 1000).toLocaleDateString()}`);
        console.log(`   📅 Due Date: ${new Date(Number(loanDetails.dueDate) * 1000).toLocaleDateString()}`);
        console.log(`   🏷️  Status: ${loanDetails.status}`);
        console.log("");

        // Step 7: Check Reputation Updates
        console.log("⭐ STEP 7: REPUTATION CHECK");
        console.log("===========================");
        
        const lenderReputation = await reputation.getReputationProfile(lenderWallet.address);
        const borrowerReputation = await reputation.getReputationProfile(borrowerWallet.address);
        
        console.log(`👤 Lender Reputation Score: ${lenderReputation.currentReputationScore}`);
        console.log(`   📊 Loans Lent: ${lenderReputation.totalLoansLent}`);
        console.log(`   📊 Loan Offers Created: ${lenderReputation.totalLoanOffersCreated}`);
        console.log("");
        
        console.log(`👤 Borrower Reputation Score: ${borrowerReputation.currentReputationScore}`);
        console.log(`   📊 Loans Borrowed: ${borrowerReputation.totalLoansBorrowed}`);
        console.log(`   📊 On-time Repayments: ${borrowerReputation.totalOnTimeRepayments}`);
        console.log("");

        await checkBalances();

        // Final Summary
        console.log("🎉 DEMO COMPLETE - TRANSACTION SUMMARY");
        console.log("======================================");
        console.log("✅ User registration verified");
        console.log("✅ Loan offer created and accepted");
        console.log("✅ Partial loan repayment made");
        console.log("✅ Reputation system tracking loans");
        console.log("✅ All logic working on Flow testnet!");
        console.log("");
        console.log("🔍 View all contracts on Flow Explorer:");
        console.log(`${FLOW_EXPLORER_BASE}/address/${MOCK_TOKEN_ADDRESS} (Mock USDC Token)`);
        console.log(`${FLOW_EXPLORER_BASE}/address/${USER_REGISTRY_ADDRESS} (User Registry)`);
        console.log(`${FLOW_EXPLORER_BASE}/address/${REPUTATION_ADDRESS} (Reputation System)`);
        console.log(`${FLOW_EXPLORER_BASE}/address/${P2P_LENDING_ADDRESS} (P2P Lending)`);
        
    } catch (error) {
        console.error("❌ Demo failed:", error.message);
        if (error.reason) console.error("   Reason:", error.reason);
    }
}

fullWorkflowDemo().catch(console.error); 