# Blockscout MCP Server

This is a Model Context Protocol (MCP) server implementation for interacting with the Blockscout API. It provides a standardized interface for AI models to interact with the Blockscout API.

## Features

- Support for any Blockscout API endpoint
- Get current block number
- Check account balances
- Get transaction counts (nonces)
- Retrieve block information
- Get transaction details
- Make contract calls

## Prerequisites

- Node.js (v16 or higher)
- npm (Node Package Manager)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd blockscout-mcp
```

2. Install dependencies:
```bash
npm install
```

3. Build the project:
```bash
npm run build
```

4. Install globally:
```bash
npm install -g .
```

This global installation makes the `blockscout-mcp` command available system-wide, which is required for Cursor to find and execute the MCP server.

## Configuration

The server uses the following environment variable:

- `BLOCKSCOUT_API_URL`: The Blockscout API endpoint URL to connect to (e.g., 'https://mainnet.game7.io/api' or 'https://testnet.game7.io/api')

### Cursor MCP Configuration

Add the following to your `mcp.json` file in your Cursor (Settings > MCP > Add New Global Server):

```json
{
  "mcpServers": {
    "blockscout-mcp": {
      "command": "npx",
      "args": ["-y", "blockscout-mcp"],
      "env": {
        "BLOCKSCOUT_API_URL": "YOUR_API_ENDPOINT"
      }
    }
  } 
}
```

This configuration will make the following tools available in Cursor:

- `search`
- `get_transactions`
- `get_blocks`
- `get_token_transfers`
- `get_stats`
- `get_transaction_info`
- `get_transaction_token_transfers`
- `get_transaction_internal_txs`
- `get_transaction_logs`
- `get_block_info`
- `get_block_transactions`
- `get_address_info`
- `get_address_token_transfers`
- `get_token_info`
- `get_token_holders`
- `get_internal_transactions`
- `get_main_page_transactions`
- `get_main_page_blocks`
- `get_indexing_status`
- `get_transaction_chart`
- `get_market_chart`
- `get_transaction_raw_trace`
- `get_transaction_state_changes`
- `get_transaction_summary`
- `get_block_withdrawals`
- `get_address_counters`
- `get_address_internal_transactions`
- `get_address_logs`
- `get_address_blocks_validated`
- `get_address_coin_balance_history`
- `get_address_coin_balance_history_by_day`
- `get_smart_contracts`
- `get_smart_contract_counters`
- `get_smart_contract`
- `get_json_rpc_url`
- `get_account_abstraction_status`
- `get_addresses`
- `get_address_transactions`
- `get_address_token_balances`
- `get_address_tokens`
- `get_address_withdrawals`
- `get_address_nfts`
- `get_address_nft_collections`
- `get_tokens`
- `get_token_transfers_list`
- `get_token_counters`
- `get_token_instances`
- `get_token_instance_by_id`
- `get_token_instance_transfers`
- `get_token_instance_holders`
- `get_token_instance_transfers_count`
- `refetch_token_instance_metadata`
- `get_withdrawals`
- `search_redirect`
