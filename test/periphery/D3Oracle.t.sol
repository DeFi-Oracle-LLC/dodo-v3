/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "periphery/D3Oracle.sol";
import "mock/MockERC20.sol";
import "mock/MockChainlinkPriceFeed.sol";

contract D3OracleTest is Test {
    D3Oracle public oracle;
    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20 public token3;
    MockChainlinkPriceFeed public token1ChainLinkOracle;
    MockChainlinkPriceFeed public token2ChainLinkOracle;
    MockChainlinkPriceFeed public token3ChainLinkOracle;

    function setUp() public {
        createOracle();
    }

    function createOracle() public {
        oracle = new D3Oracle();
        token1 = new MockERC20("Token1", "TK1", 18);
        token2 = new MockERC20("Token2", "TK2", 18);
        token3 = new MockERC20("Token3", "TK3", 6);
        token1ChainLinkOracle = new MockChainlinkPriceFeed("Token1/USD", 18);
        token2ChainLinkOracle = new MockChainlinkPriceFeed("Token2/USD", 18);
        token3ChainLinkOracle = new MockChainlinkPriceFeed("Token3/USD", 18);
        token1ChainLinkOracle.feedData(1300 * 1e18);
        token2ChainLinkOracle.feedData(12 * 1e18);
        token3ChainLinkOracle.feedData(1 * 1e18);
        oracle.setPriceSource(
            address(token1),
            PriceSource(address(token1ChainLinkOracle), true, 1e16, 18, 18)
        );
        oracle.setPriceSource(
            address(token2),
            PriceSource(address(token2ChainLinkOracle), true, 1e16, 18, 18)
        );
        oracle.setPriceSource(
            address(token3),
            PriceSource(address(token3ChainLinkOracle), true, 1e16, 18, 6)
        );
    }

    function testSetPriceSource() public {
        vm.expectRevert(bytes("INVALID_PRICE_TOLERANCE"));
        oracle.setPriceSource(
            address(token1),
            PriceSource(address(token1ChainLinkOracle), true, 1e18+1, 18, 18)
        );

        vm.expectRevert(bytes("INVALID_PRICE_TOLERANCE"));
        oracle.setPriceSource(
            address(token1),
            PriceSource(address(token1ChainLinkOracle), true, 1e9, 18, 18)
        );
    }

    function testIsFeasible() public {
        assertEq(oracle.isFeasible(address(token1)), true);
        oracle.setPriceSource(
            address(token1),
            PriceSource(address(token1ChainLinkOracle), false, 1e18, 18, 18)
        );
        assertEq(oracle.isFeasible(address(token1)), false);
        assertEq(oracle.isFeasible(address(222)), false);
    }

    function testGetPrice() public {
        assertEq(oracle.getPrice(address(token1)), 1300e18);
        assertEq(oracle.getPrice(address(token2)), 12e18);
        assertEq(oracle.getPrice(address(token3)), 1e18 * 1e12);
        vm.expectRevert();
        oracle.getPrice(address(4444));
    }

    function testGetMaxReceive() public {
        oracle.setPriceSource(
            address(token1),
            PriceSource(address(token1ChainLinkOracle), true, 1e18, 18, 18)
        );
        oracle.setPriceSource(
            address(token3),
            PriceSource(address(token3ChainLinkOracle), true, 8e17, 18, 6)
        );
        assertEq(oracle.getMaxReceive(address(token1), address(token3), 1 ether), 1625 * 1e6);
    }

    function testSetTokenOracleFeasible() public {
        oracle.setTokenOracleFeasible(address(token1), false);
        assertEq(oracle.isFeasible(address(token1)), false);
    }
}
