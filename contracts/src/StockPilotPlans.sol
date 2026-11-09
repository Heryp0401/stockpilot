// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title StockPilotPlans
/// @notice Non-custodial on-chain registry for agent-managed tokenized-stock
/// strategies on Base. No funds are ever held by this contract: a Plan is a
/// public, ownable record of an agent strategy (e.g. "DCA $10 USDC into NVDAc
/// every week"). The StockPilot agent monitors Plans and prepares the
/// corresponding swaps (executed by the user in their own wallet); each
/// execution is recorded onchain so the app's usage is attributable and
/// auditable. Ad-hoc trades made through the app can also be recorded via
/// recordTrade.
/// @dev Built for Base "Stocks Maxxing Season" — Agentic Stock Finance track.
contract StockPilotPlans {
    struct Plan {
        address owner;
        address token; // tokenized-stock token (e.g. NVDAc)
        uint256 amountUSDC; // per-execution USDC amount (6 decimals)
        uint256 intervalSeconds; // cadence, e.g. 604800 = 1 week
        uint256 maxExecutions; // 0 = unlimited
        uint256 executions; // completed executions
        uint256 createdAt;
        uint256 lastExecutedAt; // 0 until first execution
        bool active;
        string name;
    }

    uint256 public planCount;
    uint256 public tradeCount;
    mapping(uint256 => Plan) public plans;
    mapping(address => uint256[]) private _plansOf;

    event PlanCreated(
        uint256 indexed planId,
        address indexed owner,
        address indexed token,
        uint256 amountUSDC,
        uint256 intervalSeconds,
        uint256 maxExecutions,
        string name
    );
    event PlanExecuted(
        uint256 indexed planId,
        address indexed owner,
        uint256 executionIndex,
        uint256 amountInUSDC,
        uint256 amountOut,
        bytes32 txHash
    );
    event PlanCancelled(uint256 indexed planId, address indexed owner);
    event TradeRecorded(
        uint256 indexed tradeId,
        address indexed trader,
        address indexed token,
        uint256 amountInUSDC,
        uint256 amountOut,
        bytes32 txHash
    );

    error InvalidToken();
    error InvalidAmount();
    error InvalidInterval();
    error EmptyName();
    error PlanNotFound();
    error NotPlanOwner();
    error PlanNotActive();
    error TooSoon();
    error MaxExecutionsReached();

    uint256 public constant MIN_INTERVAL = 1 hours;
    uint256 public constant MAX_NAME_LEN = 64;

    /// @notice Create a new agent strategy plan.
    function createPlan(
        address token,
        uint256 amountUSDC,
        uint256 intervalSeconds,
        uint256 maxExecutions,
        string calldata name
    ) external returns (uint256 planId) {
        if (token == address(0)) revert InvalidToken();
        if (amountUSDC == 0) revert InvalidAmount();
        if (intervalSeconds < MIN_INTERVAL) revert InvalidInterval();
        if (bytes(name).length == 0 || bytes(name).length > MAX_NAME_LEN) {
            revert EmptyName();
        }
        planId = planCount;
        planCount++;
        plans[planId] = Plan({
            owner: msg.sender,
            token: token,
            amountUSDC: amountUSDC,
            intervalSeconds: intervalSeconds,
            maxExecutions: maxExecutions,
            executions: 0,
            createdAt: block.timestamp,
            lastExecutedAt: 0,
            active: true,
            name: name
        });
        _plansOf[msg.sender].push(planId);
        emit PlanCreated(
            planId,
            msg.sender,
            token,
            amountUSDC,
            intervalSeconds,
            maxExecutions,
            name
        );
    }

    /// @notice Record one execution of a plan (called by the plan owner after
    /// the corresponding swap has been executed in their own wallet).
    /// @param txHash The hash of the swap transaction (for auditability).
    function recordExecution(
        uint256 planId,
        uint256 amountInUSDC,
        uint256 amountOut,
        bytes32 txHash
    ) external {
        Plan storage p = plans[planId];
        if (p.owner == address(0)) revert PlanNotFound();
        if (p.owner != msg.sender) revert NotPlanOwner();
        if (!p.active) revert PlanNotActive();
        if (p.maxExecutions != 0 && p.executions >= p.maxExecutions) {
            revert MaxExecutionsReached();
        }
        if (p.lastExecutedAt != 0) {
            if (block.timestamp < p.lastExecutedAt + p.intervalSeconds) {
                revert TooSoon();
            }
        }
        p.executions++;
        p.lastExecutedAt = block.timestamp;
        if (p.maxExecutions != 0 && p.executions >= p.maxExecutions) {
            p.active = false;
        }
        emit PlanExecuted(
            planId,
            msg.sender,
            p.executions,
            amountInUSDC,
            amountOut,
            txHash
        );
    }

    /// @notice Cancel a plan. Only the owner.
    function cancelPlan(uint256 planId) external {
        Plan storage p = plans[planId];
        if (p.owner == address(0)) revert PlanNotFound();
        if (p.owner != msg.sender) revert NotPlanOwner();
        if (!p.active) revert PlanNotActive();
        p.active = false;
        emit PlanCancelled(planId, msg.sender);
    }

    /// @notice Record an ad-hoc trade made through StockPilot (not tied to a
    /// plan). Lets all app-mediated tokenized-stock volume be attributable
    /// onchain. Called by the trader after the swap.
    function recordTrade(
        address token,
        uint256 amountInUSDC,
        uint256 amountOut,
        bytes32 txHash
    ) external returns (uint256 tradeId) {
        if (token == address(0)) revert InvalidToken();
        if (amountInUSDC == 0) revert InvalidAmount();
        tradeId = tradeCount;
        tradeCount++;
        emit TradeRecorded(
            tradeId,
            msg.sender,
            token,
            amountInUSDC,
            amountOut,
            txHash
        );
    }

    /// @notice Full plan record.
    function getPlan(uint256 planId) external view returns (Plan memory) {
        if (plans[planId].owner == address(0)) revert PlanNotFound();
        return plans[planId];
    }

    /// @notice Plan ids owned by an address.
    function plansOf(address owner) external view returns (uint256[] memory) {
        return _plansOf[owner];
    }

    /// @notice Whether a plan is due for its next execution.
    function isDue(uint256 planId) external view returns (bool) {
        Plan storage p = plans[planId];
        if (p.owner == address(0) || !p.active) return false;
        if (p.maxExecutions != 0 && p.executions >= p.maxExecutions) {
            return false;
        }
        if (p.lastExecutedAt == 0) return true;
        return block.timestamp >= p.lastExecutedAt + p.intervalSeconds;
    }
}
