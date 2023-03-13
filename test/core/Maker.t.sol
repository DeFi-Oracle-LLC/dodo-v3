/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "../Context.t.sol";
import "lib/PMMRangeOrder.sol";
import "mock/MockD3Trading.sol";
import "lib/Types.sol";

contract MakerTest is Context {
    address public owner = address(1);

    uint256 public BIG_NUMBER_1E18 = 10**18;

    function setUp() public {
        createD3MM();
        contextPoolOngoing();
        createD3Proxy();

        faucet(address(token3), user1, 100 ether);
        faucet(address(token2), user1, 100 ether);
        vm.startPrank(user1);
        token2.approve(address(dodoApprove), type(uint256).max);
        token3.approve(address(dodoApprove), type(uint256).max);
        vm.stopPrank();
    }

    function testSetNewToken() public {
        setDefaultTokenMMInfo();

        (, , , , , , uint256 flag, , ) = d3MM.getTokenMMInfoForRead(
            address(token1),
            user1
        );
        assertEq(flag, 0);

        // query
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = d3MM
            .querySellTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 91162051973531862);

        (payFromAmount, receiveToAmount, , ) = d3MM.queryBuyTokens(
            address(token3),
            address(token2),
            BIG_NUMBER_1E18
        );
        console.log("buy token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 11078083677122378701);

        (payFromAmount, receiveToAmount, , ) = d3MM.querySellTokens(
            address(token2),
            address(token3),
            BIG_NUMBER_1E18
        );
        console.log("sell token 2 - 3:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 12632307089314270479);

        (payFromAmount, receiveToAmount, , ) = d3MM.queryBuyTokens(
            address(token2),
            address(token3),
            BIG_NUMBER_1E18
        );
        console.log("buy token 2 - 3:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 77200081594493055);
    }

    function testSetTokensPrice() public {
        setDefaultTokenMMInfo();
        uint96 priceSet;
        uint256 flag;
        uint256 downPrice;
        uint256 upPrice;
        {
            // set 1 token new price
            address[] memory tokens = new address[](1);
            tokens[0] = address(token2);
            uint96 token2NewPrice = stickPrice(
                stickOneSlot(102, 17, 131, 17),
                stickOneSlot(801, 14, 840, 14)
            );
            uint96[] memory tokenPrices = new uint96[](1);
            tokenPrices[0] = token2NewPrice;
            vm.prank(poolCreator);
            uint256 gasleft1 = gasleft();
            d3MM.setTokensPrice(tokens, tokenPrices);
            uint256 gasleft2 = gasleft();
            console.log("setTokensPrice 1 token gas\t", gasleft1 - gasleft2);

            (priceSet, , , , , , flag, , ) = d3MM.getTokenMMInfoForRead(
                address(token2),
                user1
            );
            assertEq(flag, 0);

            (downPrice, upPrice) = Types.parseAskPrice(priceSet);
            console.log("token2 ask price:", downPrice);
            console.log(upPrice);
            (downPrice, upPrice) = Types.parseBidPrice(priceSet);
            console.log(downPrice);
            console.log(upPrice);
        }

        {
            // set 3 token new price
            address[] memory tokens = new address[](3);
            tokens[0] = address(token2);
            tokens[1] = address(token3);
            tokens[2] = address(token1);
            uint96 token2NewPrice = stickPrice(
                stickOneSlot(102, 17, 131, 17),
                stickOneSlot(801, 14, 840, 14)
            );
            uint96 token3NewPrice = stickPrice(
                stickOneSlot(934, 15, 103, 16),
                stickOneSlot(943, 15, 102, 16)
            );
            uint96[] memory tokenPrices = new uint96[](3);
            tokenPrices[0] = token2NewPrice;
            tokenPrices[1] = token3NewPrice;
            tokenPrices[2] = stickPrice(
                stickOneSlot(1290, 18, 1306, 18),
                stickOneSlot(765, 12, 773, 12)
            );
            vm.prank(poolCreator);
            uint256 gasleft1 = gasleft();
            d3MM.setTokensPrice(tokens, tokenPrices);
            uint256 gasleft2 = gasleft();
            console.log("setTokensPrice 3 token gas\t", gasleft1 - gasleft2);

            (priceSet, , , , , , flag, , ) = d3MM.getTokenMMInfoForRead(
                address(token1),
                user1
            );
            assertEq(flag, 0);
            (downPrice, upPrice) = Types.parseAskPrice(priceSet);
            assertEq(downPrice, 1290 * (10**18));
            assertEq(upPrice, 1306 * (10**18));
            (downPrice, upPrice) = Types.parseBidPrice(priceSet);
            console.log(downPrice);
            console.log(upPrice);
        }

        {
            // set token2 new price
            address[] memory tokens = new address[](2);
            tokens[0] = address(token2);
            tokens[1] = address(token3);
            uint96 token2NewPrice = stickPrice(
                stickOneSlot(105, 17, 130, 17),
                stickOneSlot(796, 14, 840, 14)
            );
            uint96 token3NewPrice = stickPrice(
                stickOneSlot(930, 15, 105, 16),
                stickOneSlot(940, 15, 102, 16)
            );
            uint96[] memory tokenPrices = new uint96[](2);
            tokenPrices[0] = token2NewPrice;
            tokenPrices[1] = token3NewPrice;
            vm.prank(poolCreator);
            uint256 gasleft1 = gasleft();
            d3MM.setTokensPrice(tokens, tokenPrices);
            uint256 gasleft2 = gasleft();
            console.log("setTokensPrice 2 token gas\t", gasleft1 - gasleft2);
        }

        (priceSet, , , , , , flag, , ) = d3MM.getTokenMMInfoForRead(
            address(token2),
            user1
        );
        assertEq(flag, 0);

        (downPrice, upPrice) = Types.parseAskPrice(priceSet);
        console.log("token2 ask price:", downPrice);
        console.log(upPrice);
        (downPrice, upPrice) = Types.parseBidPrice(priceSet);
        console.log(downPrice);
        console.log(upPrice);

        (priceSet, , , , , , flag, , ) = d3MM.getTokenMMInfoForRead(
            address(token3),
            user1
        );
        assertEq(flag, 0);

        (downPrice, upPrice) = Types.parseAskPrice(priceSet);
        console.log("token3 ask price:", downPrice);
        console.log(upPrice);
        (downPrice, upPrice) = Types.parseBidPrice(priceSet);
        console.log(downPrice);
        console.log(upPrice);

        // query
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = d3MM
            .querySellTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 101205596270334212);
        //assertEq(receiveToAmount, 91162051973531862);

        (payFromAmount, receiveToAmount, , ) = d3MM.queryBuyTokens(
            address(token3),
            address(token2),
            BIG_NUMBER_1E18
        );
        console.log("buy toke 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 9986468393501535703);
        //assertEq(payFromAmount, 11078083677122378701);

        (payFromAmount, receiveToAmount, , ) = d3MM.querySellTokens(
            address(token2),
            address(token3),
            BIG_NUMBER_1E18
        );
        console.log("sell token 2 - 3:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 13158829431075371243);
        //assertEq(receiveToAmount, 12632307089314270479);

        (payFromAmount, receiveToAmount, , ) = d3MM.queryBuyTokens(
            address(token2),
            address(token3),
            BIG_NUMBER_1E18
        );
        console.log("buy token 2 - 3:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 74158371814493533);
        //assertEq(payFromAmount, 77200081594493055);
    }

    function testSetAmounts() public {
        setDefaultTokenMMInfo();
        // swap and check flag state
        (
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 flag,
            uint256 cumulativeAsk,
            uint256 cumulativeBid
        ) = d3MM.getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

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

        // from bid, to ask
        (, , , , , , flag, cumulativeAsk, cumulativeBid) = d3MM
            .getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 12244411430531823227);

        (, , , , , , flag, cumulativeAsk, cumulativeBid) = d3MM
            .getTokenMMInfoForRead(address(token3), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 12632307089314270479);
        assertEq(cumulativeBid, 0);

        // set new amount
        uint64 token2Amount = stickAmount(40, 18, 40, 18);
        address[] memory tokens = new address[](1);
        tokens[0] = address(token2);
        uint64[] memory tokenAmounts = new uint64[](1);
        tokenAmounts[0] = token2Amount;
        vm.prank(poolCreator);
        d3MM.setTokensAmounts(tokens, tokenAmounts);

        // the second swap and flag check
        (, , , , , , flag, cumulativeAsk, cumulativeBid) = d3MM
            .getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);

        (, , , , , , flag, cumulativeAsk, cumulativeBid) = d3MM
            .getTokenMMInfoForRead(address(token3), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 12632307089314270479);
        assertEq(cumulativeBid, 0);

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

        (, , , , , , flag, cumulativeAsk, cumulativeBid) = d3MM
            .getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 1);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 12288077166374223547);
        //console.log(cumulativeBid);

        (, , , , , , flag, cumulativeAsk, cumulativeBid) = d3MM
            .getTokenMMInfoForRead(address(token3), user1);
        assertEq(flag, 1);
        //console.log(cumulativeAsk);
        assertEq(cumulativeAsk, 24874439281285027801);
        assertEq(cumulativeBid, 0);
    }

    function testSetKs() public {
        setDefaultTokenMMInfo();
        // query
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = d3MM
            .querySellTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        //console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 91162051973531862);

        uint32 token2K = stickKs(9000, 0);
        address[] memory tokens = new address[](1);
        tokens[0] = address(token2);
        uint32[] memory tokenKs = new uint32[](1);
        tokenKs[0] = token2K;
        vm.prank(poolCreator);
        d3MM.setTokensKs(tokens, tokenKs);

        vm.prank(user1);
        (payFromAmount, receiveToAmount, , ) = d3MM.querySellTokens(
            address(token3),
            address(token2),
            BIG_NUMBER_1E18
        );
        console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 91157677167838818);
    }

    function testSetAmountsAndPrices() public {
        setDefaultTokenMMInfo();
        bytes[] memory mulData = new bytes[](2);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = d3MM
            .querySellTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        //console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 91162051973531862);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token2);
        tokens[1] = address(token3);
        uint96 token2NewPrice = stickPrice(
            stickOneSlot(105, 17, 130, 17),
            stickOneSlot(796, 14, 840, 14)
        );
        uint96 token3NewPrice = stickPrice(
            stickOneSlot(930, 15, 105, 16),
            stickOneSlot(940, 15, 102, 16)
        );
        uint96[] memory tokenPrices = new uint96[](2);
        tokenPrices[0] = token2NewPrice;
        tokenPrices[1] = token3NewPrice;

        vm.prank(poolCreator);
        d3MM.setTokensPrice(tokens, tokenPrices);

        mulData[1] = abi.encodeWithSignature(
            "setTokensPrice("
            "address[],"
            "uint96[]"
            ")",
            //[address(token2), address(token3)],
            //[token2NewPrice, token3NewPrice]
            tokens,
            tokenPrices
        );

        uint64 token2Amount = stickAmount(40, 18, 40, 18);
        uint64 token3Amount = stickAmount(15, 18, 15, 18);
        uint64[] memory tokenAmounts = new uint64[](2);
        tokenAmounts[0] = token2Amount;
        tokenAmounts[1] = token3Amount;

        mulData[0] = abi.encodeWithSignature(
            "setTokensAmounts("
            "address[],"
            "uint64[]"
            ")",
            tokens,
            tokenAmounts
            //[address(token2), address(token3)],
            //[token2Amount, token3Amount]
        );

        vm.prank(poolCreator);
        d3MM.multicall(mulData);

        (payFromAmount, receiveToAmount, , ) = d3MM.querySellTokens(
            address(token3),
            address(token2),
            BIG_NUMBER_1E18
        );
        //console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 101112133720470197);
    }

    function testKInvalid1() public {
        setDefaultTokenMMInfo();
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = d3MM
            .querySellTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        //console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 91162051973531862);

        uint32 token2K = stickKs(9000, 10002);
        address[] memory tokens = new address[](1);
        tokens[0] = address(token2);
        uint32[] memory tokenKs = new uint32[](1);
        tokenKs[0] = token2K;
        vm.prank(poolCreator);
        vm.expectRevert(bytes("D3MM_K_LIMIT_ERROR"));
        d3MM.setTokensKs(tokens, tokenKs);

        tokenKs[0] = stickKs(10002, 10002);
        vm.prank(poolCreator);
        vm.expectRevert(bytes("D3MM_K_LIMIT_ERROR"));
        d3MM.setTokensKs(tokens, tokenKs);

        vm.prank(user1);
        (payFromAmount, receiveToAmount, , ) = d3MM.querySellTokens(
            address(token3),
            address(token2),
            BIG_NUMBER_1E18
        );
        //console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 91162051973531862);
    }

    function testKInvalid2() public {
        // setNewToken K invalid
        vm.startPrank(poolCreator);
        Types.TokenMMInfo memory token1Info = constructDefaultToken1Info();
        vm.expectRevert(bytes("D3MM_K_LIMIT_ERROR"));
        d3MM.setNewToken(
            address(token1),
            false,
            token1Info.priceInfo,
            token1Info.amountInfo,
            10002,
            token1Info.kBid
        );

        vm.expectRevert(bytes("D3MM_K_LIMIT_ERROR"));
        d3MM.setNewToken(
            address(token1),
            false,
            token1Info.priceInfo,
            token1Info.amountInfo,
            1000,
            10002
        );
        vm.stopPrank();
    }

    function testAskAmountInvalid() public {
        setDefaultTokenMMInfo();

        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = d3MM
            .querySellTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        //console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 91162051973531862);

        uint64 token2Amount = stickAmount(9001, 18, 40, 18);
        address[] memory tokens = new address[](1);
        tokens[0] = address(token2);
        uint64[] memory tokenAmounts = new uint64[](1);
        tokenAmounts[0] = token2Amount;

        vm.prank(poolCreator);
        vm.expectRevert(bytes("D3MM_ASK_AMOUTN_EXCEED"));
        d3MM.setTokensAmounts(tokens, tokenAmounts);

        vm.prank(user1);
        (payFromAmount, receiveToAmount, , ) = d3MM.querySellTokens(
            address(token3),
            address(token2),
            BIG_NUMBER_1E18
        );
        //console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 91162051973531862);
    }

    function testUpAndDownPriceInvalid() public {
        setDefaultTokenMMInfo();

        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = d3MM
            .querySellTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        //console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 91162051973531862);

        // construct invalid price

        uint256 downPrice = 105;
        uint256 offset = type(uint16).max - 1;
        uint256 askPriceInvalid = (downPrice << 24) + (offset << 8) + 17;
        uint256 askPrice = (downPrice << 24) + (20 << 8) + 17;

        address[] memory tokens = new address[](2);
        tokens[0] = address(token2);
        tokens[1] = address(token3);
        uint96 token2NewPrice = uint96(
            (askPriceInvalid << 40) + (796 << 24) + (105 << 8) + 14
        ); //stickPrice(stickOneSlot(105, 17, 65537, 17), stickOneSlot(796, 14, 840, 14));
        uint96 token3NewPrice = stickPrice(
            stickOneSlot(930, 15, 105, 16),
            stickOneSlot(940, 15, 102, 16)
        );
        uint96[] memory tokenPrices = new uint96[](2);
        tokenPrices[0] = token2NewPrice;
        tokenPrices[1] = token3NewPrice;
        vm.prank(poolCreator);
        vm.expectRevert(bytes("D3MM_PRICE_UP_BELOW_PRICE_DOWN"));
        d3MM.setTokensPrice(tokens, tokenPrices);

        tokenPrices[0] = uint96(
            (askPrice << 40) + (796 << 24) + (offset << 8) + 14
        ); //stickPrice(stickOneSlot(105, 17, 65537, 17), stickOneSlot(796, 14, 780, 14));
        vm.prank(poolCreator);
        vm.expectRevert(bytes("D3MM_PRICE_UP_BELOW_PRICE_DOWN"));
        d3MM.setTokensPrice(tokens, tokenPrices);

        vm.prank(user1);
        (payFromAmount, receiveToAmount, , ) = d3MM.querySellTokens(
            address(token3),
            address(token2),
            BIG_NUMBER_1E18
        );
        //console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 91162051973531862);
    }

    function testSetNSSlotPrice() public {
        setDefaultTokenMMInfo();

        uint96 token2NewPrice = stickPrice(
            stickOneSlot(105, 17, 130, 17),
            stickOneSlot(796, 14, 840, 14)
        );
        uint96 token3NewPrice = stickPrice(
            stickOneSlot(930, 15, 105, 16),
            stickOneSlot(940, 15, 102, 16)
        );
        uint96[] memory tokenPrices = new uint96[](2);
        tokenPrices[0] = token2NewPrice;
        tokenPrices[1] = token3NewPrice;

        address[] memory tokens = new address[](2);
        tokens[0] = address(token2);
        tokens[1] = address(token3);
        (, uint256[] memory nsTokenPrices) = d3MM.getNSTokenInfo();

        uint256 priceSet = nsTokenPrices[0];
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 tokenOriIndex = d3MM.getOneTokenOriginIndex(tokens[i]);
            priceSet = d3MM.stickPrice(
                priceSet,
                ((tokenOriIndex / 2) % 3),
                uint256(tokenPrices[i])
            );
        }

        // set price
        uint256[] memory slotIndex = new uint256[](1);
        uint256[] memory priceSlots = new uint256[](1);
        priceSlots[0] = priceSet;
        vm.prank(poolCreator);
        uint256 gasleft1 = gasleft();
        d3MM.setNSPriceSlot(slotIndex, priceSlots);
        uint256 gasleft2 = gasleft();
        console.log("setNSPriceSlot 2 token gas\t", gasleft1 - gasleft2);

        (uint96 priceInfo, , , , , , uint256 flag, , ) = d3MM
            .getTokenMMInfoForRead(address(token2), user1);
        assertEq(flag, 0);

        (uint256 downPrice, uint256 upPrice) = Types.parseAskPrice(priceInfo);
        console.log("token2 ask price:", downPrice);
        console.log(upPrice);
        (downPrice, upPrice) = Types.parseBidPrice(priceInfo);
        console.log(downPrice);
        console.log(upPrice);

        // query
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = d3MM
            .querySellTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 101205596270334212);
        //assertEq(receiveToAmount, 91162051973531862);

        (payFromAmount, receiveToAmount, , ) = d3MM.queryBuyTokens(
            address(token3),
            address(token2),
            BIG_NUMBER_1E18
        );
        console.log("buy toke 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 9986468393501535703);
        //assertEq(payFromAmount, 11078083677122378701);

        (payFromAmount, receiveToAmount, , ) = d3MM.querySellTokens(
            address(token2),
            address(token3),
            BIG_NUMBER_1E18
        );
        console.log("sell token 2 - 3:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 13158829431075371243);
        //assertEq(receiveToAmount, 12632307089314270479);

        (payFromAmount, receiveToAmount, , ) = d3MM.queryBuyTokens(
            address(token2),
            address(token3),
            BIG_NUMBER_1E18
        );
        console.log("buy token 2 - 3:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 74158371814493533);
        //assertEq(payFromAmount, 77200081594493055);
    }

    function testSetStableToken() public {
        setDefaultTokenMMInfo();
        addToken4InD3();

        uint96 token4NewPrice = stickPrice(
            stickOneSlot(105, 17, 130, 17),
            stickOneSlot(796, 14, 840, 14)
        );
        uint96[] memory tokenPrices = new uint96[](1);
        tokenPrices[0] = token4NewPrice;

        address[] memory tokens = new address[](1);
        tokens[0] = address(token4);
        (, uint256[] memory stableTokenPrices) = d3MM.getStableTokenInfo();

        uint256 priceSet = stableTokenPrices[0];
        uint256 tokenOriIndex = d3MM.getOneTokenOriginIndex(tokens[0]);
        priceSet = d3MM.stickPrice(
            priceSet,
            ((tokenOriIndex / 2) % 3),
            uint256(tokenPrices[0])
        );

        // set price
        uint256[] memory slotIndex = new uint256[](1);
        uint256[] memory priceSlots = new uint256[](1);
        priceSlots[0] = priceSet;
        vm.prank(poolCreator);
        uint256 gasleft1 = gasleft();
        d3MM.setStablePriceSlot(slotIndex, priceSlots);
        uint256 gasleft2 = gasleft();
        console.log("setNSPriceSlot 2 token gas\t", gasleft1 - gasleft2);

        (uint96 priceInfo, , , , , , uint256 flag, , ) = d3MM
            .getTokenMMInfoForRead(address(token4), user1);
        assertEq(flag, 0);

        (uint256 downPrice, uint256 upPrice) = Types.parseAskPrice(priceInfo);
        assertEq(downPrice, 105 * (10**17));
        assertEq(upPrice, 130 * (10**17));
        (downPrice, upPrice) = Types.parseBidPrice(priceInfo);
        assertEq(downPrice, 796 * (10**14));
    }

    function testReSetTokenZero() public {
        setDefaultTokenMMInfo();

        vm.startPrank(poolCreator);
        Types.TokenMMInfo memory token1Info = constructDefaultToken1Info();
        vm.expectRevert(bytes("D3MM_HAVE_SET_TOKEN_INFO"));
        d3MM.setNewToken(
            address(token1),
            true,
            token1Info.priceInfo,
            token1Info.amountInfo,
            token1Info.kAsk,
            token1Info.kBid
        );
        vm.stopPrank();
    }

    function testStickPriceAndAmount() public view {
        uint96 daiPrice = stickPrice(
            stickOneSlot(997, 15, 1012, 15),
            stickOneSlot(998, 15, 1002, 15)
        );
        uint64 daiAmount = stickAmount(600, 18, 600, 18);
        console.log("dai priceSet:", daiPrice);
        console.log("dai Amount:", daiAmount);

        uint96 wbtcPrice = stickPrice(
            stickOneSlot(20830, 28, 20850, 28),
            stickOneSlot(4723, 0, 4745, 0)
        );
        uint64 wbtcAmount = stickAmount(3, 8, 400, 18);
        console.log("wbtc priceSet:", wbtcPrice);
        console.log("wbtc Amount:", wbtcAmount);

        uint32 Ks = stickKs(1000, 1000);
        console.log("Ks:", Ks);
        (uint96 priceInfo, , , , , , uint256 flag, , ) = d3MM
            .getTokenMMInfoForRead(address(token4), user1);
        console.log("priceInfo", priceInfo);
        console.log("flag", flag);
    }
}
