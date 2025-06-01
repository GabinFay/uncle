#!/bin/bash

# Uncle Credit Platform - Flow Testnet Deployment & Integration Script
# This script deploys contracts to Flow testnet and sets up environment files

set -e  # Exit on any error

echo "🚀 Uncle Credit Platform - Flow Testnet Deployment"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env file not found. Creating from .env.example...${NC}"
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "${YELLOW}📝 Please edit .env file with your actual values before running this script again.${NC}"
        exit 1
    else
        echo -e "${RED}❌ .env.example file not found. Please create .env file manually.${NC}"
        exit 1
    fi
fi

# Source environment variables
source .env

# Validate required environment variables
if [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" = "your_private_key_here" ]; then
    echo -e "${RED}❌ PRIVATE_KEY not set in .env file${NC}"
    exit 1
fi

if [ -z "$FLOW_EVM_TESTNET_RPC_URL" ]; then
    echo -e "${RED}❌ FLOW_EVM_TESTNET_RPC_URL not set in .env file${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Environment variables validated${NC}"

# Compile contracts
echo -e "${YELLOW}🔨 Compiling contracts...${NC}"
forge build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Contract compilation failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Contracts compiled successfully${NC}"

# Deploy to Flow testnet
echo -e "${YELLOW}🚀 Deploying contracts to Flow testnet...${NC}"
forge script script/DeployFlow.s.sol:DeployFlow --rpc-url flow_testnet --broadcast --verify -vvvv

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Contracts deployed successfully${NC}"

# Extract contract addresses from the deployment output
echo -e "${YELLOW}📋 Extracting contract addresses...${NC}"

# Get the latest deployment file
DEPLOYMENT_FILE=$(find broadcast/DeployFlow.s.sol -name "*.json" | grep -E "/[0-9]+/" | sort -V | tail -1)

if [ -z "$DEPLOYMENT_FILE" ]; then
    echo -e "${RED}❌ Could not find deployment file${NC}"
    exit 1
fi

echo "Using deployment file: $DEPLOYMENT_FILE"

# Extract addresses using jq (install with: brew install jq or apt-get install jq)
if command -v jq > /dev/null; then
    USER_REGISTRY_ADDRESS=$(cat "$DEPLOYMENT_FILE" | jq -r '.transactions[] | select(.contractName == "UserRegistry") | .contractAddress')
    REPUTATION_ADDRESS=$(cat "$DEPLOYMENT_FILE" | jq -r '.transactions[] | select(.contractName == "Reputation") | .contractAddress')
    P2P_LENDING_ADDRESS=$(cat "$DEPLOYMENT_FILE" | jq -r '.transactions[] | select(.contractName == "P2PLending") | .contractAddress')
else
    echo -e "${YELLOW}⚠️  jq not found. Please manually extract contract addresses from deployment logs${NC}"
    echo "Deployment file location: $DEPLOYMENT_FILE"
fi

# Update .env file with contract addresses
if [ ! -z "$USER_REGISTRY_ADDRESS" ] && [ "$USER_REGISTRY_ADDRESS" != "null" ]; then
    echo -e "${YELLOW}📝 Updating .env with contract addresses...${NC}"
    
    # Use sed to update the .env file
    sed -i.bak "s/USER_REGISTRY_CONTRACT=.*/USER_REGISTRY_CONTRACT=$USER_REGISTRY_ADDRESS/" .env
    sed -i.bak "s/REPUTATION_CONTRACT=.*/REPUTATION_CONTRACT=$REPUTATION_ADDRESS/" .env
    sed -i.bak "s/P2P_LENDING_CONTRACT=.*/P2P_LENDING_CONTRACT=$P2P_LENDING_ADDRESS/" .env
    
    # Remove backup file
    rm .env.bak
    
    echo -e "${GREEN}✅ Contract addresses updated in .env${NC}"
else
    echo -e "${YELLOW}⚠️  Could not automatically extract contract addresses. Please update .env manually.${NC}"
fi

# Create scaffold-eth integration structure
echo -e "${YELLOW}🏗️  Setting up Scaffold-ETH integration...${NC}"

# Create uncle-scaff directory if it doesn't exist
if [ ! -d "uncle-scaff" ]; then
    echo -e "${YELLOW}📦 Creating scaffold-eth 2 structure...${NC}"
    
    # Clone scaffold-eth-2 template
    git clone https://github.com/scaffold-eth/scaffold-eth-2.git uncle-scaff
    cd uncle-scaff
    
    # Install dependencies
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    yarn install
    
    cd ..
    echo -e "${GREEN}✅ Scaffold-ETH structure created${NC}"
else
    echo -e "${GREEN}✅ Scaffold-ETH structure already exists${NC}"
fi

# Copy contracts to scaffold structure
echo -e "${YELLOW}📋 Copying contracts to scaffold structure...${NC}"
mkdir -p uncle-scaff/packages/foundry/contracts
cp src/*.sol uncle-scaff/packages/foundry/contracts/
cp -r src/interfaces uncle-scaff/packages/foundry/contracts/ 2>/dev/null || true

# Copy deployment script
cp script/DeployFlow.s.sol uncle-scaff/packages/foundry/script/

echo -e "${GREEN}✅ Contracts copied to scaffold structure${NC}"

# Create environment files for scaffold
echo -e "${YELLOW}📝 Creating environment files for scaffold...${NC}"

# Create foundry .env
cat > uncle-scaff/packages/foundry/.env << EOF
DEPLOYER_PRIVATE_KEY=$PRIVATE_KEY
FLOW_EVM_TESTNET_RPC_URL=$FLOW_EVM_TESTNET_RPC_URL
P2P_LENDING_CONTRACT=$P2P_LENDING_ADDRESS
USER_REGISTRY_CONTRACT=$USER_REGISTRY_ADDRESS
REPUTATION_CONTRACT=$REPUTATION_ADDRESS
WORLD_ID_APP_ID=$APP_ID_STRING
WORLD_ID_ACTION=$ACTION_ID_REGISTER_USER_STRING
EOF

# Create nextjs .env.local
cat > uncle-scaff/packages/nextjs/.env.local << EOF
NEXT_PUBLIC_ALCHEMY_API_KEY=$NEXT_PUBLIC_ALCHEMY_API_KEY
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=$NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID
P2P_LENDING_CONTRACT=$P2P_LENDING_ADDRESS
USER_REGISTRY_CONTRACT=$USER_REGISTRY_ADDRESS
REPUTATION_CONTRACT=$REPUTATION_ADDRESS
FLOW_EVM_TESTNET_RPC_URL=$FLOW_EVM_TESTNET_RPC_URL
DEPLOYER_PRIVATE_KEY=$PRIVATE_KEY
EOF

echo -e "${GREEN}✅ Environment files created for scaffold${NC}"

# Display summary
echo ""
echo -e "${GREEN}🎉 DEPLOYMENT COMPLETE!${NC}"
echo "================================"
echo -e "${GREEN}Contract Addresses:${NC}"
echo "UserRegistry:  $USER_REGISTRY_ADDRESS"
echo "Reputation:    $REPUTATION_ADDRESS" 
echo "P2PLending:    $P2P_LENDING_ADDRESS"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Navigate to uncle-scaff directory: cd uncle-scaff"
echo "2. Start local blockchain: yarn chain"
echo "3. Deploy contracts locally: yarn deploy"
echo "4. Start frontend: yarn start"
echo "5. Copy uncle app components to packages/nextjs/app/"
echo ""
echo -e "${GREEN}Flow Testnet Details:${NC}"
echo "Chain ID: 545"
echo "Block Explorer: https://evm-testnet.flowscan.io"
echo ""
echo -e "${YELLOW}📁 Files created/updated:${NC}"
echo "- .env (updated with contract addresses)"
echo "- uncle-scaff/ (scaffold-eth structure)"
echo "- uncle-scaff/packages/foundry/.env"
echo "- uncle-scaff/packages/nextjs/.env.local"
echo ""
echo -e "${GREEN}✅ Ready for frontend integration!${NC}" 