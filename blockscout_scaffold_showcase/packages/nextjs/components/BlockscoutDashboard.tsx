"use client";

import { useState, useEffect } from "react";
import { useAccount } from "wagmi";
import { useFlowTestnetStats, useBlockscoutApi } from "~~/hooks/scaffold-eth/useBlockscoutApi";
import { getBlockscoutUrl } from "~~/utils/scaffold-eth/blockscoutConfig";
import { useTargetNetwork } from "~~/hooks/scaffold-eth";

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

export const BlockscoutDashboard = () => {
  const { address } = useAccount();
  const { targetNetwork } = useTargetNetwork();
  const { stats, isLoading: statsLoading } = useFlowTestnetStats();
  const { getLatestTransactions, getAddressInfo, isLoading: apiLoading } = useBlockscoutApi();
  
  const [recentTxs, setRecentTxs] = useState<BlockscoutTransaction[]>([]);
  const [addressInfo, setAddressInfo] = useState<any>(null);

  useEffect(() => {
    const fetchData = async () => {
      // Fetch latest transactions
      const transactions = await getLatestTransactions(5);
      if (transactions) {
        // Filter out transactions with missing essential data
        const validTransactions = transactions.filter(tx => 
          tx && tx.hash && tx.from && tx.value !== undefined && tx.status
        );
        setRecentTxs(validTransactions);
      }
      
      // Fetch address info if connected
      if (address) {
        const info = await getAddressInfo(address);
        if (info) {
          setAddressInfo(info);
        }
      }
    };

    fetchData();
  }, [address]);

  const formatValue = (value: string) => {
    try {
      const ethValue = parseFloat(value || '0') / 1e18;
      return ethValue.toFixed(4);
    } catch (error) {
      return '0.0000';
    }
  };

  const formatAddress = (addr: string) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  const formatTimeAgo = (timestamp: string) => {
    try {
      const now = new Date();
      const txTime = new Date(timestamp);
      const diffMs = now.getTime() - txTime.getTime();
      const diffMins = Math.floor(diffMs / 60000);
      
      if (diffMins < 60) return `${diffMins}m ago`;
      const diffHours = Math.floor(diffMins / 60);
      if (diffHours < 24) return `${diffHours}h ago`;
      const diffDays = Math.floor(diffHours / 24);
      return `${diffDays}d ago`;
    } catch (error) {
      return 'Unknown';
    }
  };

  // Only show for Flow testnet
  if (targetNetwork.id !== 545) {
    return (
      <div className="card bg-base-100 shadow-xl">
        <div className="card-body">
          <h2 className="card-title">Blockscout Dashboard</h2>
          <p className="text-gray-500">Switch to Flow EVM Testnet to view Blockscout data</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Network Stats */}
      <div className="card bg-base-100 shadow-xl">
        <div className="card-body">
          <h2 className="card-title flex items-center gap-2">
            <span>📊</span>
            Flow EVM Testnet Stats (Powered by Blockscout)
          </h2>
          
          {statsLoading ? (
            <div className="flex items-center justify-center p-4">
              <span className="loading loading-spinner loading-md"></span>
            </div>
          ) : stats ? (
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div className="stat">
                <div className="stat-title">Total Blocks</div>
                <div className="stat-value text-sm">{parseInt(stats.total_blocks || '0').toLocaleString()}</div>
              </div>
              <div className="stat">
                <div className="stat-title">Total Transactions</div>
                <div className="stat-value text-sm">{parseInt(stats.total_transactions || '0').toLocaleString()}</div>
              </div>
              <div className="stat">
                <div className="stat-title">Total Addresses</div>
                <div className="stat-value text-sm">{parseInt(stats.total_addresses || '0').toLocaleString()}</div>
              </div>
              <div className="stat">
                <div className="stat-title">Avg Block Time</div>
                <div className="stat-value text-sm">{(stats.average_block_time || 0).toFixed(1)}s</div>
              </div>
            </div>
          ) : (
            <p className="text-gray-500">Unable to load network stats</p>
          )}
        </div>
      </div>

      {/* Connected Address Info */}
      {address && addressInfo && (
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title">Your Address Analytics</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="stat">
                <div className="stat-title">Balance</div>
                <div className="stat-value text-sm">{formatValue(addressInfo.coin_balance)} FLOW</div>
              </div>
              <div className="stat">
                <div className="stat-title">Transactions</div>
                <div className="stat-value text-sm">{addressInfo.transactions_count}</div>
              </div>
              <div className="stat">
                <div className="stat-title">Token Transfers</div>
                <div className="stat-value text-sm">{addressInfo.token_transfers_count}</div>
              </div>
            </div>
            <div className="card-actions">
              <a 
                href={getBlockscoutUrl('address', address)} 
                target="_blank" 
                rel="noopener noreferrer"
                className="btn btn-primary btn-sm"
              >
                View on Blockscout →
              </a>
            </div>
          </div>
        </div>
      )}

      {/* Recent Transactions */}
      <div className="card bg-base-100 shadow-xl">
        <div className="card-body">
          <h2 className="card-title">Recent Network Transactions</h2>
          
          {apiLoading ? (
            <div className="flex items-center justify-center p-4">
              <span className="loading loading-spinner loading-md"></span>
            </div>
          ) : recentTxs.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="table table-zebra">
                <thead>
                  <tr>
                    <th>Hash</th>
                    <th>From</th>
                    <th>To</th>
                    <th>Value</th>
                    <th>Status</th>
                    <th>Age</th>
                  </tr>
                </thead>
                <tbody>
                  {recentTxs.map((tx) => (
                    <tr key={tx.hash}>
                      <td>
                        <a 
                          href={getBlockscoutUrl('tx', tx.hash)} 
                          target="_blank" 
                          rel="noopener noreferrer"
                          className="link link-primary font-mono text-xs"
                        >
                          {formatAddress(tx.hash)}
                        </a>
                      </td>
                      <td>
                        <a 
                          href={getBlockscoutUrl('address', tx.from.hash)} 
                          target="_blank" 
                          rel="noopener noreferrer"
                          className="link font-mono text-xs"
                        >
                          {formatAddress(tx.from.hash)}
                        </a>
                      </td>
                      <td>
                        {tx.to ? (
                          <a 
                            href={getBlockscoutUrl('address', tx.to.hash)} 
                            target="_blank" 
                            rel="noopener noreferrer"
                            className="link font-mono text-xs"
                          >
                            {formatAddress(tx.to.hash)}
                          </a>
                        ) : (
                          <span className="text-gray-500 text-xs">Contract Creation</span>
                        )}
                      </td>
                      <td>{formatValue(tx.value)} FLOW</td>
                      <td>
                        <span className={`badge ${tx.status === 'ok' ? 'badge-success' : 'badge-error'}`}>
                          {tx.status}
                        </span>
                      </td>
                      <td className="text-xs">{formatTimeAgo(tx.timestamp)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p className="text-gray-500">No recent transactions found</p>
          )}
          
          <div className="card-actions justify-end">
            <a 
              href="https://evm-testnet.flowscan.io/txs" 
              target="_blank" 
              rel="noopener noreferrer"
              className="btn btn-outline btn-sm"
            >
              View All Transactions →
            </a>
          </div>
        </div>
      </div>

      {/* Blockscout Integration Info */}
      <div className="card bg-base-100 shadow-xl">
        <div className="card-body">
          <h2 className="card-title">🏆 Blockscout Integration Features</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <h3 className="font-semibold">✅ SDK Integration</h3>
              <ul className="list-disc list-inside text-sm space-y-1">
                <li>Transaction toast notifications</li>
                <li>Transaction history popup</li>
                <li>Real-time status updates</li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold">✅ API Integration</h3>
              <ul className="list-disc list-inside text-sm space-y-1">
                <li>Network statistics</li>
                <li>Transaction data</li>
                <li>Address analytics</li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold">✅ Explorer Links</h3>
              <ul className="list-disc list-inside text-sm space-y-1">
                <li>Primary explorer integration</li>
                <li>Direct transaction links</li>
                <li>Address page links</li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold">✅ Flow Testnet</h3>
              <ul className="list-disc list-inside text-sm space-y-1">
                <li>Custom chain configuration</li>
                <li>Testnet-only support</li>
                <li>Blockscout-powered explorer</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}; 