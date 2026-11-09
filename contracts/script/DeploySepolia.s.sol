// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/StockPilotPlans.sol";
import "../src/StockPilotSwapper.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockSlipstreamPool.sol";

/// @notice Full Base Sepolia deployment: registry + swapper + mock USDC,
/// mock tokenized stocks (NVDAc/AAPLc/MSFTc/GOOGLc/METAc) + a fixed-rate
/// mock Slipstream pool per stock, each funded so the real StockPilotSwapper
/// can execute swaps end-to-end on testnet.
/// Usage:
///   forge script script/DeploySepolia.s.sol --rpc-url base-sepolia --broadcast --private-key $DEPLOYER_KEY
/// The deployer key should be a disposable testnet key. Needs Sepolia ETH
/// for gas (Base Sepolia faucet). After deployment, paste the printed
/// addresses into app/index.html CHAIN[84532] and set REGISTRY_ADDRESS /
/// SWAPPER_ADDRESS for the agent service.
/// Prices below are the DexScreener spots at research time (9 Nov 2026),
/// scaled by 1e6; they are mock prices for testnet only.
contract DeploySepolia is Script {
    function run() external {
        vm.startBroadcast();

        StockPilotPlans registry = new StockPilotPlans();
        StockPilotSwapper swapper = new StockPilotSwapper();

        // Mock USDC (6dp). Real Sepolia USDC exists (Circle faucet), but a
        // mock keeps the testnet flow self-contained and free of faucets.
        MockERC20 usdc = new MockERC20("Mock USDC", "mUSDC", 6);

        // Mock stocks (8dp), one per verified symbol.
        MockERC20 nvda = new MockERC20("Mock NVIDIA Corporation", "mNVDAc", 8);
        MockERC20 aapl = new MockERC20("Mock Apple Inc.", "mAAPLc", 8);
        MockERC20 msft = new MockERC20("Mock Microsoft Corporation", "mMSFTc", 8);
        MockERC20 goog = new MockERC20("Mock Alphabet Inc.", "mGOOGLc", 8);
        MockERC20 meta = new MockERC20("Mock Meta Platforms Inc.", "mMETAc", 8);

        // Fixed-rate mock pools. USDC address < stock address, so USDC is
        // token0 in every pool, matching the real pairs.
        MockSlipstreamPool poolNvda = new MockSlipstreamPool(address(usdc), address(nvda), 176840000);
        MockSlipstreamPool poolAapl = new MockSlipstreamPool(address(usdc), address(aapl), 350940000);
        MockSlipstreamPool poolMsft = new MockSlipstreamPool(address(usdc), address(msft), 542550000);
        MockSlipstreamPool poolGoog = new MockSlipstreamPool(address(usdc), address(goog), 293620000);
        MockSlipstreamPool poolMeta = new MockSlipstreamPool(address(usdc), address(meta), 642050000);

        // Fund each pool: enough stock to sell (~$10k worth) and enough
        // USDC to buy back. Fund the deployer with mock USDC too, so the
        // demo wallet can trade immediately.
        usdc.mint(address(poolNvda), 10_000_000000);
        usdc.mint(address(poolAapl), 10_000_000000);
        usdc.mint(address(poolMsft), 10_000_000000);
        usdc.mint(address(poolGoog), 10_000_000000);
        usdc.mint(address(poolMeta), 10_000_000000);
        nvda.mint(address(poolNvda), 60_00000000);   // ~$10k at $176.84
        aapl.mint(address(poolAapl), 30_00000000);   // ~$10k at $350.94
        msft.mint(address(poolMsft), 20_00000000);   // ~$10k at $542.55
        goog.mint(address(poolGoog), 35_00000000);   // ~$10k at $293.62
        meta.mint(address(poolMeta), 16_00000000);   // ~$10k at $642.05
        usdc.mint(msg.sender, 1_000_000000);         // $1,000 demo USDC

        vm.stopBroadcast();

        console.log("=== StockPilot Sepolia deployment ===");
        console.log("StockPilotPlans:", address(registry));
        console.log("StockPilotSwapper:", address(swapper));
        console.log("Mock USDC:", address(usdc));
        console.log("Mock NVDAc:", address(nvda), "pool:", address(poolNvda));
        console.log("Mock AAPLc:", address(aapl), "pool:", address(poolAapl));
        console.log("Mock MSFTc:", address(msft), "pool:", address(poolMsft));
        console.log("Mock GOOGLc:", address(goog), "pool:", address(poolGoog));
        console.log("Mock METAc:", address(meta), "pool:", address(poolMeta));
    }
}
