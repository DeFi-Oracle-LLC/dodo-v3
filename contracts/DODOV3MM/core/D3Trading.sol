// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "lib/PMMRangeOrder.sol";
import "lib/Errors.sol";
import "lib/TradingLibrary.sol";
import {IFeeRateModel} from "intf/IFeeRateModel.sol";
import {IDODOSwapCallback} from "intf/IDODOSwapCallback.sol";
import {D3Funding} from "./D3Funding.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract D3Trading is D3Funding {
    using SafeERC20 for IERC20;

    // =========== Read ==============
    /// @notice for external users to read tokenMMInfo
    /// @return priceInfo token's priceInfo [ask price down(16) | ask price offSet + (16) | ask price down decimal(8) | bid price down(16) |  bid price offSet + (16) | bid price up decimal(8)]
    /// @return amountInfo initial token amount maker set, [ask amounts(16) | ask amounts decimal(8) | bid amounts(16) | bid amounts decimal(8) ]
    /// @return mtFeeRate mtFeeRate of this trader
    /// @return kAsk token's ask curve's k
    /// @return kBid token's bid curve's k
    /// @return updateTimeStamp last update amount's timestamp
    /// @return updateFlag record whether update cumulative amount, 0 = waiting for update, 1 = has updated
    /// @return cumulativeAsk cumulative ask amount has consumed by user's swap
    /// @return cumulativeBid cumualative bid amount has consumed by user's swap
    function getTokenMMInfoForRead(address token, address trader)
        external
        view
        returns (
            uint96 priceInfo,
            uint256 amountInfo,
            uint256 mtFeeRate,
            uint16 kAsk,
            uint16 kBid,
            uint64 updateTimeStamp,
            uint256 updateFlag,
            uint256 cumulativeAsk,
            uint256 cumulativeBid
        )
    {
        return TradingLibrary.getTokenMMInfoForRead(state, token, trader);
    }

    /// @notice give one token's address, give back token's priceInfo
    function getOneTokenPriceSet(address token) external view returns (uint96 priceSet) {
        priceSet = TradingLibrary.getOneTokenPriceSet(state, token);
    }

    // ============ Swap =============
    /// @notice get swap status for internal swap
    function getRangeOrderState(
        address fromToken,
        address toToken
    ) public view returns (Types.RangeOrderState memory roState) {
        roState = TradingLibrary.getRangeOrderState(state, fromToken, toToken);
    }

    /// @notice user sell a certain amount of fromToken,  get toToken
    function sellToken(
        address to,
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minReceiveAmount,
        bytes calldata data
    ) external poolOngoing returns (uint256) {
        require(
            block.timestamp - state.heartBeat.lastHeartBeat <= state.heartBeat.maxInterval,
            Errors.HEARTBEAT_CHECK_FAIL
        );
        _updateCumulative(fromToken);
        _updateCumulative(toToken);

        (
            uint256 payFromAmount,
            uint256 receiveToAmount,
            uint256 vusdAmount,
            uint256 mtFee
        ) = querySellTokens(fromToken, toToken, fromAmount);
        require(receiveToAmount >= minReceiveAmount, Errors.MINRES_NOT_ENOUGH);

        _transferOut(to, toToken, receiveToAmount);
        _transferOut(state._MAINTAINER_, toToken, mtFee);

        // external call & swap callback
        IDODOSwapCallback(msg.sender).d3MMSwapCallBack(fromToken, fromAmount, data);

        require(
            IERC20(fromToken).balanceOf(address(this)) - state.assetInfo[fromToken].reserve >= fromAmount,
            Errors.FROMAMOUNT_NOT_ENOUGH
        );

        require(getCollateralRatio() >= state._INITIAL_MARGIN_RATIO_, Errors.BELOW_IM_RATIO);

        // record swap
        _recordSwap(fromToken, toToken, vusdAmount, receiveToAmount + mtFee);

        emit Swap(to, fromToken, toToken, payFromAmount, receiveToAmount, 0);
        return receiveToAmount;
    }

    /// @notice user ask for a certain amount of toToken, fromToken's amount will be determined by toToken's amount
    function buyToken(
        address to,
        address fromToken,
        address toToken,
        uint256 quoteAmount,
        uint256 maxPayAmount,
        bytes calldata data
    ) external poolOngoing returns (uint256) {
        require(
            block.timestamp - state.heartBeat.lastHeartBeat <= state.heartBeat.maxInterval,
            Errors.HEARTBEAT_CHECK_FAIL
        );
        require(quoteAmount <= state.assetInfo[toToken].reserve, Errors.BALANCE_NOT_ENOUGH);

        _updateCumulative(fromToken);
        _updateCumulative(toToken);

        // query amount and transfer out
        (
            uint256 payFromAmount,
            uint256 receiveToAmount,
            uint256 vusdAmount,
            uint256 mtFee
        ) = queryBuyTokens(fromToken, toToken, quoteAmount);
        require(payFromAmount <= maxPayAmount, Errors.MAXPAY_NOT_ENOUGH);

        _transferOut(to, toToken, receiveToAmount);
        _transferOut(state._MAINTAINER_, toToken, mtFee);

        // external call & swap callback
        IDODOSwapCallback(msg.sender).d3MMSwapCallBack(fromToken, payFromAmount, data);

        require(
            IERC20(fromToken).balanceOf(address(this)) - state.assetInfo[fromToken].reserve >= payFromAmount,
            Errors.FROMAMOUNT_NOT_ENOUGH
        );

        require(getCollateralRatio() >= state._INITIAL_MARGIN_RATIO_, Errors.BELOW_IM_RATIO);

        // record swap
        _recordSwap(fromToken, toToken, vusdAmount, receiveToAmount + mtFee);

        emit Swap(to, fromToken, toToken, payFromAmount, receiveToAmount, 1);
        return payFromAmount;
    }

    /// @notice user could query sellToken result deducted mtFee, assign fromAmount
    /// @return payFromAmount fromToken's amount = fromAmount
    /// @return receiveToAmount toToken's amount
    /// @return vusdAmount fromToken bid vusd
    /// @return mtFee dodo takes the fee
    function querySellTokens(
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) public view returns (uint256, uint256, uint256, uint256) {
        require(fromAmount > 1000, Errors.AMOUNT_TOO_SMALL);
        Types.RangeOrderState memory D3State = getRangeOrderState(fromToken, toToken);

        (uint256 payFromAmount, uint256 receiveToAmount, uint256 vusdAmount) =
            PMMRangeOrder.querySellTokens(D3State, fromToken, toToken, fromAmount);

        uint256 mtFeeRate = IFeeRateModel(state._MT_FEE_RATE_MODEL_).getFeeRate(msg.sender);
        uint256 mtFee = DecimalMath.mulFloor(receiveToAmount, mtFeeRate);

        return (payFromAmount, receiveToAmount - mtFee, vusdAmount, mtFee);
    }

    /// @notice user could query sellToken result deducted mtFee, assign toAmount
    /// @return payFromAmount fromToken's amount
    /// @return receiveToAmount toToken's amount = toAmount
    /// @return vusdAmount fromToken bid vusd
    /// @return mtFee dodo takes the fee
    function queryBuyTokens(
        address fromToken,
        address toToken,
        uint256 toAmount
    ) public view returns (uint256, uint256, uint256, uint256) {
        require(toAmount > 1000, Errors.AMOUNT_TOO_SMALL);
        Types.RangeOrderState memory D3State = getRangeOrderState(fromToken, toToken);

        // query amount and transfer out
        uint256 mtFeeRate = IFeeRateModel(state._MT_FEE_RATE_MODEL_).getFeeRate(msg.sender);
        uint256 mtFee = DecimalMath.mulFloor(toAmount, mtFeeRate);
        toAmount += mtFee;

        (uint256 payFromAmount, uint256 receiveToAmountWithFee, uint256 vusdAmount) =
            PMMRangeOrder.queryBuyTokens(D3State, fromToken, toToken, toAmount);

        return (payFromAmount, receiveToAmountWithFee - mtFee, vusdAmount, mtFee);
    }

    // ================ internal ==========================

    function _recordSwap(address fromToken, address toToken, uint256 fromAmount, uint256 toAmount) internal {
        state.tokenMMInfoMap[fromToken].cumulativeBid += fromAmount;
        state.tokenMMInfoMap[toToken].cumulativeAsk += toAmount;

        updateReserve(fromToken);
        updateReserve(toToken);
    }

    function _updateCumulative(address token) internal {
        uint256 timeStamp = state.tokenMMInfoMap[token].updateTimestamp;
        uint256 tokenFlag = timeStamp & 1;
        if (tokenFlag == 0) {
            state.tokenMMInfoMap[token].cumulativeAsk = 0;
            state.tokenMMInfoMap[token].cumulativeBid = 0;
            state.tokenMMInfoMap[token].updateTimestamp = uint64(timeStamp | 1);
        }
    }

    function _transferOut(address to, address token, uint256 amount) internal {
        IERC20(token).safeTransfer(to, amount);
    }
}
