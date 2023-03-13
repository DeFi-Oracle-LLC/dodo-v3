/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "../Context.t.sol";

/// @dev swap token - token has tested in trading.t.sol, this test is additional test
contract D3ProxyTest is Context {

    uint256 BIG_NUMBER_1E18 = 10 ** 18;
    address _ETH_ADDRESS_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

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

        addWethInD3();
        vm.deal(user1, 1 ether);
    }

    function testSwapETHToTokenBuy() public {
        (uint256 payFromAmount, , , ) = d3MM.queryBuyTokens(address(token2), address(token3), 1 ether);

        uint256 beforeBalance2 = user1.balance;
        uint256 beforeBalance3 = token3.balanceOf(user1);

        // construct swap bytes data
        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        /*
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1, 
            _ETH_ADDRESS, 
            address(token3), 
            1 ether, 
            1 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );
        */

        bytes memory swapDataBytes = abi.encodeWithSignature(
            "buyTokens("
            "address,"
            "address,"
            "address,"
            "address,"
            "uint256,"
            "uint256,"
            "bytes,"
            "uint256"
            ")", 
            address(d3MM),
            user1,
            _ETH_ADDRESS_, 
            address(token3), 
            1 ether, 
            1 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // construct refund data
        bytes memory refundData = abi.encodeWithSignature("refundETH()");
        // construct multicall data
        bytes[] memory mulData = new bytes[](2);
        mulData[0] = swapDataBytes;
        mulData[1] = refundData;

        vm.prank(user1);
        d3Proxy.multicall{value: 1 ether}(mulData);

        uint256 afterBalance2 = user1.balance;
        uint256 afterBalance3 = token3.balanceOf(user1);

        assertEq(beforeBalance2 - afterBalance2, 77200081594493055);
        assertEq(beforeBalance2 - afterBalance2, payFromAmount);
        assertEq(afterBalance3 - beforeBalance3, 1 ether);
    }
        
    function testSwapETHToTokenSell() public {    
        // construct swap bytes data
        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        uint256 receiveToToken = d3Proxy.sellTokens{value: 1 ether}(
            address(d3MM),
            user1, 
            _ETH_ADDRESS_, 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        assertEq(receiveToToken, 12632307089314270479);
        //console.log("sell directly:", receiveToToken);

        uint256 beforeBalance2 = user1.balance;
        uint256 beforeBalance3 = token3.balanceOf(user1);

        bytes memory swapDataBytes = abi.encodeWithSignature(
            "sellTokens("
            "address,"
            "address,"
            "address,"
            "address,"
            "uint256,"
            "uint256,"
            "bytes,"
            "uint256"
            ")", 
            address(d3MM),
            user1,
            _ETH_ADDRESS_, 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // construct refund data
        bytes memory refundData = abi.encodeWithSignature("refundETH()");
        // construct multicall data
        bytes[] memory mulData = new bytes[](2);
        mulData[0] = swapDataBytes;
        mulData[1] = refundData;

        vm.prank(user1);
        d3Proxy.multicall{value: 1 ether}(mulData);


        uint256 afterBalance2 = user1.balance;
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log("weth:", beforeBalance2 - afterBalance2);
        //console.log(afterBalance3 - beforeBalance3);
        assertEq(beforeBalance2 - afterBalance2, 1 ether);
        assertEq(afterBalance3 - beforeBalance3, 11812386900793647420);
        //assertEq(afterBalance3 - beforeBalance3, abi.decode(results[0]));

        // if msg.value mismatch fromAmount, should revert
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        vm.expectRevert(bytes("D3PROXY_VALUE_INVALID"));
        d3Proxy.multicall{value: 2 ether}(mulData);
    }

    function testSwapTokenToETHSell() public {
        uint256 beforeBalance2 = user1.balance;
        uint256 beforeBalance3 = token3.balanceOf(user1);

        // construct swap bytes data
        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        /*
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1, 
            _ETH_ADDRESS, 
            address(token3), 
            1 ether, 
            1 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );
        */

        bytes memory swapDataBytes = abi.encodeWithSignature(
            "sellTokens("
            "address,"
            "address,"
            "address,"
            "address,"
            "uint256,"
            "uint256,"
            "bytes,"
            "uint256"
            ")", 
            address(d3MM),
            user1,
            address(token3), 
            _ETH_ADDRESS_, 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // construct refund data
        bytes memory refundData = abi.encodeWithSignature("withdrawWETH(address,uint256)", user1, 0);
        // construct multicall data
        bytes[] memory mulData = new bytes[](2);
        mulData[0] = swapDataBytes;
        mulData[1] = refundData;

        vm.prank(user1);
        d3Proxy.multicall(mulData);


        uint256 afterBalance2 = user1.balance;
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log("eth:", afterBalance2 - beforeBalance2);
        //console.log(beforeBalance3 - afterBalance3 );
        assertEq(afterBalance2 - beforeBalance2, 91162051973531862);
        assertEq(beforeBalance3 - afterBalance3, 1 ether);
    }
    
    function testSwapTokenToETHBuy() public {
        uint256 beforeBalance2 = user1.balance;
        uint256 beforeBalance3 = token3.balanceOf(user1);

        // construct swap bytes data
        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        /*
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1, 
            _ETH_ADDRESS, 
            address(token3), 
            1 ether, 
            1 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );
        */

        bytes memory swapDataBytes = abi.encodeWithSignature(
            "buyTokens("
            "address,"
            "address,"
            "address,"
            "address,"
            "uint256,"
            "uint256,"
            "bytes,"
            "uint256"
            ")", 
            address(d3MM),
            user1,
            address(token3), 
            _ETH_ADDRESS_, 
            1 ether, 
            30 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // construct refund data
        bytes memory refundData = abi.encodeWithSignature("withdrawWETH(address,uint256)", user1, 0);
        // construct multicall data
        bytes[] memory mulData = new bytes[](2);
        mulData[0] = swapDataBytes;
        mulData[1] = refundData;

        vm.prank(user1);
        d3Proxy.multicall(mulData);


        uint256 afterBalance2 = user1.balance;
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log("eth:", afterBalance2 - beforeBalance2);
        //console.log(beforeBalance3 - afterBalance3 );
        assertEq(afterBalance2 - beforeBalance2, 1 ether);
        assertEq(beforeBalance3 - afterBalance3, 11078083677122378701);
    }

    function testSwapCallBack() public {
        // if not called by D3MM
        bytes memory data;
        vm.expectRevert(bytes("D3PROXY_CALLBACK_INVALID"));
        d3Proxy.d3MMSwapCallBack(address(token1), 1 ether, data);
    }

    function testWithdrawWETH() public {
        vm.deal(user1, 2 ether);
        vm.startPrank(user1);
        weth.deposit{value: 2 ether}();
        weth.transfer(address(d3Proxy), 2 ether);
        assertEq(user1.balance, 0);
        assertEq(weth.balanceOf(address(d3Proxy)), 2 ether);

        vm.expectRevert(bytes("D3PROXY_WETH_NOT_ENOUGH"));
        d3Proxy.withdrawWETH(user1, 3 ether);

        d3Proxy.withdrawWETH(user1, 2 ether);
        assertEq(weth.balanceOf(address(d3Proxy)), 0 ether);
        assertEq(user1.balance, 2 ether);
    }
}