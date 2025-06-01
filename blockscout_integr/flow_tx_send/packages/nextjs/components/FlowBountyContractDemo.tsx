"use client";

import { useState, useEffect } from "react";
import { parseEther, formatEther } from "viem";
import { useAccount, useWriteContract, useReadContract, useWaitForTransactionReceipt } from "wagmi";
import { useTargetNetwork } from "~~/hooks/scaffold-eth";
import { notification } from "~~/utils/scaffold-eth";
import { getBlockscoutUrl } from "~~/utils/scaffold-eth/blockscoutConfig";

// Mock ABI for the FlowBountyDemo contract
const FLOW_BOUNTY_ABI = [
  {
    "inputs": [{"internalType": "string", "name": "username", "type": "string"}],
    "name": "completeOnboarding",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "performHeavyComputation",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "upgradeToPremium",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address[]", "name": "recipients", "type": "address[]"}, {"internalType": "uint256[]", "name": "amounts", "type": "uint256[]"}],
    "name": "batchTransfer",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "claimActivityRewards",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "bytes", "name": "data", "type": "bytes"}],
    "name": "complexInteraction",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
    "name": "getUserStats",
    "outputs": [
      {"internalType": "uint256", "name": "activity", "type": "uint256"},
      {"internalType": "uint256", "name": "rewards", "type": "uint256"},
      {"internalType": "bool", "name": "isPremium", "type": "bool"},
      {"internalType": "uint256", "name": "tokenBalance", "type": "uint256"},
      {"internalType": "uint256", "name": "joinDate", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getContractStats",
    "outputs": [
      {"internalType": "uint256", "name": "totalUsers", "type": "uint256"},
      {"internalType": "uint256", "name": "totalActivities", "type": "uint256"},
      {"internalType": "uint256", "name": "totalRewards", "type": "uint256"},
      {"internalType": "uint256", "name": "contractBalance", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address", "name": "account", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  }
] as const;

// Deployed contract address on local anvil network
const CONTRACT_ADDRESS = "0x0165878A594ca255338adfa4d48449f69242Eb8F";

export const FlowBountyContractDemo = () => {
  const { address } = useAccount();
  const { targetNetwork } = useTargetNetwork();
  const [username, setUsername] = useState("");

  const [batchRecipients, setBatchRecipients] = useState("");
  const [batchAmounts, setBatchAmounts] = useState("");
  const [complexData, setComplexData] = useState("");
  const [userStats, setUserStats] = useState<any>(null);
  const [contractStats, setContractStats] = useState<any>(null);

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({
    hash,
  });

  // Read user stats
  const { data: userStatsData, error: userStatsError } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: FLOW_BOUNTY_ABI,
    functionName: "getUserStats",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  // Read contract stats
  const { data: contractStatsData, error: contractStatsError } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: FLOW_BOUNTY_ABI,
    functionName: "getContractStats",
    query: {
      enabled: true,
    },
  });

  useEffect(() => {
    if (userStatsError) {
      console.error("User stats read error:", userStatsError);
    }
    
    if (userStatsData && Array.isArray(userStatsData) && userStatsData.length >= 5) {
      try {
        setUserStats({
          activity: userStatsData[0]?.toString() || "0",
          rewards: userStatsData[1]?.toString() || "0",
          isPremium: Boolean(userStatsData[2]),
          tokenBalance: userStatsData[3]?.toString() || "0",
          joinDate: userStatsData[4]?.toString() || "0",
        });
      } catch (error) {
        console.error("Error setting user stats:", error);
        setUserStats(null);
      }
    }
  }, [userStatsData, userStatsError]);

  useEffect(() => {
    if (contractStatsError) {
      console.error("Contract stats read error:", contractStatsError);
    }
    
    if (contractStatsData && Array.isArray(contractStatsData) && contractStatsData.length >= 4) {
      try {
        setContractStats({
          totalUsers: contractStatsData[0]?.toString() || "0",
          totalActivities: contractStatsData[1]?.toString() || "0",
          totalRewards: contractStatsData[2]?.toString() || "0",
          contractBalance: contractStatsData[3]?.toString() || "0",
        });
      } catch (error) {
        console.error("Error setting contract stats:", error);
        setContractStats(null);
      }
    }
  }, [contractStatsData, contractStatsError]);

  const handleOnboarding = async () => {
    if (!address) {
      notification.error("Please connect your wallet first");
      return;
    }
    
    if (!username) {
      notification.error("Please enter a username");
      return;
    }

    try {
      await writeContract({
        address: CONTRACT_ADDRESS,
        abi: FLOW_BOUNTY_ABI,
        functionName: "completeOnboarding",
        args: [username],
        value: parseEther("0.001"),
      });
      notification.success("Onboarding transaction sent!");
    } catch (error: any) {
      const errorMessage = error?.message || error?.reason || "Onboarding failed";
      notification.error(errorMessage);
      console.error("Onboarding error:", error);
    }
  };

  const handlePerformHeavyComputation = async () => {
    if (!address) {
      notification.error("Please connect your wallet first");
      return;
    }

    try {
      await writeContract({
        address: CONTRACT_ADDRESS,
        abi: FLOW_BOUNTY_ABI,
        functionName: "performHeavyComputation",
        value: parseEther("0.001"),
      });
      notification.success("Heavy computation transaction sent!");
    } catch (error: any) {
      const errorMessage = error?.message || error?.reason || "Heavy computation failed";
      notification.error(errorMessage);
      console.error("Heavy computation error:", error);
    }
  };

  const handlePremiumUpgrade = async () => {
    if (!address) {
      notification.error("Please connect your wallet first");
      return;
    }

    try {
      await writeContract({
        address: CONTRACT_ADDRESS,
        abi: FLOW_BOUNTY_ABI,
        functionName: "upgradeToPremium",
        value: parseEther("0.01"),
      });
      notification.success("Premium upgrade transaction sent!");
    } catch (error: any) {
      const errorMessage = error?.message || error?.reason || "Premium upgrade failed";
      notification.error(errorMessage);
      console.error("Premium upgrade error:", error);
    }
  };

  const handleBatchTransfer = async () => {
    if (!address) {
      notification.error("Please connect your wallet first");
      return;
    }

    if (!batchRecipients || !batchAmounts) {
      notification.error("Please fill batch transfer fields");
      return;
    }

    try {
      const recipients = batchRecipients.split(",").map(addr => addr.trim());
      const amounts = batchAmounts.split(",").map(amount => parseEther(amount.trim()));

      await writeContract({
        address: CONTRACT_ADDRESS,
        abi: FLOW_BOUNTY_ABI,
        functionName: "batchTransfer",
        args: [recipients, amounts],
      });
      notification.success("Batch transfer transaction sent!");
    } catch (error: any) {
      const errorMessage = error?.message || error?.reason || "Batch transfer failed";
      notification.error(errorMessage);
      console.error("Batch transfer error:", error);
    }
  };

  const handleClaimRewards = async () => {
    if (!address) {
      notification.error("Please connect your wallet first");
      return;
    }

    try {
      await writeContract({
        address: CONTRACT_ADDRESS,
        abi: FLOW_BOUNTY_ABI,
        functionName: "claimActivityRewards",
      });
      notification.success("Reward claim transaction sent!");
    } catch (error: any) {
      const errorMessage = error?.message || error?.reason || "Reward claim failed";
      notification.error(errorMessage);
      console.error("Reward claim error:", error);
    }
  };

  const handleComplexInteraction = async () => {
    if (!address) {
      notification.error("Please connect your wallet first");
      return;
    }

    try {
      const encodedData = complexData ? `0x${Buffer.from(complexData, 'utf8').toString('hex')}` : "0x";
      
      await writeContract({
        address: CONTRACT_ADDRESS,
        abi: FLOW_BOUNTY_ABI,
        functionName: "complexInteraction",
        args: [encodedData],
        value: parseEther("0.0001"),
      });
      notification.success("Complex interaction transaction sent!");
    } catch (error: any) {
      const errorMessage = error?.message || error?.reason || "Complex interaction failed";
      notification.error(errorMessage);
      console.error("Complex interaction error:", error);
    }
  };

  // Show for local development (anvil) or Flow testnet
  if (targetNetwork.id !== 545 && targetNetwork.id !== 31337) {
    return (
      <div className="card bg-base-100 shadow-xl">
        <div className="card-body">
          <h2 className="card-title">Flow Bounty Contract Demo</h2>
          <p className="text-gray-500">Switch to Flow EVM Testnet (or local network) to interact with the contract</p>
        </div>
      </div>
    );
  }

  if (!address) {
    return (
      <div className="card bg-base-100 shadow-xl">
        <div className="card-body">
          <h2 className="card-title">Flow Bounty Contract Demo</h2>
          <p className="text-gray-500">Connect your wallet to interact with the contract</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Contract Stats */}
      <div className="card bg-base-100 shadow-xl">
        <div className="card-body">
          <h2 className="card-title">📊 Contract Statistics</h2>
          {contractStats && (
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div className="stat">
                <div className="stat-title">Total Users</div>
                <div className="stat-value text-sm">{parseInt(contractStats.totalUsers).toLocaleString()}</div>
              </div>
              <div className="stat">
                <div className="stat-title">Total Activities</div>
                <div className="stat-value text-sm">{parseInt(contractStats.totalActivities).toLocaleString()}</div>
              </div>
              <div className="stat">
                <div className="stat-title">Total Rewards</div>
                <div className="stat-value text-sm">{formatEther(contractStats.totalRewards || "0")} FBT</div>
              </div>
              <div className="stat">
                <div className="stat-title">Contract Balance</div>
                <div className="stat-value text-sm">{formatEther(contractStats.contractBalance || "0")} FLOW</div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* User Stats */}
      {userStats && (
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title">👤 Your Statistics</h2>
            <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
              <div className="stat">
                <div className="stat-title">Activity</div>
                <div className="stat-value text-sm">{userStats.activity}</div>
              </div>
              <div className="stat">
                <div className="stat-title">Rewards</div>
                <div className="stat-value text-sm">{formatEther(userStats.rewards || "0")} FBT</div>
              </div>
              <div className="stat">
                <div className="stat-title">Status</div>
                <div className="stat-value text-sm">
                  <span className={`badge ${userStats.isPremium ? 'badge-success' : 'badge-neutral'}`}>
                    {userStats.isPremium ? 'Premium' : 'Basic'}
                  </span>
                </div>
              </div>
              <div className="stat">
                <div className="stat-title">Token Balance</div>
                <div className="stat-value text-sm">{formatEther(userStats.tokenBalance || "0")} FBT</div>
              </div>
              <div className="stat">
                <div className="stat-title">Join Date</div>
                <div className="stat-value text-sm">
                  {userStats.joinDate && parseInt(userStats.joinDate) > 0 
                    ? new Date(parseInt(userStats.joinDate) * 1000).toLocaleDateString()
                    : "Not joined"
                  }
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Contract Interactions */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Onboarding */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title">🚀 Complete Onboarding</h3>
            <p className="text-sm text-gray-600">Join the platform and receive tokens + optional NFT</p>
            <input
              type="text"
              placeholder="Enter username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="input input-bordered"
            />
            <div className="card-actions">
              <button
                onClick={handleOnboarding}
                disabled={isPending || isConfirming}
                className="btn btn-primary"
              >
                {isPending || isConfirming ? "Processing..." : "Complete Onboarding (0.001 FLOW)"}
              </button>
            </div>
          </div>
        </div>

        {/* Heavy Computation */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title">⚡ Heavy Computation</h3>
            <p className="text-sm text-gray-600">Perform gas-intensive operations for analytics</p>
            <div className="card-actions">
              <button
                onClick={handlePerformHeavyComputation}
                disabled={isPending || isConfirming}
                className="btn btn-primary"
              >
                {isPending || isConfirming ? "Processing..." : "Heavy Computation (0.001 FLOW)"}
              </button>
            </div>
          </div>
        </div>

        {/* Premium Upgrade */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title">⭐ Premium Upgrade</h3>
            <p className="text-sm text-gray-600">Upgrade to premium for 2x rewards and bonuses</p>
            <div className="card-actions">
              <button
                onClick={handlePremiumUpgrade}
                disabled={isPending || isConfirming || userStats?.isPremium}
                className="btn btn-secondary"
              >
                {userStats?.isPremium ? "Already Premium" : 
                 isPending || isConfirming ? "Processing..." : "Upgrade to Premium (0.01 FLOW)"}
              </button>
            </div>
          </div>
        </div>

        {/* Batch Transfer */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title">📤 Batch Transfer</h3>
            <p className="text-sm text-gray-600">Transfer tokens to multiple addresses</p>
            <input
              type="text"
              placeholder="Recipients (comma-separated)"
              value={batchRecipients}
              onChange={(e) => setBatchRecipients(e.target.value)}
              className="input input-bordered mb-2"
            />
            <input
              type="text"
              placeholder="Amounts (comma-separated)"
              value={batchAmounts}
              onChange={(e) => setBatchAmounts(e.target.value)}
              className="input input-bordered"
            />
            <div className="card-actions">
              <button
                onClick={handleBatchTransfer}
                disabled={isPending || isConfirming}
                className="btn btn-primary"
              >
                {isPending || isConfirming ? "Processing..." : "Batch Transfer"}
              </button>
            </div>
          </div>
        </div>

        {/* Claim Rewards */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title">🎁 Claim Activity Rewards</h3>
            <p className="text-sm text-gray-600">Claim rewards based on your activity level</p>
            <div className="card-actions">
              <button
                onClick={handleClaimRewards}
                disabled={isPending || isConfirming || parseInt(userStats?.activity || "0") < 5}
                className="btn btn-success"
              >
                {parseInt(userStats?.activity || "0") < 5 ? "Need 5+ Activity" :
                 isPending || isConfirming ? "Processing..." : "Claim Rewards"}
              </button>
            </div>
          </div>
        </div>

        {/* Complex Interaction */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title">⚡ Complex Interaction</h3>
            <p className="text-sm text-gray-600">Multi-step transaction with advanced analytics</p>
            <input
              type="text"
              placeholder="Optional data"
              value={complexData}
              onChange={(e) => setComplexData(e.target.value)}
              className="input input-bordered"
            />
            <div className="card-actions">
              <button
                onClick={handleComplexInteraction}
                disabled={isPending || isConfirming}
                className="btn btn-accent"
              >
                {isPending || isConfirming ? "Processing..." : "Complex Interaction (0.0001 FLOW)"}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Transaction Status */}
      {hash && (
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title">📋 Latest Transaction</h3>
            <p className="font-mono text-xs break-all">{hash}</p>
            {isConfirming && <p className="text-blue-500">Waiting for confirmation...</p>}
            <a
              href={getBlockscoutUrl('tx', hash)}
              target="_blank"
              rel="noopener noreferrer"
              className="btn btn-outline btn-sm"
            >
              View on Blockscout →
            </a>
          </div>
        </div>
      )}

      {/* Contract Info */}
      <div className="card bg-base-100 shadow-xl">
        <div className="card-body">
          <h2 className="card-title">🏆 Blockscout Features Demonstrated</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <h4 className="font-semibold">✅ Advanced Contract Features</h4>
              <ul className="list-disc list-inside text-sm space-y-1">
                <li>ERC20 token with rewards system</li>
                <li>Premium user upgrades</li>
                <li>Comprehensive event emission</li>
                <li>Advanced state management</li>
              </ul>
            </div>
            <div>
              <h4 className="font-semibold">✅ Transaction Analytics</h4>
              <ul className="list-disc list-inside text-sm space-y-1">
                <li>Multi-step transaction tracking</li>
                <li>Event-driven analytics</li>
                <li>Token transfer monitoring</li>
                <li>Gas usage analytics</li>
              </ul>
            </div>
            <div>
              <h4 className="font-semibold">✅ Contract Verification Ready</h4>
              <ul className="list-disc list-inside text-sm space-y-1">
                <li>Clean, well-documented code</li>
                <li>Standard OpenZeppelin imports</li>
                <li>Comprehensive NatSpec comments</li>
                <li>Verification-friendly structure</li>
              </ul>
            </div>
            <div>
              <h4 className="font-semibold">✅ Explorer Integration</h4>
              <ul className="list-disc list-inside text-sm space-y-1">
                <li>Direct Blockscout links</li>
                <li>Transaction hash tracking</li>
                <li>Contract address verification</li>
                <li>Event log analysis</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}; 