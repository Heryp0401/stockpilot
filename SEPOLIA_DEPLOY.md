# StockPilot — Base Sepolia Deployment Status

**Status: ✅ DEPLOYED + SMOKE-TESTED — 9 Nov 2026 ~23:44 WIB (deploy), ~23:45–23:57 WIB (smoke test + wiring).**
Last updated: 9 Nov 2026 ~23:57 WIB.

## Deployer (disposable, testnet-only)

- **Address:** `0x6b5Ed7019E2E56C59964e9550e814E87B42C03D7`
- **Balance (Base Sepolia):** 0.089957589 ETH (after deploy + smoke test; started at 0.09)
- **Private key:** `~/workspace/base-stocks-maxxing/.secrets/deployer-sepolia.json` (mode 600, gitignored via `.secrets/` in `.gitignore`). Testnet-only, disposable — holds no real value. **Never print or share the key.**
- **Chain:** Base Sepolia (chain ID 84532), RPC `https://sepolia.base.org`

## How it got funded (9 Nov ~23:38–23:44 WIB)

The user sent **0.1 Sepolia ETH to the deployer on Ethereum Sepolia** (chain 11155111), not Base Sepolia. Bridged **0.09 ETH** (kept 0.01 ETH for L1 gas) via the official L1StandardBridge `depositETHTo(to, 200000, 0x)`:
- Bridge tx (L1): `0xf255c952b9224e53618bca9270cdcc89b1bb9662bf1a5c5d9415bc701093cb4e`, block 12098775, status 1.
- Deposit credited on Base Sepolia: **0.09 ETH** (~5 min relay lag).

## Deployed contracts (Base Sepolia, chain 84532)

Deploy txs recorded in `contracts/broadcast/DeploySepolia.s.sol/84532/run-latest.json`. Total deploy gas 10,383,585 (~0.0001 ETH).

| Contract | Address | Explorer |
|---|---|---|
| StockPilotPlans (registry) | `0x2e5A1caB12b8902A840c8636caa58bcba084E060` | https://sepolia.basescan.org/address/0x2e5A1caB12b8902A840c8636caa58bcba084E060 |
| StockPilotSwapper | `0x1444524A69BFC4352DaAd9B5cd9272A2EbB11bb1` | https://sepolia.basescan.org/address/0x1444524A69BFC4352DaAd9B5cd9272A2EbB11bb1 |
| Mock USDC (6dp) | `0x4280743426B055e76Ee462a83efE66e787DD7C74` | https://sepolia.basescan.org/address/0x4280743426B055e76Ee462a83efE66e787DD7C74 |
| Mock NVDAc (8dp) | `0xb75Bd2C86Fc79db001e07AC5d590288B5a1AE639` | https://sepolia.basescan.org/address/0xb75Bd2C86Fc79db001e07AC5d590288B5a1AE639 |
| Mock AAPLc (8dp) | `0x21CAa92de6848b36Da97aFeA47bDBDb980F193f6` | https://sepolia.basescan.org/address/0x21CAa92de6848b36Da97aFeA47bDBDb980F193f6 |
| Mock MSFTc (8dp) | `0x15AF17033Ec02679698c2FF48F3Ed3A91068cD0E` | https://sepolia.basescan.org/address/0x15AF17033Ec02679698c2FF48F3Ed3A91068cD0E |
| Mock GOOGLc (8dp) | `0x039c1eb1dCD8513c4F77B5ab1a1c522d1B78DA4d` | https://sepolia.basescan.org/address/0x039c1eb1dCD8513c4F77B5ab1a1c522d1B78DA4d |
| Mock METAc (8dp) | `0x9fF9cf18cFaf1236EBD58D3A09eaDCB3532ba078` | https://sepolia.basescan.org/address/0x9fF9cf18cFaf1236EBD58D3A09eaDCB3532ba078 |
| Mock pool NVDAc | `0x0B286F6eE6aa92Ec750a14b5d12F4B971D67D069` | https://sepolia.basescan.org/address/0x0B286F6eE6aa92Ec750a14b5d12F4B971D67D069 |
| Mock pool AAPLc | `0xF7b1111d7b2AD109FDa383c2Eaa71eE2D9e8b1E5` | https://sepolia.basescan.org/address/0xF7b1111d7b2AD109FDa383c2Eaa71eE2D9e8b1E5 |
| Mock pool MSFTc | `0xa3983Ca7d279aAa2932a665A9a3B5a68C399A0a5` | https://sepolia.basescan.org/address/0xa3983Ca7d279aAa2932a665A9a3B5a68C399A0a5 |
| Mock pool GOOGLc | `0xbb86CF94914fAB15ad2261c05cc8cBFbd5D75604` | https://sepolia.basescan.org/address/0xbb86CF94914fAB15ad2261c05cc8cBFbd5D75604 |
| Mock pool METAc | `0x317A76d60B2dDfC6c1572E3cf763AC9505114274` | https://sepolia.basescan.org/address/0x317A76d60B2dDfC6c1572E3cf763AC9505114274 |

Mock pool fixed prices (scaled 1e6): NVDAc $176.84, AAPLc $350.94, MSFTc $542.55, GOOGLc $293.62, METAc $642.05. Each pool funded with 10,000 mock USDC + ~$10k of its stock. Deployer funded with $1,000 mock USDC.

**Verification:** every contract above was verified to have code on-chain (`eth_getCode` non-empty) at deploy time.

## Smoke test — end-to-end, all passed (9 Nov ~23:45 WIB)

Plan 0 "smoke-test": $10 mock USDC → mock NVDAc, 24h interval, max 1 execution.

| Step | Tx | Result |
|---|---|---|
| createPlan(0) | `0x8bd43d179148ec1c26d1a647c29dd7e6eeca18b515e83f1dc893dc22498926f8` (block 56605602) | ✅ status 1; planCount=1, isDue(0)=true |
| approve swapper $10 mUSDC | `0x7b34ff0dcf2872ccf3ba85b6d20230ab64a0cdc4f9696f4c02d4737e6cd66f35` | ✅ status 1 |
| swapExactInput (via swapper) | `0x56404196e03f676c2e97b58f1a6fb51b6695bc164eaa488746cd9cef85298189` (block 56605689) | ✅ status 1; **$10 mUSDC → 5,654,829 mNVDAc** (8dp); deployer mUSDC 990,000,000 ($990) after |
| recordExecution(0, 10000000, 5654829, swap tx) | `0x6ae24b4b39f9ebe69003bb8367cd9d937473c0ae9dc73213f153452974df5283` | ✅ status 1; PlanExecuted event emitted; getPlan(0): executions=1, lastExecutedAt=1794243018, active=false (max reached); isDue(0)=false |

## Wiring — frontend + agent service point at Sepolia (9 Nov ~23:50–23:57 WIB)

- **Frontend `app/index.html`:** `CHAIN[84532]` filled with registry + swapper + mock USDC; added `STOCKS_SEPOLIA` (5 mock stocks + pools + fixed prices) and a `stocks()` helper that returns the Sepolia list when connected to chain 84532; `loadPrices` uses the fixed mock rates on Sepolia (DexScreener has no pairs for mocks); dropdowns + `stockByAddr` resolve mock tokens. JS syntax-checked.
- **Agent service `agent-service/src/`:** `config.mjs` has the Sepolia deployment constants (`REGISTRY_ADDRESS_SEPOLIA`, `SWAPPER_ADDRESS_SEPOLIA`, `USDC_MOCK_SEPOLIA`, `MOCK_STOCKS_SEPOLIA`) and a `CHAIN` selector — run with `CHAIN=sepolia npm start` to point the service at Sepolia (Sepolia RPC, mock USDC, mock stocks, Sepolia addresses). `quote.mjs` / `server.mjs` / `keeper.mjs` use the chain-resolved `ACTIVE_*` values; `getSpot` returns the mock fixed price on Sepolia.
- **Service verified live against Sepolia:** `/api/health` → chain sepolia, chainId 84532, correct registry/swapper/usdc; `/api/stocks` → 5 mock stocks; `/api/spot` NVDAc → $176.84; **`/api/quote` $10 NVDAc → amountOutEst 5,654,829 — exactly matches the on-chain swap output**; `/api/plans` → plan 0 (executed 1/1, due false); `/api/due` → []; keeper `--once` → 0 due, no errors.

## Faucet attempts (all tried 9 Nov 2026, all failed autonomously)

| Faucet | Result | Why it failed |
|---|---|---|
| Coinbase faucet (`coinbase.com/faucets/base-ethereum-sepolia-faucet`) | HTTP 404 | URL dead/changed |
| QuickNode (`faucet.quicknode.com/base/sepolia`) | Claim POSTed, **refused**: "Insufficient ETH mainnet balance. Please note, you'll need a small mainnet balance on this wallet in order to use the faucet." | Now requires a small ETH balance on **Ethereum mainnet** on the submitted address. Deployer is fresh (0 mainnet ETH). Older guides saying "no mainnet balance" are out of date. |
| Alchemy faucet | Not attempted (known gate) | Requires ≥0.001 ETH on Ethereum mainnet + mainnet activity. Deployer has none. |
| Chainstack faucet | Not attempted (known gate) | Requires sign-in + 0.08 ETH on Ethereum mainnet. |
| Chainlink faucet (`faucets.chain.link/base-sepolia`) | Not attempted (known gate) | Requires sign-in (per Chainlink docs). |
| Coinbase CDP faucet | Not attempted (known gate) | Requires a free Coinbase Developer Platform account (login). No mainnet balance needed. |
| Superchain faucet (Optimism) | Not attempted (known gate) | Requires sign-in (Optimism Dev Console) + GitHub link, reCAPTCHA. 0.01 ETH/day. |
| Google Cloud Web3 faucet | Not attempted (known gate) | Requires Google login; does not list Base Sepolia (Ethereum Sepolia only). |
| Zalalena (`faucet.zalalena.com/base`) | Not attempted (known gate) | No login, no mainnet balance — but **captcha** required. Cannot be solved from CLI. |

**Conclusion:** every Base Sepolia faucet now gates on at least one of: a mainnet ETH balance, a login, or a captcha. No faucet can fund a fresh wallet fully autonomously. The user's wallets also hold 0 ETH on Ethereum mainnet, so the mainnet-balance gates cannot be passed with any existing address. **Resolved by the user funding the deployer directly with 0.1 Sepolia ETH + the L1→L2 bridge (see above).**

## Deploy command (already run — succeeded 9 Nov ~23:44 WIB)

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd ~/workspace/base-stocks-maxxing/contracts
DEPLOYER_KEY=$(python3 -c "import json;print(json.load(open('/home/hatch/workspace/base-stocks-maxxing/.secrets/deployer-sepolia.json'))['data'][0]['private_key'])")
forge script script/DeploySepolia.s.sol --rpc-url https://sepolia.base.org --broadcast --private-key "$DEPLOYER_KEY"
```

**Deploy result:** all 13 contracts deployed, total gas 10,383,585 (~0.0001 ETH). Broadcast record: `contracts/broadcast/DeploySepolia.s.sol/84532/run-latest.json`.

## What the deploy creates (DeploySepolia.s.sol)

- `StockPilotPlans` (registry)
- `StockPilotSwapper`
- Mock USDC (6dp) + 5 mock stocks (mNVDAc, mAAPLc, mMSFTc, mGOOGLc, mMETAc — 8dp)
- 5 fixed-rate mock Slipstream pools (one per stock), each funded with ~$10k of stock + 10,000 mock USDC
- Deployer funded with $1,000 mock USDC for demo trading

## After deployment

1. ✅ Record the printed contract addresses here and in `app/index.html` `CHAIN[84532]` + agent-service `REGISTRY_ADDRESS` / `SWAPPER_ADDRESS` (done 9 Nov ~23:50–23:57 WIB).
2. ✅ Verify code on-chain at each address (Base Sepolia explorer) — all 13 verified.
3. ✅ Smoke-test: create a plan, get a quote, execute a swap against the mock pools (all passed, see above).
4. Next: publish public repo → Base mainnet deploy → register Builder Code → real usage → build-in-public thread → submit by 5 Dec 2026 → apply for Base Builder Grant once live with users.
