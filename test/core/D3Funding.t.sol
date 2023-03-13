/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "../Context.t.sol";
import "periphery/UserQuotaV3.sol";

contract D3FundingTest is Context {
    UserQuotaV3 public userQuota;
    address[] public userList;
    uint256[] public quotaList;

    function setUp() public {
        contextBasic();
    }

    function testCurrentEpoch() public {
        vm.warp(2 days);
        assertEq(d3MM.currentEpoch(), 0);
        vm.warp(8 days - 1);
        assertEq(d3MM.currentEpoch(), 0);
        vm.warp(8 days);
        assertEq(d3MM.currentEpoch(), 1);
    }

    function testAccrueInterests() public {
        contextPoolOngoing();
        vm.warp(100 days);
        d3MM.lpDeposit(user1, address(token1)); // trigger accrue interest
        uint256 interestRate = d3MM.getInterestRate(address(token1));
        uint256 accruedInterest = d3MM
            .getAssetInfo(address(token1))
            .accruedInterest;
        assertEq(accruedInterest, (interestRate * 92) / 365 + Types.ONE);
        vm.warp(200 days);
        d3MM.lpDeposit(user1, address(token1)); // trigger accrue interest
        uint256 accruedInterest2 = d3MM
            .getAssetInfo(address(token1))
            .accruedInterest;
        assertEq(accruedInterest2, accruedInterest * ((interestRate * 100) / 365 + Types.ONE) / Types.ONE);
    }

    function testGetCollateralRatio() public {
        contextBasic();
        // case1: no one deposit
        uint256 ratio = d3MM.getCollateralRatio();
        assertEq(ratio, 0);

        // case2: only owner deposit
        vm.startPrank(poolCreator);
        d3MM.setMaxDeposit(address(token1), 10000 * 1e8);
        d3MM.setMaxDeposit(address(token2), 20000 ether);
        d3MM.setMaxDeposit(address(token3), 30000 ether);
        vm.stopPrank();
        ownerDeposit(address(token1), 5000 * 1e8);
        ownerDeposit(address(token2), 1000 ether);
        ownerDeposit(address(token3), 15000 ether);
        ratio = d3MM.getCollateralRatio();
        assertEq(ratio, 1e18);

        // case3: lp deposit
        lpDeposit(user1, address(token1), 5000 * 1e8);
        lpDeposit(user1, address(token2), 1000 ether);
        lpDeposit(user1, address(token3), 15000 ether);
        ratio = d3MM.getCollateralRatio();
        assertEq(ratio, 5e17);
    }

    // ---------- Pool Status ----------

    function testOngoingStatus() public {
        contextPoolOngoing();
        assertEq(uint256(d3MM.getStatus()), 0);
        logCollateralRatio();
    }

    function testLiquidatingStatus() public {
        contextPoolLiquidating();
        assertEq(uint256(d3MM.getStatus()), 1);
        logCollateralRatio();
    }

    function testEndStatusOwnerClose() public {
        contextPoolOwnerClose();
        assertEq(uint256(d3MM.getStatus()), 2);
        logCollateralRatio();
    }

    function testEndStatusLiquidationDone() public {
        contextPoolLiquidationDone();
        assertEq(uint256(d3MM.getStatus()), 2);
        logCollateralRatio();
    }

    // ---------- LP Functions ----------

    // ---------- lpDeposit() ----------

    function testLpDepositWhenBelowIM() public {
        contextPoolOngoing();
        vm.warp(2500 days);
        logCollateralRatio();
        faucet(address(token1), address(d3MM), 100 * 1e8);
        vm.expectRevert(bytes(Errors.BELOW_IM_RATIO));
        d3MM.lpDeposit(user1, address(token1));
    }

    function testLpDepositTokenNotInWhitelist() public {
        contextPoolOngoing();
        faucet(address(token4), address(d3MM), 100 ether);
        vm.expectRevert(bytes(Errors.TOKEN_NOT_EXIST));
        d3MM.lpDeposit(user1, address(token4));
    }

    function testLpDepositTokenUnlisted() public {
        contextPoolOngoing();
        vm.prank(poolCreator);
        d3MM.setMaxDeposit(address(token1), 0);
        faucet(address(token1), address(d3MM), 1);
        vm.expectRevert(bytes(Errors.EXCEED_DEPOSIT_LIMIT));
        d3MM.lpDeposit(user1, address(token1));
    }

    function testLpDepositExceedLimit() public {
        contextPoolOngoing();
        faucet(address(token1), address(d3MM), 10000 * 1e8);
        vm.expectRevert(bytes(Errors.EXCEED_DEPOSIT_LIMIT));
        d3MM.lpDeposit(user1, address(token1));
    }

    function testLpDepositOverUserQuota() public {
        contextPoolOngoing();
        userQuota = new UserQuotaV3();
        vm.prank(poolCreator);
        d3MM.setUserQuota(address(userQuota));

        userList.push(user1);
        userList.push(user2);
        quotaList.push(1500 * 1e8);
        quotaList.push(300 * 1e8);

        userQuota.enableQuota(address(token1), true);
        userQuota.setUserQuota(address(token1), userList, quotaList);

        // note: user1 already deposit 1000e18 token1 in context pool ongoing
        faucet(address(token1), address(d3MM), 500 * 1e8);
        d3MM.lpDeposit(user1, address(token1));

        faucet(address(token1), address(d3MM), 1);
        vm.expectRevert(bytes(Errors.EXCEED_QUOTA));
        d3MM.lpDeposit(user1, address(token1));

        userQuota.enableGlobalQuota(address(token1), true);
        userQuota.setGlobalQuota(address(token1), 2000 * 1e8);
        uint256 quota = userQuota.getUserQuota(user1, address(token1));
        assertEq(quota, 2000 * 1e8);
        faucet(address(token1), address(d3MM), 400 * 1e8);
        d3MM.lpDeposit(user1, address(token1));
    }

    function testLpDepositNormal() public {
        contextPoolOngoing();
        faucet(address(token1), address(d3MM), 500);
        vm.expectEmit(true, true, false, true);
        emit LpDeposit(user1, address(token1), 500);
        d3MM.lpDeposit(user1, address(token1)); 
    }

    // ---------- lpDeposit() using D3Proxy   ----------

    function testLpDepositUseD3Proxy() public {
        contextPoolOngoing();
        createD3Proxy();

        faucet(address(token1), user2, 100);
        vm.startPrank(user2);
        token1.approve(address(dodoApprove), type(uint256).max);
        d3Proxy.lpDeposit(address(d3MM), address(token1), 100);
        address d3Token1 = d3MM.getAssetInfo(address(token1)).d3Token;
        assertEq(MockERC20(d3Token1).balanceOf(user2), 100);
        vm.stopPrank();
    }

    function testLpDepositETHUseD3Proxy() public {
        contextPoolOngoing();
        createD3Proxy();
        vm.prank(poolCreator);
        d3MM.addNewToken(address(weth), 30e16, 10000 ether);
        
        vm.deal(user2, 1 ether);
        vm.prank(user2);
        d3Proxy.lpDeposit{value: 101}(address(d3MM), address(weth), 101);
        address d3WETH = d3MM.getAssetInfo(address(weth)).d3Token;
        assertEq(MockERC20(d3WETH).balanceOf(user2), 101);

        vm.prank(user2);
        vm.expectRevert(bytes("D3PROXY_PAYMENT_NOT_MATCH"));
        d3Proxy.lpDeposit{value: 102}(address(d3MM), address(weth), 101);
    }

    // ---------- lpRequestWithdraw() ----------

    function testLpRequestWithdraw() public {
        contextPoolOngoing();
        vm.warp(100 days);
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        bytes32 requestId = keccak256(abi.encode(user1, block.timestamp + 7 days));
        emit LpRequestWithdrawal(requestId, user1, address(token1), 1000 * 1e8);
        d3MM.lpRequestWithdraw(address(token1), 1000 * 1e8);
        assertEq(d3MM.getWithdrawInfo(0).d3TokenAmount, 1000 * 1e8);

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.TOKEN_NOT_EXIST));
        d3MM.lpRequestWithdraw(address(token4), 1000 ether);
    }

    function testLpRequestWithdrawWhenPoolIsLiquidating() public {
        contextPoolLiquidating();
        vm.warp(100 days);
        vm.prank(user1);
        vm.expectRevert(bytes(Errors.POOL_NOT_ONGOING));
        d3MM.lpRequestWithdraw(address(token1), 1000 * 1e8);
    }

    function testLpRequestWithdrawWhenPoolIsEnd() public {
        contextPoolOwnerClose();
        vm.warp(100 days);
        vm.prank(user1);
        vm.expectRevert(bytes(Errors.POOL_NOT_ONGOING));
        d3MM.lpRequestWithdraw(address(token1), 1000 * 1e8);
    }

    function testLpRequestWithdrawAmountLargerThanBalance() public {
        contextPoolOngoing();
        vm.warp(100 days);
        vm.prank(user1);
        vm.expectRevert(bytes(Errors.BALANCE_NOT_ENOUGH));
        d3MM.lpRequestWithdraw(address(token1), 1001 * 1e8);

        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token1), 300 * 1e8);
        assertEq(d3MM.getWithdrawInfo(0).d3TokenAmount, 300 * 1e8); 

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.BALANCE_NOT_ENOUGH));
        d3MM.lpRequestWithdraw(address(token1), 701 * 1e8);

        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token1), 700 * 1e8);
        assertEq(d3MM.getWithdrawInfo(1).d3TokenAmount, 700 * 1e8); 
    }
    
    // ---------- lpWithdrawAfterPoolEnd() ----------

    function testLpWithdrawAfterPoolEnd() public {
        contextPoolOwnerClose();
        Types.AssetInfo memory assetInfo = d3MM.getAssetInfo(address(token1));
        address d3Token = assetInfo.d3Token;
        uint256 accruedInterest = assetInfo.accruedInterest;
        uint256 d3Balance = D3Token(d3Token).balanceOf(user1);
        console.log("d3Token balance", d3Balance);
        console.log("accrued interest", accruedInterest);
        uint256 originBalance = DecimalMath.mul(d3Balance, accruedInterest);
        console.log("origin balance:", originBalance);

        uint256 token1BalanceBefore = token1.balanceOf(user1);
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Refund(user1, address(token1), originBalance);
        d3MM.lpWithdrawAfterPoolEnd(user1, address(token1));
        uint256 token1BalanceAfter = token1.balanceOf(user1);
        assertEq(originBalance, token1BalanceAfter - token1BalanceBefore);
        assertEq(D3Token(d3Token).balanceOf(user1), 0);
    }

    function testLpWithdrawAfterPoolEndClaimAll() public {
        contextPoolOwnerClose();
        Types.AssetInfo memory assetInfo1 = d3MM.getAssetInfo(address(token1));
        address d3Token1 = assetInfo1.d3Token;
        uint256 accruedInterest1 = assetInfo1.accruedInterest;
        uint256 d3Balance1 = D3Token(d3Token1).balanceOf(user1);
        console.log("d3Token1 balance", d3Balance1);
        console.log("accruedInterest1", accruedInterest1);
        uint256 originBalance1 = DecimalMath.mul(d3Balance1, accruedInterest1);
        console.log("originBalance1:", originBalance1);

        Types.AssetInfo memory assetInfo2 = d3MM.getAssetInfo(address(token2));
        address d3Token2 = assetInfo2.d3Token;
        uint256 accruedInterest2 = assetInfo2.accruedInterest;
        uint256 d3Balance2 = D3Token(d3Token2).balanceOf(user1);
        console.log("d3Token2 balance", d3Balance2);
        console.log("accruedInterest2", accruedInterest2);
        uint256 originBalance2 = DecimalMath.mul(d3Balance2, accruedInterest2);
        console.log("originBalance2:", originBalance2);

        bytes memory claimToken1Data = abi.encodeWithSignature("lpWithdrawAfterPoolEnd(address,address)", user1, address(token1));
        bytes memory claimToken2Data = abi.encodeWithSignature("lpWithdrawAfterPoolEnd(address,address)", user1, address(token2));
        bytes memory claimToken3Data = abi.encodeWithSignature("lpWithdrawAfterPoolEnd(address,address)", user1, address(token3));

        bytes[] memory mulData = new bytes[](3);
        mulData[0] = claimToken1Data;
        mulData[1] = claimToken2Data;
        mulData[2] = claimToken3Data;

        uint256 token1BalanceBefore = token1.balanceOf(user1);
        uint256 token2BalanceBefore = token2.balanceOf(user1);
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Refund(user1, address(token1), originBalance1);
        emit Refund(user1, address(token2), originBalance2);
        d3MM.multicall(mulData);
        assertEq(originBalance1, token1.balanceOf(user1) - token1BalanceBefore);
        assertEq(originBalance2, token2.balanceOf(user1) - token2BalanceBefore);
        assertEq(D3Token(d3Token1).balanceOf(user1), 0);
        assertEq(D3Token(d3Token2).balanceOf(user1), 0);
    }

    function testLpWithdrawAfterPoolEndTokenNotExsit() public {
        contextPoolOwnerClose();
        vm.prank(user1);
        vm.expectRevert(bytes(Errors.TOKEN_NOT_EXIST));
        d3MM.lpWithdrawAfterPoolEnd(user1, address(token4));
    }

    function testLpWithdrawAfterPoolEndIfPoolIsOngoing() public {
        contextPoolOngoing();
        vm.prank(user1);
        vm.expectRevert(bytes(Errors.POOL_NOT_END));
        d3MM.lpWithdrawAfterPoolEnd(user1, address(token1));
    }

    function testLpWithdrawAfterPoolEndIfPoolIsLiquidating() public {
        contextPoolLiquidating();
        vm.prank(user1);
        vm.expectRevert(bytes(Errors.POOL_NOT_END));
        d3MM.lpWithdrawAfterPoolEnd(user1, address(token1));
    }

    function testLpWithdrawAfterPoolEndIfPoolIsLiquidationDone() public {
        contextPoolLiquidationDone();
        Types.AssetInfo memory assetInfo = d3MM.getAssetInfo(address(token1));
        address d3Token = assetInfo.d3Token;
        uint256 accruedInterest = assetInfo.accruedInterest;
        uint256 d3Balance = D3Token(d3Token).balanceOf(user1);
        console.log("d3Token balance", d3Balance);
        console.log("accrued interest", accruedInterest);
        uint256 originBalance = DecimalMath.mul(d3Balance, accruedInterest);
        console.log("origin balance:", originBalance);

        uint256 token1BalanceBefore = token1.balanceOf(user1);
        vm.prank(user1);
        d3MM.lpWithdrawAfterPoolEnd(user1, address(token1));
        uint256 token1BalanceAfter = token1.balanceOf(user1);
        assertEq(originBalance, token1BalanceAfter - token1BalanceBefore);
        assertEq(D3Token(d3Token).balanceOf(user1), 0);
    }

    function testLpWithdrawAfterPoolEndIfHavePendingWithdrawRequest() public {
        contextPoolOngoing();
        vm.warp(100 days);
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token1), 1000 * 1e8);

        vm.prank(poolCreator);
        vm.expectEmit(true, true, true, true);
        emit OwnerClosePool();
        d3MM.ownerClosePool();

        Types.AssetInfo memory assetInfo = d3MM.getAssetInfo(address(token1));
        address d3Token = assetInfo.d3Token;
        uint256 accruedInterest = assetInfo.accruedInterest;
        uint256 d3Balance = D3Token(d3Token).balanceOf(user1);
        console.log("d3Token balance", d3Balance);
        console.log("accrued interest", accruedInterest);
        uint256 originBalance = DecimalMath.mul(d3Balance, accruedInterest);
        console.log("origin balance:", originBalance);

        uint256 token1BalanceBefore = token1.balanceOf(user1);
        vm.prank(user1);
        d3MM.lpWithdrawAfterPoolEnd(user1, address(token1));
        uint256 token1BalanceAfter = token1.balanceOf(user1);
        assertEq(originBalance, token1BalanceAfter - token1BalanceBefore);
        assertEq(D3Token(d3Token).balanceOf(user1), 0);
    }

    // ---------- Owner Functions ----------

    function testSetUserQuota() public {
        vm.expectRevert(bytes("NOT_OWNER"));
        d3MM.setUserQuota(address(2));
        vm.prank(poolCreator);
        vm.expectEmit(true, true, true, true);
        emit SetUserQuota(address(2));
        d3MM.setUserQuota(address(2));
        assertEq(d3MM.getUserQuota(), address(2));
    }

    function testAddNewToken() public {
        contextPoolOngoing();
        vm.expectRevert(bytes("NOT_OWNER"));
        d3MM.addNewToken(address(token4), 30 * 1e16, 10000 ether);

        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.TOKEN_ALREADY_EXIST));
        d3MM.addNewToken(address(token3), 30 * 1e16, 10000 ether);

        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.TOKEN_NOT_ON_WHITELIST));
        d3MM.addNewToken(address(token4), 30 * 1e16, 10000 ether);

        token4ChainLinkOracle = new MockChainlinkPriceFeed("Token4/USD", 18);
        token4ChainLinkOracle.feedData(5 * 1e18);
        oracle.setPriceSource(
            address(token4),
            PriceSource(address(token4ChainLinkOracle), true, 5 * (10**17), 18, 18)
        );
        vm.prank(poolCreator);
        vm.expectEmit(true, true, true, true);
        emit AddNewToken(address(token4), 30 * 1e16, 10000 ether);
        d3MM.addNewToken(address(token4), 30 * 1e16, 10000 ether);
        assertEq(d3MM.getTokenList()[3], address(token4));
        Types.AssetInfo memory assetInfo = d3MM.getAssetInfo(address(token4));
        assertEq(assetInfo.maxDepositAmount, 10000 ether);
        assertEq(d3MM.getInterestRate(address(token4)), 30 * 1e16);
    }

    function testSetMaxDeposit() public {
        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.TOKEN_NOT_EXIST));
        d3MM.setMaxDeposit(address(token4), 1000);

        vm.prank(poolCreator);
        vm.expectEmit(true, false, false, true);
        emit SetMaxDeposit(address(token1), 1000);
        d3MM.setMaxDeposit(address(token1), 1000);
        assertEq(d3MM.getAssetInfo(address(token1)).maxDepositAmount, 1000);
    }

    function testSetNextEpoch() public {
        interestRates.push(4e17); // 40%
        interestRates.push(2e17); // 20%
        interestRates.push(3e17); // 30%
        vm.startPrank(poolCreator);
        vm.warp(5 days); // epoch start at 1 days, epoch duration is 7 days
        vm.expectRevert(bytes(Errors.LATE_TO_CHANGE_EPOCH));
        d3MM.setNextEpoch(tokens, interestRates);
        vm.warp(4 days);
        vm.expectEmit(true, true, true, true);
        emit SetNextEpoch(8 days, tokens, interestRates);
        d3MM.setNextEpoch(tokens, interestRates);

        tokens.push(address(111));
        vm.expectRevert();
        d3MM.setNextEpoch(tokens, interestRates);
        vm.stopPrank();
    }

    function testExecuteEpochUpdate() public {
        interestRates.push(4e17); // 40%
        interestRates.push(2e17); // 20%
        interestRates.push(3e17); // 30%
        vm.startPrank(poolCreator);
        vm.warp(4 days);
        d3MM.setNextEpoch(tokens, interestRates);
        vm.expectRevert(bytes(Errors.WRONG_EXCUTE_EPOCH_UPDATE_TIME));
        d3MM.executeEpochUpdate();

        vm.warp(8 days);
        vm.expectEmit(true, true, true, true);
        emit ExecuteEpochUpdate();
        d3MM.executeEpochUpdate();
        assertEq(d3MM.getInterestRate(address(token1)), 4e17);
        vm.stopPrank();
    }

    function testExecuteEpochUpdateIfNextEpochNotSet() public {
        vm.warp(8 days);
        vm.expectRevert(bytes(Errors.WRONG_EXCUTE_EPOCH_UPDATE_TIME));
        d3MM.executeEpochUpdate();
    }

    // ---------- refund() ----------

    function testRefundNormal() public {
        contextPoolOngoing();
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token1), 1000 * 1e8);
        
        assertEq(d3MM.getPendingWithdrawList().length, 1);

        vm.expectEmit(false, true, true, true);
        emit RefundWithdrawal(bytes32(0), user1, address(token1), 1000 * 1e8);
        
        vm.prank(poolCreator);
        d3MM.refund(0);
        
        assertEq(d3MM.getPendingWithdrawList().length, 0);
    }

    function testRefundWhenIndexNotFound() public {
        contextPoolOngoing();
        vm.warp(100 days);
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token1), 1000 * 1e8);
        vm.prank(poolCreator);
        vm.expectRevert();
        d3MM.refund(1);
    }

    function testRefundWhenBalanceNotEnough() public {
        contextPoolOngoing();
        vm.warp(100 days);
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token1), 1000 * 1e8); // token1 decimals is 8
        faucet(address(token2), address(d3MM), 100000000 ether);
        d3MM.ownerDeposit(address(token2));
        vm.prank(poolCreator);
        d3MM.ownerWithdraw(poolCreator, address(token1), 5000 * 1e8);
        vm.prank(poolCreator);
        vm.expectRevert(bytes("BALANCE_NOT_ENOUGH"));
        d3MM.refund(0);
    }

    function testRefundWhenPoolIsLiquidating() public {
        contextPoolLiquidating();
        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.POOL_NOT_ONGOING));
        d3MM.refund(0);
    }

    function testRefundWhenPoolIsEnd() public {
        contextPoolOwnerClose();
        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.POOL_NOT_ONGOING));
        d3MM.refund(0);
    }

    // ---------- ownerDeposit() ----------

    function testOwnerDeposit() public {
        faucet(address(token1), poolCreator, 20);
        vm.prank(poolCreator);
        token1.transfer(address(d3MM), 20);
        vm.expectEmit(true, false, false, true);
        emit OwnerDeposit(address(token1), 20);
        d3MM.ownerDeposit(address(token1));
        assertEq(d3MM.getTokenReserve(address(token1)), 20);

        vm.expectRevert(bytes(Errors.TOKEN_NOT_EXIST));
        d3MM.ownerDeposit(address(token4));
    }

    function testOwnerDepositWhenPoolIsLiquidating() public {
        contextPoolLiquidating();
        faucet(address(token1), address(d3MM), 20);
        vm.expectRevert(bytes(Errors.POOL_NOT_ONGOING));
        d3MM.ownerDeposit(address(token1));
    }

    function testOwnerDepositWhenPoolIsEnd() public {
        contextPoolOwnerClose();
        faucet(address(token1), address(d3MM), 20);
        vm.expectRevert(bytes(Errors.POOL_NOT_ONGOING));
        d3MM.ownerDeposit(address(token1));
    }

    // ---------- ownerDeposit() using D3Proxy ----------

    function testOwnerDepositUseD3Proxy() public {
        contextPoolOngoing();
        createD3Proxy();

        uint256 reserveBefore = d3MM.getTokenReserve(address(token1));
        faucet(address(token1), poolCreator, 100);
        vm.startPrank(poolCreator);
        token1.approve(address(dodoApprove), type(uint256).max);
        d3Proxy.ownerDeposit(address(d3MM), address(token1), 100);
        vm.stopPrank();
        uint256 reserveAfter = d3MM.getTokenReserve(address(token1));
        assertEq(reserveAfter - reserveBefore, 100);
    }

    function testOwnerDepositETHUseD3Proxy() public {
        contextPoolOngoing();
        createD3Proxy();
        vm.prank(poolCreator);
        d3MM.addNewToken(address(weth), 30e16, 10000 ether);
        
        uint256 reserveBefore = d3MM.getTokenReserve(address(weth));
        vm.deal(poolCreator, 1 ether);
        vm.prank(poolCreator);
        d3Proxy.ownerDeposit{value: 101}(address(d3MM), address(weth), 101);
        uint256 reserveAfter = d3MM.getTokenReserve(address(weth));
        assertEq(reserveAfter - reserveBefore, 101); 
        
        vm.prank(poolCreator);
        vm.expectRevert(bytes("D3PROXY_PAYMENT_NOT_MATCH"));
        d3Proxy.ownerDeposit{value: 103}(address(d3MM), address(weth), 101);
    }

    // ---------- ownerWithdraw() ----------

    function testOwnerWithdraw() public {
        contextPoolOngoing();
        vm.prank(poolCreator);
        vm.expectEmit(true, true, false, true);
        emit OwnerWithdraw(poolCreator, address(token1), 100);
        d3MM.ownerWithdraw(poolCreator, address(token1), 100);

        vm.warp(2250 days);
        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.BELOW_IM_RATIO));
        d3MM.ownerWithdraw(poolCreator, address(token1), 1000 * 1e8);
    }

    function testOwnerWithdrawWhenPoolIsLiquidating() public {
        contextPoolLiquidating();
        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.POOL_NOT_ONGOING));
        d3MM.ownerWithdraw(poolCreator, address(token1), 100);
    }

    function testOwnerWithdrawWhenPoolIsEnd() public {
        contextPoolOwnerClose();
        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.POOL_NOT_ONGOING));
        d3MM.ownerWithdraw(poolCreator, address(token1), 100);
    }

    // ---------- ownerWithdrawAfterPoolEnd() ----------

    function testOwnerWithdrawAfterPoolEnd() public {
        contextPoolOwnerClose();
        uint256 balanceBefore = token1.balanceOf(poolCreator);
        uint256 leftBalance = d3MM.getOwnerLeftBalance(address(token1));
        console.log("owner balance after pool end", leftBalance / 1e18);
        vm.prank(poolCreator);
        vm.expectEmit(true, true, false, true);
        emit OwnerWithdraw(poolCreator, address(token1), 100 * 1e8);
        d3MM.ownerWithdrawAfterPoolEnd(poolCreator, address(token1), 100 * 1e8);
        uint256 balanceAfter = token1.balanceOf(poolCreator);
        assertEq(balanceAfter - balanceBefore, 100 * 1e8);
        leftBalance = d3MM.getOwnerLeftBalance(address(token1));
        console.log("owner balance after pool end", leftBalance / 1e18);

        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.BALANCE_NOT_ENOUGH));
        d3MM.ownerWithdrawAfterPoolEnd(poolCreator, address(token1), leftBalance + 1);
    }

    function testOwnerCallWithdrawAfterPoolEndIfPoolNotEnd() public {
        contextPoolOngoing();
        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.POOL_NOT_END));
        d3MM.ownerWithdrawAfterPoolEnd(poolCreator, address(token1), 100 * 1e8);
    }

    function testOwnerCallWithdrawNotEndNonExsitToken() public {
        contextPoolOwnerClose();
        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.TOKEN_NOT_EXIST));
        d3MM.ownerWithdrawAfterPoolEnd(poolCreator, address(token4), 100 ether);
    }

    // ---------- ownerClosePool() ----------

    function testOwnerClosePool() public {
        contextPoolOngoing();
        vm.startPrank(poolCreator);
        // In context pool ongoing, owner deposits 1000 token2, LP deposits 8000 token2.
        // If owner withdraws 2000 token2, will make token2 balance be smaller than debt.
        d3MM.ownerWithdraw(poolCreator, address(token2), 2000 ether);
        vm.expectRevert(bytes(Errors.BALANCE_NOT_ENOUGH));
        d3MM.ownerClosePool();
        vm.stopPrank();
    }

    function testOwnerClosePoolWhenPoolIsLiquidating() public {
        contextPoolLiquidating();
        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.POOL_NOT_ONGOING));
        d3MM.ownerClosePool();
    }

    function testOwnerClosePoolWhenPoolIsAlreadyEnd() public {
        contextPoolOwnerClose();
        vm.prank(poolCreator);
        vm.expectRevert(bytes(Errors.POOL_NOT_ONGOING));
        d3MM.ownerClosePool();
    }
}
