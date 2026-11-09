// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StockPilotSwapper.sol";
import "../src/StockPilotPlans.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockSlipstreamPool.sol";

/// @notice End-to-end Sepolia flow without a fork: mock USDC/stock/pool
/// + real StockPilotSwapper + real StockPilotPlans. Proves the exact
/// frontend flow (approve -> swap -> recordExecution) works against the
/// mock pool. Run: forge test --match-contract MockFlowTest -vv
contract MockFlowTest is Test {
    MockERC20 usdc;
    MockERC20 nvda;
    MockSlipstreamPool pool;
    StockPilotSwapper swapper;
    StockPilotPlans registry;
    address user = address(0xBEEF);

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "mUSDC", 6);
        nvda = new MockERC20("Mock NVIDIA", "mNVDAc", 8);
        pool = new MockSlipstreamPool(address(usdc), address(nvda), 176840000);
        swapper = new StockPilotSwapper();
        registry = new StockPilotPlans();
        // Fund pool + user.
        usdc.mint(address(pool), 10_000_000000);
        nvda.mint(address(pool), 60_00000000);
        usdc.mint(user, 1_000_000000);
    }

    function testMockSwapBuy() public {
        vm.startPrank(user);
        usdc.approve(address(swapper), 10_000000);
        uint256 out = swapper.swapExactInput(address(pool), address(usdc), address(nvda), 10_000000, 0, user);
        vm.stopPrank();
        // $10 / $176.84 = 0.05654829 NVDAc (8dp) = 5,654,829
        assertEq(out, 5654829);
        assertEq(nvda.balanceOf(user), 5654829);
        emit log_named_uint("mNVDAc out (8dp)", out);
    }

    function testMockSwapSell() public {
        vm.startPrank(user);
        usdc.approve(address(swapper), 10_000000);
        uint256 bought = swapper.swapExactInput(address(pool), address(usdc), address(nvda), 10_000000, 0, user);
        nvda.approve(address(swapper), bought);
        uint256 back = swapper.swapExactInput(address(pool), address(nvda), address(usdc), bought, 0, user);
        vm.stopPrank();
        // Sell back at the same fixed price: ~$10 minus rounding.
        assertGe(back, 9_999000);
        assertLe(back, 10_000000);
        emit log_named_uint("mUSDC back (6dp)", back);
    }

    function testMockPlanExecuteFlow() public {
        // Create a plan, then execute it via swap + recordExecution.
        vm.startPrank(user);
        uint256 planId = registry.createPlan(address(nvda), 10_000000, 1 hours, 4, "NVDA test DCA");
        usdc.approve(address(swapper), 10_000000);
        uint256 out = swapper.swapExactInput(address(pool), address(usdc), address(nvda), 10_000000, 0, user);
        bytes32 txHash = bytes32(uint256(0x1234));
        registry.recordExecution(planId, 10_000000, out, txHash);
        vm.stopPrank();
        StockPilotPlans.Plan memory pl = registry.getPlan(planId);
        assertEq(pl.executions, 1);
        assertEq(registry.tradeCount(), 0); // recordExecution does not count as a trade
    }

    function testMockMinOutReverts() public {
        vm.startPrank(user);
        usdc.approve(address(swapper), 10_000000);
        vm.expectRevert();
        swapper.swapExactInput(address(pool), address(usdc), address(nvda), 10_000000, 100_000000, user);
        vm.stopPrank();
    }
}
