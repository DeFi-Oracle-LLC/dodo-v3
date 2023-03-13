/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "../Context.t.sol";

contract ForceRefundTest is Context {

    event ForceRefundSwap(address indexed fromToken, address indexed toToken, uint256 fromAmount, uint256 toAmount);

    function setUp() public {
        contextBasic();

        token2ChainLinkOracle.feedData(1 * 1e18);
        token3ChainLinkOracle.feedData(1 * 1e18);

        vm.startPrank(poolCreator);
        d3MM.setMaxDeposit(address(token2), 20000);
        d3MM.setMaxDeposit(address(token3), 20000);
        vm.stopPrank();

        ownerDeposit(address(token2), 10);
        ownerDeposit(address(token3), 100);
        lpDeposit(user1, address(token2), 10);
        lpDeposit(user1, address(token3), 10);
    }

    // case 1: has enough balance
    function testCase1() public {
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token2), 10);
        
        // pass deadline
        vm.warp(100 days);
        
        vm.expectEmit(false, true, true, true);
        emit RefundWithdrawal(bytes32(0), user1, address(token2), 10);
        assertEq(d3MM.getPendingWithdrawList().length, 1);
        forceRefundSwap(0, address(token3), address(token2), 10);
        assertEq(d3MM.getPendingWithdrawList().length, 0);
    }

    // case 2: no enough balance, swap back is enough
    function testCase2() public {
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token2), 10);

        // owner withdraw 12 token2
        // only 8 token2 left in the pool
        vm.prank(poolCreator);
        d3MM.ownerWithdraw(poolCreator, address(token2), 12);

        // pass deadline
        vm.warp(100 days);

        assertEq(d3MM.getPendingWithdrawList().length, 1);
        
        vm.expectEmit(true, true, true, true);
        emit ForceRefundSwap(address(token3), address(token2), 2, 2);
        
        vm.expectEmit(false, true, true, true);
        emit RefundWithdrawal(bytes32(0), user1, address(token2), 10);
        
        forceRefundSwap(0, address(token3), address(token2), 2);
        
        assertEq(d3MM.getPendingWithdrawList().length, 0);
    }

    // case 3: no enough balance, swap back is not enough, force reward multiple times
    function testCase3() public {
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token2), 10);

        // owner withdraw 13 token2
        // only 7 token2 left in the pool
        vm.prank(poolCreator);
        d3MM.ownerWithdraw(poolCreator, address(token2), 13);

        // pass deadline
        vm.warp(100 days);

        assertEq(d3MM.getPendingWithdrawList().length, 1);
        
        {
            vm.expectEmit(true, true, true, true);
            emit ForceRefundSwap(address(token3), address(token2), 1, 1);
            
            vm.expectEmit(false, true, true, true);
            emit RefundWithdrawal(bytes32(0), user1, address(token2), 8);
            
            forceRefundSwap(0, address(token3), address(token2), 1);
            
            assertEq(d3MM.getPendingWithdrawList().length, 1);
        }
        {
            vm.expectEmit(true, true, true, true);
            emit ForceRefundSwap(address(token3), address(token2), 2, 2);
            
            vm.expectEmit(false, true, true, true);
            emit RefundWithdrawal(bytes32(0), user1, address(token2), 2);
            
            forceRefundSwap(0, address(token3), address(token2), 2);
            
            assertEq(d3MM.getPendingWithdrawList().length, 0);
        }
    }
}
