# StockPilot — Agentic Stock Finance on Base

**Public repo:** https://github.com/Heryp0401/stockpilot

**For the Base “Stocks Maxxing Season” hackathon (Agentic Stock Finance track, submissions close 5 Dec 2026).**

StockPilot is a non-custodial, on-chain DCA app for Coinbase tokenized stocks on Base. A user creates a **Plan** (“DCA $10 USDC into NVDAc every week”), the StockPilot **agent** watches for due plans and prepares the exact swap, and the user executes it in their own wallet. Every execution is recorded on-chain, so usage is attributable and auditable — which is what the hackathon scores (50% real on-chain usage).

No funds are ever held by any contract. The user only ever approves USDC to the StockPilotSwapper, which swaps directly against the verified Aerodrome Slipstream pool and sends the stock straight to the user.

## What it is

| Piece | Where | Status |
|---|---|---|
| `StockPilotPlans` registry | `contracts/src/StockPilotPlans.sol` | ✅ written, 6 unit tests pass |
| `StockPilotSwapper` (direct pool swap) | `contracts/src/StockPilotSwapper.sol` | ✅ written, **proven on a Base mainnet fork**: $10 USDC → 5,665,944 NVDAc; sell-back returns $9.99 USDC; 7 fork tests pass |
| Mock USDC / stocks / pools (Sepolia) | `contracts/src/mocks/` | ✅ written, 4 mock-flow tests pass |
| Agent service (quotes + keeper) | `agent-service/src/` | ✅ working live: `/api/quote` returns live DexScreener prices + prepared swap |
| Frontend (single-page app) | `app/index.html` | ✅ built (wallet connect, live prices, create plan, execute, ad-hoc trade, activity) |
| Deploy scripts | `contracts/script/` | ✅ `Deploy.s.sol` (mainnet), `DeploySepolia.s.sol` (full testnet incl. mocks; **deployed 9 Nov 2026, smoke-tested end-to-end on Base Sepolia**) |

**Deployed to Base Sepolia 9 Nov 2026 ~23:44 WIB** (registry `0x2e5A1caB12b8902A840c8636caa58bcba084E060`, swapper `0x1444524A69BFC4352DaAd9B5cd9272A2EbB11bb1` + mock USDC/stocks/pools; smoke test passed — $10 mUSDC → 5,654,829 mNVDAc, recorded on-chain). **Deployed to Base mainnet 10 Nov 2026 ~00:52 WIB** (registry `0x3C73Fc8483BEf77886D7648D1fE0e3AAd11582D1`, swapper `0xB0EE078994Af6cdC897063ec8F5777fe9a221439`; deploy cost ~0.00000845 ETH / ~$0.018; leftover ETH returned to the user). **Not yet done:** register a Builder Code, get real usage, apply for the Base Builder Grant, submit the hackathon entry (by 5 Dec 2026). See `HACKATHON.md`.

## Quick start

### Contracts
```bash
cd contracts
forge build
# unit + mock tests (no fork needed)
forge test --match-contract "StockPilotPlansTest|MockFlowTest"
# full suite incl. mainnet-fork swap proofs (requires a live Base RPC)
forge test --fork-url https://base.publicnode.com
```
> Fork tests **require** `--fork-url`. Plain `forge test` fails the fork tests with a bogus `TF`/`OpcodeNotFound`: without the global `--fork-url` flag, Foundry's lazy fork does not load the B20 token bytecode, so the pool's `transfer()` hits an empty account. With `--fork-url` all 18 tests pass.

### Agent service
```bash
cd agent-service
npm install   # ethers 6.17.0 (already installed)
npm start     # port 3001
# Endpoints: /api/health /api/stocks /api/quote /api/spot /api/plans /api/due /api/plan/<id>
# Keeper (prepares quotes for due plans): node src/keeper.mjs --once
# Env: REGISTRY_ADDRESS, SWAPPER_ADDRESS, BASE_RPC_URL, BUILDER_CODE, PORT
```

### Frontend
Open `app/index.html` in a browser (or serve it statically). Connect a wallet on Base (8453) or Base Sepolia (84532). Contract addresses are set in `app/index.html` (`CHAIN[8453]` / `CHAIN[84532]`) after deployment.

## How the swap works (and why not the router)

Aerodrome's Slipstream SwapRouter is **not usable** for these stocks (verified on-chain, 9 Nov 2026):
- Router `0xBE6D…` (original factory) looks the pool up in the original factory and gets `address(0)` → revert.
- Router `0x698C…` (paired with the newest factory `0xf8f2…`) has **no** `exactInputSingle` selector in its bytecode, and its `exactInput` derives the pool address via CREATE2 as `0x3376…` (no code) instead of the real pool → revert.
- The Odos aggregator API is Cloudflare-blocked from this VM (error 1033).
- The Aerodrome v2 (classic) USDC/NVDAc pool is dust (`totalSupply` 1000).

So StockPilot swaps **directly against the Slipstream pool** through `StockPilotSwapper`, which implements the V3 swap callback itself. This is proven on a Base mainnet fork for all five stocks. Full archaeology in `docs/RESEARCH.md`.

## The five verified stocks

All in the newest official Aerodrome CLFactory `0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef`, tickSpacing 10, fee 500, with real liquidity. Each pool's `token0` is USDC and `token1` is the stock.

| Stock | Token | Pool |
|---|---|---|
| NVDAc | `0xb20000000000000000000078ee7ce2fE4908108C` | `0x853F5f1B92b16714Fe6CDA67CAad0856B83C7ab9` |
| AAPLc | `0xb200000000000000000000C2e324d24d7eEcd1fb` | `0xA3b1E3f9747065e2073722Ff4c9027d3eA4994F0` |
| MSFTc | `0xB200000000000000000000Ab99cFa739E253872B` | `0x7103eB3c9590d1281f7dc03b2A9EE27C39dF5D54` |
| GOOGLc | `0xb2000000000000000000002D0BA3164cc74f58B7` | `0xB1987CAD1682841b4b641d50E520777eC5Ab5542` |
| METAc | `0xb2000000000000000000008bC8786B856E61707C` | `0xEAF57753BC382E0324a1D43F72E7027705a2273E` |

Native USDC on Base: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` (6 decimals). The similar address ending `…bd029029` has **no code** — do not use it.

## Deploy

### Base Sepolia (testnet, first)

**Status (9 Nov 2026 ~23:44 WIB): ✅ DEPLOYED + SMOKE-TESTED.** Full details in [`SEPOLIA_DEPLOY.md`](SEPOLIA_DEPLOY.md).
- Disposable deployer: `0x6b5Ed7019E2E56C59964e9550e814E87B42C03D7` (key in `.secrets/deployer-sepolia.json`, gitignored). Funded by the user with 0.1 Sepolia ETH on Ethereum Sepolia, bridged 0.09 ETH to Base Sepolia (bridge tx `0xf255c952b9224e53618bca9270cdcc89b1bb9662bf1a5c5d9415bc701093cb4e`). Balance after deploy + smoke test: ~0.09 ETH.
- **No Base Sepolia faucet works autonomously for a fresh wallet** (tried 9 Nov): Coinbase faucet URL is dead (404); QuickNode now refuses with "Insufficient ETH mainnet balance" (requires a small Ethereum-mainnet balance — the deployer has none); Alchemy/Chainstack need a mainnet balance; Chainlink/Coinbase CDP/Superchain/Google need a login; Zalalena needs a captcha.

**Deployed addresses (Base Sepolia, chain 84532):**

| Contract | Address |
|---|---|
| StockPilotPlans (registry) | `0x2e5A1caB12b8902A840c8636caa58bcba084E060` |
| StockPilotSwapper | `0x1444524A69BFC4352DaAd9B5cd9272A2EbB11bb1` |
| Mock USDC (6dp) | `0x4280743426B055e76Ee462a83efE66e787DD7C74` |
| Mock NVDAc / pool | `0xb75Bd2C86Fc79db001e07AC5d590288B5a1AE639` / `0x0B286F6eE6aa92Ec750a14b5d12F4B971D67D069` |
| Mock AAPLc / pool | `0x21CAa92de6848b36Da97aFeA47bDBDb980F193f6` / `0xF7b1111d7b2AD109FDa383c2Eaa71eE2D9e8b1E5` |
| Mock MSFTc / pool | `0x15AF17033Ec02679698c2FF48F3Ed3A91068cD0E` / `0xa3983Ca7d279aAa2932a665A9a3B5a68C399A0a5` |
| Mock GOOGLc / pool | `0x039c1eb1dCD8513c4F77B5ab1a1c522d1B78DA4d` / `0xbb86CF94914fAB15ad2261c05cc8cBFbd5D75604` |
| Mock METAc / pool | `0x9fF9cf18cFaf1236EBD58D3A09eaDCB3532ba078` / `0x317A76d60B2dDfC6c1572E3cf763AC9505114274` |

Smoke test (9 Nov ~23:45 WIB): plan 0 "smoke-test" — createPlan ✅, approve ✅, swapExactInput ✅ ($10 mUSDC → 5,654,829 mNVDAc), recordExecution ✅ (executions=1, isDue=false). Frontend (`app/index.html` `CHAIN[84532]` + `STOCKS_SEPOLIA`) and agent service (`CHAIN=sepolia`) are wired to these addresses; `/api/quote` $10 NVDAc returns amountOutEst 5,654,829 — exactly the on-chain result.

```bash
cd contracts
# disposable testnet key only (never a main-wallet key); Sepolia ETH from a faucet
DEPLOYER_KEY=$(python3 -c "import json;print(json.load(open('../.secrets/deployer-sepolia.json'))['data'][0]['private_key'])")
forge script script/DeploySepolia.s.sol --rpc-url https://sepolia.base.org --broadcast --private-key "$DEPLOYER_KEY"
# addresses are already wired into app/index.html CHAIN[84532]
# and the agent service (CHAIN=sepolia); see SEPOLIA_DEPLOY.md
```
Note: use the full RPC URL `https://sepolia.base.org` — the `base-sepolia` alias in `foundry.toml` is not resolved by `forge script --rpc-url`. Deployed 9 Nov 2026 ~23:44 WIB; smoke-tested end-to-end (see `SEPOLIA_DEPLOY.md`).

### Base mainnet — ✅ DEPLOYED 10 Nov 2026 ~00:52 WIB
```bash
cd contracts
forge script script/Deploy.s.sol --rpc-url base --broadcast --private-key $DEPLOYER_KEY
```
- **StockPilotPlans:** `0x3C73Fc8483BEf77886D7648D1fE0e3AAd11582D1` (tx `0x1b76f681dc8f8489ec06d1e6174141e0a04e511bfd5ef136bd4abd8443a748ec`)
- **StockPilotSwapper:** `0xB0EE078994Af6cdC897063ec8F5777fe9a221439` (tx `0xf6544b74e5cf4c1b6ddd237ee4eac9c9618f5574892f487791c0c340fe4af758`)
- Addresses are already wired into `app/index.html` `CHAIN[8453]` and the agent service (`REGISTRY_ADDRESS_MAINNET` / `SWAPPER_ADDRESS_MAINNET` in `agent-service/src/config.mjs`). Full details in `MAINNET_DEPLOY.md`.

Then: register a Builder Code on base.dev (ERC-8021, keyed to the agent wallet), set `BUILDER_CODE`, get real usage, apply for the Base Builder Grant (`docs/` in `~/workspace/base-grants/`), and submit the hackathon entry by **5 Dec 2026** (form on base.org/stocksmaxxing — a user step; this repo builds, it does not submit).

## Architecture

```
User wallet (Base)
  │  approve USDC -> StockPilotSwapper (only approval in the app)
  │  swapExactInput(pool, USDC, stock, amountIn, minOut, recipient)
  ▼
StockPilotSwapper ──► Aerodrome Slipstream pool (direct pool.swap + callback)
  │  stock -> user
  ▼
StockPilotPlans.recordExecution(planId, amountIn, amountOut, txHash)
  │  (on-chain usage record — the hackathon's 50% traction signal)

Agent service (Node + ethers, no keys, no signing)
  │  /api/quote  -> live DexScreener price + prepared swap calldata
  │  keeper      -> scans for due plans, prepares their quotes
  └─► frontend executes; user signs everything
```

## Docs
- `HACKATHON.md` — rules, tracks, scoring, submission checklist, deadlines.
- `docs/RESEARCH.md` — verified addresses, pools, fees, prices, sources, and the full router archaeology.
- `docs/BUILD_LOG.md` — build-in-public log.
- `docs/X_THREAD.md` — draft X thread for build-in-public.
- `data/cstocks_curated.json` — 34 curated Coinbase stocks; `data/cstocks_full.json` — full 64-token roster.

## Safety
- Non-custodial: no contract holds user funds. The swapper only pulls the exact `amountIn` the user approved, and only inside a swap call.
- Slippage guard: every swap has a `minOut` (1% default); it reverts if the pool delivers less.
- The swap callback only accepts calls from the pool named in the swap, and only pays the input token the pool is owed.
- Tokenized stocks are Regulation S instruments (Coinbase Onchain SPV Ltd); not offered to US persons. This repo is not financial advice.
