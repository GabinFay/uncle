// Blockscout Configuration for Flow EVM Testnet
// Note: Only works on testnet, not mainnet as per Flow EVM limitations

export const FLOW_TESTNET_CONFIG = {
  chainId: 545,
  name: "Flow EVM Testnet",
  explorerUrl: "https://evm-testnet.flowscan.io",
  apiUrl: "https://evm-testnet.flowscan.io/api/v2",
  rpcUrl: "https://testnet.evm.nodes.onflow.org",
  currencySymbol: "FLOW",
};

export const BLOCKSCOUT_ENDPOINTS = {
  // Contract verification
  verifyContract: `${FLOW_TESTNET_CONFIG.apiUrl}/smart-contracts`,
  
  // Transaction APIs
  transactions: `${FLOW_TESTNET_CONFIG.apiUrl}/transactions`,
  
  // Address APIs  
  addresses: `${FLOW_TESTNET_CONFIG.apiUrl}/addresses`,
  
  // Token APIs
  tokens: `${FLOW_TESTNET_CONFIG.apiUrl}/tokens`,
  
  // Stats APIs
  stats: `${FLOW_TESTNET_CONFIG.apiUrl}/stats`,
};

export const getBlockscoutUrl = (type: 'tx' | 'address' | 'token', hash: string) => {
  const baseUrl = FLOW_TESTNET_CONFIG.explorerUrl;
  switch (type) {
    case 'tx':
      return `${baseUrl}/tx/${hash}`;
    case 'address':
      return `${baseUrl}/address/${hash}`;
    case 'token':
      return `${baseUrl}/token/${hash}`;
    default:
      return baseUrl;
  }
};

export const getBlockscoutApiUrl = (endpoint: keyof typeof BLOCKSCOUT_ENDPOINTS, params?: string) => {
  const baseEndpoint = BLOCKSCOUT_ENDPOINTS[endpoint];
  return params ? `${baseEndpoint}/${params}` : baseEndpoint;
}; 