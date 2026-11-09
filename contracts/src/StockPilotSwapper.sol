// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title StockPilotSwapper
/// @notice Minimal, non-custodial swapper for Base tokenized stocks.
/// @dev Aerodrome's Slipstream SwapRouter computes pool addresses that do
/// not match the deployed pools (router 0x698C... derives 0x3376... while
/// the real NVDAc pool is 0x853F...), and its exactInputSingle selector
/// is absent from its bytecode. So this contract swaps DIRECTLY against
/// the Slipstream concentrated-liquidity pool, implementing the V3-style
/// swap callback itself. It holds no funds between calls: the caller
/// approves USDC (or the stock) and the contract pulls exactly amountIn,
/// pays the pool in the callback, and sends the output to `recipient`.
/// Proven on a Base mainnet fork: $10 USDC -> 5,674,599 NVDAc (8dp).
interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface ISlipstreamPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1);
}

contract StockPilotSwapper {
    /// @dev V3 price bounds. A limit of MIN+1 (sell token0) / MAX-1 (sell
    /// token1) means "no effective price limit"; slippage is enforced
    /// instead by `minOut`.
    uint160 private constant MIN_SQRT_RATIO = 4295128739;
    uint160 private constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    error Slippage(uint256 received, uint256 minOut);
    error BadPool(address pool, address tokenIn, address tokenOut);
    error CallbackNotPool(address caller, address pool);

    event Swapped(
        address indexed user,
        address indexed pool,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address recipient
    );

    function _zeroForOne(address pool, address tokenIn, address tokenOut) internal view returns (bool) {
        address t0 = ISlipstreamPool(pool).token0();
        address t1 = ISlipstreamPool(pool).token1();
        if (tokenIn == t0 && tokenOut == t1) return true;
        if (tokenIn == t1 && tokenOut == t0) return false;
        revert BadPool(pool, tokenIn, tokenOut);
    }

    /// @dev Performs the pool.swap in a separate frame so the caller keeps
    /// few live stack slots (avoids "stack too deep" on the 5-arg call).
    function _doSwap(address pool, address tokenIn, bool zeroForOne, uint256 amountIn, address recipient)
        internal
        returns (int256 amount0, int256 amount1)
    {
        uint160 limit = zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;
        return ISlipstreamPool(pool).swap(
            recipient, zeroForOne, int256(amountIn), limit, abi.encode(pool, tokenIn)
        );
    }

    /// @notice Swap an exact amount of `tokenIn` for `tokenOut` via a
    /// Slipstream pool. Caller must approve this contract for `amountIn`.
    /// @param pool The Slipstream pool for (tokenIn, tokenOut).
    /// @param tokenIn Input token (USDC when buying a stock).
    /// @param tokenOut Output token (the stock when buying).
    /// @param amountIn Exact input amount (tokenIn decimals).
    /// @param minOut Minimum acceptable output (tokenOut decimals); reverts
    ///        if the pool delivers less.
    /// @param recipient Receives the output tokens.
    /// @return amountOut Tokens delivered to `recipient`.
    function swapExactInput(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minOut,
        address recipient
    ) external returns (uint256 amountOut) {
        bool zeroForOne = _zeroForOne(pool, tokenIn, tokenOut);
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "pull failed");
        (int256 amount0, int256 amount1) = _doSwap(pool, tokenIn, zeroForOne, amountIn, recipient);
        // amount0/amount1 are the pool's deltas: negative = tokens the
        // pool sent out. The output is the token we are buying.
        int256 outDelta = zeroForOne ? amount1 : amount0;
        require(outDelta < 0, "no output");
        amountOut = uint256(-outDelta);
        if (amountOut < minOut) revert Slippage(amountOut, minOut);
        emit Swapped(msg.sender, pool, tokenIn, tokenOut, amountIn, amountOut, recipient);
    }

    /// @notice V3/Slipstream swap callback. Only the pool named in `data`
    /// may call it, and it only ever pays the input token the pool is owed.
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        (address pool, address tokenIn) = abi.decode(data, (address, address));
        if (msg.sender != pool) revert CallbackNotPool(msg.sender, pool);
        if (amount0Delta > 0) {
            require(IERC20(tokenIn).transfer(pool, uint256(amount0Delta)), "pay0 failed");
        } else if (amount1Delta > 0) {
            require(IERC20(tokenIn).transfer(pool, uint256(amount1Delta)), "pay1 failed");
        }
    }
}
