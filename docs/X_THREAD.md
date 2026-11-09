# StockPilot — draft X thread (build-in-public)

Post as a thread from @ChildLasin once the Sepolia deploy lands (fill in the real addresses/links first). Keep it in the funded-trader voice: receipts, not promises.

---

**1/** Building for Base Stocks Maxxing Season 🧵

I'm building StockPilot — an agentic DCA app for tokenized stocks on Base.

You create a plan ("DCA $10 USDC into NVDAc weekly"). An agent watches it, prepares the swap when it's due, you execute in your wallet. Every execution is recorded on-chain.

No custody. No vault. Just plans + an agent + a swap.

**2/** The stocks are real: Coinbase B20 tokenized stocks on Base (NVDAc, AAPLc, MSFTc, GOOGLc, METAc). 1 token ≈ 1 share. Deep liquidity lives on Aerodrome Slipstream.

First thing I verified on-chain: the correct native USDC is `…bdA02913`. A lookalike address ending `…bd029029` has NO code. That one would have eaten funds.

**3/** Then the fun part: the swap didn't work.

Aerodrome's Slipstream router `0xBE6D…` looks the pool up in the wrong factory → address(0) → revert.

The newer router `0x698C…` doesn't even HAVE `exactInputSingle` in its bytecode, and its `exactInput` derives a pool address that doesn't exist.

The "official" router path is broken for these stocks. Receipts in the repo.

**4/** So I stopped using a router entirely.

StockPilot swaps DIRECTLY against the Slipstream pool — a tiny contract that implements the V3 swap callback itself.

Proven on a Base mainnet fork:
$10 USDC → 5,665,944 NVDAc
Sell it back → $9.99 USDC

The pool works. The router was the problem.

**5/** Two more gotchas while proving it:

- `sqrtPriceLimitX96 = 0` is INVALID. Slipstream reverts `SPL`. You must pass MIN+1 / MAX-1 and enforce slippage with `minOut` instead.
- The pool's `slot0()` return layout differs from stock Uniswap V3. Don't decode it with the V3 ABI.

Both are in the repo with the failing traces.

**6/** The agent side is deliberately boring and safe:

- It never holds keys, never signs, never broadcasts.
- It watches due plans and PREPARES the exact swap (price + calldata).
- You sign in your wallet. The execution is recorded on-chain.

That's the whole trust model: the agent prepares, you decide.

**7/** What's shipped so far:
- StockPilotPlans registry (6 tests)
- StockPilotSwapper (7 mainnet-fork tests, all 5 stocks)
- Sepolia mocks + deploy script (4 tests)
- Agent service with live quotes
- Frontend: connect, live prices, create plan, execute, ad-hoc trade

18 tests green. Repo link below.

**8/** Next: Sepolia deploy → public repo → mainnet deploy → first real plan executed on-chain.

Scoring is 50% real on-chain usage, so the point isn't the demo — it's getting real plans executed and recorded.

Follow along, I'll post every step with receipts. 👇 [repo link]

---
