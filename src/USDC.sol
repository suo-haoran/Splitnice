// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice This is a contract mocking usdc locally,
///         use the real usdc on chain: https://developers.circle.com/stablecoins/usdc-on-main-networks

contract USDC is ERC20 {
    constructor(uint256 initialSupply) ERC20("USD Coin", "USDC") {
        _mint(msg.sender, initialSupply); // Mint to the deployer's address
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
