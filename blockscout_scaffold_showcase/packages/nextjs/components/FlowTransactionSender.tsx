"use client";

import { useState } from "react";
import { parseEther } from "viem";
import { useAccount, useSendTransaction, useWaitForTransactionReceipt } from "wagmi";
import { useNotification, useTransactionPopup } from "@blockscout/app-sdk";
import { useTargetNetwork } from "~~/hooks/scaffold-eth";
import { notification } from "~~/utils/scaffold-eth";
import { getBlockscoutUrl } from "~~/utils/scaffold-eth/blockscoutConfig";

export const FlowTransactionSender = () => {
  const { address } = useAccount();
  const { targetNetwork } = useTargetNetwork();
  const [recipient, setRecipient] = useState("");
  const [amount, setAmount] = useState("");
  const [lastTxHash, setLastTxHash] = useState<string | null>(null);

  const { data: hash, isPending, sendTransaction } = useSendTransaction();
  const { openTxToast } = useNotification();
  const { openPopup } = useTransactionPopup();

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  });

  const sendFlowTransaction = async () => {
    if (!recipient || !amount) {
      notification.error("Please enter recipient address and amount");
      return;
    }

    try {
      const txHash = await sendTransaction({
        to: recipient as `0x${string}`,
        value: parseEther(amount),
      });
      
      // Use Blockscout SDK to show transaction toast
      if (hash) {
        await openTxToast(targetNetwork.id.toString(), hash);
        setLastTxHash(hash);
      }
      
      notification.success("Transaction sent!");
    } catch (error) {
      console.error("Transaction failed:", error);
      notification.error("Transaction failed");
    }
  };

  const getTransactionUrl = (txHash: string) => {
    if (targetNetwork.id === 545) { // Flow testnet - Use Blockscout
      return getBlockscoutUrl('tx', txHash);
    }
    return `${targetNetwork.blockExplorers?.default?.url}/tx/${txHash}`;
  };

  return (
    <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-md rounded-3xl">
      <h3 className="text-xl font-bold mb-4">Send Flow Transaction</h3>
      
      {!address ? (
        <p className="text-gray-500">Connect your wallet to send transactions</p>
      ) : (
        <>
          <div className="w-full mb-4">
            <label className="block text-sm font-medium mb-2">Recipient Address</label>
            <input
              type="text"
              placeholder="0x..."
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              className="input input-bordered w-full"
            />
          </div>

          <div className="w-full mb-4">
            <label className="block text-sm font-medium mb-2">Amount (FLOW)</label>
            <input
              type="number"
              step="0.0001"
              placeholder="0.001"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="input input-bordered w-full"
            />
          </div>

          <button
            onClick={sendFlowTransaction}
            disabled={isPending || !recipient || !amount}
            className="btn btn-primary w-full mb-4"
          >
            {isPending ? "Sending..." : "Send Transaction"}
          </button>

          <button
            onClick={() => openPopup({ 
              chainId: targetNetwork.id.toString(),
              address: address 
            })}
            className="btn btn-secondary w-full mb-4"
          >
            View Transaction History
          </button>

          {hash && (
            <div className="w-full">
              <p className="text-sm font-medium mb-2">Transaction Hash:</p>
              <code className="text-xs break-all bg-gray-100 p-2 rounded block mb-2">
                {hash}
              </code>
              
              {isConfirming && <p className="text-blue-500">Waiting for confirmation...</p>}
              {isConfirmed && <p className="text-green-500">Transaction confirmed!</p>}
              
              <a
                href={getTransactionUrl(hash)}
                target="_blank"
                rel="noopener noreferrer"
                className="link link-primary block"
              >
                View on Block Explorer →
              </a>
            </div>
          )}

          <div className="mt-4 text-xs text-gray-500">
            Current Network: {targetNetwork.name} (ID: {targetNetwork.id})
          </div>
        </>
      )}
    </div>
  );
}; 