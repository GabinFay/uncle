// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {UserRegistry} from "../src/UserRegistry.sol";
import {Reputation} from "../src/Reputation.sol";
import {P2PLending} from "../src/P2PLending.sol";

contract Deploy is Script {
    function setUp() public {
        // No setup needed for simplified MVP
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(deployerPrivateKey != 0, "PRIVATE_KEY not set in .env");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy UserRegistry (simplified - no World ID)
        console.log("Deploying UserRegistry...");
        UserRegistry userRegistry = new UserRegistry();
        console.log("UserRegistry deployed to:", address(userRegistry));

        // 2. Deploy Reputation Contract
        console.log("Deploying Reputation...");
        Reputation reputation = new Reputation(address(userRegistry));
        console.log("Reputation deployed to:", address(reputation));

        // 3. Deploy P2PLending Contract
        console.log("Deploying P2PLending...");
        P2PLending p2pLending = new P2PLending(
            address(userRegistry),
            address(reputation),
            payable(address(0)), // No treasury for P2P lending
            address(0) // No cross-chain functionality for MVP
        );
        console.log("P2PLending deployed to:", address(p2pLending));

        // 4. Set P2P Lending contract address in Reputation contract
        console.log("Setting P2PLending address in Reputation contract...");
        reputation.setP2PLendingContractAddress(address(p2pLending));
        console.log("Configuration complete!");

        // 5. Log final addresses for easy copying
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("UserRegistry:", address(userRegistry));
        console.log("Reputation:", address(reputation));
        console.log("P2PLending:", address(p2pLending));
        console.log("==========================");

        vm.stopBroadcast();
    }
} 