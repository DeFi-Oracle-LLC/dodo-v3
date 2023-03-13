// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {ID3Factory} from "intf/ID3Factory.sol";
import "lib/LiquidationLibrary.sol";
import "./D3Funding.sol";

/**
 * @author  DODO
 * @title   D3Liquidation
 * @dev     To save contract size, most of the function implements are moved to LiquidationLibrary.
 * @notice  This contract manages pool liquidation and force refund.
 */

contract D3Liquidation is D3Funding {
    modifier onlyLiquidator() {
        require(ID3Factory(state._D3_FACTORY_)._LIQUIDATOR_WHITELIST_(msg.sender), Errors.NOT_ALLOWED_LIQUIDATOR);
        _;
    }

    modifier onlyRouter(address router) {
        require(ID3Factory(state._D3_FACTORY_)._ROUTER_WHITELIST_(router), Errors.NOT_ALLOWED_ROUTER);
        _;
    }

    // =========== Liquidation ===========
    /*
        1. calculate total asset value: A
        2. calculate total debt value: D
        3. calculate ratio: R = A / D
        4. if R > 1, for each token, calculate delta = (balance - debt), 
           if delta > 0, means we need sell this token, 
           if delta < 0, means we need to buy this token
        5. if R < 1, debt = debt * R, then calculate delta = (balance - debt)
        6. the delta array is like [100, -50, 200, -100], 
           the swapping goal is to make this array contains only positve (zero included) or only negative number (zero included)
        7. based on the new balance and debt, calculate the amounts each LP and owner can withdraw
    */

    /// @notice If collateral ratio is less than MM, liquiator can trigger liquidation
    function startLiquidation() external onlyLiquidator poolOngoing {
        LiquidationLibrary.startLiquidation(state);
    }

    /// @notice Liquidator pass in route data to swap tokens for liquidation.
    /// @dev This function can be called multiple times if liquidation not finished
    /// @param order the swap infomation
    /// @param routeData the swap route data
    /// @param router the route contract which will swap tokens
    function liquidate(
        Types.LiquidationOrder calldata order,
        bytes calldata routeData,
        address router
    ) external nonReentrant onlyLiquidator onlyRouter(router) poolLiquidating {
        LiquidationLibrary.liquidate(order, routeData, router, state);
    }

    /// @notice Liquidator call this function to finish liquidation
    /// @dev The goal is to make all tokens' balance be larger than target amount,
    /// @dev or all tokens' balance be smaller than target amount
    function finishLiquidation() external onlyLiquidator poolLiquidating {
        LiquidationLibrary.finishLiquidation(state);
    }

    /// @notice If owner hasn't refund LP after deadline, liquidator can call this to force refund.
    /// @dev call be called multiple times if withdrawal amount not fully paid
    /// @param index the withdraw request's index in pending request list
    /// @param order the swap infomation
    /// @param routeData the swap route data
    /// @param router the route contract which will swap tokens
    function forceRefund(
        uint256 index,
        Types.LiquidationOrder calldata order,
        bytes calldata routeData,
        address router
    ) external onlyLiquidator onlyRouter(router) poolOngoing {
        LiquidationLibrary.forceRefund(index, order, routeData, router, state);
    }
}
