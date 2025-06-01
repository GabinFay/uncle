# Deploying and Interacting with Smart Contracts on Flow Mainnet EVM using Foundry

This document serves as a comprehensive guide to deploying Solidity smart contracts to the Flow Mainnet EVM and interacting with them using Foundry. It covers general principles and provides specific examples for contracts developed in this project.

## 1. General Principles for Deploying to Flow EVM with Foundry

Successfully deploying to Flow's EVM environment with Foundry involves a consistent set of practices:

### a. Foundry Project Configuration (`foundry.toml`)

Your `foundry.toml` file should be configured for the Flow Mainnet EVM. Key aspects include:

*   **RPC Endpoint:** Define an alias for the Flow Mainnet EVM RPC.
    ```toml
    [rpc_endpoints]
    flow_mainnet = "https://mainnet.evm.nodes.onflow.org"
    ```
*   **Etherscan/Block Explorer:** Flow's EVM does not use Etherscan directly for verification in the same way Ethereum does. If you have an `[etherscan]` section for `flow_mainnet`, it's often best to comment it out or ensure it's correctly configured for a compatible Flow explorer API if available, to prevent `forge script` from attempting auto-verification that might fail. For simplicity during deployment, commenting it out is common:
    ```toml
    # [etherscan]
    # flow_mainnet = { key = "DUMMY_KEY", url = "https://flowscan.org/api", chain = 747 } # Ensure this is correct or comment out
    ```
*   **Compiler Settings:** Ensure your Solidity compiler version, optimizer settings, and other configurations (`via_ir = true`) are appropriate for your contracts.
    ```toml
    [profile.default]
    src = "src"
    out = "out"
    libs = ["lib"]
    remappings = ["@openzeppelin/=lib/openzeppelin-contracts/"]
    optimizer = true
    optimizer_runs = 200 # Or your preferred number
    via_ir = true
    ```

### b. Environment Variables (`.env`)

Store sensitive information like private keys in a `.env` file at the root of your Foundry project (e.g., `contracts/.env`). **Never commit this file to version control.**

*   **Example `.env` content:**
    ```env
    FLOW_MAINNET_PRIVATE_KEY=your_flow_mainnet_evm_compatible_private_key_without_0x_prefix
    # Optional: Add other keys like BORROWER_PRIVATE_KEY if testing with multiple accounts
    # BORROWER_PRIVATE_KEY=another_private_key_without_0x_prefix
    ```
*   Create a `.env.example` file to show the required variables.

### c. Solidity Deployment Scripts (`YourContract.s.sol`)

Use Foundry's scripting capabilities for deployments. Create script files (e.g., `script/DeployMyContract.s.sol`).

*   **Key Elements:**
    *   Import `forge-std/Script.sol` and your contract.
    *   Use `vm.startBroadcast()` before deploying your contract instance. The sender for the broadcast is specified when running `forge script` (via `--private-key` and `--sender` or from `foundry.toml`).
    *   Instantiate your contract: `MyContract myContract = new MyContract(constructorArg1, constructorArg2);`.
    *   Use `vm.stopBroadcast()` after all deployment transactions.
    *   Log the deployed contract address using `console.log("MyContract deployed to:", address(myContract));`.
*   **Example Snippet (`script/DeploySimple.s.sol`):**
    ```solidity
    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.18;

    import "forge-std/Script.sol";
    import "forge-std/console.sol";
    import "../src/MySimpleContract.sol"; // Adjust path

    contract DeploySimple is Script {
        function run() public returns (MySimpleContract) {
            vm.startBroadcast(); // Uses sender from CLI

            MySimpleContract simple = new MySimpleContract(); // Assuming no constructor args

            vm.stopBroadcast();
            console.log("MySimpleContract deployed by script to:", address(simple));
            return simple;
        }
    }
    ```

### d. Shell Wrapper Scripts (`deploy_contract.sh`)

Create shell scripts to orchestrate the deployment process. These scripts handle sourcing environment variables and calling `forge script`.

*   **Key Elements:**
    *   `set -e`: Exit immediately if a command fails.
    *   Source the `.env` file: `export $(grep -v '^#' .env | xargs)`.
    *   Verify that necessary environment variables (like `FLOW_MAINNET_PRIVATE_KEY`) are set.
    *   Define the deployer's public address. This should correspond to the `FLOW_MAINNET_PRIVATE_KEY`.
    *   Call `forge script`:
        ```bash
        forge script script/DeployMyContract.s.sol:DeployMyContract \\
            --rpc-url <RPC_ALIAS_OR_URL> \\
            --private-key "$FLOW_MAINNET_PRIVATE_KEY" \\
            --sender "$DEPLOYER_ADDRESS" \\
            --broadcast \\
            -vvvv # For verbose output
        ```
        *   `--rpc-url`: Use the alias from `foundry.toml` (e.g., `flow_mainnet`) or the full URL.
        *   `--private-key`: Pass the raw private key (without `0x` prefix).
        *   `--sender`: Specify the public address of the deployer.
        *   `--broadcast`: Essential to actually execute transactions on the network (not just a dry run).

### e. Interacting with Deployed Contracts (`cast`)

Foundry's `cast` tool is used for sending transactions and calling contract functions.

*   **Reading Data (`cast call`):**
    ```bash
    cast call <CONTRACT_ADDRESS> "functionSignature()(returnType)" --rpc-url <RPC_ALIAS_OR_URL>
    # Example: cast call 0x123... "getValue()(uint256)" --rpc-url flow_mainnet
    ```

*   **Sending Transactions (`cast send`):**
    ```bash
    cast send <CONTRACT_ADDRESS> "functionSignature(inputType)" <ARGUMENT_VALUE> \\
        --rpc-url <RPC_ALIAS_OR_URL> \\
        --private-key <YOUR_RAW_PRIVATE_KEY_WITHOUT_0X> \\
        --legacy # Often required for Flow EVM compatibility
    # Example: cast send 0x123... "setValue(uint256)" 42 --rpc-url flow_mainnet --private-key $MY_PK --legacy
    ```
    *   Ensure your private key is sourced or directly provided.
    *   The `--legacy` flag is frequently necessary for transactions on Flow EVM to be processed correctly.

### f. Flow Mainnet Specifics Summary

*   **RPC URL:** `https://mainnet.evm.nodes.onflow.org`
*   **Chain ID:** `747` (usually inferred by Foundry from the RPC alias).
*   **Verification:** Auto-verification with Etherscan keys usually fails. Comment out the `[etherscan]` section for `flow_mainnet` in `foundry.toml` or ensure a compatible Flow block explorer API is used if verification is attempted.
*   **`cast send --legacy`:** Crucial for sending transactions.

## 2. Prerequisites for Specific Deployments

*   Foundry installed.
*   A Flow Mainnet EVM-compatible account with FLOW tokens for gas.
*   The private key for this account (stored in `.env`).
*   The public address corresponding to the private key.

## 3. Step-by-Step Contract Deployment Examples

The following sections detail the deployment and basic interaction for key contracts in this project. Each assumes you are in the `contracts` directory and have set up your `.env` file.

### a. `Counter.sol` (Simple Example)

**Deployed `Counter.sol` Address (Flow Mainnet EVM):** `0x4491eCbe72569f718977C7cDee251237152bd4A0`

**i. Solidity Deployment Script (`script/DeployCounter.s.sol`)**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Counter.sol"; // Assuming Counter.sol is in src/

contract DeployCounter is Script {
    function run() public returns (Counter) {
        vm.startBroadcast(); // Uses the sender configured via CLI or foundry.toml

        Counter counter = new Counter(); // No constructor arguments for this Counter.sol

        vm.stopBroadcast();
        console.log("Counter deployed by script to:", address(counter));
        return counter;
    }
}
```

**ii. Shell Deployment Script (`deploy_counter_on_flow.sh`)**
```bash
#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Ensure this script is run from the 'contracts' directory
if [ ! -f "foundry.toml" ] || [ ! -d "src" ]; then
  echo "Error: This script must be run from the root of the 'contracts' Foundry project directory." >&2
  exit 1
fi

# Source environment variables from .env file
if [ -f .env ]; then
  echo "Sourcing .env file..."
  export $(grep -v '^#' .env | xargs)
else
  echo "Error: .env file not found in current directory ($(pwd)). Please create it from .env.example and add your FLOW_MAINNET_PRIVATE_KEY." >&2
  exit 1
fi

if [ -z "$FLOW_MAINNET_PRIVATE_KEY" ]; then
  echo "Error: FLOW_MAINNET_PRIVATE_KEY is not set in the environment after sourcing .env." >&2
  echo "Please ensure it is correctly defined in your .env file." >&2
  exit 1
fi

# IMPORTANT: Replace this with your actual deployer address derived from FLOW_MAINNET_PRIVATE_KEY
DEPLOYER_ADDRESS="0xc15f5700cc83830139440ee7b7f96662128405b3"

if [ "$DEPLOYER_ADDRESS" == "0xYourDeployerAddressPlaceholder" ]; then
    echo "Error: DEPLOYER_ADDRESS is still set to the placeholder value." >&2
    echo "Please update this script with the actual public address corresponding to your FLOW_MAINNET_PRIVATE_KEY." >&2
    exit 1
fi

SCRIPT_PATH="script/DeployCounter.s.sol"
RPC_ALIAS="flow_mainnet"

echo "Attempting to deploy Counter.sol via script to Flow Mainnet EVM..."
echo "Using RPC endpoint alias: $RPC_ALIAS"
echo "Deployer address: $DEPLOYER_ADDRESS"

forge script $SCRIPT_PATH:DeployCounter --rpc-url $RPC_ALIAS --private-key "$FLOW_MAINNET_PRIVATE_KEY" --sender "$DEPLOYER_ADDRESS" --broadcast -vvvv

echo "Deployment script finished."
```
Make it executable: `chmod +x contracts/deploy_counter_on_flow.sh`

**iii. Deployment**
Navigate to the `contracts` directory and run:
```bash
./deploy_counter_on_flow.sh
```

**iv. Interaction using `cast`**
Replace `YOUR_COUNTER_ADDRESS` with `0x4491eCbe72569f718977C7cDee251237152bd4A0`. Source your `.env` or replace `$FLOW_MAINNET_PRIVATE_KEY` with the raw key.

*   Read initial `number`:
    ```bash
    cast call YOUR_COUNTER_ADDRESS "number()(uint256)" --rpc-url flow_mainnet
    # Expected output: 0
    ```
*   Set `number` to 42:
    ```bash
    cast send YOUR_COUNTER_ADDRESS "setNumber(uint256)" 42 --rpc-url flow_mainnet --private-key $FLOW_MAINNET_PRIVATE_KEY --legacy
    ```
*   Read `number` again:
    ```bash
    cast call YOUR_COUNTER_ADDRESS "number()(uint256)" --rpc-url flow_mainnet
    # Expected output: 42
    ```
*   Increment `number`:
    ```bash
    cast send YOUR_COUNTER_ADDRESS "increment()" --rpc-url flow_mainnet --private-key $FLOW_MAINNET_PRIVATE_KEY --legacy
    ```
*   Read `number` one last time:
    ```bash
    cast call YOUR_COUNTER_ADDRESS "number()(uint256)" --rpc-url flow_mainnet
    # Expected output: 43
    ```

### b. `UserRegistry.sol`

**Deployed Address:** `0x04251e5d570C0d918a9b27E76766a334Ed7F4ec9`

**i. Solidity Deployment Script (`script/DeployUserRegistry.s.sol`)**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/UserRegistry.sol";

contract DeployUserRegistry is Script {
    function run() public returns (UserRegistry) {
        vm.startBroadcast();
        UserRegistry userRegistry = new UserRegistry();
        vm.stopBroadcast();
        console.log("UserRegistry deployed to:", address(userRegistry));
        return userRegistry;
    }
}
```

**ii. Shell Script (`deploy_user_registry_on_flow.sh`)**
(Similar structure to `deploy_counter_on_flow.sh`, just change `SCRIPT_PATH` and script name)
```bash
# ... (setup similar to deploy_counter_on_flow.sh) ...
SCRIPT_PATH="script/DeployUserRegistry.s.sol"
# ... (rest of the script similar, calling DeployUserRegistry) ...
forge script $SCRIPT_PATH:DeployUserRegistry --rpc-url $RPC_ALIAS --private-key "$FLOW_MAINNET_PRIVATE_KEY" --sender "$DEPLOYER_ADDRESS" --broadcast -vvvv
```

**iii. Interaction Examples (using `cast`)**
Replace `USER_REGISTRY_ADDRESS` with `0x04251e5d570C0d918a9b27E76766a334Ed7F4ec9`.

*   Check Owner:
    ```bash
    cast call USER_REGISTRY_ADDRESS "owner()(address)" --rpc-url flow_mainnet
    # Expected: Your deployer address (e.g., 0xc15f...)
    ```
*   Register a User (Owner Only):
    ```bash
    cast send USER_REGISTRY_ADDRESS "registerUser(address,bytes32)" 0x1111111111111111111111111111111111111111 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --private-key $FLOW_MAINNET_PRIVATE_KEY --rpc-url flow_mainnet --legacy
    ```
*   Check if User is World ID Verified:
    ```bash
    cast call USER_REGISTRY_ADDRESS "isUserWorldIdVerified(address)(bool)" 0x1111111111111111111111111111111111111111 --rpc-url flow_mainnet
    # Expected: true (after registration)
    ```

### c. `Reputation.sol`

**Deployed Address:** `0xa69F055d1A40938CcB4A76fc0b958E8A1cd376f6`

**Constructor Arguments:**
*   `_userRegistryAddress`: `0x04251e5d570C0d918a9b27E76766a334Ed7F4ec9` (UserRegistry address)

**i. Solidity Deployment Script (`script/DeployReputation.s.sol`)**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Reputation.sol";
import "../src/UserRegistry.sol"; // For type casting if needed

contract DeployReputation is Script {
    address constant USER_REGISTRY_ADDRESS = 0x04251e5d570C0d918a9b27E76766a334Ed7F4ec9; // Deployed UserRegistry

    function run() public returns (Reputation) {
        vm.startBroadcast();
        Reputation reputation = new Reputation(USER_REGISTRY_ADDRESS);
        vm.stopBroadcast();
        console.log("Reputation deployed to:", address(reputation));
        console.log("UserRegistry used:", reputation.userRegistry());
        return reputation;
    }
}
```

**ii. Shell Script (`deploy_reputation_on_flow.sh`)**
(Similar structure, adjust `SCRIPT_PATH` and script name)

**iii. Interaction Examples (using `cast`)**
Replace `REPUTATION_ADDRESS` with `0xa69F055d1A40938CcB4A76fc0b958E8A1cd376f6`.

*   Check UserRegistry Address:
    ```bash
    cast call REPUTATION_ADDRESS "userRegistry()(address)" --rpc-url flow_mainnet
    # Expected: 0x04251e5d570C0d918a9b27E76766a334Ed7F4ec9
    ```
*   Set P2P Lending Contract Address (Owner Only, done after `P2PLending` deployment):
    ```bash
    # P2PLENDING_ADDRESS is 0x80B9227bA27b0DD2096626eD6B2EC90BF626B0c9
    cast send REPUTATION_ADDRESS "setP2PLendingContractAddress(address)" <P2PLENDING_ADDRESS> --private-key $FLOW_MAINNET_PRIVATE_KEY --rpc-url flow_mainnet --legacy
    ```

### d. `P2PLending.sol`

**Deployed Address:** `0x80B9227bA27b0DD2096626eD6B2EC90BF626B0c9`

**Constructor Arguments:**
*   `_userRegistryAddress`: `0x04251e5d570C0d918a9b27E76766a334Ed7F4ec9`
*   `_reputationContractAddress`: `0xa69F055d1A40938CcB4A76fc0b958E8A1cd376f6`
*   `_reputationOAppAddress`: `0x0000000000000000000000000000000000000000`
*   `_treasuryAddressForOldLogic`: `0x0000000000000000000000000000000000000000`

**i. Solidity Deployment Script (`script/DeployP2PLending.s.sol`)**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/P2PLending.sol";
import "../src/interfaces/IReputationOApp.sol"; // For type casting if needed

contract DeployP2PLending is Script {
    address constant USER_REGISTRY_ADDRESS = 0x04251e5d570C0d918a9b27E76766a334Ed7F4ec9;
    address constant REPUTATION_ADDRESS = 0xa69F055d1A40938CcB4A76fc0b958E8A1cd376f6;
    address constant MOCK_OAPP_ADDRESS = address(0); // Or a deployed mock
    address constant MOCK_TREASURY_ADDRESS = address(0); // Or a deployed mock

    function run() public returns (P2PLending) {
        vm.startBroadcast();
        P2PLending p2pLending = new P2PLending(
            USER_REGISTRY_ADDRESS,
            REPUTATION_ADDRESS,
            IReputationOApp(MOCK_OAPP_ADDRESS), // Cast to interface type
            MOCK_TREASURY_ADDRESS
        );
        vm.stopBroadcast();
        console.log("P2PLending deployed to:", address(p2pLending));
        return p2pLending;
    }
}
```

**ii. Shell Script (`deploy_p2p_lending_on_flow.sh`)**
(Similar structure, adjust `SCRIPT_PATH` and script name)

**iii. Interaction Examples (using `cast`)**
Replace `P2PLENDING_ADDRESS` with `0x80B9227bA27b0DD2096626eD6B2EC90BF626B0c9`.

*   Check ReputationContract Address:
    ```bash
    cast call P2PLENDING_ADDRESS "reputationContract()(address)" --rpc-url flow_mainnet
    # Expected: 0xa69F055d1A40938CcB4A76fc0b958E8A1cd376f6
    ```

### e. `MockERC20.sol` (For Testing)

**Deployed Address (MFT):** `0x3d7803318Fc43F57fe29675B81EFA8a9A8Cf9F4b`
**Token Name:** MockFlowToken
**Token Symbol:** MFT

**i. Solidity Deployment Script (`script/DeployMockERC20.s.sol`)**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/mocks/MockERC20.sol";

contract DeployMockERC20 is Script {
    string public constant TOKEN_NAME = "MockFlowToken";
    string public constant TOKEN_SYMBOL = "MFT";

    function run() public returns (MockERC20) {
        vm.startBroadcast();
        MockERC20 mockToken = new MockERC20(TOKEN_NAME, TOKEN_SYMBOL);
        vm.stopBroadcast();
        console.log(TOKEN_NAME, " (", TOKEN_SYMBOL, ") deployed to:", address(mockToken));
        return mockToken;
    }
}
```

**ii. Shell Script (`deploy_mock_erc20_on_flow.sh`)**
(Similar structure, adjust `SCRIPT_PATH` and script name)

**iii. Interaction Example (Minting - Owner Only):**
Replace `MOCK_ERC20_ADDRESS` with `0x3d7803318Fc43F57fe29675B81EFA8a9A8Cf9F4b`.
Replace `RECIPIENT_ADDRESS` and `AMOUNT_TO_MINT_WEIS`.
```bash
cast send MOCK_ERC20_ADDRESS "mint(address,uint256)" RECIPIENT_ADDRESS AMOUNT_TO_MINT_WEIS --rpc-url flow_mainnet --private-key $FLOW_MAINNET_PRIVATE_KEY --legacy
```

## 4. End-to-End P2P Scenario Test (with MockERC20)

This section outlines testing the deployed P2P contracts (`UserRegistry`, `Reputation`, `P2PLending`) through a full loan lifecycle using the deployed `MockERC20` token.

**Key Addresses for this Scenario:**
*   UserRegistry: `0x04251e5d570C0d918a9b27E76766a334Ed7F4ec9`
*   Reputation: `0xa69F055d1A40938CcB4A76fc0b958E8A1cd376f6`
*   P2PLending: `0x80B9227bA27b0DD2096626eD6B2EC90BF626B0c9`
*   MockERC20 (MFT): `0x3d7803318Fc43F57fe29675B81EFA8a9A8Cf9F4b`
*   Lender (Deployer): `0xc15f5700cc83830139440ee7b7f96662128405b3` (uses `$FLOW_MAINNET_PRIVATE_KEY` from `.env`)
*   Borrower: `0x4ddB3e81434cb130512edaa04092E5b17297f1c5` (uses `$BORROWER_PRIVATE_KEY` from `.env`, if set)

**Steps (Conceptual, using `cast`):**

1.  **User Registration (Owner of UserRegistry, i.e., Lender/Deployer):**
    *   Register Lender (`0xc15f...`) with a unique World ID nullifier:
        ```bash
        # Ensure $FLOW_MAINNET_PRIVATE_KEY is the owner of UserRegistry
        cast send 0x0425... "registerOrUpdateUser(address,bytes32)" 0xc15f... 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc --private-key $FLOW_MAINNET_PRIVATE_KEY --rpc-url flow_mainnet --legacy
        ```
    *   Register Borrower (`0x4ddB...`) with a unique World ID nullifier:
        ```bash
        cast send 0x0425... "registerOrUpdateUser(address,bytes32)" 0x4ddB... 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd --private-key $FLOW_MAINNET_PRIVATE_KEY --rpc-url flow_mainnet --legacy
        ```

2.  **Mint MFT (Owner of MFT - typically Lender/Deployer):**
    *   To Lender (`0xc15f...`, 1,000,000 MFT with 18 decimals):
        ```bash
        cast send 0x3d78... "mint(address,uint256)" 0xc15f... 1000000000000000000000000 --private-key $FLOW_MAINNET_PRIVATE_KEY --rpc-url flow_mainnet --legacy
        ```
    *   To Borrower (`0x4ddB...`, 500,000 MFT):
        ```bash
        cast send 0x3d78... "mint(address,uint256)" 0x4ddB... 500000000000000000000000 --private-key $FLOW_MAINNET_PRIVATE_KEY --rpc-url flow_mainnet --legacy
        ```

3.  **Lender: Approve `P2PLending` contract to spend MFT:**
    (Approve 100,000 MFT for the loan offer)
    ```bash
    cast send 0x3d78... "approve(address,uint256)" 0x80B9... 100000000000000000000000 --private-key $FLOW_MAINNET_PRIVATE_KEY --rpc-url flow_mainnet --legacy
    ```

4.  **Lender: Create Loan Offer:**
    (Offer: 50,000 MFT, MFT token `0x3d78...`, 5% interest (500 basis points), 30 days (2592000 seconds), no collateral `address(0)`, collateral amount 0)
    ```bash
    cast send 0x80B9... "createLoanOffer(uint256,address,uint256,uint256,uint256,address)" 50000000000000000000000 0x3d78... 500 2592000 0 0x0000000000000000000000000000000000000000 --private-key $FLOW_MAINNET_PRIVATE_KEY --rpc-url flow_mainnet --legacy
    ```
    *   Note the emitted `LoanOfferCreated` event to get the `offerId`. For this example, let's assume the Offer ID was: `0x3a5d26cde772415af57c337c700e93f20ab5dcaf2769d5495370931640a4e39a`

5.  **Verify Loan Offer Details:**
    ```bash
    cast call 0x80B9... "getLoanOfferDetails(bytes32)((bytes32,address,uint256,address,uint256,uint256,uint256,address,uint8))" 0x3a5d... --rpc-url flow_mainnet
    ```

6.  **Borrower: Accept Loan Offer:**
    (Requires Borrower's private key, e.g., `$BORROWER_PRIVATE_KEY` if set in `.env`)
    ```bash
    # Ensure BORROWER_PRIVATE_KEY is set in .env and corresponds to 0x4ddB...
    cast send 0x80B9... "acceptLoanOffer(bytes32,uint256,address)" 0x3a5d... 0 0x00...00 --private-key $BORROWER_PRIVATE_KEY --rpc-url flow_mainnet --legacy
    ```
    *   Note the emitted `LoanAgreementCreated` event to get the `agreementId`. For this example, Agreement ID: `0x8de8e4b9892627920673bfc2b2915f6491886011bc1297b78ff788af707bc7d1`

7.  **Post-Acceptance Verification:**
    *   Lender MFT Balance: `cast call 0x3d78... "balanceOf(address)(uint256)" 0xc15f... --rpc-url flow_mainnet` (Expected: 950,000 MFT)
    *   Borrower MFT Balance: `cast call 0x3d78... "balanceOf(address)(uint256)" 0x4ddB... --rpc-url flow_mainnet` (Expected: 550,000 MFT)
    *   Agreement Status: `cast call 0x80B9... "getLoanAgreementDetails(bytes32)(bytes32,address,address,uint256,address,uint256,uint256,uint256,uint256,uint256,uint256,uint8)" 0x8de8e4b9892627920673bfc2b2915f6491886011bc1297b78ff788af707bc7d1 --rpc-url flow_mainnet` (Check status, should be `Active` which is enum value 1).

8.  **Borrower: Approve `P2PLending` for Repayment (MFT):**
    (Principal 50,000 + Interest 2,500 = 52,500 MFT)
    ```bash
    cast send 0x3d78... "approve(address,uint256)" 0x80B9... 52500000000000000000000 --private-key $BORROWER_PRIVATE_KEY --rpc-url flow_mainnet --legacy
    ```

9.  **Borrower: Repay Loan:**
    (Repay full amount: 52,500 MFT)
    ```bash
    cast send 0x80B9... "repayP2PLoan(bytes32,uint256)" 0x8de8... 52500000000000000000000 --private-key $BORROWER_PRIVATE_KEY --rpc-url flow_mainnet --legacy
    ```

10. **Post-Repayment Verification:**
    *   Lender MFT Balance: (Expected: 1,002,500 MFT)
        `cast call 0x3d78... "balanceOf(address)(uint256)" 0xc15f... --rpc-url flow_mainnet`
    *   Borrower MFT Balance: (Expected: 497,500 MFT)
        `cast call 0x3d78... "balanceOf(address)(uint256)" 0x4ddB... --rpc-url flow_mainnet`
    *   Agreement Status: (Check status, should be `Repaid`, enum value 2)
        `cast call 0x80B9... "getLoanAgreementDetails(bytes32)(...)" 0x8de8... --rpc-url flow_mainnet`
    *   Lender Reputation (in `Reputation.sol`):
        `cast call 0xa69F055d1A40938CcB4A76fc0b958E8A1cd376f6 "userReputations(address)((uint256,uint256,uint256,uint256,uint256,uint256,uint256))" 0xc15f5700cc83830139440ee7b7f96662128405b3 --rpc-url flow_mainnet` (Expected score: 5 for loans given)
    *   Borrower Reputation (in `Reputation.sol`):
        `cast call 0xa69F055d1A40938CcB4A76fc0b958E8A1cd376f6 "userReputations(address)((uint256,uint256,uint256,uint256,uint256,uint256,uint256))" 0x4ddB3e81434cb130512edaa04092E5b17297f1c5 --rpc-url flow_mainnet` (Expected score: 10 for loans repaid)

(Full contract addresses and function signatures have been abbreviated in comments for readability; use the actual values from the contract code and deployment outputs.)

This comprehensive scenario demonstrates the core P2P lending flow and reputation updates on Flow Mainnet EVM.
---
This concludes the guide for deploying and interacting with these smart contracts on Flow Mainnet EVM using Foundry.