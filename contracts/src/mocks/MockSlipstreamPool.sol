// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Fixed-rate mock of an Aerodrome Slipstream pool, for Base
/// Sepolia testing only. NOT for mainnet.
/// @dev Implements exactly the interface StockPilotSwapper uses:
/// token0(), token1(), swap(recipient, zeroForOne, amountSpecified,
/// sqrtPriceLimitX96, data). The swap is exact-input at a fixed price:
/// `priceScaled` is the price of ONE token1 in token0 units, scaled by
/// 1e6 (e.g. NVDA $176.84 -> 176840000). The pool must be funded with
/// enough token1 (to sell) and token0 (to buy back). It collects the
/// input via the standard V3 swap callback, exactly like a real pool.
/// The deployer funds each mock pool after deployment; the pool holds no
/// privileges and cannot mint.
interface IERC20Mock {
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface ISwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

contract MockSlipstreamPool {
    address public immutable token0;
    address public immutable token1;
    /// @dev Price of 1 token1 in token0, scaled by 1e6. token0 is 6dp
    /// (USDC) and token1 is 8dp (stock), matching the real pairs.
    uint256 public immutable priceScaled;
    uint24 public constant fee = 500;

    error ExactInputOnly();

    constructor(address _token0, address _token1, uint256 _priceScaled) {
        token0 = _token0;
        token1 = _token1;
        priceScaled = _priceScaled;
    }

    /// @notice Exact-input swap at the fixed price. amountSpecified must
    /// be positive (exact input). Returns the pool's deltas: positive =
    /// pool receives, negative = pool sends.
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1)
    {
        if (amountSpecified <= 0) revert ExactInputOnly();
        uint256 amountIn = uint256(amountSpecified);
        uint256 amountOut;
        if (zeroForOne) {
            // token0 (USDC, 6dp) in -> token1 (stock, 8dp) out.
            amountOut = (amountIn * 100000000) / priceScaled;
            require(IERC20Mock(token1).balanceOf(address(this)) >= amountOut, "pool: insufficient token1");
            ISwapCallback(msg.sender).uniswapV3SwapCallback(int256(amountIn), 0, data);
            require(IERC20Mock(token1).transfer(recipient, amountOut), "pool: send token1 failed");
            amount0 = int256(amountIn);
            amount1 = -int256(amountOut);
        } else {
            // token1 (stock, 8dp) in -> token0 (USDC, 6dp) out.
            amountOut = (amountIn * priceScaled) / 100000000;
            require(IERC20Mock(token0).balanceOf(address(this)) >= amountOut, "pool: insufficient token0");
            ISwapCallback(msg.sender).uniswapV3SwapCallback(0, int256(amountIn), data);
            require(IERC20Mock(token0).transfer(recipient, amountOut), "pool: send token0 failed");
            amount0 = -int256(amountOut);
            amount1 = int256(amountIn);
        }
    }
}
