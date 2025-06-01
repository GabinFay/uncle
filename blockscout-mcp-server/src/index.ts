#!/usr/bin/env node

import {Server} from '@modelcontextprotocol/sdk/server/index.js'
import {StdioServerTransport} from '@modelcontextprotocol/sdk/server/stdio.js'
import {CallToolRequestSchema, ListToolsRequestSchema} from '@modelcontextprotocol/sdk/types.js'
import {z} from 'zod'
import {zodToJsonSchema} from 'zod-to-json-schema'
import fetch from 'node-fetch'
import dotenv from 'dotenv'
import {
  SearchSchema,
  GetTransactionsSchema,
  GetBlocksSchema,
  GetTokenTransfersSchema,
  GetStatsSchema,
  GetTransactionInfoSchema,
  GetTransactionTokenTransfersSchema,
  GetTransactionInternalTxsSchema,
  GetTransactionLogsSchema,
  GetBlockInfoSchema,
  GetBlockTransactionsSchema,
  GetAddressInfoSchema,
  GetAddressTokenTransfersSchema,
  GetTokenInfoSchema,
  GetTokenHoldersSchema,
  GetInternalTransactionsSchema,
  GetIndexingStatusSchema,
  GetTransactionRawTraceSchema,
  GetTransactionStateChangesSchema,
  GetTransactionSummarySchema,
  GetBlockWithdrawalsSchema,
  GetAddressCountersSchema,
  GetAddressInternalTransactionsSchema,
  GetAddressLogsSchema,
  GetAddressCoinBalanceHistorySchema,
  GetAddressCoinBalanceHistoryByDaySchema,
  GetSmartContractsSchema,
  GetSmartContractSchema,
  GetAddressesSchema,
  GetAddressTransactionsSchema,
  GetAddressTokenBalancesSchema,
  GetAddressTokensSchema,
  GetAddressWithdrawalsSchema,
  GetAddressNFTSchema,
  GetAddressNFTCollectionsSchema,
  GetTokensSchema,
  GetTokenTransfersListSchema,
  GetTokenCountersSchema,
  GetWithdrawalsSchema,
} from './zodSchemas.js'

dotenv.config()

// Create server instance
const server = new Server(
  {
    name: 'blockscout-mcp',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  },
)

// Handle list tools request
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'search',
        description: 'Search for addresses, transactions, tokens, etc',
        inputSchema: zodToJsonSchema(SearchSchema),
      },
      {
        name: 'get_transactions',
        description: 'Get list of transactions with optional filters',
        inputSchema: zodToJsonSchema(GetTransactionsSchema),
      },
      {
        name: 'get_blocks',
        description: 'Get list of blocks',
        inputSchema: zodToJsonSchema(GetBlocksSchema),
      },
      {
        name: 'get_token_transfers',
        description: 'Get list of token transfers',
        inputSchema: zodToJsonSchema(GetTokenTransfersSchema),
      },
      {
        name: 'get_stats',
        description: 'Get network statistics',
        inputSchema: zodToJsonSchema(GetStatsSchema),
      },
      {
        name: 'get_transaction_info',
        description: 'Get detailed information about a specific transaction',
        inputSchema: zodToJsonSchema(GetTransactionInfoSchema),
      },
      {
        name: 'get_transaction_token_transfers',
        description: 'Get token transfers for a specific transaction',
        inputSchema: zodToJsonSchema(GetTransactionTokenTransfersSchema),
      },
      {
        name: 'get_transaction_internal_txs',
        description: 'Get internal transactions for a specific transaction',
        inputSchema: zodToJsonSchema(GetTransactionInternalTxsSchema),
      },
      {
        name: 'get_transaction_logs',
        description: 'Get logs for a specific transaction',
        inputSchema: zodToJsonSchema(GetTransactionLogsSchema),
      },
      {
        name: 'get_block_info',
        description: 'Get detailed information about a specific block',
        inputSchema: zodToJsonSchema(GetBlockInfoSchema),
      },
      {
        name: 'get_block_transactions',
        description: 'Get transactions for a specific block',
        inputSchema: zodToJsonSchema(GetBlockTransactionsSchema),
      },
      {
        name: 'get_address_info',
        description: 'Get detailed information about an address',
        inputSchema: zodToJsonSchema(GetAddressInfoSchema),
      },
      {
        name: 'get_address_token_transfers',
        description: 'Get token transfers for an address',
        inputSchema: zodToJsonSchema(GetAddressTokenTransfersSchema),
      },
      {
        name: 'get_token_info',
        description: 'Get detailed information about a token',
        inputSchema: zodToJsonSchema(GetTokenInfoSchema),
      },
      {
        name: 'get_token_holders',
        description: 'Get list of token holders',
        inputSchema: zodToJsonSchema(GetTokenHoldersSchema),
      },
      {
        name: 'get_internal_transactions',
        description: 'Get list of internal transactions',
        inputSchema: zodToJsonSchema(GetInternalTransactionsSchema),
      },
      {
        name: 'get_indexing_status',
        description: 'Get indexing status',
        inputSchema: zodToJsonSchema(GetIndexingStatusSchema),
      },
      {
        name: 'get_transaction_raw_trace',
        description: 'Get transaction raw trace',
        inputSchema: zodToJsonSchema(GetTransactionRawTraceSchema),
      },
      {
        name: 'get_transaction_state_changes',
        description: 'Get transaction state changes',
        inputSchema: zodToJsonSchema(GetTransactionStateChangesSchema),
      },
      {
        name: 'get_transaction_summary',
        description: 'Get human-readable transaction summary',
        inputSchema: zodToJsonSchema(GetTransactionSummarySchema),
      },
      {
        name: 'get_block_withdrawals',
        description: 'Get block withdrawals',
        inputSchema: zodToJsonSchema(GetBlockWithdrawalsSchema),
      },
      {
        name: 'get_address_counters',
        description: 'Get address counters',
        inputSchema: zodToJsonSchema(GetAddressCountersSchema),
      },
      {
        name: 'get_address_internal_transactions',
        description: 'Get address internal transactions',
        inputSchema: zodToJsonSchema(GetAddressInternalTransactionsSchema),
      },
      {
        name: 'get_address_logs',
        description: 'Get address logs',
        inputSchema: zodToJsonSchema(GetAddressLogsSchema),
      },
      {
        name: 'get_address_coin_balance_history',
        description: 'Get address coin balance history',
        inputSchema: zodToJsonSchema(GetAddressCoinBalanceHistorySchema),
      },
      {
        name: 'get_address_coin_balance_history_by_day',
        description: 'Get address coin balance history by day',
        inputSchema: zodToJsonSchema(GetAddressCoinBalanceHistoryByDaySchema),
      },
      {
        name: 'get_smart_contracts',
        description: 'Get verified smart contracts',
        inputSchema: zodToJsonSchema(GetSmartContractsSchema),
      },
      {
        name: 'get_smart_contract',
        description: 'Get smart contract',
        inputSchema: zodToJsonSchema(GetSmartContractSchema),
      },
      {
        name: 'get_addresses',
        description: 'Get addresses',
        inputSchema: zodToJsonSchema(GetAddressesSchema),
      },
      {
        name: 'get_address_transactions',
        description: 'Get transactions for an address',
        inputSchema: zodToJsonSchema(GetAddressTransactionsSchema),
      },
      {
        name: 'get_address_token_balances',
        description: 'Get token balances for an address',
        inputSchema: zodToJsonSchema(GetAddressTokenBalancesSchema),
      },
      {
        name: 'get_address_tokens',
        description: 'Get tokens for an address',
        inputSchema: zodToJsonSchema(GetAddressTokensSchema),
      },
      {
        name: 'get_address_withdrawals',
        description: 'Get withdrawals for an address',
        inputSchema: zodToJsonSchema(GetAddressWithdrawalsSchema),
      },
      {
        name: 'get_address_nft',
        description: 'Get NFTs for an address',
        inputSchema: zodToJsonSchema(GetAddressNFTSchema),
      },
      {
        name: 'get_address_nft_collections',
        description: 'Get NFT collections for an address',
        inputSchema: zodToJsonSchema(GetAddressNFTCollectionsSchema),
      },
      {
        name: 'get_tokens',
        description: 'Get tokens',
        inputSchema: zodToJsonSchema(GetTokensSchema),
      },
      {
        name: 'get_token_transfers_list',
        description: 'Get token transfers list',
        inputSchema: zodToJsonSchema(GetTokenTransfersListSchema),
      },
      {
        name: 'get_token_counters',
        description: 'Get token counters',
        inputSchema: zodToJsonSchema(GetTokenCountersSchema),
      },
      {
        name: 'get_withdrawals',
        description: 'Get withdrawals',
        inputSchema: zodToJsonSchema(GetWithdrawalsSchema),
      },
    ],
  }
})

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  try {
    if (!request.params?.name) {
      throw new Error('Missing tool name')
    }

    if (!request.params.arguments) {
      throw new Error('Missing arguments')
    }

    const BLOCKSCOUT_API_URL = process.env.BLOCKSCOUT_API_URL
    if (!BLOCKSCOUT_API_URL) {
      throw new Error('BLOCKSCOUT_API_URL is not set')
    }

    // Ensure the base URL ends with /v2/
    const baseUrl = BLOCKSCOUT_API_URL.endsWith('/v2/') ? BLOCKSCOUT_API_URL : 
                   BLOCKSCOUT_API_URL.endsWith('/v2') ? BLOCKSCOUT_API_URL + '/' :
                   BLOCKSCOUT_API_URL.endsWith('/') ? BLOCKSCOUT_API_URL + 'v2/' :
                   BLOCKSCOUT_API_URL + '/v2/'

    let endpoint: string
    let queryParams: URLSearchParams = new URLSearchParams()

    switch (request.params.name) {
      case 'search': {
        endpoint = '/search'
        queryParams.append('q', request.params.arguments.q as string)
        break
      }
      case 'get_transactions': {
        endpoint = '/transactions'
        if (request.params.arguments.filter) {
          queryParams.append('filter', request.params.arguments.filter as string)
        }
        if (request.params.arguments.type) {
          queryParams.append('type', request.params.arguments.type as string)
        }
        if (request.params.arguments.method) {
          queryParams.append('method', request.params.arguments.method as string)
        }
        break
      }
      case 'get_blocks': {
        endpoint = '/blocks'
        if (request.params.arguments.type) {
          queryParams.append('type', request.params.arguments.type as string)
        }
        break
      }
      case 'get_token_transfers': {
        endpoint = '/token-transfers'
        break
      }
      case 'get_stats': {
        endpoint = '/stats'
        break
      }
      case 'get_transaction_info': {
        endpoint = `/transactions/${request.params.arguments.transaction_hash}`
        break
      }
      case 'get_transaction_token_transfers': {
        endpoint = `/transactions/${request.params.arguments.transaction_hash}/token-transfers`
        if (request.params.arguments.type) {
          queryParams.append('type', request.params.arguments.type as string)
        }
        break
      }
      case 'get_transaction_internal_txs': {
        endpoint = `/transactions/${request.params.arguments.transaction_hash}/internal-transactions`
        break
      }
      case 'get_transaction_logs': {
        endpoint = `/transactions/${request.params.arguments.transaction_hash}/logs`
        break
      }
      case 'get_block_info': {
        endpoint = `/blocks/${request.params.arguments.block_number_or_hash}`
        break
      }
      case 'get_block_transactions': {
        endpoint = `/blocks/${request.params.arguments.block_number_or_hash}/transactions`
        break
      }
      case 'get_address_info': {
        endpoint = `/addresses/${request.params.arguments.address_hash}`
        break
      }
      case 'get_address_token_transfers': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/token-transfers`
        if (request.params.arguments.type) {
          queryParams.append('type', request.params.arguments.type as string)
        }
        if (request.params.arguments.filter) {
          queryParams.append('filter', request.params.arguments.filter as string)
        }
        break
      }
      case 'get_token_info': {
        endpoint = `/tokens/${request.params.arguments.address_hash}`
        break
      }
      case 'get_token_holders': {
        endpoint = `/tokens/${request.params.arguments.address_hash}/holders`
        break
      }
      case 'get_internal_transactions': {
        endpoint = '/internal-transactions'
        break
      }
      case 'get_main_page_transactions': {
        endpoint = '/main-page/transactions'
        break
      }
      case 'get_main_page_blocks': {
        endpoint = '/main-page/blocks'
        break
      }
      case 'get_indexing_status': {
        endpoint = '/main-page/indexing-status'
        break
      }
      case 'get_transaction_chart': {
        endpoint = '/stats/charts/transactions'
        break
      }
      case 'get_market_chart': {
        endpoint = '/stats/charts/market'
        break
      }
      case 'get_transaction_raw_trace': {
        endpoint = `/transactions/${request.params.arguments.transaction_hash}/raw-trace`
        break
      }
      case 'get_transaction_state_changes': {
        endpoint = `/transactions/${request.params.arguments.transaction_hash}/state-changes`
        break
      }
      case 'get_transaction_summary': {
        endpoint = `/transactions/${request.params.arguments.transaction_hash}/summary`
        break
      }
      case 'get_block_withdrawals': {
        endpoint = `/blocks/${request.params.arguments.block_number_or_hash}/withdrawals`
        break
      }
      case 'get_address_counters': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/counters`
        break
      }
      case 'get_address_internal_transactions': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/internal-transactions`
        if (request.params.arguments.filter) {
          queryParams.append('filter', request.params.arguments.filter as string)
        }
        break
      }
      case 'get_address_logs': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/logs`
        break
      }
      case 'get_address_blocks_validated': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/blocks-validated`
        break
      }
      case 'get_address_coin_balance_history': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/coin-balance-history`
        break
      }
      case 'get_address_coin_balance_history_by_day': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/coin-balance-history-by-day`
        break
      }
      case 'get_smart_contracts': {
        endpoint = '/smart-contracts'
        if (request.params.arguments.q) {
          queryParams.append('q', request.params.arguments.q as string)
        }
        if (request.params.arguments.filter) {
          queryParams.append('filter', request.params.arguments.filter as string)
        }
        break
      }
      case 'get_smart_contract_counters': {
        endpoint = '/smart-contracts/counters'
        break
      }
      case 'get_smart_contract': {
        endpoint = `/smart-contracts/${request.params.arguments.address_hash}`
        break
      }
      case 'get_json_rpc_url': {
        endpoint = '/config/json-rpc-url'
        break
      }
      case 'get_account_abstraction_status': {
        endpoint = '/proxy/account-abstraction/status'
        break
      }
      case 'get_addresses': {
        endpoint = '/addresses'
        break
      }
      case 'get_address_transactions': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/transactions`
        if (request.params.arguments.filter) {
          queryParams.append('filter', request.params.arguments.filter as string)
        }
        break
      }
      case 'get_address_token_balances': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/token-balances`
        break
      }
      case 'get_address_tokens': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/tokens`
        if (request.params.arguments.type) {
          queryParams.append('type', request.params.arguments.type as string)
        }
        break
      }
      case 'get_address_withdrawals': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/withdrawals`
        break
      }
      case 'get_address_nft': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/nft`
        if (request.params.arguments.type) {
          queryParams.append('type', request.params.arguments.type as string)
        }
        break
      }
      case 'get_address_nft_collections': {
        endpoint = `/addresses/${request.params.arguments.address_hash}/nft-collections`
        if (request.params.arguments.type) {
          queryParams.append('type', request.params.arguments.type as string)
        }
        break
      }
      case 'get_tokens': {
        endpoint = '/tokens'
        if (request.params.arguments.q) {
          queryParams.append('q', request.params.arguments.q as string)
        }
        if (request.params.arguments.type) {
          queryParams.append('type', request.params.arguments.type as string)
        }
        break
      }
      case 'get_token_transfers_list': {
        endpoint = `/tokens/${request.params.arguments.address_hash}/transfers`
        break
      }
      case 'get_token_counters': {
        endpoint = `/tokens/${request.params.arguments.address_hash}/counters`
        break
      }
      case 'get_token_instances': {
        endpoint = `/tokens/${request.params.arguments.address_hash}/instances`
        break
      }
      case 'get_token_instance_by_id': {
        endpoint = `/tokens/${request.params.arguments.address_hash}/instances/${request.params.arguments.id}`
        break
      }
      case 'get_token_instance_transfers': {
        endpoint = `/tokens/${request.params.arguments.address_hash}/instances/${request.params.arguments.id}/transfers`
        break
      }
      case 'get_token_instance_holders': {
        endpoint = `/tokens/${request.params.arguments.address_hash}/instances/${request.params.arguments.id}/holders`
        break
      }
      case 'get_token_instance_transfers_count': {
        endpoint = `/tokens/${request.params.arguments.address_hash}/instances/${request.params.arguments.id}/transfers-count`
        break
      }
      case 'refetch_token_instance_metadata': {
        endpoint = `/tokens/${request.params.arguments.address_hash}/instances/${request.params.arguments.id}/metadata`
        queryParams.append('recaptcha_response', request.params.arguments.recaptcha_response as string)
        break
      }
      case 'get_withdrawals': {
        endpoint = `/withdrawals`
        break
      }
      case 'search_redirect': {
        endpoint = '/search/check-redirect'
        queryParams.append('q', request.params.arguments.q as string)
        break
      }
      default:
        throw new Error(`Unknown method: ${request.params.name}`)
    }

    const url = new URL(endpoint.startsWith('/') ? endpoint.slice(1) : endpoint, baseUrl)
    url.search = queryParams.toString()

    const method = request.params.name === 'refetch_token_instance_metadata' ? 'PATCH' : 'GET'
    const headers: Record<string, string> = {
      'Accept': 'application/json',
    }
    
    if (method === 'PATCH') {
      headers['Content-Type'] = 'application/json'
    }

    try {
      const response = await fetch(url.toString(), {
        method,
        headers,
        body: method === 'PATCH' ? JSON.stringify({
          recaptcha_response: request.params.arguments.recaptcha_response
        }) : undefined
      })

      if (!response.ok) {
        const errorText = await response.text()
        throw new Error(`HTTP error! status: ${response.status}, body: ${errorText}`)
      }

      const data = await response.json()

      // Format the response based on the data structure
      let formattedResponse = ''
      if (request.params.name === 'search' && typeof data === 'object' && data !== null) {
        const searchData = data as { items?: Array<{ 
          name?: string;
          type?: string;
          address?: string;
          symbol?: string;
          token_type?: string;
          is_smart_contract_verified?: boolean;
        }> }

        if (searchData.items && Array.isArray(searchData.items)) {
          formattedResponse = searchData.items.map(item => {
            let details = []
            if (item.name) details.push(`Name: ${item.name}`)
            if (item.type) details.push(`Type: ${item.type}`)
            if (item.address) details.push(`Address: ${item.address}`)
            if (item.symbol) details.push(`Symbol: ${item.symbol}`)
            if (item.token_type) details.push(`Token Type: ${item.token_type}`)
            if (item.is_smart_contract_verified) details.push('Verified Contract')
            return details.join('\n')
          }).join('\n\n')

          if (formattedResponse) {
            formattedResponse = `Found ${searchData.items.length} results:\n\n${formattedResponse}`
          } else {
            formattedResponse = 'No results found.'
          }
        } else {
          formattedResponse = 'No results found.'
        }
      } else {
        formattedResponse = JSON.stringify(data, null, 2)
      }

      return {content: [{type: 'text', text: formattedResponse}]}
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        throw new Error(`Invalid input: ${JSON.stringify(error.errors)}`)
      }
      throw error
    }
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      throw new Error(`Invalid input: ${JSON.stringify(error.errors)}`)
    }
    throw new Error(`API call failed: ${error.message}`)
  }
})

// Start server
async function runServer() {
  const transport = new StdioServerTransport()
  await server.connect(transport)
  console.error('Blockscout MCP Server running on stdio')
}

runServer().catch((error) => {
  console.error('Fatal error:', error)
  process.exit(1)
})