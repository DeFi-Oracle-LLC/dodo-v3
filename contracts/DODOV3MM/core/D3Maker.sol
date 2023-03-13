// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "lib/PMMRangeOrder.sol";
import "lib/Types.sol";
import "./D3MMStorage.sol";

/// @dev maker could not delete token function
contract D3Maker is D3Storage {
    // ============= Read =================

    /// @notice get one token index. odd for none-stable, even for stable,  true index = (tokenIndex[address] - 1) / 2
    function getOneTokenOriginIndex(address token) external view returns (uint256) {
        return state.priceListInfo.tokenIndexMap[token] - 1;
    }

    /// @notice get all stable token Info
    /// @return numberOfStable stable tokens' quantity
    /// @return tokenPriceStable stable tokens' price slot array. each data contains up to 3 token prices
    function getStableTokenInfo() external view returns (uint256 numberOfStable, uint256[] memory tokenPriceStable) {
        numberOfStable = state.priceListInfo.numberOfStable;
        tokenPriceStable = state.priceListInfo.tokenPriceStable;
    }

    /// @notice get all non-stable token Info
    /// @return number stable tokens' quantity
    /// @return tokenPrices stable tokens' price slot array. each data contains up to 3 token prices
    function getNSTokenInfo() external view returns (uint256 number, uint256[] memory tokenPrices) {
        number = state.priceListInfo.numberOfNS;
        tokenPrices = state.priceListInfo.tokenPriceNS;
    }

    /// @notice used for construct several price in one price slot
    /// @param priceSlot origin price slot
    /// @param slotInnerIndex token index in slot
    /// @param priceSet the token info needed to update
    function stickPrice(
        uint256 priceSlot,
        uint256 slotInnerIndex,
        uint256 priceSet
    ) public pure returns (uint256 newPriceSlot) {
        uint256 leftPriceSet = priceSlot >> ((slotInnerIndex + 1) * Types.ONE_PRICE_BIT * 2);
        uint256 rightPriceSet = priceSlot & ((2 ** (slotInnerIndex * Types.ONE_PRICE_BIT * 2)) - 1);
        newPriceSlot = (leftPriceSet << ((slotInnerIndex + 1) * Types.ONE_PRICE_BIT * 2))
            + (priceSet << (slotInnerIndex * Types.ONE_PRICE_BIT * 2)) + rightPriceSet;
    }

    // ============= Set params ===========

    /// @notice maker could use multicall to set different params in one tx.
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }

            results[i] = result;
        }
    }

    /// @notice maker set a new token info
    /// @param token token's address
    /// @param priceSet describe ask and bid price, [ask price down(16) | ask price offSet + (16) | ask price decimal (8)| bid price down(16) | bid price offSet + (16) | bid price decimal(8)]
    /// @param priceSet packed price, [ask price down(16) | ask price offSet + (16) | ask price decimal (8)| bid price down(16) | bid price offSet + (16) | bid price decimal(8)]
    /// @param amountSet describe ask and bid amount and K, [ask amounts(16) | ask amounts decimal(8) | bid amounts(16) | bid amounts decimal(8) ] = one slot could contains 4 token info
    /// @param stableOrNot describe this token is stable or not, true = stable coin
    /// @param kAsk k of ask curve
    /// @param kBid k of bid curve
    function setNewToken(
        address token,
        bool stableOrNot,
        uint96 priceSet,
        uint64 amountSet,
        uint16 kAsk,
        uint16 kBid
    ) external onlyOwner {
        require(state.priceListInfo.tokenIndexMap[token] == 0, Errors.HAVE_SET_TOKEN_INFO);
        // check amount
        _checkAskAmount(token, amountSet);
        require(kAsk >= 0 && kAsk <= 10000, Errors.K_LIMIT);
        require(kBid >= 0 && kBid <= 10000, Errors.K_LIMIT);

        // set new token info
        state.tokenMMInfoMap[token].priceInfo = priceSet;
        state.tokenMMInfoMap[token].amountInfo = amountSet;
        state.tokenMMInfoMap[token].kAsk = kAsk;
        state.tokenMMInfoMap[token].kBid = kBid;
        state.tokenMMInfoMap[token].updateTimestamp = uint64(block.timestamp) << 1;
        state.heartBeat.lastHeartBeat = block.timestamp;

        // set token price index
        uint256 tokenIndex;
        if (stableOrNot) {
            // is stable
            tokenIndex = state.priceListInfo.numberOfStable * 2;
            uint256 innerSlotIndex = state.priceListInfo.numberOfStable % Types.PRICE_QUANTITY_IN_ONE_SLOT;
            uint256 slotIndex = state.priceListInfo.numberOfStable / Types.PRICE_QUANTITY_IN_ONE_SLOT;
            if (innerSlotIndex == 0) {
                state.priceListInfo.tokenPriceStable.push(priceSet);
            } else {
                state.priceListInfo.tokenPriceStable[slotIndex] = (
                    uint256(priceSet) << (Types.ONE_PRICE_BIT * 2 * innerSlotIndex)
                ) + state.priceListInfo.tokenPriceStable[slotIndex];
            }
            state.priceListInfo.numberOfStable++;
        } else {
            tokenIndex = state.priceListInfo.numberOfNS * 2 + 1;
            uint256 innerSlotIndex = state.priceListInfo.numberOfNS % Types.PRICE_QUANTITY_IN_ONE_SLOT;
            uint256 slotIndex = state.priceListInfo.numberOfNS / Types.PRICE_QUANTITY_IN_ONE_SLOT;
            if (innerSlotIndex == 0) {
                state.priceListInfo.tokenPriceNS.push(priceSet);
            } else {
                state.priceListInfo.tokenPriceNS[slotIndex] = (
                    uint256(priceSet) << (Types.ONE_PRICE_BIT * 2 * innerSlotIndex)
                ) + state.priceListInfo.tokenPriceNS[slotIndex];
            }
            state.priceListInfo.numberOfNS++;
        }
        // to avoid reset the same token, tokenIndexMap record index from 1, but actualIndex = tokenIndex[address] - 1
        state.priceListInfo.tokenIndexMap[token] = tokenIndex + 1;

        emit SetPoolInfo(1);
    }

    /// @notice set token prices
    /// @param tokens token address set
    /// @param tokenPrices token prices set, each number pack one token all price.Each format is the same with priceSet
    /// [ask price down(16) | ask price offSet + (16) | ask price decimal (8)| bid price down(16) | bid price offSet + (16) | bid price decimal(8)] = one slot could contains 3 token info
    function setTokensPrice(address[] calldata tokens, uint96[] calldata tokenPrices) external onlyOwner {
        uint256[] memory haveWrittenToken = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            if (haveWrittenToken[i] == 1) continue;

            haveWrittenToken[i] = 1;
            address curToken = tokens[i];
            uint96 curTokenPriceSet = tokenPrices[i];
            _checkUpAndDownPrice(curTokenPriceSet);

            // get slot price
            uint256 curTokenIndex = (state.priceListInfo.tokenIndexMap[curToken] - 1) / 2;
            uint256 slotIndex = curTokenIndex / Types.PRICE_QUANTITY_IN_ONE_SLOT;
            uint256 priceInfoSet = (state.priceListInfo.tokenIndexMap[curToken] - 1) % 2 == 1
                ? state.priceListInfo.tokenPriceNS[slotIndex]
                : state.priceListInfo.tokenPriceStable[slotIndex];

            priceInfoSet =
                stickPrice(priceInfoSet, curTokenIndex % Types.PRICE_QUANTITY_IN_ONE_SLOT, uint256(curTokenPriceSet));

            // find one slot token
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                address tokenJ = tokens[j];
                uint256 tokenJOriIndex = (state.priceListInfo.tokenIndexMap[tokenJ] - 1);
                if (
                    haveWrittenToken[j] == 1 // have written
                        || (state.priceListInfo.tokenIndexMap[curToken] - 1) % 2 != tokenJOriIndex % 2 // not the same stable type
                        || tokenJOriIndex / 2 / Types.PRICE_QUANTITY_IN_ONE_SLOT != slotIndex
                ) {
                    // not one slot
                    continue;
                }
                _checkUpAndDownPrice(tokenPrices[j]);
                priceInfoSet = stickPrice(
                    priceInfoSet, (tokenJOriIndex / 2) % Types.PRICE_QUANTITY_IN_ONE_SLOT, uint256(tokenPrices[j])
                );

                haveWrittenToken[j] = 1;
            }

            if ((state.priceListInfo.tokenIndexMap[curToken] - 1) % 2 == 1) {
                state.priceListInfo.tokenPriceNS[slotIndex] = priceInfoSet;
            } else {
                state.priceListInfo.tokenPriceStable[slotIndex] = priceInfoSet;
            }
        }
        state.heartBeat.lastHeartBeat = block.timestamp;

        emit SetPoolInfo(2);
    }

    /// @notice user set PriceListInfo.tokenPriceNS price info, only for none-stable coin
    /// @param slotIndex tokenPriceNS index
    /// @param priceSlots tokenPriceNS price info, every data has packed all 3 token price info
    /// @dev maker should be responsible for data availability
    function setNSPriceSlot(uint256[] calldata slotIndex, uint256[] calldata priceSlots) external onlyOwner {
        for (uint256 i = 0; i < slotIndex.length; ++i) {
            state.priceListInfo.tokenPriceNS[i] = priceSlots[i];
        }
        state.heartBeat.lastHeartBeat = block.timestamp;

        emit SetPoolInfo(3);
    }

    /// @notice user set PriceListInfo.tokenPriceStable price info, only for stable coin
    /// @param slotIndex tokenPriceStable index
    /// @param priceSlots tokenPriceNS price info, every data has packed all 3 token price info
    /// @dev maker should be responsible for data availability
    function setStablePriceSlot(uint256[] calldata slotIndex, uint256[] calldata priceSlots) external onlyOwner {
        for (uint256 i = 0; i < slotIndex.length; ++i) {
            state.priceListInfo.tokenPriceStable[i] = priceSlots[i];
        }
        state.heartBeat.lastHeartBeat = block.timestamp;

        emit SetPoolInfo(4);
    }

    /// @notice set token Amounts
    /// @param tokens token address set
    /// @param tokenAmounts token amounts set, each number pack one token all amounts.Each format is the same with amountSetAndK
    /// [ask amounts(16) | ask amounts decimal(8) | bid amounts(16) | bid amounts decimal(8) ]
    function setTokensAmounts(address[] calldata tokens, uint64[] calldata tokenAmounts) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; ++i) {
            address curToken = tokens[i];
            uint64 curTokenAmountSet = tokenAmounts[i];

            _checkAskAmount(curToken, curTokenAmountSet);
            state.tokenMMInfoMap[curToken].amountInfo = curTokenAmountSet;
            state.tokenMMInfoMap[curToken].updateTimestamp = uint64(block.timestamp) << 1;
        }
        state.heartBeat.lastHeartBeat = block.timestamp;

        emit SetPoolInfo(5);
    }

    /// @notice set token Ks
    /// @param tokens token address set
    /// @param tokenKs token k_ask and k_bid, structure like [kAsk(16) | kBid(16)]
    function setTokensKs(address[] calldata tokens, uint32[] calldata tokenKs) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; ++i) {
            address curToken = tokens[i];
            uint32 curTokenK = tokenKs[i];
            uint16 kAsk = uint16(curTokenK >> 16);
            uint16 kBid = uint16(curTokenK & 0xffff);

            require(kAsk >= 0 && kAsk <= 10000, Errors.K_LIMIT);
            require(kBid >= 0 && kBid <= 10000, Errors.K_LIMIT);

            state.tokenMMInfoMap[curToken].kAsk = kAsk;
            state.tokenMMInfoMap[curToken].kBid = kBid;
        }
        state.heartBeat.lastHeartBeat = block.timestamp;

        emit SetPoolInfo(6);
    }

    // =========== internal ==========

    function _checkAskAmount(address token, uint64 amountSet) internal view {
        uint256 amountWithDecimal = Types.parseAskAmount(amountSet);
        require(amountWithDecimal >= 0 && amountWithDecimal <= state.assetInfo[token].reserve, Errors.ASK_AMOUNT_EXCEED);
    }

    function _checkUpAndDownPrice(uint96 priceSet) internal pure {
        (uint256 askDownPrice, uint256 askUpPrice) = Types.parseAskPrice(priceSet);
        require(askUpPrice >= askDownPrice && askDownPrice >= 0, Errors.PRICE_UP_BELOW_PRICE_DOWN);
        (uint256 bidDownPrice, uint256 bidUpPrice) = Types.parseBidPrice(priceSet);
        require(bidUpPrice >= bidDownPrice && bidDownPrice >= 0, Errors.PRICE_UP_BELOW_PRICE_DOWN);
    }
}
