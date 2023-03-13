/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "../Context.t.sol";
import "lib/PMMRangeOrder.sol";
import "lib/Types.sol";
import {MockFeeRateImpl} from "mock/MockFeeRateModel.sol";

contract TradingSecondTest is Context {

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

        // swap first
        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        d3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );
    }

    function testNormalSellTokensSecondTime() public {
        // before swap flag
        ( , , , , , ,uint256 flag, uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 12244411430531823227);

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
        console.log("sellToken2ndTime gas\t", gasleft1 - gasleft2);

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log(receiveToToken);
        assertEq(beforeBalance2 - afterBalance2, 1 ether); 
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 11812386900793647420);

        // from bid, to ask
        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 24091922915612269200);
        //console.log("cumualativeBid:", cumulativeBid);


        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token3), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 24444693990107917899);
        assertEq(cumulativeBid, 0);
        //console.log("token3 cumAsk:", cumulativeAsk);
    }

    function testNormalBuyTokensSecondTime() public {
        // before swap flag
        ( , , , , , ,uint256 flag, uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 12244411430531823227);

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
        console.log("buyToken2ndTime gas\t", gasleft1 - gasleft2);

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log(beforeBalance2 - afterBalance2);
        //console.log(afterBalance3 - beforeBalance3);

        assertEq(beforeBalance2 - afterBalance2, receiveToToken); 
        assertEq(beforeBalance2 - afterBalance2, 81816364708521177); 
        assertEq(afterBalance3 - beforeBalance3, 1 ether);

        // from bid, to ask
        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 1);
        //assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 13230227157314448407);
        //console.log("cumualativeBid:", cumulativeBid);


        ( , , , , , ,flag, cumulativeAsk, cumulativeBid) = d3MM.getTokenMMInfoForRead(address(token3), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 13632307089314270479);
        assertEq(cumulativeBid, 0);
        //console.log("token3 cumAsk:", cumulativeAsk);
    }
}