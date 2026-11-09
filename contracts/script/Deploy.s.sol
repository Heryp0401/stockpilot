// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/StockPilotPlans.sol";
import "../src/StockPilotSwapper.sol";

/// @notice Deploy StockPilotPlans + StockPilotSwapper.
/// Usage:
///   Base Sepolia: forge script script/Deploy.s.sol --rpc-url base-sepolia --broadcast --private-key $DEPLOYER_KEY
///   Base mainnet: forge script script/Deploy.s.sol --rpc-url base --broadcast --private-key $DEPLOYER_KEY
/// The deployer key should be a disposable testnet key for Sepolia. Mainnet
/// deployment is a deliberate, user-approved step (needs ETH for gas).
/// For a full Sepolia setup with mock USDC/stocks/pools, use
/// script/DeploySepolia.s.sol instead.
contract Deploy is Script {
    function run() external returns (StockPilotPlans, StockPilotSwapper) {
        vm.startBroadcast();
        StockPilotPlans registry = new StockPilotPlans();
        StockPilotSwapper swapper = new StockPilotSwapper();
        vm.stopBroadcast();
        console.log("StockPilotPlans deployed at:", address(registry));
        console.log("StockPilotSwapper deployed at:", address(swapper));
        return (registry, swapper);
    }
}
