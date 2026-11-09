// Fork tests — REQUIRE a live Base fork. Run with:
//   forge test --fork-url https://base.publicnode.com
// (Plain `forge test` fails these with a bogus "TF"/OpcodeNotFound: without
// the global --fork-url flag, Foundry's lazy fork does not load the B20
// token bytecode, so the pool's transfer() hits an empty account. With
// --fork-url the state loads correctly and all fork tests pass.)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StockPilotSwapper.sol";

/// @notice Fork tests for the production StockPilotSwapper: buys $10 USDC
/// of each of the five verified stocks, sells NVDAc back to USDC, and
/// checks the minOut slippage guard reverts. Run:
/// forge test --match-contract SwapperTest --fork-url base -vv
contract SwapperTest is Test {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant NVDAC = 0xb20000000000000000000078ee7ce2fE4908108C;
    address constant AAPLC = 0xb200000000000000000000C2e324d24d7eEcd1fb;
    address constant MSFTC = 0xB200000000000000000000Ab99cFa739E253872B;
    address constant GOOGLC = 0xb2000000000000000000002D0BA3164cc74f58B7;
    address constant METAC = 0xb2000000000000000000008bC8786B856E61707C;
    address constant NVDA_POOL = 0x853F5f1B92b16714Fe6CDA67CAad0856B83C7ab9;
    address constant AAPL_POOL = 0xA3b1E3f9747065e2073722Ff4c9027d3eA4994F0;
    address constant MSFT_POOL = 0x7103eB3c9590d1281f7dc03b2A9EE27C39dF5D54;
    address constant GOOGL_POOL = 0xB1987CAD1682841b4b641d50E520777eC5Ab5542;
    address constant META_POOL = 0xEAF57753BC382E0324a1D43F72E7027705a2273E;
    address constant USER = address(0xBEEF);

    StockPilotSwapper swapper;

    function setUp() public {
        uint256 fork = vm.createFork(vm.envOr("BASE_FORK_URL", string("https://base.publicnode.com")));
        vm.selectFork(fork);
        swapper = new StockPilotSwapper();
    }

    function _buy(address pool, address stock) internal returns (uint256 out) {
        uint256 amountIn = 10_000000;
        deal(USDC, USER, amountIn);
        vm.startPrank(USER);
        IERC20(USDC).approve(address(swapper), amountIn);
        out = swapper.swapExactInput(pool, USDC, stock, amountIn, 0, USER);
        vm.stopPrank();
        assertEq(IERC20(stock).balanceOf(USER), out);
        assertGt(out, 0);
    }

    function testBuyNvdac() public {
        uint256 out = _buy(NVDA_POOL, NVDAC);
        assertGt(out, 5_000000);
        assertLt(out, 6_500000);
        emit log_named_uint("NVDAc (8dp)", out);
    }

    function testBuyAaplc() public {
        uint256 out = _buy(AAPL_POOL, AAPLC);
        assertGt(out, 2_500000);
        assertLt(out, 3_200000);
        emit log_named_uint("AAPLc (8dp)", out);
    }

    function testBuyMsftc() public {
        uint256 out = _buy(MSFT_POOL, MSFTC);
        assertGt(out, 1_500000);
        assertLt(out, 2_200000);
        emit log_named_uint("MSFTc (8dp)", out);
    }

    function testBuyGooglc() public {
        uint256 out = _buy(GOOGL_POOL, GOOGLC);
        assertGt(out, 3_000000);
        assertLt(out, 3_800000);
        emit log_named_uint("GOOGLc (8dp)", out);
    }

    function testBuyMetac() public {
        uint256 out = _buy(META_POOL, METAC);
        assertGt(out, 1_300000);
        assertLt(out, 1_800000);
        emit log_named_uint("METAc (8dp)", out);
    }

    function testSellNvdacBack() public {
        uint256 bought = _buy(NVDA_POOL, NVDAC);
        vm.startPrank(USER);
        IERC20(NVDAC).approve(address(swapper), bought);
        uint256 usdcBack = swapper.swapExactInput(NVDA_POOL, NVDAC, USDC, bought, 0, USER);
        vm.stopPrank();
        assertGt(usdcBack, 9_000000);
        assertLt(usdcBack, 10_500000);
        emit log_named_uint("USDC back (6dp)", usdcBack);
    }

    function testMinOutReverts() public {
        uint256 amountIn = 10_000000;
        deal(USDC, USER, amountIn);
        vm.startPrank(USER);
        IERC20(USDC).approve(address(swapper), amountIn);
        vm.expectRevert();
        swapper.swapExactInput(NVDA_POOL, USDC, NVDAC, amountIn, 100_000000, USER);
        vm.stopPrank();
    }
}
