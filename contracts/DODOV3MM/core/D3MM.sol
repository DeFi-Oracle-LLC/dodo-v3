// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {D3Liquidation} from "core/D3Liquidation.sol";
import {D3Funding, Types, Errors} from "core/D3Funding.sol";
import {D3Trading} from "core/D3Trading.sol";
import {D3Maker} from "core/D3Maker.sol";

contract D3MM is D3Funding, D3Liquidation, D3Trading, D3Maker {
    /// @notice init D3MM pool
    /// @param creator the pool creator address
    /// @param factory the D3MMFactory contract address
    /// @param oracle the oracle address
    /// @param epochStartTime the epoch start timestamp
    /// @param epochDuration the epoch duration
    /// @param tokens token list
    /// @param d3Tokens token list's corresponding d3Token list
    /// @param mixData other initialization data, including IM, MM, maintainer address, feeModel contract address
    function init(
        address creator,
        address factory,
        address oracle,
        uint256 epochStartTime,
        uint256 epochDuration,
        address[] calldata tokens,
        address[] calldata d3Tokens,
        bytes calldata mixData
    ) external {
        require(epochDuration >= 1 days && epochDuration <= 30 days, Errors.WRONG_EPOCH_DURATION);
        require(tokens.length == d3Tokens.length, Errors.ARRAY_NOT_MATCH);
        initOwner(creator);
        state._CREATOR_ = creator;
        state._D3_FACTORY_ = factory;
        state._ORACLE_ = oracle;
        state.tokenList = tokens;
        state._EPOCH_START_TIME_ = epochStartTime;
        state._EPOCH_DURATION_ = epochDuration;
        (
            state._INITIAL_MARGIN_RATIO_, 
            state._MAINTENANCE_MARGIN_RATIO_, 
            state._MAINTAINER_, 
            state._MT_FEE_RATE_MODEL_
        ) = abi.decode(mixData, (uint256, uint256, address, address)); // IM, MM, maintainer,feeModel
        require(state._MAINTENANCE_MARGIN_RATIO_ < Types.ONE && state._MAINTENANCE_MARGIN_RATIO_ > 0, Errors.WRONG_MM_RATIO);
        require(state._INITIAL_MARGIN_RATIO_ < Types.ONE && state._INITIAL_MARGIN_RATIO_ > state._MAINTENANCE_MARGIN_RATIO_, Errors.WRONG_IM_RATIO);
        for (uint256 i; i < tokens.length; i++) {
            state.assetInfo[tokens[i]].d3Token = d3Tokens[i];
            state.assetInfo[tokens[i]].accruedInterest = Types.ONE;
        }
    }

    // ============= View =================
    /// @notice return the pool creator address
    /// @dev we can use creator as key to query pools from D3MMFactory's pool registry
    function getCreator() external view returns (address) {
        return state._CREATOR_;
    }

    /// @notice get basic pool info
    function getD3MMInfo()
        external
        view
        returns (
            address creator,
            address oracle,
            uint256 epochStartTime,
            uint256 epochDuration,
            uint256 accrualTimestamp,
            uint256 IM,
            uint256 MM
        )
    {
        creator = state._CREATOR_;
        oracle = state._ORACLE_;
        epochStartTime = state._EPOCH_START_TIME_;
        epochDuration = state._EPOCH_DURATION_;
        accrualTimestamp = state.accrualTimestamp;
        IM = state._INITIAL_MARGIN_RATIO_;
        MM = state._MAINTENANCE_MARGIN_RATIO_;
    }

    /// @notice get a token's reserve in pool
    function getTokenReserve(address token) external view returns (uint256) {
        return state.assetInfo[token].reserve;
    }

    /// @notice get pool status
    function getStatus() external view returns (Types.PoolStatus) {
        return state._POOL_STATUS_;
    }

    /// @notice get liquidation target for a token
    function getLiquidationTarget(address token) external view returns (uint256) {
        return state.liquidationTarget[token];
    }

    /// @notice get all pending withdraw requests
    function getPendingWithdrawList() external view returns (Types.WithdrawInfo[] memory) {
        return state.pendingWithdrawList;
    }

    /// @notice get asset info
    function getAssetInfo(address token) external view returns (Types.AssetInfo memory) {
        return state.assetInfo[token];
    }

    /// @notice get withdrawl info at specific index
    function getWithdrawInfo(uint256 index) external view returns (Types.WithdrawInfo memory) {
        return state.pendingWithdrawList[index];
    }

    /// @notice get UserQuota contract address
    function getUserQuota() external view returns (address) {
        return state._USER_QUOTA_;
    }

    /// @notice get a list of tokens in pool
    function getTokenList() external view returns (address[] memory) {
        return state.tokenList;
    }

    /// @notice get interest rate for token
    function getInterestRate(address token) external view returns (uint256) {
        return state.interestRate[token];
    }

    /// @notice get next epoch start time and interest rate
    /// @param token the token we want to query for next interest rate
    function getNextEpoch(address token) external view returns (uint256 timestamp, uint256 interestRate) {
        timestamp = state.nextEpoch.timestamp;
        interestRate = state.nextEpoch.interestRate[token];
    }

    /// @notice get the owner left balance after pool closed
    /// @param token the token we want to query
    function getOwnerLeftBalance(address token) external view returns (uint256) {
        return state.ownerBalanceAfterPoolEnd[token];
    }

    /// @notice get D3MM contract version
    function version() external pure virtual returns (string memory) {
        return "D3MM 1.0.0";
    }
}
