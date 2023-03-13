/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "../Context.t.sol";
import "lib/PMMRangeOrder.sol";
import "lib/Types.sol";
import {MockFeeRateImpl} from "mock/MockFeeRateModel.sol";

contract TradingTest is Context {

    address public owner = address(1);

    uint256 public BIG_NUMBER_1E18 = 10 ** 18;

    function setUp() public {
        createD3MM();
        contextPoolOngoing();
        createD3Proxy();
        setDefaultTokenMMInfo();
        
        faucet(address(token3), user1, 100 ether);
        faucet(address(token2), user1, 100 ether);
        vm.startPrank(user1);
        token2.approve(address(dodoApprove), type(uint256).max);
        token3.approve(address(dodoApprove), type(uint256).max);
        vm.stopPrank();
    }

    function testNormalSellTokens() public {
        // before swap flag
        ( , , , , , ,uint256 flag, uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);

        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        uint256 gasleft1 = gasleft();
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );
        uint256 gasleft2 = gasleft();
        console.log("sellToken1stTime gas\t", gasleft1 - gasleft2);

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log(receiveToToken);
        assertEq(beforeBalance2 - afterBalance2, 1 ether); 
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 12632307089314270479);

        // from bid, to ask
        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 12244411430531823227);


        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token3), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 12632307089314270479);
        assertEq(cumulativeBid, 0);
    }

    function testNormalBuyTokens() public {
        // before swap flag
        ( , , , , , ,uint256 flag, uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);

        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        uint256 gasleft1 = gasleft();
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            30 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );
        uint256 gasleft2 = gasleft();
        console.log("buyToken1stTime gas\t", gasleft1 - gasleft2);

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log(beforeBalance2 - afterBalance2);
        //console.log(afterBalance3 - beforeBalance3);

        assertEq(beforeBalance2 - afterBalance2, receiveToToken); 
        assertEq(beforeBalance2 - afterBalance2, 77200081594493055); 
        assertEq(afterBalance3 - beforeBalance3, 1 ether);

        // from bid, to ask
        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 1);
        //assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 956932880610229917);
        //console.log("cumualativeBid:", cumulativeBid);


        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token3), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 1 ether);
        //assertEq(cumulativeBid, 0);
    }

    function testNormalSwapFee() public {
        // before set feerate
        (uint256 payFrom, uint256 receiveToToken, ,uint256 mtFee) = d3MM.querySellTokens(
            address(token2), 
            address(token3), 
            1 ether
        );
        //console.log("before mtFee:", receiveToToken, mtFee);
        assertEq(receiveToToken, 12632307089314270479);
        assertEq(mtFee, 0);

        (payFrom, receiveToToken, , mtFee) = d3MM.queryBuyTokens(
            address(token2), 
            address(token3), 
            1 ether 
        );
        //console.log("before mtFee:", payFrom, mtFee);
        assertEq(payFrom, 77200081594493055);
        assertEq(mtFee, 0);

        // set fee rate 0.1%
        MockFeeRateImpl rateImpl;
        rateImpl = new MockFeeRateImpl();
        vm.prank(poolCreator);
        feeRate.setFeeProxy(address(rateImpl));

        // after feeRate query and Swap
        (payFrom, receiveToToken, ,mtFee) = d3MM.querySellTokens(
            address(token2), 
            address(token3), 
            1 ether
        );
        assertEq(receiveToToken + mtFee, 12632307089314270479);
        assertEq(mtFee, 12632307089314270);
        
        //console.log("after mtFee:", receiveToToken, mtFee);
        (payFrom, receiveToToken, , mtFee) = d3MM.queryBuyTokens(
            address(token2), 
            address(token3), 
            1 ether 
        );
        //console.log("after mtFee:", payFrom, mtFee);
        assertEq(mtFee, 1 ether / (10** 3));
        assertEq(payFrom, 77277429840929863);
        assertEq(receiveToToken + mtFee, 1 ether * 1.001);

        // swap sell
        {
        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);
        uint256 beforeBalancePC3 = token3.balanceOf(poolCreator);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);
        uint256 afterBalancePC3 = token3.balanceOf(poolCreator);

        //console.log(beforeBalance2 - afterBalance2);
        //console.log(afterBalance3 - beforeBalance3);

        assertEq(beforeBalance2 - afterBalance2, 1 ether); 
        assertEq(afterBalance3 - beforeBalance3, 12619674782224956209);
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalancePC3 - beforeBalancePC3, 12632307089314270);
        }

        // swap buy
        {
        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);
        uint256 beforeBalancePC3 = token3.balanceOf(poolCreator);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            30 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);
        uint256 afterBalancePC3 = token3.balanceOf(poolCreator);

        //console.log(beforeBalance2 - afterBalance2);
        //console.log(afterBalance3 - beforeBalance3);
        //console.log(afterBalancePC3 - beforeBalancePC3);

        assertEq(beforeBalance2 - afterBalance2, 81898408637708943); 
        assertEq(beforeBalance2 - afterBalance2, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 1 ether);
        assertEq(afterBalancePC3 - beforeBalancePC3, 1000000000000000);
        }
    }

    function testBuyTokensMaxPayNotEnough() public {
        // before swap flag
        ( , , , , , ,uint256 flag, uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);

        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        vm.expectRevert(bytes("D3MM_MAXPAYAMOUNT_NOT_ENOUGH"));
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        assertEq(beforeBalance2 - afterBalance2, 0); 
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 0);

        // from bid, to ask
        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        //assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);
        //console.log("cumualativeBid:", cumulativeBid);


        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token3), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        //assertEq(cumulativeBid, 0);
    }

    function testSellTokenReceiveNotEnough() public {
        // before swap flag
        ( , , , , , ,uint256 flag, uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);

        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        vm.expectRevert(bytes("D3MM_MINRESERVE_NOT_ENOUGH"));
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            13 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        assertEq(beforeBalance2 - afterBalance2, 0); 
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 0);

        // from bid, to ask
        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);


        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token3), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);
    }

    function testTransferInNotEnough() public {
        vm.startPrank(user1);
        token2.approve(address(dodoApprove), 10**14);
        token3.approve(address(dodoApprove), 10**17);
        vm.stopPrank();

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        // approve not enough
        vm.expectRevert();
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            13 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        vm.expectRevert();
        receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // d3mm balance not enough
        faucet(address(token2), address(d3MM), 10 ** 14);
        vm.expectRevert(bytes("D3MM_FROMAMOUNT_NOT_ENOUGH"));
        receiveToToken = failD3Proxy.buyTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            13 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        faucet(address(token2), address(d3MM), 10 ** 17);
        vm.expectRevert(bytes("D3MM_FROMAMOUNT_NOT_ENOUGH"));
        receiveToToken = failD3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // success test

        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);
        ( , , , , , ,uint256 flag,  , uint256 cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeBid, 0);

        receiveToToken = failD3Proxy.buyTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            13 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        assertEq(beforeBalance2 - afterBalance2, 1000); 
        assertEq(afterBalance3 - beforeBalance3, 1000000000000000000);

        ( , , , , , ,flag, , cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 1);
        assertEq(cumulativeBid, 956932880610229917);
        //console.log("cumualativeBid:", cumulativeBid);

        beforeBalance2 = afterBalance2;
        beforeBalance3 = afterBalance3;

        faucet(address(token2), address(d3MM), 10 ** 18);
        receiveToToken = failD3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        afterBalance2 = token2.balanceOf(user1);
        afterBalance3 = token3.balanceOf(user1);

        //console.log(receiveToToken);
        assertEq(beforeBalance2 - afterBalance2, 1000); 
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 12576032061388552670);
    }

    function testSwapBelowIMRatio() public {
        // before swap flag
        ( , , , , , ,uint256 flag, uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);

        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        vm.prank(poolCreator);
        d3MM.setBeatInterval(5000 days);

        // CollateralRatio
        vm.warp(4000 days);

        vm.expectRevert(bytes("D3MM_BELOW_IM_RATIO"));
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        assertEq(beforeBalance2 - afterBalance2, 0); 
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 0);

        vm.expectRevert(bytes("D3MM_BELOW_IM_RATIO"));
        receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            13 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        afterBalance2 = token2.balanceOf(user1);
        afterBalance3 = token3.balanceOf(user1);

        assertEq(beforeBalance2 - afterBalance2, 0); 
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 0);

        // from bid, to ask
        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);


        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token3), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);
    }

    function testSwapWhenHearbeatPassMaxInterval() public {
        // before swap flag
        ( , , , , , ,uint256 flag, uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        vm.warp(10 days);

        vm.expectRevert(bytes(Errors.HEARTBEAT_CHECK_FAIL));
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        vm.expectRevert(bytes(Errors.HEARTBEAT_CHECK_FAIL));
        receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            13 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );
    }

    function testPoolNotOngoingStopSwap() public {
        // before swap flag
        ( , , , , , ,uint256 flag, uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);

        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        // CollateralRatio
        vm.warp(4000 days);
        vm.prank(liquidator);
        d3MM.startLiquidation();

        vm.expectRevert();
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        assertEq(beforeBalance2 - afterBalance2, 0); 
        assertEq(afterBalance3 - beforeBalance3, 0);
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);

    }

    function testGetOneTokenPriceSet() public {
        uint96 token2Price = d3MM.getOneTokenPriceSet(address(token2));
        uint96 oriToken2Price = stickPrice(
            stickOneSlot(115, 17, 126, 17),
            stickOneSlot(806, 14, 884, 14)
        );
        assertEq(oriToken2Price, token2Price);
    }
}