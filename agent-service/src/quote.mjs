// StockPilot agent service — quote engine.
// Builds a prepared swap (USDC -> tokenized stock) through the
// StockPilotSwapper, which swaps directly against the verified Aerodrome
// Slipstream pool. No private keys, no signing, no broadcasting: the
// service only PREPARES; the user signs the swap in their own wallet.
//
// Price source: DexScreener (free, no key) top USDC pair for the token
// (price only — the DexScreener pair itself is NOT routable, so the swap
// always uses the verified pool from config). minOut uses a slippage
// buffer on the spot price. The user must approve USDC to the swapper
// first; buildSwap returns the approve calldata for that step.

import { ethers } from "ethers";
import {
  CHAIN,
  ACTIVE_USDC,
  SWAPPER_ADDRESS,
  ACTIVE_STOCKS,
  SWAPPER_ABI,
  ERC20_ABI,
  DEFAULT_SLIPPAGE_BPS,
  BUILDER_CODE,
  ACTIVE_RPC_URL,
} from "./config.mjs";

const DEXSCREENER_UA =
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36";

const provider = new ethers.JsonRpcProvider(ACTIVE_RPC_URL);
const swapperIface = new ethers.Interface(SWAPPER_ABI);
const erc20Iface = new ethers.Interface(ERC20_ABI);

export function verifiedStock(tokenAddress) {
  if (!tokenAddress) return null;
  const a = tokenAddress.toLowerCase();
  return ACTIVE_STOCKS.find((s) => s.address.toLowerCase() === a) || null;
}

/** Live spot price (USD) + best USDC pair for a token, via DexScreener. */
export async function getSpot(tokenAddress) {
  // Sepolia mock pools are fixed-rate; DexScreener has no pairs for them.
  if (CHAIN === "sepolia") {
    const known = ACTIVE_STOCKS.find(
      (s) => s.address.toLowerCase() === tokenAddress.toLowerCase()
    );
    if (!known || !known.priceUsd) throw new Error("not a mock stock");
    return {
      priceUsd: known.priceUsd,
      pairAddress: known.pool,
      dexId: "mock",
      liquidityUsd: 0,
      priceChange24h: null,
    };
  }
  const url = `https://api.dexscreener.com/tokens/v1/base/${tokenAddress}`;
  const res = await fetch(url, { headers: { "User-Agent": DEXSCREENER_UA } });
  if (!res.ok) throw new Error(`dexscreener http ${res.status}`);
  const pairs = await res.json();
  const usdcPairs = (pairs || []).filter(
    (p) => p?.quoteToken?.symbol === "USDC"
  );
  if (usdcPairs.length === 0) throw new Error("no USDC pair on DexScreener");
  // Prefer Aerodrome ("aero") then highest liquidity.
  usdcPairs.sort((a, b) => {
    const aAero = a.dexId === "aero" ? 1 : 0;
    const bAero = b.dexId === "aero" ? 1 : 0;
    if (aAero !== bAero) return bAero - aAero;
    return (b.liquidity?.usd || 0) - (a.liquidity?.usd || 0);
  });
  const p = usdcPairs[0];
  return {
    priceUsd: Number(p.priceUsd),
    pairAddress: p.pairAddress,
    dexId: p.dexId,
    liquidityUsd: p.liquidity?.usd || 0,
    priceChange24h: p.priceChange?.h24 ?? null,
  };
}

/**
 * Build a prepared swap: USDC -> tokenized stock, via StockPilotSwapper.
 * The swapper must be deployed first (SWAPPER_ADDRESS env); if it is the
 * zero address the quote still computes price/minOut but calldata is null.
 * @param {string} tokenOut - stock token address (8 decimals)
 * @param {bigint|string|number} amountInUSDC - USDC amount in 6-decimal units
 * @param {string} recipient - wallet that receives the stock tokens
 * @param {number} slippageBps - slippage buffer, default 100 (1%)
 * @returns prepared swap object (JSON-safe; bigints stringified)
 */
export async function buildSwap(
  tokenOut,
  amountInUSDC,
  recipient,
  slippageBps = DEFAULT_SLIPPAGE_BPS
) {
  const amountIn = BigInt(amountInUSDC);
  if (amountIn <= 0n) throw new Error("amountIn must be > 0");
  if (!ethers.isAddress(tokenOut)) throw new Error("invalid tokenOut");
  if (!ethers.isAddress(recipient)) throw new Error("invalid recipient");

  const known = verifiedStock(tokenOut);
  if (!known) throw new Error("token is not one of the verified stocks");
  const spot = await getSpot(tokenOut);
  if (!spot.priceUsd || spot.priceUsd <= 0)
    throw new Error("no usable spot price");

  // amountOut (stock, 8 decimals) = amountInUSDC / priceUsd * 1e8.
  // Integer math with price scaled to 1e6.
  const priceScaled = BigInt(Math.round(spot.priceUsd * 1e6)); // USD per token, 6dp
  const amountOutEst = (amountIn * 100000000n) / priceScaled;
  const minOut =
    (amountOutEst * BigInt(10000 - slippageBps)) / 10000n;

  const swapperDeployed =
    SWAPPER_ADDRESS !== "0x0000000000000000000000000000000000000000";
  const calldata = swapperDeployed
    ? swapperIface.encodeFunctionData("swapExactInput", [
        known.pool,
        ACTIVE_USDC,
        tokenOut,
        amountIn,
        minOut,
        recipient,
      ])
    : null;
  // Step 1 for the user: approve the swapper to pull `amountIn` USDC.
  const approveCalldata = swapperDeployed
    ? erc20Iface.encodeFunctionData("approve", [SWAPPER_ADDRESS, amountIn])
    : null;

  return {
    tokenIn: ACTIVE_USDC,
    tokenOut,
    tokenSymbol: known.symbol,
    pool: known.pool,
    poolFee: known.fee,
    pricePairAddress: spot.pairAddress, // DexScreener price source only
    dexId: spot.dexId,
    liquidityUsd: spot.liquidityUsd,
    priceUsd: spot.priceUsd,
    amountIn: amountIn.toString(),
    amountOutEst: amountOutEst.toString(),
    amountOutMinimum: minOut.toString(),
    slippageBps,
    swapper: SWAPPER_ADDRESS,
    swapperDeployed,
    // Step 1: approve USDC -> swapper (to USDC contract, value 0).
    approve: approveCalldata
      ? { to: ACTIVE_USDC, calldata: approveCalldata, value: "0" }
      : null,
    // Step 2: the swap itself (to the swapper, value 0).
    swap: calldata
      ? { to: SWAPPER_ADDRESS, calldata, value: "0" }
      : null,
    // ERC-8021 Builder Code suffix, appended to the swap tx data when set.
    // Empty string = no Builder Code configured yet.
    dataSuffix: BUILDER_CODE,
    value: "0",
  };
}

/** Read plans from the registry and return the ones that are due. */
export async function getDuePlans(registryAddress, owner = null) {
  const { REGISTRY_ABI } = await import("./config.mjs");
  const registry = new ethers.Contract(
    registryAddress,
    REGISTRY_ABI,
    provider
  );
  const count = Number(await registry.planCount());
  const out = [];
  for (let id = 0; id < count; id++) {
    const p = await registry.getPlan(id);
    if (owner && p.owner.toLowerCase() !== owner.toLowerCase()) continue;
    const due = await registry.isDue(id);
    if (!due) continue;
    out.push({
      planId: id,
      owner: p.owner,
      token: p.token,
      amountUSDC: p.amountUSDC.toString(),
      intervalSeconds: Number(p.intervalSeconds),
      maxExecutions: Number(p.maxExecutions),
      executions: Number(p.executions),
      createdAt: Number(p.createdAt),
      lastExecutedAt: Number(p.lastExecutedAt),
      active: p.active,
      name: p.name,
    });
  }
  return out;
}

/** Read all plans for an owner (with due flag). */
export async function getPlansOf(registryAddress, owner) {
  const { REGISTRY_ABI } = await import("./config.mjs");
  const registry = new ethers.Contract(
    registryAddress,
    REGISTRY_ABI,
    provider
  );
  const ids = await registry.plansOf(owner);
  const out = [];
  for (const id of ids) {
    const p = await registry.getPlan(id);
    const due = await registry.isDue(id);
    out.push({
      planId: Number(id),
      owner: p.owner,
      token: p.token,
      amountUSDC: p.amountUSDC.toString(),
      intervalSeconds: Number(p.intervalSeconds),
      maxExecutions: Number(p.maxExecutions),
      executions: Number(p.executions),
      createdAt: Number(p.createdAt),
      lastExecutedAt: Number(p.lastExecutedAt),
      active: p.active,
      name: p.name,
      due,
    });
  }
  return out;
}
