import { useState, useEffect } from "react";
import { getBlockscoutApiUrl, FLOW_TESTNET_CONFIG } from "~~/utils/scaffold-eth/blockscoutConfig";

interface BlockscoutTransaction {
  hash: string;
  block_number: number;
  from: {
    hash: string;
  };
  to: {
    hash: string;
  } | null;
  value: string;
  gas_price: string;
  gas_used: string;
  status: string;
  timestamp: string;
}

interface BlockscoutStats {
  total_blocks: string;
  total_transactions: string;
  total_addresses: string;
  average_block_time: number;
}

interface AddressInfo {
  hash: string;
  coin_balance: string;
  transactions_count: number;
  token_transfers_count: number;
}

export const useBlockscoutApi = () => {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchData = async <T>(url: string): Promise<T | null> => {
    setIsLoading(true);
    setError(null);
    
    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();
      return data;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Unknown error occurred";
      setError(errorMessage);
      console.error("Blockscout API error:", errorMessage);
      return null;
    } finally {
      setIsLoading(false);
    }
  };

  const getAddressTransactions = async (address: string, limit = 10): Promise<BlockscoutTransaction[] | null> => {
    const url = `${getBlockscoutApiUrl('addresses', address)}/transactions?limit=${limit}`;
    const response = await fetchData<{ items: BlockscoutTransaction[] }>(url);
    return response?.items || null;
  };

  const getTransactionDetails = async (hash: string): Promise<BlockscoutTransaction | null> => {
    const url = `${getBlockscoutApiUrl('transactions', hash)}`;
    return await fetchData<BlockscoutTransaction>(url);
  };

  const getAddressInfo = async (address: string): Promise<AddressInfo | null> => {
    const url = `${getBlockscoutApiUrl('addresses', address)}`;
    return await fetchData<AddressInfo>(url);
  };

  const getNetworkStats = async (): Promise<BlockscoutStats | null> => {
    const url = getBlockscoutApiUrl('stats');
    return await fetchData<BlockscoutStats>(url);
  };

  const getLatestTransactions = async (limit = 10): Promise<BlockscoutTransaction[] | null> => {
    const url = `${getBlockscoutApiUrl('transactions')}?limit=${limit}`;
    const response = await fetchData<{ items: BlockscoutTransaction[] }>(url);
    return response?.items || null;
  };

  return {
    isLoading,
    error,
    getAddressTransactions,
    getTransactionDetails,
    getAddressInfo,
    getNetworkStats,
    getLatestTransactions,
  };
};

export const useFlowTestnetStats = () => {
  const [stats, setStats] = useState<BlockscoutStats | null>(null);
  const { getNetworkStats, isLoading, error } = useBlockscoutApi();

  useEffect(() => {
    const fetchStats = async () => {
      const networkStats = await getNetworkStats();
      if (networkStats) {
        setStats(networkStats);
      }
    };

    fetchStats();
    
    // Refresh stats every 30 seconds
    const interval = setInterval(fetchStats, 30000);
    return () => clearInterval(interval);
  }, []);

  return { stats, isLoading, error };
}; 