// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StockPilotPlans.sol";

contract StockPilotPlansTest is Test {
    StockPilotPlans public registry;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public constant NVDAC =
        0xb20000000000000000000078ee7ce2fE4908108C;
    address public constant TSLAC =
        0xb2000000000000000000001e800a7f5189430cD0;

    function setUp() public {
        registry = new StockPilotPlans();
    }

    function testCreatePlan() public {
        vm.prank(alice);
        uint256 id = registry.createPlan(NVDAC, 10_000000, 7 days, 4, "NVDA weekly");
        assertEq(id, 0);
        assertEq(registry.planCount(), 1);
        StockPilotPlans.Plan memory p = registry.getPlan(0);
        assertEq(p.owner, alice);
        assertEq(p.token, NVDAC);
        assertEq(p.amountUSDC, 10_000000);
        assertEq(p.intervalSeconds, 7 days);
        assertEq(p.maxExecutions, 4);
        assertEq(p.executions, 0);
        assertTrue(p.active);
        assertEq(registry.plansOf(alice).length, 1);
    }

    function testCreatePlanRejectsBadInput() public {
        vm.prank(alice);
        vm.expectRevert(StockPilotPlans.InvalidToken.selector);
        registry.createPlan(address(0), 10_000000, 7 days, 0, "x");
        vm.expectRevert(StockPilotPlans.InvalidAmount.selector);
        registry.createPlan(NVDAC, 0, 7 days, 0, "x");
        vm.expectRevert(StockPilotPlans.InvalidInterval.selector);
        registry.createPlan(NVDAC, 10_000000, 30 minutes, 0, "x");
        vm.expectRevert(StockPilotPlans.EmptyName.selector);
        registry.createPlan(NVDAC, 10_000000, 7 days, 0, "");
    }

    function testRecordExecutionFlow() public {
        vm.prank(alice);
        uint256 id = registry.createPlan(NVDAC, 10_000000, 7 days, 2, "NVDA weekly");
        bytes32 h = bytes32(uint256(0x1234));
        vm.prank(alice);
        registry.recordExecution(id, 10_000000, 55_000000, h);
        StockPilotPlans.Plan memory p = registry.getPlan(id);
        assertEq(p.executions, 1);
        assertEq(p.lastExecutedAt, block.timestamp);
        assertTrue(p.active);
        // too soon for the second execution
        vm.prank(alice);
        vm.expectRevert(StockPilotPlans.TooSoon.selector);
        registry.recordExecution(id, 10_000000, 55_000000, h);
        // after the interval, second execution completes the plan
        vm.warp(block.timestamp + 7 days);
        vm.prank(alice);
        registry.recordExecution(id, 10_000000, 56_000000, h);
        p = registry.getPlan(id);
        assertEq(p.executions, 2);
        assertFalse(p.active); // maxExecutions reached
        // further executions revert
        vm.warp(block.timestamp + 7 days);
        vm.prank(alice);
        vm.expectRevert(StockPilotPlans.PlanNotActive.selector);
        registry.recordExecution(id, 10_000000, 56_000000, h);
    }

    function testOnlyOwnerCanExecuteAndCancel() public {
        vm.prank(alice);
        uint256 id = registry.createPlan(TSLAC, 5_000000, 1 days, 0, "TSLA daily");
        vm.prank(bob);
        vm.expectRevert(StockPilotPlans.NotPlanOwner.selector);
        registry.recordExecution(id, 5_000000, 1_000000, bytes32(0));
        vm.prank(bob);
        vm.expectRevert(StockPilotPlans.NotPlanOwner.selector);
        registry.cancelPlan(id);
        vm.prank(alice);
        registry.cancelPlan(id);
        assertFalse(registry.getPlan(id).active);
    }

    function testRecordTrade() public {
        vm.prank(alice);
        uint256 tid = registry.recordTrade(NVDAC, 25_000000, 140_000000, bytes32(uint256(0xabcd)));
        assertEq(tid, 0);
        assertEq(registry.tradeCount(), 1);
    }

    function testIsDue() public {
        vm.prank(alice);
        uint256 id = registry.createPlan(NVDAC, 10_000000, 1 days, 0, "due?");
        assertTrue(registry.isDue(id));
        vm.prank(alice);
        registry.recordExecution(id, 10_000000, 55_000000, bytes32(0));
        assertFalse(registry.isDue(id));
        vm.warp(block.timestamp + 1 days);
        assertTrue(registry.isDue(id));
    }
}
