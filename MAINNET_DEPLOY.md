# StockPilot — Mainnet Deploy (Base, chain 8453)

Status: **DEPLOYED ✅ — 10 Nov 2026 ~00:52 WIB.** Both contracts live on Base mainnet, verified with code on-chain. Leftover ETH returned to the user. Total real cost: ~0.00000845 ETH (~$0.02).

## Deployer (fresh, disposable, mainnet)

- **Address:** `0xE10e358D26B5F9F250dc7ae6c23f5Bf63588D7aF`
- **Balance (Base mainnet, verified 10 Nov 2026 ~00:44 WIB):** 0 ETH
- **Key:** `~/workspace/base-stocks-maxxing/.secrets/deployer-mainnet.json` (mode 600, gitignored — confirmed via `git check-ignore`; does not appear in `git status`).
- This is a **fresh mainnet deployer, NOT the Sepolia deployer** (`0x6b5Ed7019E2E56C59964e9550e814E87B42C03D7`). It will only ever hold a small amount of Base ETH for gas (a few dollars at most). It is not a user wallet; no main-wallet private key was used, asked for, or touched.

## Deployment results (10 Nov 2026 ~00:52 WIB)

- **Funding received:** 0.000166195617136139 ETH (~$0.35) from the user's personal wallet `0xde9083325351caa0aa9db3461e984ffd3f5705ae`, tx `0x4c273f788394dc08334344dd5b938ba6b20b76a57a610ea614eeab476a2643c0` (block 55279768).
- **StockPilotPlans:** `0x3C73Fc8483BEf77886D7648D1fE0e3AAd11582D1` — tx `0x1b76f681dc8f8489ec06d1e6174141e0a04e511bfd5ef136bd4abd8443a748ec`, block 55281630, gas used 928,634, status 1. Explorer: https://basescan.org/address/0x3C73Fc8483BEf77886D7648D1fE0e3AAd11582D1
- **StockPilotSwapper:** `0xB0EE078994Af6cdC897063ec8F5777fe9a221439` — tx `0xf6544b74e5cf4c1b6ddd237ee4eac9c9618f5574892f487791c0c340fe4af758`, block 55281630, gas used 558,037, status 1. Explorer: https://basescan.org/address/0xB0EE078994Af6cdC897063ec8F5777fe9a221439
- Total gas used: 1,486,671. Deploy cost: 0.000008449496741287 ETH (~$0.018).
- Both contracts verified with code on-chain (Plans 8,102 hex chars, Swapper 4,668 hex chars).
- Broadcast saved to `contracts/broadcast/Deploy.s.sol/8453/run-latest.json`.
- Frontend (`app/index.html` `CHAIN[8453]`) and agent-service (`agent-service/src/config.mjs`, `REGISTRY_ADDRESS_MAINNET` / `SWAPPER_ADDRESS_MAINNET`) wired to the live mainnet contracts.

## Leftover ETH returned

- Deployer balance after deploy: 0.000157746120394852 ETH.
- Returned 0.000156746120394852 ETH (~$0.33) to the user's personal wallet `0xde9083325351caa0aa9db3461e984ffd3f5705ae` (the address that funded the deployer), keeping a 0.000001 ETH buffer for the return tx's own gas. Return tx `0x3fe1655a3af88010002ceba829571fa4a0f54f37bac4d91820a809e00c875d61`, block 55281768, status 1, gas used 21,000. Explorer: https://basescan.org/tx/0x3fe1655a3af88010002ceba829571fa4a0f54f37bac4d91820a809e00c875d61. Deployer now holds ~0.00000089 ETH dust.
- Note: the first `cast send` attempt via `https://base.publicnode.com` returned a 403 ("Archive requests require a personal token") but the transaction had already been broadcast — the deployer nonce was 3 (2 deploys + 1 return) and the balance had dropped, confirming the return landed. Do not re-send.

## Funding received (done)

The user sent 0.000166195617136139 ETH (~$0.35) from their personal wallet `0xde9083325351caa0aa9db3461e984ffd3f5705ae` to the deployer (tx `0x4c273f788394dc08334344dd5b938ba6b20b76a57a610ea614eeab476a2643c0`, block 55279768). Actual deploy cost was 0.000008449496741287 ETH (~$0.018) — far below the estimate. No further funding needed.

## Deploy command (used)

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd ~/workspace/base-stocks-maxxing/contracts
DEPLOYER_KEY=$(python3 -c "import json;print(json.load(open('../.secrets/deployer-mainnet.json'))['data'][0]['private_key'])")
forge script script/Deploy.s.sol --rpc-url https://base.publicnode.com --broadcast --private-key "$DEPLOYER_KEY"
```

Notes:
- Use `https://base.publicnode.com` (the `base` alias in `foundry.toml`); `mainnet.base.org` is flaky (TLS EOF) but worked for the simulation. The `base-sepolia` alias is NOT resolved by `forge script --rpc-url` — always use a full URL.
- The script deploys **2 contracts only** (no mocks on mainnet):
  - `StockPilotPlans` (registry)
  - `StockPilotSwapper`
- The Sepolia deploy used `DeploySepolia.s.sol` (13 contracts incl. mocks). Mainnet uses `Deploy.s.sol` (2 contracts). Do not confuse them.

## Simulation result (verified 10 Nov 2026 ~00:44 WIB)

- Dry-run (default sender) against `https://mainnet.base.org`, chain 8453: **SIMULATION COMPLETE.**
  - StockPilotPlans → `0x5b73C5498c1E3b4dbA84de0F1833c4a029d90519` (simulated, default sender — actual addresses will differ with the real deployer)
  - StockPilotSwapper → `0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496` (simulated)
  - Estimated total gas: 1,933,337; estimated max fee per gas 0.01011 gwei; estimated amount required 0.00001954603707 ETH.
  - Dry-run saved to `contracts/broadcast/Deploy.s.sol/8453/dry-run/run-latest.json`.
- Simulation with `--sender 0xE10e358D26B5F9F250dc7ae6c23f5Bf63588D7aF` (the real deployer): fails with `EVM error: transaction validation error: lack of funds (0) for max fee` — **exactly as expected.** The deploy path reaches the EVM and is valid; the ONLY blocker is the deployer's 0 balance.

## After the deploy (done except step 4)

1. ✅ Recorded the `StockPilotPlans` and `StockPilotSwapper` addresses (see Deployment results above).
2. ✅ Verified each has code on-chain (Base mainnet).
3. ✅ Updated `app/index.html` `CHAIN[8453]` and the agent-service addresses (config.mjs) with the mainnet registry + swapper.
4. ✅ Verified the agent service against mainnet (`/api/health` → chain base/8453, registry + swapper correct; `/api/stocks` → 5 real stocks with live prices; `/api/spot` NVDAc → $177.43; `/api/quote` $10 NVDAc → amountOutEst 5,636,025, `swapperDeployed: true`).
5. ⏳ Update README.md with the mainnet addresses.
6. Then: register Builder Code on base.dev → real usage → build-in-public thread → submit hackathon by **5 Dec 2026** → apply Base Builder Grant after live with users.

## Constraints honored

- Testnet Sepolia deployer key (`.secrets/deployer-sepolia.json`) was NOT reused for mainnet; a fresh mainnet deployer was generated.
- Deployed only the 2 StockPilot contracts; nothing else deployed, hackathon not submitted.
- Leftover ETH returned to the user's sending address (see above).
- No main-wallet private key was used, asked for, or touched.
