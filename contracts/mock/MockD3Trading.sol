/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "lib/Types.sol";
import {D3Trading} from "core/D3Trading.sol";
import {D3Maker} from "core/D3Maker.sol";
import "lib/Errors.sol";
import {DecimalMath} from "lib/DecimalMath.sol";
import {PMMRangeOrder} from "lib/PMMRangeOrder.sol";
import {PMMPricing} from "lib/PMMPricing.sol";
import {IFeeRateModel} from "intf/IFeeRateModel.sol";
import {ID3Oracle} from "intf/ID3Oracle.sol";
import "lib/DODOMath.sol";

contract MockD3Trading is D3Trading, D3Maker {
    function init(
        address creator,
        address oracle,
        address feeRate
    ) external {
        initOwner(creator);
        state._ORACLE_ = oracle;
        state._MT_FEE_RATE_MODEL_ = feeRate;
    }

    function setNewTokenMMInfo(
        address token,
        Types.TokenMMInfo memory tokenInfo
    ) public onlyOwner {
        state.tokenMMInfoMap[token] = tokenInfo;
        
        // add price set
        // set token price index, default as non-stable
        uint256 tokenIndex;
        uint priceSet = tokenInfo.priceInfo;

            tokenIndex = state.priceListInfo.numberOfNS * 2 + 1;
            uint256 innerSlotIndex = state.priceListInfo.numberOfNS % Types.PRICE_QUANTITY_IN_ONE_SLOT;
            uint256 slotIndex = state.priceListInfo.numberOfNS / Types.PRICE_QUANTITY_IN_ONE_SLOT;
            if(innerSlotIndex == 0) {
                state.priceListInfo.tokenPriceNS.push(priceSet);
            } else {
                state.priceListInfo.tokenPriceNS[slotIndex] = (uint256(priceSet) << (Types.ONE_PRICE_BIT * 2 * innerSlotIndex)) +
                                                                    state.priceListInfo.tokenPriceNS[slotIndex];
            }
            state.priceListInfo.numberOfNS ++;
        
        state.priceListInfo.tokenIndexMap[token] = tokenIndex + 1;
    }

    function parseAskAmount(uint64 amountSet) public pure returns (uint256) {
        uint256 amountWithDecimal = Types.parseAskAmount(amountSet);
        return amountWithDecimal;
    }

    function parseBidAmount(uint64 amountSet) public pure returns (uint256) {
        uint256 amountWithDecimal = Types.parseBidAmount(amountSet);
        return amountWithDecimal;
    }

    function parseAskPrice(uint96 priceSet)
        public
        pure
        returns (uint256 askDownPriceWithDecimal, uint256 askUpPriceWithDecimal)
    {
        return Types.parseAskPrice(priceSet);
    }

    function parseBidPrice(uint96 priceSet)
        public
        pure
        returns (uint256 bidDownPriceWithDecimal, uint256 bidUpPriceWithDecimal)
    {
        return Types.parseBidPrice(priceSet);
    }

    function parseK(uint16 originK) public pure returns (uint256) {
        uint256 result = Types.parseK(originK);
        return result;
    }

    // for pmmrangeOrder
    function libQuerySellTokens(
        Types.RangeOrderState memory roState, 
        address fromToken, 
        address toToken, 
        uint256 fromAmount
    ) public view returns(uint256, uint256, uint256) {
        (uint256 payFromAmount, uint256 receiveToAmount, uint256 vusdAmount) = libQuerySellTokensInner(roState, fromToken, toToken, fromAmount);
        return (payFromAmount, receiveToAmount, vusdAmount);
    }

    function querySellTokensForLib(address fromToken, address toToken, uint256 fromAmount) public view returns(uint256, uint256, uint256, uint256) {
        require(fromAmount > 1000, Errors.AMOUNT_TOO_SMALL);
        Types.RangeOrderState memory D3State = getRangeOrderState(
            fromToken,
            toToken
        );

        (uint256 payFromAmount, uint256 receiveToAmount, uint256 vusdAmount) = libQuerySellTokens(D3State, fromToken, toToken, fromAmount);

        uint256 mtFeeRate = IFeeRateModel(state._MT_FEE_RATE_MODEL_).getFeeRate(msg.sender);
        uint256 mtFee = DecimalMath.mulFloor(receiveToAmount, mtFeeRate);

        return (payFromAmount, receiveToAmount - mtFee, vusdAmount, mtFee);
    }

    // for pmmPricing
    function queryBuyTokensForLib(address fromToken, address toToken, uint256 toAmount) public view returns(uint256, uint256, uint256, uint256) {
        require(toAmount > 1000, Errors.AMOUNT_TOO_SMALL);
        Types.RangeOrderState memory D3State = getRangeOrderState(
            fromToken,
            toToken
        );

        // query amount and transfer out
        uint256 mtFeeRate = IFeeRateModel(state._MT_FEE_RATE_MODEL_).getFeeRate(msg.sender);
        uint256 mtFee = DecimalMath.mulFloor(toAmount, mtFeeRate);
        toAmount += mtFee;

        (uint256 payFromAmount, uint256 receiveToAmountWithFee, uint256 vusdAmount) = libQueryBuyTokens(D3State, fromToken, toToken, toAmount);

        return (payFromAmount, receiveToAmountWithFee - mtFee, vusdAmount, mtFee);
    }

    function libQueryBuyTokens( 
        Types.RangeOrderState memory roState, 
        address fromToken, address toToken, 
        uint256 toTokenAmount) public view returns(uint256 payFromToken, uint256 toAmount, uint256 vusdAmount)
    {
        // contruct fromToken to vUSD
        uint256 payVUSD;
        {
            PMMPricing.PMMState memory toTokenState = PMMRangeOrder._contructTokenState(roState, false, true);
            // vault reserve protect
            require(toTokenAmount <= toTokenState.BMaxAmount - roState.toTokenMMInfo.cumulativeAsk, Errors.RO_VAULT_RESERVE);
            payVUSD = queryBuyBaseTokenForLib(toTokenState, toTokenAmount);
        }

        // construct vUSD to toToken
        {
            PMMPricing.PMMState memory fromTokenState = PMMRangeOrder._contructTokenState(roState, true, false);
            payFromToken = queryBuyBaseTokenForMath(fromTokenState, payVUSD);
        }

        // oracle protect 
        {
            uint256 oracleToAmount = ID3Oracle(roState.oracle).getMaxReceive(fromToken, toToken, payFromToken);
            require(oracleToAmount >= toTokenAmount, Errors.RO_ORACLE_PROTECTION);
        }

        return (payFromToken, toTokenAmount, payVUSD);
    }

    function queryBuyBaseTokenForLib(PMMPricing.PMMState memory state, uint256 amount)
        public
        pure
        returns (uint256)
    {
        uint256 payQuote = PMMPricing._queryBuyBaseToken(state, amount);
        return payQuote;
    }
    
    // for dodoMath
    function queryBuyBaseTokenForMath(PMMPricing.PMMState memory state, uint256 amount)
        public
        pure
        returns (uint256)
    {
        uint256 payQuote = _BuyBaseTokenForMath(state, amount, state.B, state.B0);
        return payQuote;
    }

    function _BuyBaseTokenForMath(
        PMMPricing.PMMState memory state,
        uint256 amount,
        uint256 baseBalance,
        uint256 targetBaseAmount
    ) public pure returns (uint256 ) {
        require(amount < baseBalance, "DODOstate.BNOT_ENOUGH");
        uint256 B2 = baseBalance - amount;
        
        uint256 payQuoteToken = DODOMath._GeneralIntegrate(
                targetBaseAmount, 
                baseBalance, 
                B2, 
                state.i, 
                state.K
            );
        return payQuoteToken;
    }


    // for dodo math sell and pmmpricing sell
    function libQuerySellTokensInner( 
        Types.RangeOrderState memory roState, 
        address fromToken, address toToken, 
        uint256 fromTokenAmount) public view returns(uint256 payFromToken, uint256 receiveToToken, uint256 vusdAmount)
    {
        // contruct fromToken state and swap to vUSD
        uint256 receiveVUSD;
        {
            PMMPricing.PMMState memory fromTokenState = PMMRangeOrder._contructTokenState(
                roState,
                true,
                false
            );
            receiveVUSD = querySellQuoteTokenForLib(
                fromTokenState,
                fromTokenAmount
            );
        }

        // construct toToken state and swap from vUSD to toToken
        {
            PMMPricing.PMMState memory toTokenState = PMMRangeOrder._contructTokenState(
                roState,
                false,
                true
            );
            receiveToToken = querySellQuoteTokenForMath(
                toTokenState,
                receiveVUSD
            );
        }

        // oracle protect
        {
            uint256 oracleToAmount = ID3Oracle(roState.oracle).getMaxReceive(
                fromToken,
                toToken,
                fromTokenAmount
            );
            require(
                oracleToAmount >= receiveToToken,
                Errors.RO_ORACLE_PROTECTION
            );
        }
        return (fromTokenAmount, receiveToToken, receiveVUSD);
    }

    function querySellQuoteTokenForLib(PMMPricing.PMMState memory state, uint256 amount)
        public
        pure
        returns (uint256)
    {
        uint256 payQuote = PMMPricing._querySellQuoteToken(state, amount);
        return payQuote;
    }
    
    // for dodoMath
    function querySellQuoteTokenForMath(PMMPricing.PMMState memory state, uint256 amount)
        public
        pure
        returns (uint256)
    {
        uint256 payQuote = DODOMath._SolveQuadraticFunctionForTrade(
                state.B0,
                state.B,
                amount,
                DecimalMath.reciprocalFloor(state.i),
                state.K
            );
        return payQuote;
    }

}
