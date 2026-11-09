// StockPilot agent service — HTTP server.
// Read-only + quote preparation. No private keys, no signing, no
// broadcasting. The frontend calls this to prepare swaps; the user signs
// every transaction in their own wallet.
//
// Endpoints:
//   GET  /api/health
//   GET  /api/stocks                 verified stock list (pools + fees)
//   GET  /api/quote?token=0x..&amountIn=10000000&recipient=0x..[&slippageBps=100]
//   GET  /api/plans?owner=0x..      plans for an owner (with due flag)
//   GET  /api/due[?owner=0x..]      due plans (all, or for one owner)
//   GET  /api/plan/<id>             single plan
//
// Run:  npm start            (port $PORT, default 3001)
// Env:  REGISTRY_ADDRESS, SWAPPER_ADDRESS, BASE_RPC_URL, BUILDER_CODE, PORT

import http from "node:http";
import {
  CHAIN,
  ACTIVE_CHAIN_ID,
  REGISTRY_ADDRESS,
  ACTIVE_STOCKS,
  SWAPPER_ADDRESS,
  ACTIVE_USDC,
  ACTIVE_RPC_URL,
} from "./config.mjs";
import { buildSwap, getDuePlans, getPlansOf, getSpot } from "./quote.mjs";
import { ethers } from "ethers";

const PORT = Number(process.env.PORT || 3001);

function send(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Content-Length": Buffer.byteLength(body),
  });
  res.end(body);
}

function registryOr400(res) {
  if (
    !REGISTRY_ADDRESS ||
    REGISTRY_ADDRESS === "0x0000000000000000000000000000000000000000"
  ) {
    send(res, 503, {
      ok: false,
      error:
        "registry not deployed yet: set REGISTRY_ADDRESS to the deployed StockPilotPlans address",
    });
    return null;
  }
  return REGISTRY_ADDRESS;
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "OPTIONS") {
      res.writeHead(204, {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
      });
      return res.end();
    }
    const url = new URL(req.url, `http://localhost:${PORT}`);
    const path = url.pathname;

    if (path === "/api/health") {
      return send(res, 200, {
        ok: true,
        service: "stockpilot-agent",
        chain: CHAIN,
        chainId: ACTIVE_CHAIN_ID,
        rpc: ACTIVE_RPC_URL,
        registry: REGISTRY_ADDRESS,
        swapper: SWAPPER_ADDRESS,
        usdc: ACTIVE_USDC,
      });
    }

    if (path === "/api/stocks") {
      return send(res, 200, { ok: true, stocks: ACTIVE_STOCKS });
    }

    if (path === "/api/quote") {
      const token = url.searchParams.get("token");
      const amountIn = url.searchParams.get("amountIn");
      const recipient = url.searchParams.get("recipient");
      const slippageBps = Number(url.searchParams.get("slippageBps") || 100);
      if (!token || !amountIn || !recipient) {
        return send(res, 400, {
          ok: false,
          error: "query params required: token, amountIn (USDC 6dp), recipient",
        });
      }
      if (!ethers.isAddress(token) || !ethers.isAddress(recipient)) {
        return send(res, 400, { ok: false, error: "invalid address" });
      }
      const q = await buildSwap(token, amountIn, recipient, slippageBps);
      return send(res, 200, { ok: true, quote: q });
    }

    if (path === "/api/spot") {
      const token = url.searchParams.get("token");
      if (!token) {
        return send(res, 400, { ok: false, error: "query param required: token" });
      }
      const spot = await getSpot(token);
      return send(res, 200, { ok: true, spot });
    }

    if (path === "/api/plans") {
      const reg = registryOr400(res);
      if (!reg) return;
      const owner = url.searchParams.get("owner");
      if (!owner || !ethers.isAddress(owner)) {
        return send(res, 400, { ok: false, error: "query param required: owner (address)" });
      }
      const plans = await getPlansOf(reg, owner);
      return send(res, 200, { ok: true, plans });
    }

    if (path === "/api/due") {
      const reg = registryOr400(res);
      if (!reg) return;
      const owner = url.searchParams.get("owner") || null;
      if (owner && !ethers.isAddress(owner)) {
        return send(res, 400, { ok: false, error: "invalid owner address" });
      }
      const due = await getDuePlans(reg, owner);
      return send(res, 200, { ok: true, due });
    }

    const planMatch = path.match(/^\/api\/plan\/(\d+)$/);
    if (planMatch) {
      const reg = registryOr400(res);
      if (!reg) return;
      const { REGISTRY_ABI } = await import("./config.mjs");
      const provider = new ethers.JsonRpcProvider(ACTIVE_RPC_URL);
      const registry = new ethers.Contract(reg, REGISTRY_ABI, provider);
      const id = Number(planMatch[1]);
      const p = await registry.getPlan(id);
      const due = await registry.isDue(id);
      return send(res, 200, {
        ok: true,
        plan: {
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
          due,
        },
      });
    }

    return send(res, 404, { ok: false, error: "not found" });
  } catch (e) {
    return send(res, 500, { ok: false, error: String(e?.message || e) });
  }
});

server.listen(PORT, () => {
  console.log(`stockpilot-agent listening on :${PORT}`);
  console.log(`chain: ${CHAIN} (${ACTIVE_CHAIN_ID})`);
  console.log(`registry: ${REGISTRY_ADDRESS}`);
  console.log(`swapper:  ${SWAPPER_ADDRESS}`);
});
