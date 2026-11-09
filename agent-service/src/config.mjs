// StockPilot agent service — config.
// All Base mainnet addresses below were VERIFIED on-chain (9 Nov 2026) via
// public Base RPCs. Do not "fix" them from memory: the correct native USDC
// on Base ends in ...bdA02913 (the similar ...bd029029 has NO code).
//
// SWAP PATH (verified on a Base mainnet fork, 9 Nov 2026):
// Aerodrome's Slipstream SwapRouter is NOT usable for these stocks:
//  * router 0xBE6D... (original factory) looks up the pool in the original
//    factory and gets address(0) -> revert.
//  * router 0x698C... (paired with the newest factory 0xf8f2...) HAS no
//    exactInputSingle selector in its bytecode, and its exactInput derives
//    the pool address via CREATE2 as 0x3376... (no code) instead of the
//    real pool -> revert.
//  * Odos aggregator API is Cloudflare-blocked (error 1033) from this VM.
//  * The Aerodrome v2 (classic) USDC/NVDAc pool is dust (totalSupply 1000).
// So StockPilot swaps DIRECTLY against the Slipstream pool through its own
// StockPilotSwapper contract (contracts/src/StockPilotSwapper.sol), which
// implements the V3 swap callback. Proven on-fork: $10 USDC -> 5,665,944
// NVDAc (8dp), and the reverse sell returns $9.99 USDC. The swapper is
// the ONLY contract the user approves USDC to; it holds no funds between
// calls. See docs/RESEARCH.md for the full router archaeology.

export const BASE_CHAIN_ID = 8453;
export const BASE_SEPOLIA_CHAIN_ID = 84532;

export const RPC_URLS = {
  base: process.env.BASE_RPC_URL || "https://mainnet.base.org",
  baseSepolia: process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org",
};

// Native USDC (Circle). 6 decimals. Verified: symbol "USDC", $4.31B supply.
export const USDC_BASE = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
// Circle testnet USDC on Base Sepolia (faucet.circle.com). 6 decimals.
export const USDC_BASE_SEPOLIA = "0x036CbD53842c5426634e7929541eC2318f3dCF7e";

// ---- Base mainnet deployment (live, 10 Nov 2026) ----
// Mainnet deployment of StockPilotPlans + StockPilotSwapper (real Slipstream
// pools, no mocks). See MAINNET_DEPLOY.md.
// Deployer: 0xE10e358D26B5F9F250dc7ae6c23f5Bf63588D7aF (disposable).
//   StockPilotPlans:  0x3C73Fc8483BEf77886D7648D1fE0e3AAd11582D1
//     tx 0x1b76f681dc8f8489ec06d1e6174141e0a04e511bfd5ef136bd4abd8443a748ec
//   StockPilotSwapper: 0xB0EE078994Af6cdC897063ec8F5777fe9a221439
//     tx 0xf6544b74e5cf4c1b6ddd237ee4eac9c9618f5574892f487791c0c340fe4af758
// Both verified with code on-chain (BaseScan). Default is mainnet (CHAIN=base).
export const REGISTRY_ADDRESS_MAINNET =
  "0x3C73Fc8483BEf77886D7648D1fE0e3AAd11582D1";
export const SWAPPER_ADDRESS_MAINNET =
  "0xB0EE078994Af6cdC897063ec8F5777fe9a221439";

// ---- Base Sepolia deployment (live, 9 Nov 2026) ----
// Testnet deployment of StockPilotPlans + StockPilotSwapper + mock USDC,
// mock stocks and fixed-rate mock pools. See SEPOLIA_DEPLOY.md.
// The service runs against Sepolia when CHAIN=sepolia is set:
//   CHAIN=sepolia npm start
// (uses the Sepolia RPC, mock USDC, mock stocks at fixed prices, and the
// addresses below). Default is mainnet (CHAIN=base).
export const CHAIN = process.env.CHAIN === "sepolia" ? "sepolia" : "base";
export const REGISTRY_ADDRESS_SEPOLIA =
  "0x2e5A1caB12b8902A840c8636caa58bcba084E060";
export const SWAPPER_ADDRESS_SEPOLIA =
  "0x1444524A69BFC4352DaAd9B5cd9272A2EbB11bb1";
export const USDC_MOCK_SEPOLIA =
  "0x4280743426B055e76Ee462a83efE66e787DD7C74";
export const MOCK_STOCKS_SEPOLIA = [
  { symbol: "NVDAc", ticker: "NVDA", name: "NVIDIA Corporation", address: "0xb75Bd2C86Fc79db001e07AC5d590288B5a1AE639", pool: "0x0B286F6eE6aa92Ec750a14b5d12F4B971D67D069", fee: 500, decimals: 8, priceUsd: 176.84 },
  { symbol: "AAPLc", ticker: "AAPL", name: "Apple Inc.", address: "0x21CAa92de6848b36Da97aFeA47bDBDb980F193f6", pool: "0xF7b1111d7b2AD109FDa383c2Eaa71eE2D9e8b1E5", fee: 500, decimals: 8, priceUsd: 350.94 },
  { symbol: "MSFTc", ticker: "MSFT", name: "Microsoft Corporation", address: "0x15AF17033Ec02679698c2FF48F3Ed3A91068cD0E", pool: "0xa3983Ca7d279aAa2932a665A9a3B5a68C399A0a5", fee: 500, decimals: 8, priceUsd: 542.55 },
  { symbol: "GOOGLc", ticker: "GOOGL", name: "Alphabet Inc.", address: "0x039c1eb1dCD8513c4F77B5ab1a1c522d1B78DA4d", pool: "0xbb86CF94914fAB15ad2261c05cc8cBFbd5D75604", fee: 500, decimals: 8, priceUsd: 293.62 },
  { symbol: "METAc", ticker: "META", name: "Meta Platforms Inc.", address: "0x9fF9cf18cFaf1236EBD58D3A09eaDCB3532ba078", pool: "0x317A76d60B2dDfC6c1572E3cf763AC9505114274", fee: 500, decimals: 8, priceUsd: 642.05 },
];

// StockPilotSwapper — the contract the user calls to swap USDC -> stock.
// Set after deployment (env SWAPPER_ADDRESS). Same contract on Sepolia
// (mock pools) and mainnet (real Slipstream pools); fill both.
// Default resolves to the live Sepolia deployment when CHAIN=sepolia.
export const SWAPPER_ADDRESS =
  process.env.SWAPPER_ADDRESS ||
  (CHAIN === "sepolia"
    ? SWAPPER_ADDRESS_SEPOLIA
    : SWAPPER_ADDRESS_MAINNET);

// StockPilotPlans registry — set after deployment (env REGISTRY_ADDRESS).
// Sepolia and mainnet deployments use the same contract; fill both.
// Default resolves to the live Sepolia deployment when CHAIN=sepolia.
export const REGISTRY_ADDRESS =
  process.env.REGISTRY_ADDRESS ||
  (CHAIN === "sepolia"
    ? REGISTRY_ADDRESS_SEPOLIA
    : REGISTRY_ADDRESS_MAINNET);

// Base Builder Code (ERC-8021) for StockPilot — App Builder Code registered
// on base.dev (dashboard.base.org), code bc_1d16z07i. Public value: it is
// appended to transaction calldata so Base can attribute the activity.
// The value must be the FULL dataSuffix hex (code ASCII + 1-byte length +
// schema 0 + 16-byte 8021 marker), NOT just the marker "0x8021..." alone.
// Override with BUILDER_CODE=<full suffix> when starting the service.
export const BUILDER_CODE =
  process.env.BUILDER_CODE ||
  "0x62635f316431367a3037690b0080218021802180218021802180218021";

// Default slippage for prepared swaps: 100 bps = 1%.
export const DEFAULT_SLIPPAGE_BPS = 100;

// Coinbase tokenized stocks with VERIFIED routable Aerodrome Slipstream
// pools. All five pools live in the newest official Aerodrome CLFactory
// 0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef, all tickSpacing=10, fee=500.
// Pool addresses were verified on-chain 9 Nov 2026: each pool's token0 is
// USDC and token1 is the stock, and a $10 fork swap through the
// StockPilotSwapper succeeded for every one. The DexScreener "top" USDC
// pairs (factory 0x9CB2...) are NOT routable by any known public router —
// do NOT use them. priceUsd is the DexScreener spot at research time; the
// service always fetches a live price, these are fallbacks / display only.
export const VERIFIED_STOCKS = [
  {
    symbol: "NVDAc",
    ticker: "NVDA",
    name: "NVIDIA Corporation",
    address: "0xb20000000000000000000078ee7ce2fE4908108C",
    decimals: 8,
    pool: "0x853F5f1B92b16714Fe6CDA67CAad0856B83C7ab9",
    fee: 500,
    priceUsd: 179.68,
  },
  {
    symbol: "AAPLc",
    ticker: "AAPL",
    name: "Apple Inc.",
    address: "0xb200000000000000000000C2e324d24d7eEcd1fb",
    decimals: 8,
    pool: "0xA3b1E3f9747065e2073722Ff4c9027d3eA4994F0",
    fee: 500,
    priceUsd: 350.94,
  },
  {
    symbol: "MSFTc",
    ticker: "MSFT",
    name: "Microsoft Corporation",
    address: "0xB200000000000000000000Ab99cFa739E253872B",
    decimals: 8,
    pool: "0x7103eB3c9590d1281f7dc03b2A9EE27C39dF5D54",
    fee: 500,
    priceUsd: 542.55,
  },
  {
    symbol: "GOOGLc",
    ticker: "GOOGL",
    name: "Alphabet Inc.",
    address: "0xb2000000000000000000002D0BA3164cc74f58B7",
    decimals: 8,
    pool: "0xB1987CAD1682841b4b641d50E520777eC5Ab5542",
    fee: 500,
    priceUsd: 293.62,
  },
  {
    symbol: "METAc",
    ticker: "META",
    name: "Meta Platforms Inc.",
    address: "0xb2000000000000000000008bC8786B856E61707C",
    decimals: 8,
    pool: "0xEAF57753BC382E0324a1D43F72E7027705a2273E",
    fee: 500,
    priceUsd: 642.05,
  },
];

// Chain-resolved values the service actually uses (CHAIN=sepolia selects
// the live Sepolia deployment; default is mainnet).
export const ACTIVE_CHAIN_ID =
  CHAIN === "sepolia" ? BASE_SEPOLIA_CHAIN_ID : BASE_CHAIN_ID;
export const ACTIVE_RPC_URL =
  CHAIN === "sepolia" ? RPC_URLS.baseSepolia : RPC_URLS.base;
export const ACTIVE_USDC =
  CHAIN === "sepolia" ? USDC_MOCK_SEPOLIA : USDC_BASE;
export const ACTIVE_STOCKS =
  CHAIN === "sepolia" ? MOCK_STOCKS_SEPOLIA : VERIFIED_STOCKS;

// Minimal ABIs.
export const REGISTRY_ABI = [
  "function planCount() view returns (uint256)",
  "function tradeCount() view returns (uint256)",
  "function getPlan(uint256 planId) view returns (tuple(address owner, address token, uint256 amountUSDC, uint256 intervalSeconds, uint256 maxExecutions, uint256 executions, uint256 createdAt, uint256 lastExecutedAt, bool active, string name))",
  "function plansOf(address owner) view returns (uint256[])",
  "function isDue(uint256 planId) view returns (bool)",
  "function createPlan(address token, uint256 amountUSDC, uint256 intervalSeconds, uint256 maxExecutions, string name) returns (uint256)",
  "function recordExecution(uint256 planId, uint256 amountInUSDC, uint256 amountOut, bytes32 txHash)",
  "function cancelPlan(uint256 planId)",
  "function recordTrade(address token, uint256 amountInUSDC, uint256 amountOut, bytes32 txHash) returns (uint256)",
  "event PlanCreated(uint256 indexed planId, address indexed owner, address indexed token, uint256 amountUSDC, uint256 intervalSeconds, uint256 maxExecutions, string name)",
  "event PlanExecuted(uint256 indexed planId, address indexed owner, uint256 executionIndex, uint256 amountInUSDC, uint256 amountOut, bytes32 txHash)",
  "event PlanCancelled(uint256 indexed planId, address indexed owner)",
  "event TradeRecorded(uint256 indexed tradeId, address indexed trader, address indexed token, uint256 amountInUSDC, uint256 amountOut, bytes32 txHash)",
];

// StockPilotSwapper: swapExactInput(pool, tokenIn, tokenOut, amountIn,
// minOut, recipient). The swapper pulls amountIn of tokenIn from the
// caller (needs a prior ERC20 approve to the swapper), swaps directly
// against the Slipstream pool, and sends the output to recipient.
export const SWAPPER_ABI = [
  "function swapExactInput(address pool, address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut, address recipient) returns (uint256 amountOut)",
  "event Swapped(address indexed user, address indexed pool, address indexed tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, address recipient)",
];

export const ERC20_ABI = [
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
  "function transfer(address to, uint256 amount) returns (bool)",
];

export const POOL_ABI = [
  "function fee() view returns (uint24)",
  "function token0() view returns (address)",
  "function token1() view returns (address)",
  "function liquidity() view returns (uint128)",
];
