// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SplitBillFactory.sol";
import "../src/USDC.sol";
import "forge-std/console.sol";

contract SplitBillFactoryScript is Script {
    SplitBillFactory public splitBillFactory;
    USDC public usdc;

    function run() external {
        vm.startBroadcast();
        // Supply 1 mil of USDC
        uint256 initialSupply = 1_000_000 * 10 ** 6;
        // Local Test only, Use real USDC on mainnet or L2 chains
        usdc = new USDC(initialSupply);
        splitBillFactory = new SplitBillFactory(address(usdc));
        vm.stopBroadcast();
    }
}
