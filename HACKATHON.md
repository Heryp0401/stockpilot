# Base “Stocks Maxxing Season” — hackathon notes

Source: base.org/stocksmaxxing (verified 9 Nov 2026). Re-verify the page before submitting — dates and forms can change.

## Facts
- **Name:** Stocks Maxxing Season.
- **Dates:** 5 Nov – **5 Dec 2026** (submissions close 5 Dec). Timeline: 5 Nov applications open; 6–13 Nov brainstorm with partners; 13 Nov – 5 Dec build & launch; 5 Dec submit.
- **Prizes:** $100,000+ total. **$6,000 for best build-in-public.**
- **Tracks (3):** Meme & Community Economies · **Agentic Stock Finance** (this app) · Programmable Stock Markets.
- **Scoring:** **50% real on-chain usage/traction** · 25% product · 25% building in public.
- **Partners:** o1 Exchange, Bankr, Stonks Exchange, BaseStonk, Feel.cash, Hydropump by Hydrex.
- **Apply/submit:** via a Google Form linked on base.org/stocksmaxxing. Participants must be 18+.
- **No token launch required.**

## What “build-in-public” means here
It is a scored criterion (25%) with its own $6,000 prize. In practice: post the build openly as it happens — what you built, what broke, what you verified on-chain, with links and receipts — on X (and ideally a public repo). The draft thread is in `docs/X_THREAD.md` and the running log in `docs/BUILD_LOG.md`. Keep posting as the app ships (Sepolia deploy, mainnet deploy, first real user plan).

## Why StockPilot fits the Agentic Stock Finance track
- An AI agent (the StockPilot agent service) monitors on-chain DCA plans and **prepares** the exact swap for each due execution. The user signs; the agent never holds funds or keys.
- Real on-chain usage is the product: every plan, execution, and trade is recorded in the `StockPilotPlans` registry, so traction is attributable and auditable on-chain — directly aligned with the 50% usage score.
- It uses the real tokenized-equity rails on Base (Coinbase B20 stocks + Aerodrome Slipstream), not a mock.

## Submission checklist (for 5 Dec)
- [ ] App deployed on Base mainnet (registry + swapper) — user-approved step, needs ETH gas.
- [ ] Frontend live on a public URL (static host / IPFS) with the mainnet addresses wired in.
- [ ] Public repo (grant prefers open source; also supports build-in-public).
- [ ] Real usage: at least one real plan created and executed on mainnet (ideally several, by real users).
- [ ] Builder Code (ERC-8021) registered on base.dev and appended to the app's transactions.
- [ ] README + demo video/screenshots showing the full flow (create plan → agent prepares → user executes → on-chain record).
- [ ] Build-in-public thread posted (X), with links to the repo, the deployed contracts, and the demo.
- [ ] Submission form filled on base.org/stocksmaxxing (a user step — the agent builds, it does not submit).
- [ ] (Optional, parallel) Base Builder Grant application — see `~/workspace/base-grants/` (draft + checklist). The grant needs the product live with users first.

## Order of work
1. Deploy to Base Sepolia (mock pools) → test the full flow end-to-end. *(needs Sepolia ETH + a disposable deployer key — user funds it)*
2. Publish the public repo.
3. Deploy to Base mainnet (user-approved, needs ETH gas) → wire addresses into the frontend + agent service.
4. Register a Builder Code on base.dev → set `BUILDER_CODE`.
5. Get real usage (create + execute at least one real plan; invite a few users).
6. Post the build-in-public thread + keep posting milestones.
7. Submit the hackathon entry by **5 Dec 2026** (user step).
8. Apply for the Base Builder Grant (rolling, no deadline) once the app has real usage.
