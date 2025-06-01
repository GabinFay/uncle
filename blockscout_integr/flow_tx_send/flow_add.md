# Flow Testnet Integration Guide

## Flow Testnet Chain Integration

### 1. **Chain Definition** (`flowTestnet.ts`)
```typescript
export const flowTestnet = defineChain({
  id: 545,                                    // Flow EVM Testnet Chain ID
  name: "Flow EVM Testnet",
  nativeCurrency: {
    decimals: 18,
    name: "Flow",
    symbol: "FLOW",
  },
  rpcUrls: {
    default: {
      http: ["https://testnet.evm.nodes.onflow.org"],  // Official Flow EVM RPC
    },
  },
  blockExplorers: {
    default: {
      name: "Flow Testnet Explorer",
      url: "https://evm-testnet.flowscan.io",          // FlowScan explorer
      apiUrl: "https://evm-testnet.flowscan.io/api",
    },
  },
  testnet: true,
});
```

### 2. **Scaffold Config** (`scaffold.config.ts`)
```typescript
import { flowTestnet } from "./utils/scaffold-eth/flowTestnet";

const scaffoldConfig = {
  targetNetworks: [chains.foundry, flowTestnet],  // Added Flow alongside Foundry
  onlyLocalBurnerWallet: false,                   // Allow MetaMask connections
  // ... other config
};
```

## Network Switching Implementation

### 3. **Automatic Network Detection** (`RainbowKitCustomConnectButton`)
```typescript
if (chain.unsupported || chain.id !== targetNetwork.id) {
  return <WrongNetworkDropdown />;  // Shows when on wrong network
}
```

### 4. **Network Switch Dropdown** (`WrongNetworkDropdown.tsx`)
- Displays "Wrong network" button when connected to unsupported chain
- Opens dropdown with available networks and disconnect option

### 5. **Network Options** (`NetworkOptions.tsx`)
```typescript
const allowedNetworks = getTargetNetworks();  // Gets [foundry, flowTestnet]

// Shows switch button for each network except current one
{allowedNetworks
  .filter(allowedNetwork => allowedNetwork.id !== chain?.id)
  .map(allowedNetwork => (
    <button onClick={() => switchChain?.({ chainId: allowedNetwork.id })}>
      Switch to {allowedNetwork.name}
    </button>
  ))}
```

## How It Works:

1. **Chain Registration**: Flow testnet (ID: 545) is defined with proper RPC and explorer URLs
2. **Multi-Network Support**: App supports both Foundry local (ID: 31337) and Flow testnet (ID: 545)
3. **Automatic Detection**: When wallet connects to wrong network, shows "Wrong network" dropdown
4. **One-Click Switching**: Users can switch between Foundry and Flow testnet via dropdown
5. **MetaMask Integration**: Disabled burner wallet requirement to allow MetaMask connections

The integration uses Wagmi's `useSwitchChain` hook and Viem's `defineChain` to create a seamless multi-network experience where users can easily switch between local development (Foundry) and Flow testnet for live testing. 