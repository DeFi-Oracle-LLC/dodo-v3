// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "./Types.sol";
import {IFeeRateModel} from "intf/IFeeRateModel.sol";

/// @notice trading read function
library TradingLibrary {
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
    function getTokenMMInfoForRead(
        Types.D3MMState storage state,
        address token,
        address trader
    )
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
        if (state.tokenMMInfoMap[token].amountInfo == 0) {
            return (0, 0, 0, 0, 0, 0, 0, 0, 0);
        }
        priceInfo = getOneTokenPriceSet(state, token);
        amountInfo = state.tokenMMInfoMap[token].amountInfo;
        mtFeeRate = IFeeRateModel(state._MT_FEE_RATE_MODEL_).getFeeRate(trader);
        kAsk = state.tokenMMInfoMap[token].kAsk;
        kBid = state.tokenMMInfoMap[token].kBid;
        updateTimeStamp = state.tokenMMInfoMap[token].updateTimestamp >> 1;
        updateFlag = state.tokenMMInfoMap[token].updateTimestamp & 1;
        cumulativeAsk = updateFlag == 1 ? state.tokenMMInfoMap[token].cumulativeAsk : 0;
        cumulativeBid = updateFlag == 1 ? state.tokenMMInfoMap[token].cumulativeBid : 0;
    }

    /// @notice give one token's address, give back token's priceInfo
    function getOneTokenPriceSet(Types.D3MMState storage state, address token) public view returns (uint96 priceSet) {
        uint256 tokenOriIndex = state.priceListInfo.tokenIndexMap[token] - 1;
        uint256 tokenIndex = (tokenOriIndex / 2);
        uint256 tokenIndexInnerSlot = tokenIndex % Types.PRICE_QUANTITY_IN_ONE_SLOT;

        uint256 curAllPrices = tokenOriIndex % 2 == 1
            ? state.priceListInfo.tokenPriceNS[tokenIndex / Types.PRICE_QUANTITY_IN_ONE_SLOT]
            : state.priceListInfo.tokenPriceStable[tokenIndex / Types.PRICE_QUANTITY_IN_ONE_SLOT];
        curAllPrices = curAllPrices >> (Types.ONE_PRICE_BIT * tokenIndexInnerSlot * 2);
        priceSet = uint96(curAllPrices & ((2 ** (Types.ONE_PRICE_BIT * 2)) - 1));
    }

    // ============ Swap =============
    /// @notice get swap status for internal swap
    function getRangeOrderState(
        Types.D3MMState storage state,
        address fromToken,
        address toToken
    ) public view returns (Types.RangeOrderState memory roState) {
        roState.oracle = state._ORACLE_;
        roState.fromTokenMMInfo = state.tokenMMInfoMap[fromToken];
        roState.toTokenMMInfo = state.tokenMMInfoMap[toToken];
        roState.fromTokenMMInfo.priceInfo = getOneTokenPriceSet(state, fromToken);
        roState.toTokenMMInfo.priceInfo = getOneTokenPriceSet(state, toToken);

        // deal with update flag
        if (roState.fromTokenMMInfo.updateTimestamp & 1 == 0) {
            roState.fromTokenMMInfo.cumulativeAsk = 0;
            roState.fromTokenMMInfo.cumulativeBid = 0;
        }

        if (roState.toTokenMMInfo.updateTimestamp & 1 == 0) {
            roState.toTokenMMInfo.cumulativeAsk = 0;
            roState.toTokenMMInfo.cumulativeBid = 0;
        }
    }
}
