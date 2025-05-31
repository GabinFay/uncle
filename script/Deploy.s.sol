// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {UserRegistry} from "../src/UserRegistry.sol";
import {Reputation} from "../src/Reputation.sol";
import {P2PLending} from "../src/P2PLending.sol";
// import {Treasury} from "../src/Treasury.sol"; // Removed
// import {SocialVouching} from "../src/SocialVouching.sol"; // Removed

contract Deploy is Script {
    // Existing deployment constants and variables ...
    // address public constant WORLD_ID_ROUTER_OPTIMISM_SEPOLIA = 0x734A416F014C1497E17293A5154932C8084691C0;
    // address public constant WORLD_ID_ROUTER_POLYGON_MUMBAI = 0xABB70f63F3EAB8557Ab4E0c0495E5B59dC55038a; // Example old, check new
    // For World Chain, this will be specific to its testnet/mainnet router address
    address public worldIdRouterAddress; // To be configured via env or args
    string public appIdString = "credease-app-v1"; // Example App ID
    string public actionIdRegisterUserString = "credease-register-user"; // Example Action ID

    function setUp() public {
        // Load from .env or set default for local testing
        worldIdRouterAddress = vm.envAddress("WORLD_ID_ROUTER_ADDRESS");
        if (worldIdRouterAddress == address(0)) {
            // Fallback for local testing if no env var is set - THIS IS NOT A REAL ROUTER
            // In a real deployment, this must be the correct World ID Router for the target chain.
            // For local tests, UserRegistryTest uses a MockWorldIdRouter.
            // For a real local deployment testing World ID, you might deploy World ID's test contracts.
            // console.log("Warning: WORLD_ID_ROUTER_ADDRESS not set, using address(1) as placeholder for local non-WorldID-interacting deployment.");
            worldIdRouterAddress = address(0x1); // Placeholder, will cause issues if interacted with
        }
        string memory envAppId = vm.envString("APP_ID_STRING");
        if (bytes(envAppId).length > 0) {
            appIdString = envAppId;
        }
        string memory envActionId = vm.envString("ACTION_ID_REGISTER_USER_STRING");
        if (bytes(envActionId).length > 0) {
            actionIdRegisterUserString = envActionId;
        }
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(deployerPrivateKey != 0, "PRIVATE_KEY not set in .env");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy UserRegistry
        // console.log("Deploying UserRegistry with Router:", worldIdRouterAddress, ", AppID:", appIdString, ", ActionID:", actionIdRegisterUserString);
        UserRegistry userRegistry = new UserRegistry(worldIdRouterAddress, appIdString, actionIdRegisterUserString);
        // console.log("UserRegistry deployed to:", address(userRegistry));

        // 2. Deploy Reputation Contract
        Reputation reputation = new Reputation(address(userRegistry));
        // console.log("Reputation deployed to:", address(reputation));

        // 3. Deploy P2PLending Contract (LoanContract)
        // P2PLending(UserRegistry, Reputation, Treasury, OApp)
        // Treasury is address(0), OApp is placeholder for now
        address reputationOAppPlaceholder = address(0x2); // Example placeholder
        P2PLending p2pLending = new P2PLending(
            address(userRegistry),
            address(reputation),
            payable(address(0)), // Treasury address (not used for P2P)
            reputationOAppPlaceholder // Placeholder for IReputationOApp
        );
        // console.log("P2PLending deployed to:", address(p2pLending));

        // 4. Set P2P Lending contract address in Reputation contract
        reputation.setP2PLendingContractAddress(address(p2pLending));
        // console.log("P2PLending address set in Reputation contract.");

        // Treasury and SocialVouching removed

        vm.stopBroadcast();
    }
} 