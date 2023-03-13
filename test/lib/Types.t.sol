/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "../Context.t.sol";
import "mock/MockD3Trading.sol";
import "lib/PMMRangeOrder.sol";
import "lib/Types.sol";


contract TypesTest is Context {
    MockD3Trading public mockTrading;
    address public owner = address(1);

    uint256 BIG_NUMBER_1E18 = 10 ** 18;

    function setUp() public {
        createTokens();
        createOracle();
        mockTrading = new MockD3Trading();
        mockTrading.init(owner, address(oracle), address(1234));
    }

    function testParseAskAmount() public {
        uint64 amountSet = stickAmount(30, 18, 30, 18); // 30 ethers
        uint256 askAmount = mockTrading.parseAskAmount(amountSet);
        assertEq(askAmount, 30 ether);
    }

    function testParseBidAmount() public {
        uint64 amountSet = stickAmount(30, 18, 30, 18); // 30 ethers
        uint256 bidAmount = mockTrading.parseBidAmount(amountSet);
        assertEq(bidAmount, 30 ether);
    }

    function testParseAskPrice() public {
        uint96 priceSet = stickPrice(stickOneSlot(956, 15, 105, 16), stickOneSlot(953, 15, 102, 16));
        (uint askDown, uint askUp) = mockTrading.parseAskPrice(priceSet);
        assertEq(askUp, 105 * (10 **16));
        assertEq(askDown, 956 * (10 **15));
    }

    function testParseBidPrice() public {
        uint96 priceSet = stickPrice(stickOneSlot(956, 15, 105, 16), stickOneSlot(953, 15, 102, 16));
        (uint bidDown, uint bidUp) = mockTrading.parseBidPrice(priceSet);
        assertEq(bidUp, 102 * (10 **16));
        assertEq(bidDown, 953 * (10 **15));
    }

    function testParseK() public {
        uint16 originK = 1000;
        uint k = mockTrading.parseK(originK);
        assertEq(k, 10**17);
    }
}