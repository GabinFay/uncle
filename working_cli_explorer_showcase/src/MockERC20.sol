// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev Simple ERC20 token for testing purposes
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Mint 1 million tokens to deployer
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    /**
     * @dev Mint tokens to any address (for testing)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens from any address (for testing)
     */
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
} 