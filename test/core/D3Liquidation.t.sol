/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "../Context.t.sol";

contract D3LiquidationTest is Context {
    function setUp() public {
        contextBasic();
    }

    // ---------- Start Liquidation ----------

    function testStartLiquidation() public {
        contextPoolLiquidating();
        assertEq(uint256(d3MM.getStatus()), 1);
    }

    function testStartLiquidationByNonLiquidator() public {
        contextPoolOngoing();
        vm.expectRevert(bytes(Errors.NOT_ALLOWED_LIQUIDATOR));
        d3MM.startLiquidation();
    }

    function testStartLiquidationFailIfNotBelowMM() public {
        contextPoolOngoing();
        vm.prank(liquidator);
        vm.expectRevert(bytes(Errors.ABOVE_MM_RATIO));
        d3MM.startLiquidation();
    }

    // ---------- Liquidate ----------

    function testLiquidationNotStartedLiquidating() public {
        contextPoolOngoing();
        vm.expectRevert(bytes(Errors.POOL_NOT_LIQUIDATING));
        liquidateSwap(address(token1), address(token2), 153 ether);
    }

    function testLiquidationWrongRouter() public {
        contextPoolLiquidating();
        Types.LiquidationOrder memory order = Types.LiquidationOrder(
            address(token1),
            address(token2),
            100 ether
        );
        bytes memory routeData = abi.encodeWithSignature(
            "swap(address,address,uint256)",
            address(token1),
            address(token2),
            100 ether
        );
        vm.prank(liquidator);
        vm.expectRevert(bytes(Errors.NOT_ALLOWED_ROUTER));
        d3MM.liquidate(order, routeData, address(router));
    }

    function testLiquidationRouteFail() public {
        contextPoolLiquidating();
        router.disableRouter();
        vm.expectRevert(bytes(Errors.ROUTE_FAILED));
        liquidateSwap(address(token1), address(token2), 153 * 1e8);
    }

    function testLiquidationReturnValueLessThan95() public {
        contextPoolLiquidating();
        router.setSlippage(94);
        vm.expectRevert(bytes(Errors.DISCOUNT_EXCEED_5));
        liquidateSwap(address(token1), address(token2), 153 * 1e8);
    }

    // Under extreme condition, collateral ratio can become 0
    function testLiquidationExtreme() public {
        contextPoolLiquidatingExtreme();
        router.setSlippage(96);
        logLiquidationProcessInfo();

        vm.prank(liquidator);
        vm.expectRevert(bytes(Errors.LIQUIDATION_NOT_DONE));
        d3MM.finishLiquidation();

        liquidateSwap(address(token1), address(token2), 156 * 1e8);
        vm.prank(liquidator);
        vm.expectRevert(bytes(Errors.LIQUIDATION_NOT_DONE));
        d3MM.finishLiquidation();

        liquidateSwap(address(token1), address(token3), 10 * 1e8);
        vm.prank(liquidator);
        d3MM.finishLiquidation();
        assertEq(uint256(d3MM.getStatus()), 2);
    }

    // Liquidation can only be finished when the differences between balances
    // and targets are all positive or negative
    function testLiquidationNotDone() public {
        contextPoolLiquidating();
        router.setSlippage(96);
        liquidateSwap(address(token1), address(token2), 800 * 1e8);
        vm.expectRevert(bytes(Errors.LIQUIDATION_NOT_DONE));
        vm.prank(liquidator);
        d3MM.finishLiquidation();
    }

    // Liquidation can't start when collateral ratio above MM
    function testTriggerLiquidationFail() public {
        contextPoolOngoing();
        vm.prank(liquidator);
        vm.expectRevert(bytes(Errors.ABOVE_MM_RATIO));
        d3MM.startLiquidation();
    }

    // ---------- Finish Liquidation ----------

    function testFinishLiquidation() public {
        contextPoolLiquidationDone();
        assertEq(uint256(d3MM.getStatus()), 2);
    }

    function testFinishLiquidationInWrongState() public {
        contextPoolLiquidationDone();
        vm.prank(liquidator);
        vm.expectRevert(bytes(Errors.POOL_NOT_LIQUIDATING));
        d3MM.finishLiquidation();
    }

    function testFinishLiquidationByNonLiquidator() public {
        contextPoolLiquidating();
        vm.expectRevert(bytes(Errors.NOT_ALLOWED_LIQUIDATOR));
        d3MM.finishLiquidation();
    }

    function testFinishLiquidationWhenNotDone() public {
        contextPoolLiquidating();
        vm.prank(liquidator);
        vm.expectRevert(bytes(Errors.LIQUIDATION_NOT_DONE));
        d3MM.finishLiquidation();
    }

    // In this case, token3 has no debt
    function testFinishLiquidationIfSomeTokenHasNoDebt() public {
        interestRates.push(4e17); // 40%
        interestRates.push(2e17); // 20%
        interestRates.push(3e17); // 30%
        vm.startPrank(poolCreator);
        d3MM.setNextEpoch(tokens, interestRates);
        vm.warp(8 days);
        d3MM.executeEpochUpdate();
        d3MM.setMaxDeposit(address(token1), 10000 * 1e8);
        d3MM.setMaxDeposit(address(token2), 20000 ether);
        d3MM.setMaxDeposit(address(token3), 30000 ether);
        vm.stopPrank();

        ownerDeposit(address(token1), 5000 * 1e8);
        ownerDeposit(address(token2), 1000 ether);
        ownerDeposit(address(token3), 15000 ether);
        lpDeposit(user1, address(token1), 1000 * 1e8);
        lpDeposit(user1, address(token2), 8000 ether);

        vm.warp(4000 days);
        vm.prank(liquidator);
        d3MM.startLiquidation();

        uint256 token1Price = ID3Oracle(oracle).getPrice(address(token1));
        uint256 token2Price = ID3Oracle(oracle).getPrice(address(token2));
        uint256 token3Price = ID3Oracle(oracle).getPrice(address(token3));
        console.log(token1Price / 1e18, token2Price / 1e18, token3Price / 1e18);
        console.log("");
        logLiquidationProcessInfo();
        liquidateSwap(address(token1), address(token2), 153 * 1e8); // token1 is WBTC, decimals: 8
        vm.prank(liquidator);
        vm.expectEmit(true, true, true, true);
        emit FinishLiquidation();
        d3MM.finishLiquidation();
        assertEq(uint256(d3MM.getStatus()), 2);
    }

    // ---------- Force Refund ----------

    function testForceRefundWhenBalanceEnough() public {
        contextPoolOngoing();
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token2), 1000 ether);
        vm.expectRevert(bytes(Errors.NOT_PASS_DEADLINE));
        forceRefundSwap(0, address(token1), address(token2), 100 * 1e8);

        vm.warp(100 days);
        forceRefundSwap(0, address(token1), address(token2), 100 * 1e8);
    }

    function testForceRefundWhenBalanceNotEnough() public {
        contextPoolOngoing();

        // owner withdraw 9000 token2, LP withdraw 8000 token2
        vm.prank(poolCreator);
        d3MM.ownerWithdraw(poolCreator, address(token2), 9000 ether);
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token2), 8000 ether);

        vm.warp(100 days);

        forceRefundSwap(0, address(token1), address(token2), 10 * 1e8);
        assertEq(d3MM.getPendingWithdrawList().length, 1);

        forceRefundSwap(0, address(token1), address(token2), 90 * 1e8);
        assertEq(d3MM.getPendingWithdrawList().length, 0);
    }

    function testForceRefundWrongToToken() public {
        contextPoolOngoing();
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token2), 1000 ether);

        vm.warp(100 days);
        vm.expectRevert(bytes(Errors.TOKEN_NOT_MATCH));
        forceRefundSwap(0, address(token1), address(token3), 100 * 1e8);
    }

    function testForceRefundRouterFail() public {
        contextPoolOngoing();
        vm.prank(poolCreator);
        d3MM.ownerWithdraw(poolCreator, address(token2), 9000 ether);
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token2), 8000 ether);

        vm.warp(100 days);
        router.disableRouter();
        vm.expectRevert(bytes(Errors.ROUTE_FAILED));
        forceRefundSwap(0, address(token1), address(token2), 100 * 1e8);
    }

    function testForceRefundRouterReturnLessThan95() public {
        contextPoolOngoing();
        vm.prank(poolCreator);
        d3MM.ownerWithdraw(poolCreator, address(token2), 9000 ether);
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token2), 8000 ether);

        vm.warp(100 days);
        router.setSlippage(94);
        vm.expectRevert(bytes(Errors.DISCOUNT_EXCEED_5));
        forceRefundSwap(0, address(token1), address(token2), 100 * 1e8);
    }

    function testForceRefundWrongIndex() public {
        contextPoolOngoing();
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token2), 1000 ether);

        vm.warp(100 days);
        vm.expectRevert();
        forceRefundSwap(1, address(token1), address(token2), 100 * 1e8);
    }
}
