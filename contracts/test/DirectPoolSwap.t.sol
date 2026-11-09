// Fork tests — REQUIRE a live Base fork. Run with:
//   forge test --fork-url https://base.publicnode.com
// (Plain `forge test` fails these with a bogus "TF"/OpcodeNotFound: without
// the global --fork-url flag, Foundry's lazy fork does not load the B20
// token bytecode, so the pool's transfer() hits an empty account. With
// --fork-url the state loads correctly and all fork tests pass.)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IERC20Minimal {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface ISlipstreamPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data)
        external returns (int256 amount0, int256 amount1);
}

/// @notice Proves whether the Slipstream CL pool itself can be swapped
/// against directly (bypassing the broken/mismatched router). If this
/// works, the app ships its own tiny swapper contract that calls the
/// pool and implements the callback.
/// Run: forge test --match-contract DirectPoolSwapTest --fork-url base -vv
contract Swapper {
    address public immutable pool;
    address public immutable usdc;
    address public immutable stock;

    constructor(address _pool, address _usdc, address _stock) {
        pool = _pool; usdc = _usdc; stock = _stock;
    }

    /// @notice Swap an exact USDC amount for the stock token. Caller must
    /// have approved this contract to pull `amountIn` USDC.
    function swapExactUsdcForStock(uint256 amountIn, address recipient) external returns (uint256 stockOut) {
        // Pull USDC from caller into this contract (we will pay the pool in the callback).
        require(IERC20Minimal(usdc).transferFrom(msg.sender, address(this), amountIn), "pull failed");
        uint256 before = IERC20Minimal(stock).balanceOf(recipient);
        ISlipstreamPool(pool).swap(
            recipient,
            true, // zeroForOne: USDC (token0) -> stock (token1)
            int256(amountIn), // exact input
            4295128740, // MIN_SQRT_RATIO+1: no effective price limit
            ""
        );
        uint256 afterBal = IERC20Minimal(stock).balanceOf(recipient);
        return afterBal - before;
    }

    /// @notice Uniswap V3 / Slipstream swap callback. The pool calls this
    /// to collect the input token. amount0Delta > 0 means we owe USDC.
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == pool, "not pool");
        if (amount0Delta > 0) {
            require(IERC20Minimal(usdc).transfer(pool, uint256(amount0Delta)), "pay0 failed");
        }
        if (amount1Delta > 0) {
            require(IERC20Minimal(stock).transfer(pool, uint256(amount1Delta)), "pay1 failed");
        }
    }
}

contract DirectPoolSwapTest is Test {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant NVDAC = 0xb20000000000000000000078ee7ce2fE4908108C;
    address constant NVDA_POOL = 0x853F5f1B92b16714Fe6CDA67CAad0856B83C7ab9;
    address constant USER = address(0xBEEF);

    function testDirectPoolSwap() public {
        uint256 fork = vm.createFork(vm.envOr("BASE_FORK_URL", string("https://base.publicnode.com")));
        vm.selectFork(fork);
        // Sanity: pool tokens
        assertEq(ISlipstreamPool(NVDA_POOL).token0(), USDC);
        assertEq(ISlipstreamPool(NVDA_POOL).token1(), NVDAC);

        Swapper swapper = new Swapper(NVDA_POOL, USDC, NVDAC);
        uint256 amountIn = 10_000000;
        deal(USDC, USER, amountIn);
        vm.startPrank(USER);
        IERC20Minimal(USDC).approve(address(swapper), amountIn);
        uint256 out = swapper.swapExactUsdcForStock(amountIn, USER);
        vm.stopPrank();
        assertGt(out, 0);
        assertEq(IERC20Minimal(NVDAC).balanceOf(USER), out);
        assertGt(out, 5_000000);
        assertLt(out, 6_500000);
        emit log_named_uint("NVDAc received direct (8dp)", out);
    }
}
