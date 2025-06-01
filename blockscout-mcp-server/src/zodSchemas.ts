import { z } from "zod"

// Zod schemas for Blockscout API endpoints
export const SearchSchema = z.object({ 
  q: z.string().describe('Search query'),
})

export const GetTransactionsSchema = z.object({
  filter: z.string().optional().describe('Filter: pending | validated'),
  type: z.string().optional().describe('Transaction type: token_transfer,contract_creation,contract_call,coin_transfer,token_creation'),
  method: z.string().optional().describe('Method: approve,transfer,multicall,mint,commit'),
})

export const GetBlocksSchema = z.object({
  type: z.string().optional().describe('Block type: block | uncle | reorg'),
})

export const GetTokenTransfersSchema = z.object({})

export const GetStatsSchema = z.object({})

export const GetTransactionInfoSchema = z.object({
  transaction_hash: z.string().describe('Transaction hash'),
})

export const GetTransactionTokenTransfersSchema = z.object({
  transaction_hash: z.string().describe('Transaction hash'),
  type: z.string().optional().describe('Token type: ERC-20,ERC-721,ERC-1155'),
})

export const GetTransactionInternalTxsSchema = z.object({
  transaction_hash: z.string().describe('Transaction hash'),
})

export const GetTransactionLogsSchema = z.object({
  transaction_hash: z.string().describe('Transaction hash'),
})

export const GetBlockInfoSchema = z.object({
  block_number_or_hash: z.string().describe('Block number or hash'),
})

export const GetBlockTransactionsSchema = z.object({
  block_number_or_hash: z.string().describe('Block number or hash'),
})

export const GetAddressInfoSchema = z.object({
  address_hash: z.string().describe('Address hash'),
})

export const GetAddressTokenTransfersSchema = z.object({
  address_hash: z.string().describe('Address hash'),
  type: z.string().optional().describe('Token type: ERC-20,ERC-721,ERC-1155'),
  filter: z.string().optional().describe('Filter: to | from'),
})

export const GetTokenInfoSchema = z.object({
  address_hash: z.string().describe('Token contract address'),
})

export const GetTokenHoldersSchema = z.object({
  address_hash: z.string().describe('Token contract address'),
})

export const GetInternalTransactionsSchema = z.object({})

export const GetIndexingStatusSchema = z.object({})

export const GetTransactionRawTraceSchema = z.object({
  transaction_hash: z.string().describe('Transaction hash'),
})

export const GetTransactionStateChangesSchema = z.object({
  transaction_hash: z.string().describe('Transaction hash'),
})

export const GetTransactionSummarySchema = z.object({
  transaction_hash: z.string().describe('Transaction hash'),
})

export const GetBlockWithdrawalsSchema = z.object({
  block_number_or_hash: z.string().describe('Block number or hash'),
})

export const GetAddressCountersSchema = z.object({
  address_hash: z.string().describe('Address hash'),
})

export const GetAddressInternalTransactionsSchema = z.object({
  address_hash: z.string().describe('Address hash'),
  filter: z.string().optional().describe('Filter: to | from'),
})

export const GetAddressLogsSchema = z.object({
  address_hash: z.string().describe('Address hash'),
})

export const GetAddressCoinBalanceHistorySchema = z.object({
  address_hash: z.string().describe('Address hash'),
})

export const GetAddressCoinBalanceHistoryByDaySchema = z.object({
  address_hash: z.string().describe('Address hash'),
})

export const GetSmartContractsSchema = z.object({
  q: z.string().optional().describe('Search query'),
  filter: z.string().optional().describe('Filter: vyper | solidity | yul'),
})

export const GetSmartContractSchema = z.object({
  address_hash: z.string().describe('Address hash'),
})

export const GetAddressesSchema = z.object({})

export const GetAddressTransactionsSchema = z.object({
  address_hash: z.string().describe('Address hash'),
  filter: z.string().optional().describe('Filter: to | from'),
})

export const GetAddressTokenBalancesSchema = z.object({
  address_hash: z.string().describe('Address hash'),
})

export const GetAddressTokensSchema = z.object({
  address_hash: z.string().describe('Address hash'),
  type: z.string().optional().describe('Token type: ERC-20,ERC-721,ERC-1155'),
})

export const GetAddressWithdrawalsSchema = z.object({
  address_hash: z.string().describe('Address hash'),
})

export const GetAddressNFTSchema = z.object({
  address_hash: z.string().describe('Address hash'),
  type: z.string().optional().describe('Token type: ERC-721,ERC-404,ERC-1155'),
})

export const GetAddressNFTCollectionsSchema = z.object({
  address_hash: z.string().describe('Address hash'),
  type: z.string().optional().describe('Token type: ERC-721,ERC-404,ERC-1155'),
})

export const GetTokensSchema = z.object({
  q: z.string().optional().describe('Search query for token name or symbol'),
  type: z.string().optional().describe('Token type: ERC-20,ERC-721,ERC-1155'),
})

export const GetTokenTransfersListSchema = z.object({
  address_hash: z.string().describe('Token contract address'),
})

export const GetTokenCountersSchema = z.object({
  address_hash: z.string().describe('Token contract address'),
})

export const GetWithdrawalsSchema = z.object({})