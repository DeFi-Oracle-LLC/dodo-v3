// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

library Types {
    struct D3MMState {
        // tokens in the pool
        address[] tokenList;
        // token => AssetInfo, including dToken, reserve, max deposit, accrued interest
        mapping(address => AssetInfo) assetInfo;
        // token => interest rate
        mapping(address => uint256) interestRate;
        // token => liquidation target amount
        mapping(address => uint256) liquidationTarget;
        // token => amount, how many token can owner withdraw after pool end
        mapping(address => uint256) ownerBalanceAfterPoolEnd;
        // the last time of updating accrual of interest
        uint256 accrualTimestamp;
        // the D3Factory contract
        address _D3_FACTORY_;
        // the UserQuota contract
        address _USER_QUOTA_;
        // the creator of pool
        address _CREATOR_;
        // the start time of first epoch
        uint256 _EPOCH_START_TIME_;
        // the epoch duration
        uint256 _EPOCH_DURATION_;
        // use oracle to get token price
        address _ORACLE_;
        // when collateral ratio below IM, owner cannot withdraw, LPs cannot deposit
        uint256 _INITIAL_MARGIN_RATIO_;
        // when collateral ratio below MM, pool is going to be liquidated
        uint256 _MAINTENANCE_MARGIN_RATIO_;
        // swap maintainer
        address _MAINTAINER_;
        // swap fee model
        address _MT_FEE_RATE_MODEL_;
        // all pending LP withdraw requests
        WithdrawInfo[] pendingWithdrawList;
        // record next epoch interest rates and timestamp
        Epoch nextEpoch;
        // the current status of pool, including Ongoing, Liquidating, End
        PoolStatus _POOL_STATUS_;
        // record market maker last time updating pool
        HeartBeat heartBeat;
        // price list to package prices in one slot
        PriceListInfo priceListInfo;
        // =============== Swap Storage =================
        mapping(address => TokenMMInfo) tokenMMInfoMap;
    }

    struct AssetInfo {
        address d3Token;
        uint256 reserve;
        uint256 maxDepositAmount;
        uint256 accruedInterest;
    }

    // epoch info
    struct Epoch {
        // epoch start time
        uint256 timestamp;
        // token => interest rate
        mapping(address => uint256) interestRate;
    }

    // LP withdraw request
    struct WithdrawInfo {
        // request id, a hash of lp address + deadline timestamp
        bytes32 requestId;
        // refund deadline, if owner hasn't refunded after this time, liquidator can force refund
        uint256 deadline;
        // user who requests withdrawing
        address user;
        // the token to be withdrawn
        address token;
        // this amount of D3Token will be locked after user submit withdraw request,
        // but will still generate interest during pending time
        uint256 d3TokenAmount;
    }

    // liquidation swap info
    struct LiquidationOrder {
        address fromToken;
        address toToken;
        uint256 fromAmount;
    }

    struct TokenMMInfo {
        // [ask price down(16) | ask price offSet + (16) | ask price down decimal(8) | bid price down(16) |  bid price offSet + (16) | bid price up decimal(8)]
        uint96 priceInfo;
        // [ask amounts(16) | ask amounts decimal(8) | bid amounts(16) | bid amounts decimal(8) ]
        uint64 amountInfo;
        // k is [0, 10000]
        uint16 kAsk;
        uint16 kBid;
        // [timeStamp | cumulativeflag = 0 or 1(1 bit)]
        uint64 updateTimestamp;
        uint256 cumulativeBid;
        uint256 cumulativeAsk;
    }

    // package three token price in one slot
    struct PriceListInfo {
        // to avoid reset the same token, tokenIndexMap record index from 1, but actualIndex = tokenIndex[address] - 1
        // odd for none-stable, even for stable,  true index = actualIndex / 2 = (tokenIndex[address] - 1) / 2
        mapping(address => uint256) tokenIndexMap;
        uint256 numberOfNS; // quantity of not stable token
        uint256 numberOfStable; // quantity of stable token
        // [ask price down(16) | ask price offSet + (16) | ask price decimal (8)| bid price down(16) | bid price offSet + (16) | bid price decimal(8)] = 80 bit
        // one slot contain = 80 * 3, 3 token price
        // [2 | 1 | 0]
        uint256[] tokenPriceNS; // not stable token price
        uint256[] tokenPriceStable; // stable token price
    }

    struct HeartBeat {
        uint256 lastHeartBeat;
        uint256 maxInterval;
    }

    uint16 internal constant ONE_PRICE_BIT = 40;
    uint256 internal constant PRICE_QUANTITY_IN_ONE_SLOT = 3;
    uint16 internal constant ONE_AMOUNT_BIT = 24;
    uint256 internal constant SECONDS_PER_YEAR = 31536000;
    uint256 internal constant ONE = 10 ** 18;

    // [ask amounts(16) | ask amounts decimal(8) | bid amounts(16) | bid amounts decimal(8) ]
    function parseAskAmount(uint64 amountSet) internal pure returns (uint256 amountWithDecimal) {
        uint256 askAmount = (amountSet >> (ONE_AMOUNT_BIT + 8)) & 0xffff;
        uint256 askAmountDecimal = (amountSet >> ONE_AMOUNT_BIT) & 255;
        amountWithDecimal = askAmount * (10 ** askAmountDecimal);
    }

    // [ask amounts(16) | ask amounts decimal(8) | bid amounts(16) | bid amounts decimal(8) ]
    function parseBidAmount(uint64 amountSet) internal pure returns (uint256 amountWithDecimal) {
        uint256 bidAmount = (amountSet >> 8) & 0xffff;
        uint256 bidAmountDecimal = amountSet & 255;
        amountWithDecimal = bidAmount * (10 ** bidAmountDecimal);
    }

    // [ask price down(16) | ask price offSet + (16) | ask price decimal (8)| bid price down(16) | bid price offSet + (16) | bid price decimal(8)]
    function parseAskPrice(uint96 priceSet)
        internal
        pure
        returns (uint256 askDownPriceWithDecimal, uint256 askUpPriceWithDecimal)
    {
        uint256 askDownPrice = (priceSet >> (ONE_PRICE_BIT + 24)) & 0xffff;
        uint256 askPriceOffset = (priceSet >> (ONE_PRICE_BIT + 8)) & 0xffff;
        uint256 askDownPriceDecimal = (priceSet >> (ONE_PRICE_BIT)) & 255;
        uint256 askUpPrice = (askDownPrice + askPriceOffset) < type(uint16).max ? askDownPrice + askPriceOffset : 0;
        uint256 askUpPriceDecimal = askDownPriceDecimal;
        askDownPriceWithDecimal = askDownPrice * (10 ** askDownPriceDecimal);
        askUpPriceWithDecimal = askUpPrice * (10 ** askUpPriceDecimal);
    }

    // [ask price down(16) | ask price offSet + (16) | ask price decimal (8)| bid price down(16) | bid price offSet + (16) | bid price decimal(8)]
    function parseBidPrice(uint96 priceSet)
        internal
        pure
        returns (uint256 bidDownPriceWithDecimal, uint256 bidUpPriceWithDecimal)
    {
        uint256 bidDownPrice = (priceSet >> 24) & 0xffff;
        uint256 bidPriceOffset = (priceSet >> 8) & 0xffff;
        uint256 bidDownPriceDecimal = priceSet & 255;
        uint256 bidUpPrice = (bidDownPrice + bidPriceOffset) < type(uint16).max ? bidDownPrice + bidPriceOffset : 0;
        uint256 bidUpPriceDecimal = bidDownPriceDecimal;
        bidDownPriceWithDecimal = bidDownPrice * (10 ** bidDownPriceDecimal);
        bidUpPriceWithDecimal = bidUpPrice * (10 ** bidUpPriceDecimal);
    }

    function parseK(uint16 originK) internal pure returns (uint256) {
        return uint256(originK) * (10 ** 14);
    }

    struct RangeOrderState {
        address oracle;
        TokenMMInfo fromTokenMMInfo;
        TokenMMInfo toTokenMMInfo;
    }

    enum PoolStatus {
        Ongoing,
        Liquidating,
        End
    }
}
