// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/UserRegistry.sol";
import "src/Reputation.sol";
import "src/P2PLending.sol";
import "src/interfaces/IReputationOApp.sol"; // For the type if needed, though we deploy a mock/placeholder

// Mock for Reputation OApp for deployment script if no real one is available
contract MockReputationOApp is IReputationOApp {
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IReputationOApp).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function sendReputationToChain(
        uint32 /*_destinationChainId*/,
        address /*_userAddress*/, 
        int256 /*_newReputationScore*/,
        bytes calldata /*_adapterParams*/
    ) external payable override {
        // Mock implementation: do nothing
    }

    function receiveReputationUpdate(
        uint32 /*_sourceChainId*/,
        address /*_userAddress*/, 
        int256 /*_newReputationScore*/
    ) external override {
        // Mock implementation: do nothing
    }

    function getLocalReputation(address /*user*/) external view override returns (int256) {
        // Mock implementation: return a default value
        return 0;
    }

    // Removed setMinDstGas and estimateFee as they are not in the IReputationOApp interface shown above
}

contract DeployContracts is Script {
    address public userRegistryAddress;
    address public reputationAddress;
    address public p2pLendingAddress;
    address public mockReputationOAppAddress;

    function run() external returns (address, address, address) {
        vm.startBroadcast();

        // 1. Deploy UserRegistry
        UserRegistry userRegistry = new UserRegistry();
        userRegistryAddress = address(userRegistry);
        console.log("UserRegistry deployed at:", userRegistryAddress);

        // 2. Deploy Reputation contract, linking to UserRegistry
        Reputation reputation = new Reputation(userRegistryAddress);
        reputationAddress = address(reputation);
        console.log("Reputation deployed at:", reputationAddress);

        // 3. Deploy MockReputationOApp (placeholder for LayerZero OApp)
        MockReputationOApp mockOApp = new MockReputationOApp();
        mockReputationOAppAddress = address(mockOApp);
        console.log("MockReputationOApp deployed at:", mockReputationOAppAddress);

        // 4. Deploy P2PLending contract, linking to UserRegistry, Reputation, and MockOApp
        // The old treasury address parameter is not used in P2P, pass address(0)
        P2PLending p2pLending = new P2PLending(userRegistryAddress, reputationAddress, payable(address(0)), mockReputationOAppAddress);
        p2pLendingAddress = address(p2pLending);
        console.log("P2PLending deployed at:", p2pLendingAddress);

        // 5. Set P2PLending contract address in Reputation contract
        reputation.setP2PLendingContractAddress(p2pLendingAddress);
        console.log("P2PLending address set in Reputation contract.");

        // 6. Transfer ownership of all contracts to a designated owner (e.g., deployer or a multisig)
        // For simplicity in hackathon, could leave as deployer (vm.broadcast() sender)
        // Or explicitly transfer: 
        // address designatedOwner = vm.envAddress("CONTRACT_OWNER_ADDRESS"); // Get from .env
        // if (designatedOwner != address(0)) {
        //     userRegistry.transferOwnership(designatedOwner);
        //     reputation.transferOwnership(designatedOwner);
        //     p2pLending.transferOwnership(designatedOwner);
        //     console.log("Ownership transferred to:", designatedOwner);
        // } else {
        //     console.log("Ownership retained by deployer:", msg.sender);
        // }
        console.log("Ownership of contracts retained by deployer:", msg.sender);


        vm.stopBroadcast();
        return (userRegistryAddress, reputationAddress, p2pLendingAddress);
    }
} 