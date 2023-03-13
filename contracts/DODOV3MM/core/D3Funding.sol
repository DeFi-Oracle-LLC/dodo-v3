// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ID3Oracle} from "intf/ID3Oracle.sol";
import {ID3Token} from "intf/ID3Token.sol";
import {DecimalMath} from "lib/DecimalMath.sol";
import {FundingLibrary} from "lib/FundingLibrary.sol";
import "./D3MMStorage.sol";

/**
 * @author  DODO
 * @title   D3Funding
 * @dev     To save contract size, most of the function implements are moved to FundingLibrary.
 * @notice  This contract manages LP deposit/withdraw, owner deposit/withdraw.
 */

contract D3Funding is D3Storage {
    modifier poolOngoing() {
        require(state._POOL_STATUS_ == Types.PoolStatus.Ongoing, Errors.POOL_NOT_ONGOING);
        _;
    }

    modifier poolLiquidating() {
        require(state._POOL_STATUS_ == Types.PoolStatus.Liquidating, Errors.POOL_NOT_LIQUIDATING);
        _;
    }

    modifier poolEnd() {
        require(state._POOL_STATUS_ == Types.PoolStatus.End, Errors.POOL_NOT_END);
        _;
    }

    modifier tokenExist(address token) {
        require(state.assetInfo[token].d3Token != address(0), Errors.TOKEN_NOT_EXIST);
        _;
    }

    modifier tokenNotExist(address token) {
        require(state.assetInfo[token].d3Token == address(0), Errors.TOKEN_ALREADY_EXIST);
        _;
    }

    /// @notice Return current epoch number
    /// @return epoch the current epoch number
    function currentEpoch() external view returns (uint256 epoch) {
        epoch = (block.timestamp - state._EPOCH_START_TIME_) / state._EPOCH_DURATION_;
    }

    /// @notice Return the total USD value of the tokens in pool
    /// @return totalValue the total asset value in USD
    function getTotalAssetsValue() external view returns (uint256 totalValue) {
        totalValue = FundingLibrary.getTotalAssetsValue(state);
    }

    /// @notice Return the total USD value of the debts
    /// @return totalDebt the total debt value in USD
    function getTotalDebtValue() external view returns (uint256 totalDebt) {
        totalDebt = FundingLibrary.getTotalDebtValue(state);
    }

    /// @notice Return the collateral ratio
    /// @dev if totalAsset >= totalDebt, collateral ratio = (totalAsset - totalDebt) / totalAsset
    /// @dev if totalAsset < totalDebt, collateral ratio = 0
    /// @return collateralRatio the current collateral ratio
    function getCollateralRatio() public view returns (uint256 collateralRatio) {
        uint256 totalValue;
        uint256 totalDebt;
        uint256 timeDelta = block.timestamp - state.accrualTimestamp;
        for (uint8 i = 0; i < state.tokenList.length; i++) {
            address token = state.tokenList[i];
            uint256 interestRate = state.interestRate[token];
            uint256 price = ID3Oracle(state._ORACLE_).getPrice(token);
            totalValue += DecimalMath.mul(IERC20(token).balanceOf(address(this)), price);
            totalDebt += DecimalMath.mul(
                DecimalMath.mul(
                    ID3Token(state.assetInfo[token].d3Token).totalSupply(),
                    state.assetInfo[token].accruedInterest + (timeDelta * interestRate) / Types.SECONDS_PER_YEAR
                ),
                price
            );
        }
        if (totalValue <= totalDebt) {
            collateralRatio = 0;
        } else {
            collateralRatio = Types.ONE - DecimalMath.div(totalDebt, totalValue);
        }
    }

    // =========== LP Functions ==========

    /// @notice When LPs deposit token, they will receive the corresponding d3Token.
    /// @param lp the LP account address
    /// @param token the token address
    function lpDeposit(address lp, address token) external nonReentrant poolOngoing tokenExist(token) {
        FundingLibrary.lpDeposit(lp, token, state);
    }

    /// @notice LP can submit a withdraw request by locking some amount of the corresponding dToken.
    /// @dev The locked d3Token will still generate interest during withdraw pending time.
    /// @param token the token LP wants to withdraw
    /// @param d3TokenAmount the amount of d3Token going to lock
    function lpRequestWithdraw(
        address token,
        uint256 d3TokenAmount
    ) external nonReentrant poolOngoing tokenExist(token) {
        FundingLibrary.lpRequestWithdraw(msg.sender, token, d3TokenAmount, state);
    }

    /// @notice LPs can withdraw their tokens after pool is closed, either by liquidation or pool owner.
    /// @notice LPs can get their tokens back immediately, whether or not they have pending withdraw request before pool closed.
    /// @notice If pool is closed by liquidation, under some extreme conditions, the total pool assets value might be less than total debts,
    /// @notice which means LP will suffer a loss. The returned token amount might be less than the deposit amount.
    /// @dev After pool closed, all tokens' interest rates are set to 0, and will no longer call `function accrueInterests()` to accrue interests.
    /// @param lp the LP account address
    /// @param token the token requested to withdraw
    function lpWithdrawAfterPoolEnd(address lp, address token) external nonReentrant poolEnd tokenExist(token) {
        FundingLibrary.lpWithdrawAfterPoolEnd(lp, token, state);
    }

    // =========== Pool Owner Functions ==========

    /// @notice Owner set max heartbeat interval
    /// @param interval the max heartbeat interval
    function setBeatInterval(uint256 interval) external onlyOwner {
        state.heartBeat.maxInterval = interval;
    }

    /// @notice Owner can set a UserQuota contract to limit LP deposit amount
    function setUserQuota(address userQuota) external onlyOwner {
        state._USER_QUOTA_ = userQuota;
        emit SetUserQuota(userQuota);
    }

    /// @notice Owner add a new token
    /// @param token the token address
    /// @param interestRate the token interestRate
    /// @param maxDepositAmount the max deposit amount for the token
    function addNewToken(
        address token,
        uint256 interestRate,
        uint256 maxDepositAmount
    ) external onlyOwner poolOngoing tokenNotExist(token) {
        FundingLibrary.addNewToken(token, interestRate, maxDepositAmount, state);
    }

    /// @notice Owner set max deposit amount for a token
    /// @param token the token address
    /// @param maxDepositAmount the max deposit amount for the token
    function setMaxDeposit(address token, uint256 maxDepositAmount) external onlyOwner poolOngoing tokenExist(token) {
        state.assetInfo[token].maxDepositAmount = maxDepositAmount;
        emit SetMaxDeposit(token, maxDepositAmount);
    }

    /// @notice Owner set new interest rate for next epoch.
    /// @param tokenList an array of tokens going to be updated
    /// @param interestRates an array of new interest rates
    function setNextEpoch(
        address[] calldata tokenList,
        uint256[] calldata interestRates
    ) external poolOngoing onlyOwner {
        FundingLibrary.setNextEpoch(tokenList, interestRates, state);
    }

    /// @notice The new interest rates will only be effective by calling this function
    function executeEpochUpdate() external poolOngoing {
        FundingLibrary.executeEpochUpdate(state);
    }

    /// @notice Owner refund LP. The LP must have submit a withdraw request before.
    /// @param index the index of the withdraw request in the pending request list
    function refund(uint256 index) external onlyOwner nonReentrant poolOngoing {
        FundingLibrary.refund(index, state);
    }

    /// @notice Owner deposit token
    /// @param token the token going to be deposited
    function ownerDeposit(address token) external poolOngoing tokenExist(token) {
        emit OwnerDeposit(token, IERC20(token).balanceOf(address(this)) - state.assetInfo[token].reserve);
        updateReserve(token);
    }

    /// @notice Owner withdraw token
    /// @param to the address where token will be tranferred to
    /// @param token the token address
    /// @param amount the amount going to be withdrawn
    function ownerWithdraw(
        address to,
        address token,
        uint256 amount
    ) external onlyOwner nonReentrant poolOngoing tokenExist(token) {
        FundingLibrary.ownerWithdraw(to, token, amount, state);
    }

    /// @notice Owner withdraw assets after pool is closed
    /// @param to the address where token will be tranferred to
    /// @param token the token address
    /// @param amount the amount going to be withdrawn
    function ownerWithdrawAfterPoolEnd(
        address to,
        address token,
        uint256 amount
    ) external onlyOwner nonReentrant poolEnd tokenExist(token) {
        FundingLibrary.ownerWithdrawAfterPoolEnd(to, token, amount, state);
    }

    /// @notice Owner cannot close pool if pool is under liquidating process
    function ownerClosePool() external onlyOwner poolOngoing {
        FundingLibrary.ownerClosePool(state);
    }

    // =========== Pool Status ===========

    /// @notice update token reserve
    /// @param token the token address
    function updateReserve(address token) internal returns (uint256 balance) {
        balance = IERC20(token).balanceOf(address(this));
        state.assetInfo[token].reserve = balance;
    }
}
