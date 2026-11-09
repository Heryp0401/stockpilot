// StockPilot agent service — keeper.
// Scans StockPilotPlans for due plans and PREPARES their next execution
// (a quote + the exact swap calldata). It never signs, never broadcasts,
// never moves funds: the plan owner executes the swap in their own wallet
// and the execution is then recorded onchain via recordExecution.
//
// Run once:  node src/keeper.mjs --once
// Run loop:  node src/keeper.mjs            (every KEEPER_INTERVAL_MIN, default 10)
// Env:       REGISTRY_ADDRESS, BASE_RPC_URL, KEEPER_INTERVAL_MIN
//
// Output: keeper-status.json in this directory (last run, due plans,
// prepared quotes). The frontend reads /api/due for the same data live.

import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { ethers } from "ethers";
import {
  CHAIN,
  ACTIVE_CHAIN_ID,
  REGISTRY_ADDRESS,
  REGISTRY_ABI,
} from "./config.mjs";
import { buildSwap, getDuePlans } from "./quote.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const STATUS_FILE = join(__dirname, "..", "keeper-status.json");
const INTERVAL_MIN = Number(process.env.KEEPER_INTERVAL_MIN || 10);
const ONCE = process.argv.includes("--once");

async function scanOnce() {
  const startedAt = new Date().toISOString();
  const status = {
    startedAt,
    registry: REGISTRY_ADDRESS,
    chain: CHAIN,
    chainId: ACTIVE_CHAIN_ID,
    due: [],
    errors: [],
  };

  if (
    !REGISTRY_ADDRESS ||
    REGISTRY_ADDRESS === "0x0000000000000000000000000000000000000000"
  ) {
    status.errors.push(
      "registry not deployed yet: set REGISTRY_ADDRESS to the deployed StockPilotPlans address"
    );
    writeFileSync(STATUS_FILE, JSON.stringify(status, null, 2));
    console.log(JSON.stringify(status, null, 2));
    return status;
  }

  try {
    const due = await getDuePlans(REGISTRY_ADDRESS);
    console.log(`[${startedAt}] ${due.length} due plan(s)`);
    for (const plan of due) {
      try {
        const quote = await buildSwap(
          plan.token,
          plan.amountUSDC,
          plan.owner
        );
        console.log(
          `  plan #${plan.planId} "${plan.name}" — ${plan.amountUSDC} USDC -> ~${quote.amountOutEst} ${quote.tokenSymbol || plan.token} (min ${quote.amountOutMinimum})`
        );
        status.due.push({ ...plan, preparedQuote: quote });
      } catch (e) {
        const msg = `plan #${plan.planId}: quote failed: ${e?.message || e}`;
        console.log(`  ${msg}`);
        status.errors.push(msg);
        status.due.push({ ...plan, preparedQuote: null, error: msg });
      }
    }
  } catch (e) {
    const msg = `scan failed: ${e?.message || e}`;
    console.log(msg);
    status.errors.push(msg);
  }

  status.finishedAt = new Date().toISOString();
  writeFileSync(STATUS_FILE, JSON.stringify(status, null, 2));
  return status;
}

if (ONCE) {
  await scanOnce();
  process.exit(0);
}

console.log(
  `stockpilot keeper running every ${INTERVAL_MIN} min (registry ${REGISTRY_ADDRESS})`
);
await scanOnce();
setInterval(scanOnce, INTERVAL_MIN * 60 * 1000);
