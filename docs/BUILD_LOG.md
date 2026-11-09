# StockPilot build log (build-in-public)

## 9 Nov 2026
- **Hackathon research (done).** Base “Stocks Maxxing Season”, 5 Nov – 5 Dec 2026, $100k+, Agentic Stock Finance track. Scoring 50% real on-chain usage / 25% product / 25% build-in-public. $6k best build-in-public. Submission via a form on base.org/stocksmaxxing.
- **App design (done).** Non-custodial DCA plans for Coinbase tokenized stocks on Base. A Plan is a public, ownable on-chain record; the agent prepares the swap; the user executes it; every execution is recorded on-chain (the traction signal).
- **Registry contract (done).** `StockPilotPlans.sol` — createPlan / recordExecution / cancelPlan / recordTrade / getPlan / plansOf / isDue. 6 Foundry unit tests pass.
- **On-chain research (done, verified).** Native USDC `…bdA02913` (the lookalike `…bd029029` has no code). Uniswap V3 has NO USDC/stock pools. Deep liquidity is Aerodrome Slipstream; the 5 routable pools live in the newest CLFactory `0xf8f2…`, fee 500, tickSpacing 10. DexScreener “top” pairs (factory `0x9CB2…`) are NOT routable.
- **The router saga (done, and the reason this build is interesting).** The Slipstream SwapRouter is not usable for these stocks: router `0xBE6D…` looks the pool up in the wrong factory (`address(0)`); router `0x698C…` has no `exactInputSingle` selector and its `exactInput` derives a non-existent pool address via CREATE2. Odos is Cloudflare-blocked; the v2 pool is dust. So I built `StockPilotSwapper`, which swaps **directly against the pool** (implements the V3 callback). Proven on a Base mainnet fork: $10 → 5,665,944 NVDAc; sell-back $9.99. Two subtleties: `sqrtPriceLimitX96=0` reverts `SPL` (use MIN+1/MAX-1 + a `minOut` guard), and the pool's `slot0()` layout differs from stock V3.
- **Agent service (done, live).** Node + ethers. `/api/quote` returns a live DexScreener price + the prepared swap (approve + swap calldata) for all 5 stocks. Keeper scans for due plans and prepares their quotes. No keys, no signing, no broadcasting.
- **Frontend (done).** Single-page app (`app/index.html`): wallet connect (Base + Base Sepolia), live prices, create plan, my plans with due status, execute (approve → swap → record), ad-hoc trade, activity log.
- **Sepolia mocks (done).** `MockERC20` + `MockSlipstreamPool` (fixed-rate) + `DeploySepolia.s.sol`. 4 mock-flow tests pass; the deploy script dry-run prints all addresses. Full flow (approve → swap → record) proven against the mocks without a fork.
- **Tests (done).** 18 tests pass (`forge test --fork-url https://base.publicnode.com`): 6 registry unit, 1 direct pool swap, 7 swapper fork, 4 mock flow. Note: fork tests require `--fork-url` (Foundry's lazy fork doesn't load B20 token bytecode otherwise).
- **Base Builder Grant research (done, separate).** Up to $5,000, rolling, needs the product live with users + a Builder Code first. Draft + checklist in `~/workspace/base-grants/`.

## Next
- [ ] Deploy to Base Sepolia (needs Sepolia ETH + a disposable deployer key — user funds it).
- [ ] End-to-end test on Sepolia (create plan → keeper prepares → execute → record).
- [ ] Publish the public repo.
- [ ] Deploy to Base mainnet (user-approved, needs ETH gas).
- [ ] Register a Builder Code on base.dev; set `BUILDER_CODE`.
- [ ] Real usage: first real plan + execution on mainnet.
- [ ] Post the build-in-public thread; keep posting milestones.
- [ ] Submit the hackathon entry by 5 Dec 2026 (user step).
- [ ] Apply for the Base Builder Grant once live with users.
