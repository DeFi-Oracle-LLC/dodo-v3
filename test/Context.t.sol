/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "lib/Errors.sol";
import "lib/Types.sol";
import "core/D3Token.sol";
import "core/D3MMFactory.sol";
import "core/D3MM.sol";
import "periphery/D3MMLiquidationRouter.sol";
import "periphery/D3Oracle.sol";
import "mock/MockERC20.sol";
import "mock/MockChainlinkPriceFeed.sol";
import "mock/MockRouter.sol";
import {MockFailD3Proxy} from "mock/MockD3Proxy.sol";
import {DODOApprove} from "mock/DODOApprove.sol";
import {DODOApproveProxy} from "mock/DODOApproveProxy.sol";
import {WETH9} from "mock/WETH9.sol";
import {MockFeeRateModel} from "mock/MockFeeRateModel.sol";
import {CloneFactory} from "lib/CloneFactory.sol";
import {D3Proxy} from "periphery/D3Proxy.sol";

contract Context is Test {
    struct SwapCallbackData {
        bytes data;
        address payer;
    }

    DODOApprove public dodoApprove;
    DODOApproveProxy public dodoApproveProxy;
    D3Proxy public d3Proxy;
    MockFailD3Proxy public failD3Proxy;
    WETH9 public weth;

    MockFeeRateModel public feeRate;
    D3MM public d3Logic;
    D3Token public d3TokenLogic;
    CloneFactory public cloneFactory;

    D3MMFactory public d3Factory;
    D3MM public d3MM;
    D3MMLiquidationRouter public liquidationRouter;
    D3Oracle public oracle;
    MockRouter public router;
    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20 public token3;
    MockERC20 public token4;
    address[] public tokens;
    uint256[] public interestRates;
    address public poolCreator = address(123);
    MockChainlinkPriceFeed public token1ChainLinkOracle;
    MockChainlinkPriceFeed public token2ChainLinkOracle;
    MockChainlinkPriceFeed public token3ChainLinkOracle;
    MockChainlinkPriceFeed public token4ChainLinkOracle;
    address public user1 = address(1111);
    address public user2 = address(2222);
    address public liquidator = address(3333);

    event SetUserQuota(address indexed userQuota);
    event SetMaxDeposit(address indexed token, uint256 amount);
    event AddNewToken(
        address indexed token,
        uint256 interestRate,
        uint256 maxDepositAmount
    );
    event SetNextEpoch(
        uint256 indexed nextEpochStart,
        address[] tokenList,
        uint256[] interestRates
    );
    event ExecuteEpochUpdate();
    event LpDeposit(address indexed lp, address indexed token, uint256 amount);
    event LpRequestWithdrawal(
        bytes32 indexed requestId,
        address indexed lp,
        address indexed token,
        uint256 d3TokenAmount
    );
    event RefundWithdrawal(
        bytes32 indexed requestId,
        address indexed lp,
        address indexed token,
        uint256 amount
    );
    event Refund(address indexed lp, address indexed token, uint256 amount);
    event OwnerDeposit(address indexed token, uint256 amount);
    event OwnerWithdraw(
        address indexed to,
        address indexed token,
        uint256 amount
    );
    event OwnerClosePool();

    event StartLiquidation();
    event FinishLiquidation();

    // ---------- Gas Report Helper ----------

    string private checkpointLabel;
    uint256 private checkpointGasLeft = 1; // Start the slot warm.

    function startMeasuringGas(string memory label) internal virtual {
        checkpointLabel = label;

        checkpointGasLeft = gasleft();
    }

    function stopMeasuringGas() internal virtual {
        uint256 checkpointGasLeft2 = gasleft();

        // Subtract 100 to account for the warm SLOAD in startMeasuringGas.
        uint256 gasDelta = checkpointGasLeft - checkpointGasLeft2 - 100;
        console.log(checkpointLabel, " Gas", gasDelta);
    }

    // ---------- Create Contracts ----------

    function createTokens() public {
        token1 = new MockERC20("Wrapped BTC", "WBTC", 8);
        token2 = new MockERC20("Token2", "TK2", 18);
        token3 = new MockERC20("Token3", "TK3", 18);
        token4 = new MockERC20("Token4", "TK4", 18);
        createWETH();
    }

    function createWETH() public {
        weth = new WETH9();
    }

    function createOracle() public {
        oracle = new D3Oracle();
        token1ChainLinkOracle = new MockChainlinkPriceFeed("Token1/USD", 18);
        token2ChainLinkOracle = new MockChainlinkPriceFeed("Token2/USD", 18);
        token3ChainLinkOracle = new MockChainlinkPriceFeed("Token3/USD", 18);
        token4ChainLinkOracle = new MockChainlinkPriceFeed("WETH/USD", 18);
        token1ChainLinkOracle.feedData(1300 * 1e18);
        token2ChainLinkOracle.feedData(12 * 1e18);
        token3ChainLinkOracle.feedData(1 * 1e18);
        token4ChainLinkOracle.feedData(12 * 1e18);
        oracle.setPriceSource(
            address(token1),
            PriceSource(
                address(token1ChainLinkOracle),
                true,
                5 * (10**17),
                18,
                8
            )
        );
        oracle.setPriceSource(
            address(token2),
            PriceSource(
                address(token2ChainLinkOracle),
                true,
                5 * (10**17),
                18,
                18
            )
        );
        oracle.setPriceSource(
            address(token3),
            PriceSource(
                address(token3ChainLinkOracle),
                true,
                5 * (10**17),
                18,
                18
            )
        );
        oracle.setPriceSource(
            address(weth),
            PriceSource(
                address(token4ChainLinkOracle),
                true,
                5 * (10**17),
                18,
                18
            )
        );
    }

    function createRouter() public {
        router = new MockRouter(address(oracle));
        faucet(address(token1), address(router), 100000 ether);
        faucet(address(token2), address(router), 100000 ether);
        faucet(address(token3), address(router), 100000 ether);
    }

    function createLiquidatorAdapter() public {
        liquidationRouter = new D3MMLiquidationRouter(address(dodoApprove));
    }

    function createFeeRate() public {
        feeRate = new MockFeeRateModel();
        feeRate.initOwner(poolCreator);
    }

    function createD3MMFactory() public {
        d3Logic = new D3MM();
        d3TokenLogic = new D3Token();
        cloneFactory = new CloneFactory();
        d3Factory = new D3MMFactory(
            address(d3Logic),
            address(d3TokenLogic),
            address(cloneFactory),
            poolCreator,
            address(feeRate)
        );

        createTokens();
        createOracle();
        createRouter();
        createLiquidatorAdapter();

        d3Factory.addLiquidator(liquidator);
        d3Factory.addRouter(address(liquidationRouter));
        d3Factory.setOracle(address(oracle));
    }

    function createD3MM() public {
        createFeeRate();
        createD3MMFactory();
        resetTokenList();
        vm.warp(2 days);
        address d3MMAddress = d3Factory.breedDODO(
            poolCreator, // market maker address
            tokens, // token list
            1 days, // epoch start time
            7 days, // epoch duration
            4e17, // IM
            2e17 // MM
        );
        d3MM = D3MM(d3MMAddress);
        vm.prank(poolCreator);
        d3MM.setBeatInterval(1 days);
    }

    function createD3Proxy() public {
        dodoApprove = new DODOApprove();
        dodoApproveProxy = new DODOApproveProxy(address(dodoApprove));
        dodoApprove.init(poolCreator, address(dodoApproveProxy));

        d3Proxy = new D3Proxy(
            address(dodoApproveProxy),
            address(weth),
            address(d3Factory)
        );
        failD3Proxy = new MockFailD3Proxy(
            address(dodoApproveProxy),
            address(weth)
        );

        address[] memory proxies = new address[](2);
        proxies[0] = address(d3Proxy);
        proxies[1] = address(failD3Proxy);
        dodoApproveProxy.init(poolCreator, proxies);
    }

    // ---------- Context ----------

    function contextBasic() public {
        createD3MM();
    }

    /*
        Context One: Pool Ongoing
        1. Use D3MMFactory to create D3MM
        2. Pool owner set interest rates
        3. Pool owner wait to next epoch to update interest rates
        4. Pool owner set max deposit
        5. Pool owner deposit some tokens
        
    */
    function contextPoolOngoing() public {
        interestRates.push(4e17); // 40%
        interestRates.push(2e17); // 20%
        interestRates.push(3e17); // 30%
        vm.startPrank(poolCreator);
        d3MM.setNextEpoch(tokens, interestRates);
        vm.warp(8 days);
        d3MM.executeEpochUpdate();
        d3MM.setMaxDeposit(address(token1), 10000 * 1e8);
        d3MM.setMaxDeposit(address(token2), 20000 ether);
        d3MM.setMaxDeposit(address(token3), 30000 ether);
        vm.stopPrank();

        ownerDeposit(address(token1), 5000 * 1e8);
        ownerDeposit(address(token2), 1000 ether);
        ownerDeposit(address(token3), 15000 ether);
        lpDeposit(user1, address(token1), 1000 * 1e8);
        lpDeposit(user1, address(token2), 8000 ether);
        lpDeposit(user1, address(token3), 8000 ether);
    }

    /*
        Context Two: Pool Liquidating
        1. create a normal pool
        2. user deposit tokens
        3. after a long time, the accrual interests will make collateral ratio below MM
        4. use liquidator account to trigger liquidation
    */
    function contextPoolLiquidating() public {
        contextPoolOngoing();
        // logCollateralRatio();
        vm.warp(4000 days);
        // logCollateralRatio();
        vm.prank(liquidator);
        d3MM.startLiquidation();
    }

    /*
        Context Three: Pool Liquidating With Collateral Ratio 0%
        1. create a normal pool
        2. user deposit tokens
        3. after an EXTREME long time, the accrual interests will make collateral ratio 0
        4. use liquidator account to trigger liquidation
    */
    function contextPoolLiquidatingExtreme() public {
        contextPoolOngoing();
        logCollateralRatio();
        vm.warp(8000 days);
        logCollateralRatio();
        vm.prank(liquidator);
        vm.expectEmit(true, true, true, true);
        emit StartLiquidation();
        d3MM.startLiquidation();
    }

    /*
        Context Four: Pool End - Liquidation Done
        1. create a pool under liquidating
        2. use route to swap remaining assets
        3. end liquidating
    */
    function contextPoolLiquidationDone() public {
        contextPoolLiquidating();
        uint256 token1Price = ID3Oracle(oracle).getPrice(address(token1));
        uint256 token2Price = ID3Oracle(oracle).getPrice(address(token2));
        uint256 token3Price = ID3Oracle(oracle).getPrice(address(token3));
        console.log(token1Price / 1e18, token2Price / 1e18, token3Price / 1e18);
        console.log("");
        logLiquidationProcessInfo();
        liquidateSwap(address(token1), address(token2), 153 * 1e8); // token1 is WBTC, decimals: 8
        liquidateSwap(address(token1), address(token3), 9 * 1e8);
        vm.prank(liquidator);
        d3MM.finishLiquidation();
    }

    /*
        Context Five: Pool End - Owner Close
        1. create a normal pool
        2. owner close the pool
    */
    function contextPoolOwnerClose() public {
        contextPoolOngoing();
        vm.warp(100 days);
        vm.prank(poolCreator);
        d3MM.ownerClosePool();
    }

    // -------- Helper Functions ---------
    function faucet(
        address token,
        address to,
        uint256 amount
    ) public {
        MockERC20(token).mint(to, amount);
    }

    function ownerDeposit(address token, uint256 amount) public {
        faucet(token, address(d3MM), amount);
        d3MM.ownerDeposit(token);
    }

    function lpDeposit(
        address lp,
        address token,
        uint256 amount
    ) public {
        faucet(token, address(d3MM), amount);
        d3MM.lpDeposit(lp, token);
    }

    // add weth into d3mm
    function addWethInD3() public {
        vm.prank(poolCreator);
        d3MM.addNewToken(address(weth), 30 * 1e16, 10000 ether);

        vm.deal(poolCreator, 30 ether);
        vm.startPrank(poolCreator);
        weth.deposit{value: 30 ether}();
        weth.transfer(address(d3MM), 30 ether);
        vm.stopPrank();
        d3MM.ownerDeposit(address(weth));

        vm.deal(poolCreator, 60 ether);
        vm.startPrank(poolCreator);
        weth.deposit{value: 30 ether}();
        weth.transfer(address(d3MM), 30 ether);
        vm.stopPrank();
        d3MM.lpDeposit(user1, address(weth));

        // maker set
        Types.TokenMMInfo memory token2Info = constructDefaultToken2Info();
        vm.prank(poolCreator);
        d3MM.setNewToken(
            address(weth),
            false,
            token2Info.priceInfo,
            token2Info.amountInfo,
            token2Info.kAsk,
            token2Info.kBid
        );
    }

    // add weth into d3mm
    function addToken4InD3() public {
        oracle.setPriceSource(
            address(token4),
            PriceSource(
                address(token4ChainLinkOracle),
                true,
                5 * (10**17),
                18,
                18
            )
        );

        vm.prank(poolCreator);
        d3MM.addNewToken(address(token4), 30 * 1e16, 10000 ether);

        faucet(address(token4), address(d3MM), 30 ether);
        d3MM.ownerDeposit(address(token4));
        faucet(address(token4), address(d3MM), 10 ether);
        d3MM.lpDeposit(user1, address(token4));

        // maker set
        Types.TokenMMInfo memory token2Info = constructDefaultToken2Info();
        vm.prank(poolCreator);
        d3MM.setNewToken(
            address(token4),
            true,
            token2Info.priceInfo,
            token2Info.amountInfo,
            token2Info.kAsk,
            token2Info.kBid
        );
    }

    function resetTokenList() public {
        if (tokens.length == 3) {
            tokens[0] = address(token1);
            tokens[1] = address(token2);
            tokens[2] = address(token3);
        } else if (tokens.length == 0) {
            tokens.push(address(token1));
            tokens.push(address(token2));
            tokens.push(address(token3));
        }
    }

    function liquidateSwap(
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) public {
        Types.LiquidationOrder memory order = Types.LiquidationOrder(
            fromToken,
            toToken,
            fromAmount
        );
        bytes memory realRouteData = abi.encodeWithSignature(
            "swap(address,address,uint256)",
            fromToken,
            toToken,
            fromAmount
        );
        bytes memory routeData = abi.encodeWithSignature(
            "D3Callee((address,address,uint256),address,bytes)",
            order,
            address(router),
            realRouteData
        );
        vm.prank(liquidator);
        d3MM.liquidate(order, routeData, address(liquidationRouter));
        logLiquidationProcessInfo();
    }

    function forceRefundSwap(
        uint256 index,
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) public {
        Types.LiquidationOrder memory order = Types.LiquidationOrder(
            fromToken,
            toToken,
            fromAmount
        );
        bytes memory realRouteData = abi.encodeWithSignature(
            "swap(address,address,uint256)",
            fromToken,
            toToken,
            fromAmount
        );
        bytes memory routeData = abi.encodeWithSignature(
            "D3Callee((address,address,uint256),address,bytes)",
            order,
            address(router),
            realRouteData
        );
        vm.prank(liquidator);
        d3MM.forceRefund(index, order, routeData, address(liquidationRouter));
    }

    function logCollateralRatio() public view {
        console.log(
            "total asset value:",
            d3MM.getTotalAssetsValue() / 1e18,
            "USD"
        );
        console.log(
            "total debt value:",
            d3MM.getTotalDebtValue() / 1e18,
            "USD"
        );
        console.log("collateral ratio:", d3MM.getCollateralRatio() / 1e16, "%");
    }

    function logLiquidationProcessInfo() public view {
        console.log("Tokens\tBalance\tTarget");
        for (uint256 i; i < tokens.length; i++) {
            uint256 balance = MockERC20(tokens[i]).balanceOf(address(d3MM));
            console.log(
                "token%d\t%d\t%d",
                i + 1,
                balance / 1e18,
                d3MM.getLiquidationTarget(tokens[i]) / 1e18
            );
        }
        console.log("----------------------------");
    }

    function logTokensBalance() public view {
        console.log("Tokens\tBalance");
        for (uint256 i; i < tokens.length; i++) {
            uint256 balance = MockERC20(tokens[i]).balanceOf(address(d3MM));
            console.log("token%d\t%d", i + 1, balance / 1e18);
        }
        console.log("----------------------------");
    }

    function logInterestRateAndAccrued() public view {
        console.log("Tokens\trate\taccrued interest");
        for (uint256 i; i < tokens.length; i++) {
            uint256 rate = d3MM.getInterestRate(tokens[i]);
            uint256 accrual = d3MM.getAssetInfo(tokens[i]).accruedInterest;
            console.log(
                "token%d\t%d%%\t%d%%",
                i + 1,
                rate / 1e16,
                accrual / 1e16
            );
        }
        console.log("----------------------------");
    }

    // Make forge coverage ignore
    function testSuccess() public {
        assertEq(true, true);
    }

    function makeMixDataForD3(
        uint256 iM,
        uint256 mM,
        address maintainer,
        address feemodel
    ) public pure returns (bytes memory mixData) {
        mixData = abi.encode(iM, mM, maintainer, feemodel);
    }

    function setDefaultTokenMMInfo() public {
        vm.startPrank(poolCreator);
        Types.TokenMMInfo memory token1Info = constructDefaultToken1Info();
        d3MM.setNewToken(
            address(token1),
            true,
            token1Info.priceInfo,
            token1Info.amountInfo,
            token1Info.kAsk,
            token1Info.kBid
        );

        Types.TokenMMInfo memory token2Info = constructDefaultToken2Info();
        d3MM.setNewToken(
            address(token2),
            false,
            token2Info.priceInfo,
            token2Info.amountInfo,
            token2Info.kAsk,
            token2Info.kBid
        );

        Types.TokenMMInfo memory token3Info = constructDefaultToken3Info();
        d3MM.setNewToken(
            address(token3),
            false,
            token3Info.priceInfo,
            token3Info.amountInfo,
            token3Info.kAsk,
            token3Info.kBid
        );
        vm.stopPrank();
    }

    function stickOneSlot(
        uint256 numberA,
        uint256 numberADecimal,
        uint256 numberB,
        uint256 numberBDecimal
    ) public pure returns (uint256 numberSet) {
        numberSet =
            (numberA << 32) +
            (numberADecimal << 24) +
            (numberB << 8) +
            numberBDecimal;
    }

    function stickAmount(
        uint256 askAmount,
        uint256 askAmountDecimal,
        uint256 bidAmount,
        uint256 bidAmountDecimal
    ) public pure returns (uint64 amountSet) {
        amountSet = uint64(
            stickOneSlot(
                askAmount,
                askAmountDecimal,
                bidAmount,
                bidAmountDecimal
            )
        );
    }

    function reStickPrice(uint256 oriPriceSet)
        public
        pure
        returns (uint256 newPriceSet)
    {
        uint256 downPrice = oriPriceSet >> 32;
        uint256 downPriceDecimal = (oriPriceSet >> 24) & 255;
        uint256 upPrice = (oriPriceSet >> 8) & 0xffff;
        uint256 upPriceDecimal = oriPriceSet & 255;
        uint256 priceOffset;

        if (upPriceDecimal > downPriceDecimal) {
            priceOffset =
                upPrice *
                (10**(upPriceDecimal - downPriceDecimal)) -
                downPrice;
        } else {
            priceOffset = upPrice - downPrice;
        }

        //console.log(downPrice);
        //console.log(priceOffset);
        //console.log(downPriceDecimal);
        newPriceSet = (downPrice << 24) + (priceOffset << 8) + downPriceDecimal;
    }

    function stickPrice(uint256 askPriceAll, uint256 bidPriceAll)
        public
        pure
        returns (uint96 priceSet)
    {
        priceSet = uint96(
            (reStickPrice(askPriceAll) << 40) + reStickPrice(bidPriceAll)
        );
    }

    function stickKs(uint256 kAsk, uint256 kBid)
        public
        pure
        returns (uint32 kSet)
    {
        kSet = uint32((kAsk << 16) + kBid);
    }

    // price = 12
    function constructDefaultToken2Info()
        public
        pure
        returns (Types.TokenMMInfo memory token2Info)
    {
        Types.TokenMMInfo memory toTokenInfo;
        toTokenInfo.priceInfo = stickPrice(
            stickOneSlot(115, 17, 126, 17),
            stickOneSlot(806, 14, 884, 14)
        ); // stickOneSlot(806, 14, 884, 14)  stickOneSlot(115, 17, 126, 17)
        toTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        toTokenInfo.kAsk = 1000;
        toTokenInfo.kBid = 1000;
        toTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        toTokenInfo.cumulativeAsk = 4 ether;
        toTokenInfo.cumulativeBid = 4 ether;

        token2Info = toTokenInfo;
    }

    // price = 1
    function constructDefaultToken3Info()
        public
        pure
        returns (Types.TokenMMInfo memory token3Info)
    {
        Types.TokenMMInfo memory fromTokenInfo;
        fromTokenInfo.priceInfo = stickPrice(
            stickOneSlot(956, 15, 105, 16),
            stickOneSlot(953, 15, 102, 16)
        );
        fromTokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        fromTokenInfo.kAsk = 1000;
        fromTokenInfo.kBid = 1000;
        fromTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        fromTokenInfo.cumulativeAsk = 4 ether;
        fromTokenInfo.cumulativeBid = 4 ether;

        token3Info = fromTokenInfo;
    }

    // price = 1300
    function constructDefaultToken1Info()
        public
        pure
        returns (Types.TokenMMInfo memory token1Info)
    {
        Types.TokenMMInfo memory toTokenInfo;
        toTokenInfo.priceInfo = stickPrice(
            stickOneSlot(1296, 18, 1305, 18),
            stickOneSlot(766, 12, 773, 12)
        ); // stickOneSlot(806, 14, 884, 14)  stickOneSlot(115, 17, 126, 17)
        toTokenInfo.amountInfo = stickAmount(30, 8, 30, 8);
        toTokenInfo.kAsk = 1000;
        toTokenInfo.kBid = 1000;
        toTokenInfo.updateTimestamp = 1; // updateTimestamp = 0
        toTokenInfo.cumulativeAsk = 4 ether;
        toTokenInfo.cumulativeBid = 4 ether;

        token1Info = toTokenInfo;
    }
}
