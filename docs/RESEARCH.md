# StockPilot research — verified on-chain facts (9 Nov 2026)

All addresses below were verified on-chain via public Base RPCs (base.publicnode.com / mainnet.base.org) and DexScreener. Do not “fix” them from memory.

## Coinbase tokenized stocks (B20)
- 64 tokens total (official roster: base.org/stocks). B20 tokens, **8 decimals**, 1 token ≈ 1 share, issued by Coinbase Onchain SPV Ltd (Regulation S, not offered to US persons).
- Curated list (34, with addresses/NAV/supply): `data/cstocks_curated.json`. Full roster: `data/cstocks_full.json`.
- DexScreener spot prices, 9 Nov 2026: NVDAc $179.68, AAPLc $350.94, MSFTc $542.55, GOOGLc $293.62, METAc $642.05. (Live prices are fetched at runtime; these are research-time reference only.)

## USDC on Base
- **Correct native USDC: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`** (ends `…bdA02913`, 6 decimals, $4.31B supply) — confirmed by Circle's own docs (developers.circle.com) AND on-chain (symbol “USDC”, decimals 6).
- **The similar address ending `…bd029029` has NO code on any Base RPC — it is WRONG. Do not use it.**
- Base Sepolia USDC (Circle docs; faucet.circle.com): `0x036CbD53842c5426634e7929541eC2318f3dCF7e`.

## Where the liquidity is: Aerodrome Slipstream (CL)
- Deep liquidity is on **Aerodrome Slipstream** (concentrated liquidity, Uniswap-V3 fork). **Uniswap V3 has NO USDC/stock pools at any fee tier** (verified: `getPool` returns `0x0` for NVDAc/AAPLc/TSLAc/GOOGLc at fees 100/500/3000/10000).
- **DexScreener “top” USDC pairs live in factory `0x9CB220581b91b0C83223012FE69688b92aD07a76` and are NOT routable by any known public router** — do not use them for swaps. Their fees (read on-chain): NVDAc 1295, AAPLc 326, MSFTc 252, GOOGLc 328, METAc 700.
- **Routable pools live in the newest official Aerodrome CLFactory `0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef`, all tickSpacing=10, fee=500, with real liquidity.** Verified 9 Nov 2026 (each pool's `token0` = USDC, `token1` = the stock):

| Stock | Token | Pool | Liquidity (on-chain) |
|---|---|---|---|
| NVDAc | `0xb20000000000000000000078ee7ce2fE4908108C` | `0x853F5f1B92b16714Fe6CDA67CAad0856B83C7ab9` | 3.07e10 |
| AAPLc | `0xb200000000000000000000C2e324d24d7eEcd1fb` | `0xA3b1E3f9747065e2073722Ff4c9027d3eA4994F0` | 3.74e10 |
| MSFTc | `0xB200000000000000000000Ab99cFa739E253872B` | `0x7103eB3c9590d1281f7dc03b2A9EE27C39dF5D54` | 2.50e10 |
| GOOGLc | `0xb2000000000000000000002D0BA3164cc74f58B7` | `0xB1987CAD1682841b4b641d50E520777eC5Ab5542` | 7.13e10 |
| METAc | `0xb2000000000000000000008bC8786B856E61707C` | `0xEAF57753BC382E0324a1D43F72E7027705a2273E` | 2.67e11 |

- AMZNc/TSLAc top USDC pairs are on Uniswap with thin liquidity (~$33–35k), so the default basket is the 5 deep ones above.

## The router problem (why StockPilot swaps directly against the pool)
Verified step by step on a Base mainnet fork, 9 Nov 2026:

1. **Router `0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5`** → factory `0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A` (original). Fork test with fee 1295 reverted: the router looks the pool up in the original factory, gets `address(0)`. Proven cause (trace: router call reverts with no subcalls).
2. **Router `0x698Cb2b6dd822994581fEa6eA4Fc755d1363A92F`** → factory `0xf8f2…` (newest — the correct one for the 5 pools). Fork test with fee 500 ALSO reverted:
   - `exactInputSingle` (selector `0x414bf389`) is **absent from the router's bytecode** — the call hits the fallback and reverts with no subcalls.
   - `exactInput` (selector `0xc04b8d59`, present) gets further but reverts: the router calls `poolImplementation()` on the factory, derives the pool address via CREATE2 as `0x33768Aa8bA485cfb3862eD7D2EAEEc70dd151ed8` (no code) instead of the real pool `0x853F…`. The router's CREATE2 derivation does not match the deployed pools.
3. **Odos aggregator API** (`api.odos.xyz/sor/quote/v2`) returns Cloudflare error 1033 from this VM — blocked.
4. **Aerodrome v2 (classic) USDC/NVDAc pool** `0x2e39A9018330c8784956998185D23D9dB503d1F7` exists but is dust (`totalSupply` 1000 LP tokens) — not usable.
5. **Other routers** (for reference): `0xcbBb8035cAc7D4B3Ca7aBb74cF7BdF900215Ce0D` → factory `0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a`; Aerodrome v2 Router (classic) `0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43`; Aerodrome Universal Router `0x6Cb442acF35158D5eDa88fe602221b67B400Be3E`; Slipstream Quoter `0x3d4C22254F86f64B7eC90ab8F7aeC1FBFD271c6C`.

**Resolution:** `StockPilotSwapper` (`contracts/src/StockPilotSwapper.sol`) swaps directly against the Slipstream pool, implementing the V3 swap callback. Proven on a Base mainnet fork (7 tests, `contracts/test/Swapper.t.sol`):
- $10 USDC → 5,665,944 NVDAc (8dp); AAPLc ~2.8M; MSFTc 1,850,014; GOOGLc ~3.4M; METAc ~1.5M (prices move; bounds in the tests).
- Sell NVDAc back → $9.99 USDC (round-trip cost ≈ the 500-fee + price move).
- `minOut` slippage guard reverts when the minimum is unreachable.
- Two subtleties found while proving it: (a) `sqrtPriceLimitX96 = 0` is invalid — Slipstream reverts `SPL` (SqrtPriceLimit); the swapper passes `MIN_SQRT_RATIO+1` (sell token0) / `MAX_SQRT_RATIO-1` (sell token1) and enforces slippage via `minOut` instead. (b) The pool's `slot0()` return layout differs from the stock V3 declaration — the swapper never calls `slot0()`.

## Verified swap results (fork, 9 Nov 2026)
| Swap | Result |
|---|---|
| $10 USDC → NVDAc (direct pool) | 5,674,599 (8dp) |
| $10 USDC → NVDAc (via StockPilotSwapper) | 5,665,944 (8dp) |
| $10 USDC → MSFTc (via swapper) | 1,850,014 (8dp) |
| NVDAc → USDC sell-back (via swapper) | $9.99 USDC |
| $10 USDC → mNVDAc (Sepolia mock pool) | 5,654,829 (8dp, exact fixed-rate) |

## Sources
- base.org/stocks (official roster), base.org/stocksmaxxing (hackathon).
- developers.circle.com (native USDC addresses).
- DexScreener API (prices, pairs, liquidity) — blocks Python's default User-Agent (403); always send a browser UA.
- Aerodrome docs (Slipstream, routers, factories).
- On-chain reads via `cast` / Foundry fork tests against base.publicnode.com (mainnet.base.org is flaky — TLS EOF — so the fork default is publicnode; see `contracts/foundry.toml`).
