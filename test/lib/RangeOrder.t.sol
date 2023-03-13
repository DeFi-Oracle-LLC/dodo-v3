/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "../Context.t.sol";
import "lib/PMMRangeOrder.sol";
import "mock/MockD3Trading.sol";
import "lib/Types.sol";

contract RangeOrderTest is Context {
    MockD3Trading public mockTrading;
    address public owner = address(1);

    uint256 BIG_NUMBER_1E18 = 10 ** 18;

    function setUp() public {
        createTokens();
        createOracle();
        createFeeRate();
        mockTrading = new MockD3Trading();
        mockTrading.init(owner, address(oracle), address(feeRate));
    }

    // use fromToken bid curve and toToken ask curve

    function testNormalSwapZero() public {
        // token3 oracle price = 1
        Types.TokenMMInfo memory fromTokenInfo;
        fromTokenInfo.priceInfo = stickPrice(stickOneSlot(956, 15, 105, 16), stickOneSlot(953, 15, 102, 16));
        fromTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        fromTokenInfo.kAsk = 1000;
        fromTokenInfo.kBid = 1000;
        fromTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        fromTokenInfo.cumulativeAsk = 0;
        fromTokenInfo.cumulativeBid = 0;

        // token2 oracle price = 12
        // bid unit = 18 -vusd + token = token, ask unit = 18 - token + VUSD = 36 - token
        Types.TokenMMInfo memory toTokenInfo;
        toTokenInfo.priceInfo = stickPrice(stickOneSlot(115, 17, 126, 17), stickOneSlot(115, 17, 126, 17)); 
        toTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        toTokenInfo.kAsk = 1000;
        toTokenInfo.kBid = 1000;
        toTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        toTokenInfo.cumulativeAsk = 0;
        toTokenInfo.cumulativeBid = 0;

        // set token info
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token3), fromTokenInfo);
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("sell token:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 91162051973531862);
        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("buy token:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 11078083677122378701);
    }

    // Fuzz test, out of limit amount = 3242 89095 67565 43560 29131 93809 03196 25483
    function testNormalSwapZeroSellNoLimit(uint120 amount) public {
        // token3 oracle price = 1
        Types.TokenMMInfo memory fromTokenInfo;
        fromTokenInfo.priceInfo = stickPrice(stickOneSlot(956, 15, 105, 16), stickOneSlot(953, 15, 102, 16));
        fromTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        fromTokenInfo.kAsk = 1000;
        fromTokenInfo.kBid = 1000;
        fromTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        fromTokenInfo.cumulativeAsk = 0;
        fromTokenInfo.cumulativeBid = 0;

        // token2 oracle price = 12
        // bid unit = 18 -vusd + token = token, ask unit = 18 - token + VUSD = 36 - token
        Types.TokenMMInfo memory toTokenInfo;
        toTokenInfo.priceInfo = stickPrice(stickOneSlot(115, 17, 126, 17), stickOneSlot(115, 17, 126, 17)); 
        toTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        toTokenInfo.kAsk = 1000;
        toTokenInfo.kBid = 1000;
        toTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        toTokenInfo.cumulativeAsk = 0;
        toTokenInfo.cumulativeBid = 0;

        // set token info
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token3), fromTokenInfo);
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        if(amount <= 1000) amount += 1001;
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), uint256(amount));
        console.log(payFromAmount);
        require(receiveToAmount <= 30 ether, "out of set amount");
    }

    function testNormalSwapHasCumulative() public {
        // token3 oracle price = 1
        Types.TokenMMInfo memory fromTokenInfo;
        fromTokenInfo.priceInfo = stickPrice(stickOneSlot(956, 15, 105, 16), stickOneSlot(953, 15, 102, 16));
        fromTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        fromTokenInfo.kAsk = 1000;
        fromTokenInfo.kBid = 1000;
        fromTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        fromTokenInfo.cumulativeAsk = 4 ether;
        fromTokenInfo.cumulativeBid = 4 ether;

        // token2 oracle price = 12
        // bid unit = 18 -vusd + token = token, ask unit = 18 - token + VUSD = 36 - token
        Types.TokenMMInfo memory toTokenInfo;
        toTokenInfo.priceInfo = stickPrice(stickOneSlot(115, 17, 126, 17), stickOneSlot(115, 17, 126, 17)); 
        toTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        toTokenInfo.kAsk = 1000;
        toTokenInfo.kBid = 1000;
        toTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        toTokenInfo.cumulativeAsk = 4 ether;
        toTokenInfo.cumulativeBid = 4 ether;

        // set token info
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token3), fromTokenInfo);
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("sell token:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 89838918851537582);
        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("buy token:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 11253195762265955576);
    }

    function testNormalSwapBuyNotEnough() public {
        // token3 oracle price = 1
        Types.TokenMMInfo memory fromTokenInfo;
        fromTokenInfo.priceInfo = stickPrice(stickOneSlot(956, 15, 105, 16), stickOneSlot(953, 15, 102, 16));
        fromTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        fromTokenInfo.kAsk = 1000;
        fromTokenInfo.kBid = 1000;
        fromTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        fromTokenInfo.cumulativeAsk = 4 ether;
        fromTokenInfo.cumulativeBid = 4 ether;

        // token2 oracle price = 12
        // bid unit = 18 -vusd + token = token, ask unit = 18 - token + VUSD = 36 - token
        Types.TokenMMInfo memory toTokenInfo;
        toTokenInfo.priceInfo = stickPrice(stickOneSlot(115, 17, 126, 17), stickOneSlot(115, 17, 126, 17)); 
        toTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        toTokenInfo.kAsk = 1000;
        toTokenInfo.kBid = 1000;
        toTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        toTokenInfo.cumulativeAsk = 29 ether;
        toTokenInfo.cumulativeBid = 4 ether;

        // set token info
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token3), fromTokenInfo);
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokens(address(token3), address(token2), BIG_NUMBER_1E18 * 30);
        console.log("sell token:", payFromAmount, receiveToAmount);
        //assertEq(receiveToAmount, 165888333152374882);

        vm.expectRevert(bytes("PMMRO_VAULT_RESERVE_NOT_ENOUGH"));
        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), BIG_NUMBER_1E18 * 2);
        console.log("buy token:", payFromAmount, receiveToAmount);
        //assertEq(payFromAmount, 11253195762265955576);
    }

    function testNormalSwapFromDecimalIs6() public {
        Types.TokenMMInfo memory fromTokenInfo = constructDefaultToken3Info();
        Types.TokenMMInfo memory toTokenInfo = constructDefaultToken2Info();

        fromTokenInfo.priceInfo = stickPrice(stickOneSlot(956, 27, 105, 28), stickOneSlot(953, 3, 102, 4));
        fromTokenInfo.amountInfo = stickAmount(30, 6, 30, 18); // bid amount use VUSD amount
        fromTokenInfo.cumulativeAsk = 4 * (10**6);
        fromTokenInfo.cumulativeBid = 4 * (10**18); // bid vusd amount cumulative
        // special if
        //fromTokenInfo.kBid = 0;

        // reset oracle price
        oracle.setPriceSource(
            address(token3),
            PriceSource(address(token3ChainLinkOracle), true, 5* (10**17), 18, 6)
        );
        
        // set token info
        setTokenInfo(address(token3), fromTokenInfo);
        setTokenInfo(address(token2), toTokenInfo);

        // query token2 = 12, token3 = 1
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), 10**6);
        console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 89838918851537582);

        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("buy token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 11253195);

        (payFromAmount, receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token2), address(token3), BIG_NUMBER_1E18);
        console.log("sell token 2 - 3:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 12394134);

        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token2), address(token3), 10**6);
        console.log("buy token 2 - 3:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 78483386520988782);

    }

    function testNormalSwapToDecimalIs6() public {
        Types.TokenMMInfo memory fromTokenInfo = constructDefaultToken3Info();
        Types.TokenMMInfo memory toTokenInfo = constructDefaultToken2Info();

        toTokenInfo.priceInfo = stickPrice(stickOneSlot(115, 29, 126, 29), stickOneSlot(806, 2, 884, 2)); // stickOneSlot(806, 14, 884, 14)  stickOneSlot(115, 17, 126, 17)
        toTokenInfo.amountInfo = stickAmount(30, 6, 30, 18); // bid amount use VUSD amount
        toTokenInfo.cumulativeAsk = 4 * (10**6);
        toTokenInfo.cumulativeBid = 4 * (10**18); // bid vusd amount cumulative
        // special if
        //fromTokenInfo.kBid = 0;

        // reset oracle price
        oracle.setPriceSource(
            address(token2),
            PriceSource(address(token2ChainLinkOracle), true, 5* (10**17), 18, 6)
        );
        
        // set token info
        setTokenInfo(address(token3), fromTokenInfo);
        setTokenInfo(address(token2), toTokenInfo);

        // query token2 = 12, token3 = 1
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18); // 6 token decimal may cause price decimal is 1
        console.log("sell token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 89839);

        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), 10 ** 6);
        console.log("buy token 3 - 2:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 11253195762560614773);

        (payFromAmount, receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token2), address(token3), 10 ** 6);
        console.log("sell token 2 - 3:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 12394134141342483049);

        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token2), address(token3), BIG_NUMBER_1E18);
        console.log("buy token 2 - 3:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 78483);
    }

    function testCornerSwapFromAmountIsZero() public {
        // token3 oracle price = 1
        Types.TokenMMInfo memory fromTokenInfo;
        fromTokenInfo.priceInfo = stickPrice(stickOneSlot(956, 15, 105, 16), stickOneSlot(953, 15, 102, 16));
        fromTokenInfo.amountInfo = stickAmount(30, 18, 0, 18);
        fromTokenInfo.kAsk = 1000;
        fromTokenInfo.kBid = 1000;
        fromTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        fromTokenInfo.cumulativeAsk = 4 ether;
        fromTokenInfo.cumulativeBid = 4 ether;

        // token2 oracle price = 12
        // bid unit = 18 -vusd + token = token, ask unit = 18 - token + VUSD = 36 - token
        Types.TokenMMInfo memory toTokenInfo;
        toTokenInfo.priceInfo = stickPrice(stickOneSlot(115, 17, 126, 17), stickOneSlot(115, 17, 126, 17)); // stickOneSlot(806, 14, 884, 14)
        toTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        toTokenInfo.kAsk = 1000;
        toTokenInfo.kBid = 1000;
        toTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        toTokenInfo.cumulativeAsk = 4 ether;
        toTokenInfo.cumulativeBid = 4 ether;

        // set token info
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token3), fromTokenInfo);
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        vm.expectRevert(bytes("PMMRO_AMOUNT_ZERO"));
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18 * 2);
        console.log("sell token:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 0);

        vm.expectRevert(bytes("PMMRO_AMOUNT_ZERO"));
        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), BIG_NUMBER_1E18 * 2);
        console.log("buy token:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 0);
    }

    function testCornerSwapBidAmountIsZero() public {
        // token3 oracle price = 1
        Types.TokenMMInfo memory fromTokenInfo;
        fromTokenInfo.priceInfo = stickPrice(stickOneSlot(956, 15, 105, 16), stickOneSlot(953, 15, 102, 16));
        fromTokenInfo.amountInfo = stickAmount(30, 18, 0, 18);
        fromTokenInfo.kAsk = 1000;
        fromTokenInfo.kBid = 1000;
        fromTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        fromTokenInfo.cumulativeAsk = 4 ether;
        fromTokenInfo.cumulativeBid = 4 ether;

        // token2 oracle price = 12
        // bid unit = 18 -vusd + token = token, ask unit = 18 - token + VUSD = 36 - token
        Types.TokenMMInfo memory toTokenInfo;
        toTokenInfo.priceInfo = stickPrice(stickOneSlot(115, 17, 126, 17), stickOneSlot(115, 17, 126, 17)); // stickOneSlot(806, 14, 884, 14)
        toTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        toTokenInfo.kAsk = 1000;
        toTokenInfo.kBid = 1000;
        toTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        toTokenInfo.cumulativeAsk = 4 ether;
        toTokenInfo.cumulativeBid = 4 ether;

        // set token info
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token3), fromTokenInfo);
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        vm.expectRevert(bytes("PMMRO_AMOUNT_ZERO"));
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18 * 2);
        console.log("sell token:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 0);

        vm.expectRevert(bytes("PMMRO_AMOUNT_ZERO"));
        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), BIG_NUMBER_1E18 * 2);
        console.log("buy token:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 0);
    }

    function testCornerSwapFromBidPriceIsZero() public {
        Types.TokenMMInfo memory fromTokenInfo = constructDefaultToken3Info();
        Types.TokenMMInfo memory toTokenInfo = constructDefaultToken2Info();

        fromTokenInfo.priceInfo = stickPrice(stickOneSlot(956, 15, 105, 16), stickOneSlot(0, 15, 102, 16));
        
        // set token info
        setTokenInfo(address(token3), fromTokenInfo);
        setTokenInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        vm.expectRevert(bytes("PMMRO_PRICE_ZERO"));
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18 * 2);
        console.log("sell token:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 0);

        vm.expectRevert(bytes("PMMRO_PRICE_ZERO"));
        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), BIG_NUMBER_1E18 * 2);
        console.log("buy token:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 0);
    }

    function testCornerSwapToAskPriceIsZero() public {
        Types.TokenMMInfo memory fromTokenInfo = constructDefaultToken3Info();
        Types.TokenMMInfo memory toTokenInfo = constructDefaultToken2Info();

        toTokenInfo.priceInfo = stickPrice(stickOneSlot(0, 17, 126, 17), stickOneSlot(115, 17, 126, 17));
        
        // set token info
        setTokenInfo(address(token3), fromTokenInfo);
        setTokenInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        vm.expectRevert(bytes("PMMRO_PRICE_ZERO"));
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18 * 2);
        console.log("sell token:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 0);

        vm.expectRevert(bytes("PMMRO_PRICE_ZERO"));
        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), BIG_NUMBER_1E18 * 2);
        console.log("buy token:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 0);
    }

    function testCornerSwapFromKBidIsOne() public {
        Types.TokenMMInfo memory fromTokenInfo = constructDefaultToken3Info();
        Types.TokenMMInfo memory toTokenInfo = constructDefaultToken2Info();

        fromTokenInfo.kBid = 10000;
        
        // set token info
        setTokenInfo(address(token3), fromTokenInfo);
        setTokenInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("sell token:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 89598459638685782);

        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("buy token:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 11305531443697634459);
    }

    function testCornerSwapToKAskIsOne() public {
        Types.TokenMMInfo memory fromTokenInfo = constructDefaultToken3Info();
        Types.TokenMMInfo memory toTokenInfo = constructDefaultToken2Info();

        toTokenInfo.kAsk = 10000;
        
        // set token info
        setTokenInfo(address(token3), fromTokenInfo);
        setTokenInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("sell token:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 89484395257223794);

        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("buy token:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 11302778558381434341);
    }

    function testCornerSwapFromKBidIsZero() public {
        Types.TokenMMInfo memory fromTokenInfo = constructDefaultToken3Info();
        Types.TokenMMInfo memory toTokenInfo = constructDefaultToken2Info();

        fromTokenInfo.kBid = 0;
        
        // set token info
        setTokenInfo(address(token3), fromTokenInfo);
        setTokenInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("sell token:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 90506925438227533);

        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("buy token:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 11059633588427863377);
    }

    function testCornerSwapToKAskIsZero() public {
        Types.TokenMMInfo memory fromTokenInfo = constructDefaultToken3Info();
        Types.TokenMMInfo memory toTokenInfo = constructDefaultToken2Info();

        toTokenInfo.kAsk = 0;
        
        // set token info
        setTokenInfo(address(token3), fromTokenInfo);
        setTokenInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokensForLib(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("sell token:", payFromAmount, receiveToAmount);
        assertEq(receiveToAmount, 90571519982421877);

        (payFromAmount, receiveToAmount, , ) = mockTrading.queryBuyTokens(address(token3), address(token2), BIG_NUMBER_1E18);
        console.log("buy token:", payFromAmount, receiveToAmount);
        assertEq(payFromAmount, 11150110754684329200);
    }

    function setTokenInfo(address token, Types.TokenMMInfo memory tokenInfo) public {
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(token, tokenInfo);
    }

    function testSwapLargeFromAmount() public {
        // token3 oracle price = 1
        Types.TokenMMInfo memory fromTokenInfo;
        fromTokenInfo.priceInfo = stickPrice(stickOneSlot(956, 15, 105, 16), stickOneSlot(953, 15, 102, 16));
        fromTokenInfo.amountInfo = stickAmount(30, 18, 30000, 18);
        fromTokenInfo.kAsk = 1000;
        fromTokenInfo.kBid = 1000;
        fromTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        fromTokenInfo.cumulativeAsk = 0;
        fromTokenInfo.cumulativeBid = 0;

        // token2 oracle price = 12
        // bid unit = 18 -vusd + token = token, ask unit = 18 - token + VUSD = 36 - token
        Types.TokenMMInfo memory toTokenInfo;
        toTokenInfo.priceInfo = stickPrice(stickOneSlot(115, 17, 126, 17), stickOneSlot(115, 17, 126, 17)); 
        toTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        toTokenInfo.kAsk = 1000;
        toTokenInfo.kBid = 1000; 
        toTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        toTokenInfo.cumulativeAsk = 0;
        toTokenInfo.cumulativeBid = 0;

        // set token info
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token3), fromTokenInfo);
        vm.prank(owner);
        mockTrading.setNewTokenMMInfo(address(token2), toTokenInfo);

        // query
        vm.prank(user1);
        (uint256 payFromAmount, uint256 receiveToAmount, , ) = mockTrading.querySellTokens(address(token3), address(token2), 3000000 ether);
        console.log(payFromAmount);
        console.log(receiveToAmount);
        require(receiveToAmount <= 30 ether, "out of set amount");
    }
}