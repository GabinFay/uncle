// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/FlowBountyDemo.sol";

contract DeployFlowBountyDemo is Script {
    function run() external {
        // Use the first anvil account's private key
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the FlowBountyDemo contract
        FlowBountyDemo bountyDemo = new FlowBountyDemo();
        
        console.log("FlowBountyDemo deployed to:", address(bountyDemo));
        console.log("Deployer address:", msg.sender);
        console.log("Initial token supply:", bountyDemo.totalSupply());
        
        // Perform initial interactions to generate activity
        bountyDemo.completeOnboarding{value: 0.001 ether}("DeployerUser");
        console.log("Completed onboarding interaction");
        
        bountyDemo.performHeavyComputation{value: 0.001 ether}();
        console.log("Performed heavy computation interaction");

        vm.stopBroadcast();
    }
} 