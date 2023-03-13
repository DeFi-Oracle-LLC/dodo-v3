// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/Types.sol";
import "lib/Errors.sol";
import "lib/DecimalMath.sol";
import "intf/ID3Token.sol";
import "intf/ID3Oracle.sol";
import "./D3Common.sol";

/**
 * @author  DODO
 * @title   LiquidationLibrary
 * @dev     This contract contains the real code implementations for D3Liquidation.
 */

library LiquidationLibrary {
    using SafeERC20 for IERC20;

    event StartLiquidation();
    event FinishLiquidation();
    event RefundWithdrawal(bytes32 indexed requestId, address indexed lp, address indexed token, uint256 amount);
    event ForceRefundSwap(address indexed fromToken, address indexed toToken, uint256 fromAmount, uint256 toAmount);

    /// @notice If collateral ratio is less than MM, liquiator can trigger liquidation
    /// @param state pool state
    function startLiquidation(Types.D3MMState storage state) external {
        uint256 collateralRatio = D3Common.getCollateralRatio(state);
        require(collateralRatio < state._MAINTENANCE_MARGIN_RATIO_, Errors.ABOVE_MM_RATIO);
        D3Common.accrueInterests(state); // accrue interests for the last time
        state._POOL_STATUS_ = Types.PoolStatus.Liquidating;

        uint256 ratio;
        if (collateralRatio == 0) {
            uint256 totalValue = D3Common.getTotalAssetsValue(state);
            uint256 totalDebt = D3Common.getTotalDebtValue(state);
            ratio = DecimalMath.div(totalValue, totalDebt);
        } else {
            ratio = Types.ONE;
        }

        for (uint256 i; i < state.tokenList.length; i++) {
            address token = state.tokenList[i];
            uint256 debt = DecimalMath.mul(
                DecimalMath.mul(
                    IERC20(state.assetInfo[token].d3Token).totalSupply(),
                    state.assetInfo[token].accruedInterest
                ),
                ratio
            );
            state.liquidationTarget[token] = debt; // record the token amount we would like to achieve after liquidation
            state.interestRate[token] = 0;
            state.assetInfo[token].maxDepositAmount = 0;
        }
        emit StartLiquidation();
    }

    /// @notice Liquidator pass in route data to swap tokens for liquidation.
    /// @param order the swap infomation
    /// @param routeData the swap route data
    /// @param router the route contract which will swap tokens
    /// @param state pool state
    function liquidate(
        Types.LiquidationOrder calldata order,
        bytes calldata routeData,
        address router,
        Types.D3MMState storage state
    ) external {
        uint256 toTokenReserve = IERC20(order.toToken).balanceOf(address(this));
        uint256 fromTokenValue = DecimalMath.mul(
            ID3Oracle(state._ORACLE_).getPrice(order.fromToken),
            order.fromAmount
        );

        // swap using Route
        {
            IERC20(order.fromToken).transfer(router, order.fromAmount);
            (bool success,) = router.call(routeData);
            require(success, Errors.ROUTE_FAILED);
        }

        // the transferred-in toToken USD value should not be less than 95% of the transferred-out fromToken
        uint256 receivedToToken = IERC20(order.toToken).balanceOf(address(this)) - toTokenReserve;
        uint256 toTokenValue = DecimalMath.mul(ID3Oracle(state._ORACLE_).getPrice(order.toToken), receivedToToken);

        require(toTokenValue * 100 >= fromTokenValue * 95, Errors.DISCOUNT_EXCEED_5);
    }

    /// @notice Liquidator call this function to finish liquidation
    /// @dev The goal is to make all tokens' balance be larger than target amount,
    /// @dev or all tokens' balance be smaller than target amount
    /// @param state pool state
    function finishLiquidation(Types.D3MMState storage state) external {
        bool hasPositiveBalance;
        bool hasNegativeBalance;
        for (uint256 i; i < state.tokenList.length; i++) {
            address token = state.tokenList[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 debt = state.liquidationTarget[token];
            int256 difference = int256(balance) - int256(debt);
            if (difference > 0) {
                require(!hasNegativeBalance, Errors.LIQUIDATION_NOT_DONE);
                hasPositiveBalance = true;
                // if balance is larger than target amount, the extra amount is credited to owner
                state.ownerBalanceAfterPoolEnd[token] = uint256(difference);
            } else if (difference < 0) {
                require(!hasPositiveBalance, Errors.LIQUIDATION_NOT_DONE);
                hasNegativeBalance = true;
                debt = balance; // if balance is less than target amount, just repay with balance
            }
            uint256 dSupply = IERC20(state.assetInfo[token].d3Token).totalSupply();
            if (dSupply == 0) continue;
            uint256 ratio = DecimalMath.div(debt, dSupply); // calculate new d3Token redeem rate
            state.assetInfo[token].accruedInterest = ratio;
        }

        state._POOL_STATUS_ = Types.PoolStatus.End; // mark pool as closed, LPs can withdraw tokens now
        emit FinishLiquidation();
    }

    /// @notice If owner hasn't refund LP after deadline, liquidator can call this to force refund.
    /// @param index the withdraw request's index in pending request list
    /// @param order the swap infomation
    /// @param routeData the swap route data
    /// @param router the route contract which will swap tokens
    /// @param state pool state
    function forceRefund(
        uint256 index,
        Types.LiquidationOrder calldata order,
        bytes calldata routeData,
        address router,
        Types.D3MMState storage state
    ) external {
        Types.WithdrawInfo storage wInfo = state.pendingWithdrawList[index];
        Types.AssetInfo storage assetInfo = state.assetInfo[wInfo.token];

        require(wInfo.deadline < block.timestamp, Errors.NOT_PASS_DEADLINE);
        require(wInfo.token == order.toToken, Errors.TOKEN_NOT_MATCH);

        D3Common.accrueInterests(state);

        uint256 toTokenReserve = IERC20(order.toToken).balanceOf(address(this));
        uint256 originTokenAmount = DecimalMath.mul(wInfo.d3TokenAmount, assetInfo.accruedInterest);

        // if current reserve is less than the withdrawal amount, need swap other token to get more target token
        if (toTokenReserve < originTokenAmount) {
            _refundSwap(order, routeData, router, state, toTokenReserve);
            toTokenReserve = IERC20(order.toToken).balanceOf(address(this));
        }

        // force refund could be called multiple times, if swap result still cannot fulfill the withdraw amount
        uint256 refundAmount = originTokenAmount;
        uint256 d3RefundAmount = wInfo.d3TokenAmount;
        if (toTokenReserve < originTokenAmount) {
            refundAmount = toTokenReserve;
            d3RefundAmount = DecimalMath.div(refundAmount, assetInfo.accruedInterest);
        }

        ID3Token(assetInfo.d3Token).unlock(wInfo.user, d3RefundAmount);
        ID3Token(assetInfo.d3Token).burn(wInfo.user, d3RefundAmount);
        IERC20(wInfo.token).safeTransfer(wInfo.user, refundAmount);
        wInfo.d3TokenAmount -= d3RefundAmount;
        D3Common.updateReserve(wInfo.token, state);

        emit RefundWithdrawal(wInfo.requestId, wInfo.user, wInfo.token, refundAmount);

        // if all withdrawal amount has been paid, this request can be removed
        // moving the last request to this index
        if (wInfo.d3TokenAmount == 0) {
            state.pendingWithdrawList[index] = state.pendingWithdrawList[state.pendingWithdrawList.length - 1];
            state.pendingWithdrawList.pop();
        }
    }

    /// @notice If not enough token in the pool for refunding, call this method to swap token.
    /// @param order the swap infomation
    /// @param routeData the swap route data
    /// @param router the route contract which will swap tokens
    /// @param state pool state
    function _refundSwap(
        Types.LiquidationOrder calldata order,
        bytes calldata routeData,
        address router,
        Types.D3MMState storage state,
        uint256 toTokenReserve
    ) internal {
        uint256 fromTokenValue = DecimalMath.mul(ID3Oracle(state._ORACLE_).getPrice(order.fromToken), order.fromAmount);

        IERC20(order.fromToken).transfer(router, order.fromAmount);
        (bool success,) = router.call(routeData);
        require(success, Errors.ROUTE_FAILED);

        // the transferred-in toToken USD value should not be less than 95% of the transferred-out fromToken
        uint256 toTokenBalance = IERC20(order.toToken).balanceOf(address(this));
        uint256 toTokenValue =
            DecimalMath.mul(ID3Oracle(state._ORACLE_).getPrice(order.toToken), toTokenBalance - toTokenReserve);
        require(toTokenValue * 100 >= fromTokenValue * 95, Errors.DISCOUNT_EXCEED_5);
        emit ForceRefundSwap(order.fromToken, order.toToken, order.fromAmount, toTokenBalance - toTokenReserve);
    }
}
