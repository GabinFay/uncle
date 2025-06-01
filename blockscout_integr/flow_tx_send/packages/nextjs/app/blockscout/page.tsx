"use client";

import type { NextPage } from "next";
import { BlockscoutDashboard } from "~~/components/BlockscoutDashboard";
import { FlowBountyContractDemo } from "~~/components/FlowBountyContractDemo";
import { FlowTransactionSender } from "~~/components/FlowTransactionSender";

const BlockscoutPage: NextPage = () => {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="text-center mb-8">
        <h1 className="text-4xl font-bold mb-4">
          🔍 Blockscout Integration Demo
        </h1>
        <p className="text-lg text-gray-600 max-w-2xl mx-auto">
          Comprehensive integration with Blockscout explorer for Flow EVM Testnet. 
          This demo showcases the SDK, REST APIs, and explorer features.
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Transaction Sender */}
        <div className="lg:col-span-1">
          <FlowTransactionSender />
        </div>
        
        {/* Main Dashboard */}
        <div className="lg:col-span-2">
          <BlockscoutDashboard />
        </div>
      </div>

      {/* Contract Interaction Demo */}
      <div className="mt-12">
        <div className="text-center mb-8">
          <h2 className="text-3xl font-bold mb-4">
            🚀 Contract Interaction Demo
          </h2>
          <p className="text-lg text-gray-600 max-w-2xl mx-auto">
            Comprehensive smart contract featuring ERC20+ERC721 tokens, advanced analytics, 
            and complex transaction patterns to showcase Blockscout's capabilities.
          </p>
        </div>
        <FlowBountyContractDemo />
      </div>

      {/* Bounty Information */}
      <div className="mt-12 card bg-gradient-to-r from-blue-50 to-purple-50 shadow-xl">
        <div className="card-body">
          <h2 className="card-title text-center mb-6">🏆 Blockscout Bounty Qualifications</h2>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Best Use of Blockscout */}
            <div className="card bg-white shadow-md">
              <div className="card-body">
                <h3 className="card-title text-lg">⭐ Best Use of Blockscout</h3>
                <p className="text-sm text-gray-600 mb-4">$6,000 Prize Pool</p>
                <ul className="text-sm space-y-2">
                  <li>✅ REST API Integration</li>
                  <li>✅ SDK Implementation</li>
                  <li>✅ Custom Analytics</li>
                  <li>✅ Real-time Data</li>
                  <li>✅ Multi-feature Usage</li>
                </ul>
              </div>
            </div>

            {/* Best SDK Integration */}
            <div className="card bg-white shadow-md">
              <div className="card-body">
                <h3 className="card-title text-lg">📚 Best SDK Integration</h3>
                <p className="text-sm text-gray-600 mb-4">$3,000 Prize Pool</p>
                <ul className="text-sm space-y-2">
                  <li>✅ Transaction Notifications</li>
                  <li>✅ History Popup</li>
                  <li>✅ Real-time Updates</li>
                  <li>✅ Error Handling</li>
                  <li>✅ User Experience</li>
                </ul>
              </div>
            </div>

            {/* Explorer Pool Prize */}
            <div className="card bg-white shadow-md">
              <div className="card-body">
                <h3 className="card-title text-lg">💧 Explorer Pool Prize</h3>
                <p className="text-sm text-gray-600 mb-4">$10,000 Prize Pool</p>
                <ul className="text-sm space-y-2">
                  <li>✅ Primary Explorer</li>
                  <li>✅ Link Integration</li>
                  <li>✅ Contract Verification</li>
                  <li>✅ API Usage</li>
                  <li>✅ Flow Testnet Support</li>
                </ul>
              </div>
            </div>
          </div>

          <div className="text-center mt-6">
            <p className="text-sm text-gray-600">
              This application demonstrates comprehensive Blockscout integration specifically for Flow EVM Testnet (Chain ID: 545).
              <br />
              <strong>Note:</strong> Flow mainnet is not supported by Blockscout at this time.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default BlockscoutPage; 