# StockPilot — Base Builder Code Registration (prep)

Status: **PREPARATION ONLY — 10 Nov 2026 ~01:05 WIB.** Nothing registered, no wallet
connected, no form submitted, $0 spent. This doc records the exact registration
flow (verified against docs.base.org + the official `base/skills` repo), what the
user must decide/do, and the exact integration plan for when the code exists.

Why it matters: Base's own docs state **"The first step to be eligible for
grants is to integrate Builder Codes"** (Builder Grant Season 2, up to $5,000,
rolling — see `~/workspace/base-grants/research.md`). Without a Builder Code,
StockPilot's on-chain activity is unattributed and invisible to Base.

## 1. What a Builder Code is

- A unique identifier (e.g. `bc_a1b2c3d4`) appended to transaction calldata as an
  **ERC-8021** suffix. Smart contracts ignore the suffix; off-chain indexers
  extract it after the fact. **No contract changes, no redeploy.**
- Builder Codes are an ERC-721 NFT collection; each code carries on-chain metadata
  (notably a **payout address** — where potential rewards are sent) and off-chain
  metadata (app name, site).
- Gas overhead: **16 gas per non-zero byte**. A typical 11-char code makes a
  29-byte suffix → ~464 extra gas per transaction. Negligible.
- Works with EOAs and smart wallets. Attribution is silent when missing — there
  is no error or warning, just invisible activity.

## 2. The ERC-8021 suffix format (verified)

Layout, forward order: `0x` + ASCII-hex(code) + 1-byte length + `00` (schema ID 0)
+ 16-byte marker `80218021802180218021802180218021`.

Verified against the official example in docs.base.org: code `bc_b7k3p9da`
produces suffix `0x62635f62376b33703964610b0080218021802180218021802180218021`
— recomputed independently in Python on 10 Nov 2026, **byte-for-byte match**.

Generate it with `ox` (the official way, removes all byte-order doubt):

```typescript
import { Attribution } from "ox/erc8021";
export const DATA_SUFFIX = Attribution.toDataSuffix({ codes: [BUILDER_CODE] });
```

Or compute it by hand: `0x` + `code.encode().hex()` + `len(code)` as 1 byte +
`00` + `80218021802180218021802180218021`.

To verify a transaction is attributed: open it on Basescan → input data → the
last 16 bytes are `8021` repeating → decode the ASCII codes before the marker.
Or use the open tool https://builder-code-checker.vercel.app (select transaction
type, paste tx/UserOp hash, Check Attribution). base.dev also shows attributed
counts under Onchain → Total Transactions.

## 3. The two registration paths (they are different codes)

StockPilot has TWO transaction surfaces, and Base has a registration path for
each. They produce different codes for different senders.

### Path A — App Builder Code (PRIMARY — do this one)

For the **frontend user transactions**: createPlan, approve USDC, swapExactInput,
recordExecution — all sent by the USER's own wallet through `app/index.html`.

- **Where:** register the project on **Base Dashboard (dashboard.base.org)**;
  the code itself lives under **base.dev → Settings → Builder Code**.
  (Sources: docs.base.org/specifications/builder-codes/for-app-developers;
  `base/skills` references/builder-codes/overview.md: "A Builder Code from
  base.dev > Settings > Builder Codes".)
- **What you get:** a random string like `bc_b7k3p9da` (+ the fully encoded
  suffix, which base.dev provides — you do not encode it yourself).
- **What it needs:** a base.dev account + **wallet sign-in in the browser**
  (SIWE). Project details: name (StockPilot), site/repo URL
  (https://github.com/Heryp0401/stockpilot), contract addresses
  (Plans `0x3C73Fc8483BEf77886D7648D1fE0e3AAd11582D1`,
  Swapper `0xB0EE078994Af6cdC897063ec8F5777fe9a221439`).
  Also set the **payout address** (where potential rewards go).
- **Effect:** once registered, the Base App auto-appends the code to
  transactions users make in the app. For the web frontend, the code must be
  integrated manually (see §5).
- **Who does it:** **the USER, in their browser.** The agent cannot do this —
  it needs the user's base.dev account + wallet sign-in, and the agent never
  touches the user's personal wallet key.

### Path B — Agent Builder Code (FUTURE — only when the agent sends its own txs)

For transactions the **StockPilot agent itself** sends from its own wallet.

- **Where:** API, no dashboard, **no authentication required.**
- **Exact call** (from the official `base/skills` repo,
  `skills/build-on-base/references/agents/register.md` + `scripts/register.sh`):

```bash
curl -X POST https://api.base.dev/v1/agents/builder-codes \
  -H "Content-Type: application/json" \
  -d '{"wallet_address": "<agent_wallet_address>"}'
```

Response:

```json
{
  "builder_code": "bc_a1b2c3d4",
  "wallet_address": "0x...",
  "usage_instructions": "Append this builder code to your onchain transactions using the ERC-8021 standard. See: https://docs.base.org/base-chain/quickstart/builder-codes"
}
```

- The same wallet address always returns the same code. If a
  `builderCode.ts` already exists in the project, **do NOT re-register** —
  re-registering would generate a new code and break the existing one.
- **Status for StockPilot: NOT APPLICABLE YET.** The agent service
  (`agent-service/src/`) currently prepares quotes only — it holds no keys and
  signs nothing; the user executes every transaction in their own wallet.
  There is no agent wallet and no agent-sent transaction to attribute.
  Register an agent code only when the keeper starts sending transactions
  itself (a future autonomous-execution mode).
- **Who could do it:** once an agent wallet is chosen, this API call needs no
  auth and no signature, so the agent could run it autonomously. The wallet
  choice itself is the user's decision (§4, D3).

## 4. Decisions the user must make

| # | Decision | Recommendation | Why |
|---|----------|----------------|-----|
| D1 | App code, agent code, or both? | **App code first (Path A).** Agent code later, only when the agent sends its own txs. | The app code attributes the real transaction volume the grant scores (users creating plans + swapping). The agent code currently attributes nothing — there is no agent wallet and no agent-sent tx. |
| D2 | Payout address for the app code | **User's personal wallet `0xde9083325351caa0aa9db3461e984ffd3f5705ae`** | That is where any future Base rewards should land; it is the wallet that funded the deploy and owns the project. |
| D3 | Wallet for a future agent code | **A NEW dedicated StockPilot agent wallet** (fresh disposable, created when autonomous execution is built) | NOT the mainnet deployer `0xE10e358D26B5F9F250dc7ae6c23f5Bf63588D7aF` (disposable deployer, ~0.00000089 ETH dust, never sends agent txs) and NOT the personal wallet (that is the user's identity, not the agent's). |
| D4 | Who registers the app code? | **The user, in their browser on base.dev** | Needs a base.dev account + wallet sign-in. The agent cannot sign in as the user and never touches their key. |

## 5. Integration plan (apply AFTER the code exists — nothing applied yet)

### 5.1 Compute the suffix

From the registered `bc_...` code, generate the full `DATA_SUFFIX` hex with
`ox` (`Attribution.toDataSuffix({ codes: [code] })`) or the hand formula in §2.
Store the code + suffix in `agent-service/src/config.mjs` (`BUILDER_CODE` env)
and in the frontend (below). **Do not re-register to get a second code.**

### 5.2 Agent service (already plumbed — just set the value)

Already done in code, waiting only for the value:

- `agent-service/src/config.mjs:91-95`: `export const BUILDER_CODE =
  process.env.BUILDER_CODE || "";` — start the service with
  `BUILDER_CODE=<full DATA_SUFFIX hex>`.
- `agent-service/src/quote.mjs:155-157`: the `/api/quote` response already
  returns `dataSuffix: BUILDER_CODE` (empty string until configured).
- ⚠️ **Correction needed in `config.mjs` when integrating:** the comment says
  set BUILDER_CODE to "the hex suffix, e.g. '0x8021...'". That is misleading —
  the value must be the **FULL dataSuffix** (code ASCII + length + schema +
  marker, e.g. `0x62635f...8021`), NOT just the marker. Fix the comment when
  the value is set.

### 5.3 Frontend (not yet integrated — 4 write call sites)

`app/index.html` is a single self-contained page using **ethers v6** with
`ethers.BrowserProvider(window.ethereum)` and direct contract-method calls.
It does NOT call `/api/quote` for execution (it fetches prices straight from
DexScreener), so the suffix must live in the page itself as a constant — not
via the quote API.

Steps:

1. Add near the top of the script, next to the chain config:
   ```js
   // Base Builder Code (ERC-8021), registered on base.dev. Public value.
   const DATA_SUFFIX = "0x..."; // full suffix hex from §5.1; "" = none yet
   ```
2. Add the attribution helper (exact pattern from the official skill's
   `references/builder-codes/rpc.md`):
   ```js
   function withAttribution(data) {
     return DATA_SUFFIX ? data + DATA_SUFFIX.slice(2) : data;
   }
   ```
3. Change the 4 write call sites from direct contract calls to
   populate-then-send (ethers v6 contract methods do not accept a `data`
   override, so build the unsigned tx, append the suffix, then send):
   - `createPlan` (~line 322): `registry().createPlan(...)`
   - `approve` (~line 351): `us.approve(c.swapper, amountInUSDC)`
   - `swapExactInput` (~line 356): `sw.swapExactInput(...)`
   - `recordExecution` (~line 379): `reg.recordExecution(...)`
   
   Pattern per site:
   ```js
   const txReq = await contract.METHOD.populateTransaction(...args);
   txReq.data = withAttribution(txReq.data);
   const tx = await signer.sendTransaction(txReq);
   ```
   (The `signer` is already available in the page; `registry()`/`swapper()`/
   `usdc()` helpers return signer-connected contracts — use
   `contract.METHOD.populateTransaction` on those same instances.)
4. Keep the suffix append **unconditional once set** — every write tx carries
   it (createPlan, approve, swap, recordExecution). A missing suffix is silent
   data loss, not an error.

### 5.4 Verify + publish

1. Do one real mainnet transaction through the frontend (e.g. a test plan or a
   small swap) and confirm on Basescan that the input data ends with the
   `8021` marker and decodes to the registered code. Also run it through
   https://builder-code-checker.vercel.app.
2. Confirm the code shows attributed activity on base.dev (Onchain → Total
   Transactions).
3. Commit the integration + push to https://github.com/Heryp0401/stockpilot.
4. Then: real usage → build-in-public thread → submit hackathon by
   **5 Dec 2026** → apply for the Base Builder Grant (draft in
   `~/workspace/base-grants/application-draft.md`, TODOs must be replaced with
   real values) once live with users.

## 6. What can be done autonomously vs what needs the user

| Step | Who | Notes |
|------|-----|-------|
| Register the **app** code (Path A) | **User** | base.dev account + wallet sign-in in browser; set payout address (D2). |
| Register the **agent** code (Path B) | Agent, once D3 is decided | No auth, no signature — a single `curl` POST. But pointless until an agent wallet exists and the agent sends txs. |
| Compute the suffix from the code | Agent | Formula verified (§2); or `npm i ox` + `Attribution.toDataSuffix`. |
| Integrate into frontend + agent service | Agent | Exact plan in §5.2–5.3; needs the code first. |
| Verify attribution on Basescan | Agent | After one real attributed tx. |
| Grant application | User (form) | Agent prepares the draft; the user submits from their own account. |

## 7. Current state (10 Nov 2026 ~01:10 WIB)

- **Builder Code REGISTERED by the user on base.dev: `bc_1d16z07i`.**
- **Suffix computed (verified vs official example, byte-for-byte match):**
  `0x62635f316431367a3037690b0080218021802180218021802180218021`
  (29 bytes; decodes to `bc_1d16z07i`, length 11, schema 0, marker `8021`×8).
- **INTEGRATED 10 Nov ~01:10 WIB:**
  - Agent service `agent-service/src/config.mjs`: `BUILDER_CODE` defaults to the
    full suffix (env override still works); the misleading "0x8021..." comment
    fixed. `/api/quote` dry-run verified live: returns
    `dataSuffix: 0x62635f316431367a3037690b00...8021` ($10 NVDAc quote,
    amountOutEst 5,652,272, price $176.92).
  - Frontend `app/index.html`: `DATA_SUFFIX` constant + `withAttribution()`
    helper + `sendAttributed()` (populate → append suffix → send) applied at
    the 4 write call sites: createPlan, approve, swapExactInput,
    recordExecution. Frontend JS syntax validated (`node --check`).
  - NOTE: two remaining write sites are NOT yet attributed — `cancelPlan` and
    `recordTrade` still call the contract directly. Apply the same helper
    there if full attribution is wanted.
- **Basescan attribution verification of a real attributed transaction is
  still pending** — it happens when the user does their first real on-chain
  action (create a plan) through the frontend.
- Mainnet contracts live: Plans `0x3C73Fc8483BEf77886D7648D1fE0e3AAd11582D1`,
  Swapper `0xB0EE078994Af6cdC897063ec8F5777fe9a221439` (Base, chain 8453).
- Repo: https://github.com/Heryp0401/stockpilot (up to date with mainnet).

## Sources

- docs.base.org/specifications/builder-codes (overview, FAQ)
- docs.base.org/specifications/builder-codes/for-app-developers (dashboard
  registration, `dataSuffix` wiring, suffix byte layout + `bc_b7k3p9da` example)
- docs.base.org/specifications/builder-codes/for-agent-developers (agent API,
  no-auth registration, `walletAddress` field)
- github.com/base/skills — `skills/build-on-base/references/agents/register.md`
  (exact API endpoint `POST https://api.base.dev/v1/agents/builder-codes`,
  `scripts/register.sh`, 4-phase flow, "do not re-register" rule)
- github.com/base/skills — `skills/build-on-base/references/builder-codes/
  overview.md` (framework detection, `ox` install, verification steps) and
  `rpc.md` (ethers v6 `withAttribution` pattern used in §5.3)
- docs.relay.link — ERC-8021 suffix construction (cross-checked; Base docs
  example is authoritative and was recomputed to match)
- `~/workspace/base-grants/research.md` (grant eligibility: Builder Code
  integration is the stated first step)
