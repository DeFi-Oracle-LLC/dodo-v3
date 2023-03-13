/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "core/D3Token.sol";
import "mock/MockERC20.sol";

contract D3TokenTest is Test {
    D3Token public d3Token;
    MockERC20 public token1;
    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public pool = 0xBA428FC3c5ce457c236869787c26f725Ff5168D8;

    function setUp() public {
        d3Token = new D3Token();
        token1 = new MockERC20("Token1", "TK1", 18);
        vm.label(address(token1), "Token1");
        token1.mint(address(this), 1000 ether);
        d3Token.init(address(token1), pool);
        vm.prank(pool);
        d3Token.mint(address(this), 1000 ether);
    }

    // forge coverage doesn't see setUp() as test, that's why we need below test to cover init()
    function testInit() public {
        d3Token = new D3Token();
        token1 = new MockERC20("DAI COIN", "DAI", 18);
        vm.label(address(token1), "Token1");
        token1.mint(address(this), 1000 ether);
        d3Token.init(address(token1), pool);
        vm.prank(pool);
        d3Token.mint(address(this), 1000 ether);
        assertEq(d3Token.symbol(), "d3DAI");
        assertEq(d3Token.name(), "d3DAI_ba428fc3");
    }

    function testSymbolAndName() public {
        assertEq(d3Token.symbol(), "d3TK1");
        assertEq(d3Token.name(), "d3TK1_ba428fc3");
    }

    function testDecimals() public {
        assertEq(d3Token.decimals(), 18);
    }

    function testTotalSupply() public {
        assertEq(d3Token.totalSupply(), 1000 ether);
        vm.prank(pool);
        d3Token.burn(address(this), 400 ether);
        assertEq(d3Token.totalSupply(), 600 ether);
    }

    function testMintAndBurn() public {
        vm.prank(pool);
        d3Token.mint(user1, 10 ether);
        assertEq(d3Token.balanceOf(user1), 10 ether);

        vm.prank(pool);
        d3Token.burn(user1, 10 ether);
        assertEq(d3Token.balanceOf(user1), 0 ether);
    }

    function testTransfer() public {
        assertEq(d3Token.balanceOf(user1), 0);
        d3Token.transfer(user1, 10 ether);
        assertEq(d3Token.balanceOf(user1), 10 ether);
    }

    function testTransferFrom() public {
        vm.prank(pool);
        d3Token.mint(pool, 10 ether);

        vm.prank(pool);
        d3Token.approve(user1, 10 ether);
        assertEq(d3Token.allowance(pool, user1), 10 ether);

        vm.prank(user1);
        d3Token.transferFrom(pool, user2, 5 ether);
        assertEq(d3Token.balanceOf(user2), 5 ether);

        vm.prank(user1);
        vm.expectRevert(bytes("BALANCE_NOT_ENOUGH"));
        d3Token.transferFrom(pool, user2, 10 ether);

        vm.prank(pool);
        d3Token.mint(pool, 10 ether);
        vm.prank(user1);
        vm.expectRevert(bytes("ALLOWANCE_NOT_ENOUGH"));
        d3Token.transferFrom(pool, user2, 10 ether);
    }

    function testLockAndUnlock() public {
        vm.prank(pool);
        d3Token.mint(user1, 10 ether);
        vm.prank(pool);
        d3Token.lock(user1, 5 ether);

        vm.expectRevert(bytes("BALANCE_NOT_ENOUGH"));
        vm.prank(user1);
        d3Token.transfer(user2, 6 ether);
        
        vm.prank(pool);
        d3Token.unlock(user1, 1 ether);
        d3Token.transfer(user2, 6 ether);
        assertEq(d3Token.balanceOf(user2), 6 ether);
    }
}
