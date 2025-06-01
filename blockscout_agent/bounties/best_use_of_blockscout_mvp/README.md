# Best Use of Blockscout APIs MVP

This MVP demonstrates using the Blockscout APIs (via the AI agent and its MCP server tools) to perform a more complex analysis of a user's P2P activity on the Flow EVM Testnet.

## Functionality

The `p2p_user_activity_analyzer.py` script will:
1. Take a user's wallet address as input.
2. Take the deployed P2P contract addresses (`UserRegistry`, `Reputation`, `P2PLending`) as input (or read from a config).
3. Instruct the AI agent to:
    a. Fetch all transactions for the user's address (`get_address_transactions` tool).
    b. Identify transactions where the user interacted with any of the P2P contracts.
    c. For each relevant P2P transaction, fetch its event logs (`get_transaction_logs` tool).
    d. Analyze these logs (e.g., looking for `UserRegistered`, `LoanOfferCreated`, `LoanRepaymentMade` events) to understand the user's P2P journey.
    e. Provide a natural language summary of the user's P2P lifecycle on the platform.

## Running the MVP

1.  Ensure the `blockscout-mcp-server` is runnable (`npx -y blockscout-mcp`).
2.  Ensure `blockscout_agent/.env` is configured with `OPENAI_API_KEY` and `BLOCKSCOUT_API_URL=https://evm-testnet.flowscan.io/api`.
3.  Have the P2P contract addresses (UserRegistry, Reputation, P2PLending) ready from your Flow EVM Testnet deployment.
4.  Run the script: `python blockscout_agent/bounties/best_use_of_blockscout_mvp/p2p_user_activity_analyzer.py --user_address <USER_ADDRESS_HERE> --user_registry_address <USER_REGISTRY_ADDRESS> --reputation_address <REPUTATION_ADDRESS> --p2p_lending_address <P2P_LENDING_ADDRESS>`

## Expected Output

The script will print the AI agent's summary of the user's P2P activities, derived from Blockscout data.

This showcases a deeper integration than just fetching raw data, as it involves filtering, multi-step querying, and AI-powered interpretation relevant to the P2P application's domain. 