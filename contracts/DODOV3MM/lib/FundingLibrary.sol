// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/Types.sol";
import "lib/Errors.sol";
import "lib/DecimalMath.sol";
import "intf/ID3Token.sol";
import "intf/ID3Oracle.sol";
import "intf/ID3Factory.sol";
import "intf/IUserQuotaV3.sol";
import "./D3Common.sol";

/**
 * @author  DODO
 * @title   FundingLibrary
 * @dev     This contract contains the real code implementations for D3Funding.
 */

library FundingLibrary {
    using SafeERC20 for IERC20;

    event AddNewToken(address indexed token, uint256 interestRate, uint256 maxDepositAmount);
    event SetNextEpoch(uint256 indexed nextEpochStart, address[] tokenList, uint256[] interestRates);
    event ExecuteEpochUpdate();
    event LpDeposit(address indexed lp, address indexed token, uint256 amount);
    event LpRequestWithdrawal(bytes32 indexed requestId, address indexed lp, address indexed token, uint256 d3TokenAmount);
    event RefundWithdrawal(bytes32 indexed requestId, address indexed lp, address indexed token, uint256 amount);
    event Refund(address indexed lp, address indexed token, uint256 amount);
    event OwnerWithdraw(address indexed to, address indexed token, uint256 amount);
    event OwnerClosePool();

    // --------- LP Functions ---------

    /// @notice When LPs deposit token, they will receive the corresponding d3Token.
    /// @param lp the LP account address
    /// @param token the token address
    /// @param state pool state
    function lpDeposit(address lp, address token, Types.D3MMState storage state) external {
        D3Common.accrueInterests(state);
        Types.AssetInfo storage info = state.assetInfo[token];

        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 amount = balance - info.reserve;
        D3Common.updateReserve(token, state);

        uint256 d3TokenAmount = DecimalMath.div(amount, info.accruedInterest);
        ID3Token(info.d3Token).mint(lp, d3TokenAmount);

        if (state._USER_QUOTA_ != address(0)) {
            uint256 quota = IUserQuotaV3(state._USER_QUOTA_).getUserQuota(lp, token);
            uint256 lpBalance = DecimalMath.mul(ID3Token(info.d3Token).balanceOf(lp), info.accruedInterest);
            require(lpBalance <= quota, Errors.EXCEED_QUOTA);
        }

        uint256 totalDeposit = DecimalMath.mul(ID3Token(info.d3Token).totalSupply(), info.accruedInterest);
        require(totalDeposit <= info.maxDepositAmount, Errors.EXCEED_DEPOSIT_LIMIT);

        require(D3Common.getCollateralRatio(state) >= state._INITIAL_MARGIN_RATIO_, Errors.BELOW_IM_RATIO);
        emit LpDeposit(lp, token, amount);
    }

    /// @notice LP can submit a withdraw request by locking some amount of the corresponding dToken.
    /// @dev The locked d3Token will still generate interest during withdraw pending time.
    /// @param token the token LP wants to withdraw
    /// @param d3TokenAmount the amount of d3Token going to lock
    /// @param state pool state
    function lpRequestWithdraw(
        address lp,
        address token,
        uint256 d3TokenAmount,
        Types.D3MMState storage state
    ) external {
        Types.AssetInfo storage info = state.assetInfo[token];
        ID3Token d3Token = ID3Token(info.d3Token);
        uint256 withdrawable = d3Token.balanceOf(lp) - d3Token.lockedOf(lp);
        require(withdrawable >= d3TokenAmount, Errors.BALANCE_NOT_ENOUGH);
        bytes32 requestId = keccak256(abi.encode(lp, block.timestamp + state._EPOCH_DURATION_));
        state.pendingWithdrawList.push(
            Types.WithdrawInfo(requestId, block.timestamp + state._EPOCH_DURATION_, lp, token, d3TokenAmount)
        );
        d3Token.lock(lp, d3TokenAmount);
        emit LpRequestWithdrawal(requestId, lp, token, d3TokenAmount);
    }

    /// @notice LPs can withdraw their tokens after pool is closed, either by liquidation or pool owner.
    /// @notice LPs can get their tokens back immediately, whether or not they have pending withdraw request before pool closed.
    /// @notice If pool is closed by liquidation, under some extreme conditions, the total pool assets value might be less than total debts,
    /// @notice which means LP will suffer a loss. The returned token amount might be less than the deposit amount.
    /// @dev After pool closed, all tokens' interest rates are set to 0, and will no longer call `function accrueInterests()` to accrue interests.
    /// @param token the token requested to withdraw
    /// @param state pool state
    function lpWithdrawAfterPoolEnd(address lp, address token, Types.D3MMState storage state) external {
        Types.AssetInfo storage assetInfo = state.assetInfo[token];
        uint256 d3Balance = ID3Token(assetInfo.d3Token).balanceOf(lp);
        uint256 originBalance = DecimalMath.mul(d3Balance, assetInfo.accruedInterest);
        ID3Token(assetInfo.d3Token).burn(lp, d3Balance);
        IERC20(token).safeTransfer(lp, originBalance);
        emit Refund(lp, token, originBalance);
    }

    // --------- Owner Functions ---------

    /// @notice Owner add a new token
    /// @param token the token address
    /// @param interestRate the token interestRate
    /// @param maxDepositAmount the max deposit amount for the token
    /// @param state pool state
    function addNewToken(
        address token,
        uint256 interestRate,
        uint256 maxDepositAmount,
        Types.D3MMState storage state
    ) external {
        require(ID3Oracle(state._ORACLE_).isFeasible(token), Errors.TOKEN_NOT_ON_WHITELIST);
        address d3Token = ID3Factory(state._D3_FACTORY_).createDToken(token, address(this));
        state.assetInfo[token].d3Token = d3Token;
        state.assetInfo[token].accruedInterest = Types.ONE; // the base accrued interest is 1
        state.assetInfo[token].maxDepositAmount = maxDepositAmount;

        D3Common.accrueInterests(state);
        state.interestRate[token] = interestRate;
        state.nextEpoch.interestRate[token] = interestRate;

        state.tokenList.push(token);
        emit AddNewToken(token, interestRate, maxDepositAmount);
    }

    /// @notice Pool owner set the interest rates for next epoch. The time to next epoch must be larger than half epoch duration.
    /// @param tokenList Tokens to be set.
    /// @param interestRates The interest rates correspond to the token list.
    /// @param state Pool state.
    function setNextEpoch(
        address[] calldata tokenList,
        uint256[] calldata interestRates,
        Types.D3MMState storage state
    ) external {
        uint256 epoch = D3Common.currentEpoch(state);
        uint256 nextEpochStart = state._EPOCH_START_TIME_ + state._EPOCH_DURATION_ * (epoch + 1);
        require(nextEpochStart - block.timestamp > (state._EPOCH_DURATION_ / 2), Errors.LATE_TO_CHANGE_EPOCH); // to set next epoch, the time to next epoch must be larger than half epoch duration
        state.nextEpoch.timestamp = nextEpochStart;
        for (uint8 i = 0; i < tokenList.length; i++) {
            state.nextEpoch.interestRate[tokenList[i]] = interestRates[i];
        }
        emit SetNextEpoch(nextEpochStart, tokenList, interestRates);
    }

    /// @notice Apply new interest rates setting.
    /// @param state  Pool state.
    function executeEpochUpdate(Types.D3MMState storage state) external {
        require(
            block.timestamp >= state.nextEpoch.timestamp && state.nextEpoch.timestamp != 0,
            Errors.WRONG_EXCUTE_EPOCH_UPDATE_TIME
        );
        D3Common.accrueInterests(state);

        for (uint8 i = 0; i < state.tokenList.length; i++) {
            state.interestRate[state.tokenList[i]] = state.nextEpoch.interestRate[state.tokenList[i]];
        }
        emit ExecuteEpochUpdate();
    }

    /// @notice Owner refund LP. The LP must have submit a withdraw request before.
    /// @param index the index of the withdraw request in the pending request list
    /// @param state pool state
    function refund(uint256 index, Types.D3MMState storage state) external {
        D3Common.accrueInterests(state);
        Types.WithdrawInfo storage withdrawInfo = state.pendingWithdrawList[index];
        Types.AssetInfo storage assetInfo = state.assetInfo[withdrawInfo.token];
        uint256 originTokenAmount = DecimalMath.mul(withdrawInfo.d3TokenAmount, assetInfo.accruedInterest);

        ID3Token(assetInfo.d3Token).unlock(withdrawInfo.user, withdrawInfo.d3TokenAmount);
        ID3Token(assetInfo.d3Token).burn(withdrawInfo.user, withdrawInfo.d3TokenAmount);
        IERC20(withdrawInfo.token).safeTransfer(withdrawInfo.user, originTokenAmount);
        D3Common.updateReserve(withdrawInfo.token, state);

        emit RefundWithdrawal(withdrawInfo.requestId, withdrawInfo.user, withdrawInfo.token, originTokenAmount);

        // replace with last withdraw request
        state.pendingWithdrawList[index] = state.pendingWithdrawList[state.pendingWithdrawList.length - 1];
        state.pendingWithdrawList.pop();
    }

    /// @notice Owner withdraw token from pool.
    /// @param to  Asset receiver.
    /// @param token  Token to withdraw.
    /// @param amount  Amount to Withdraw.
    /// @param state  Pool state.
    function ownerWithdraw(address to, address token, uint256 amount, Types.D3MMState storage state) external {
        IERC20(token).safeTransfer(to, amount);
        D3Common.updateReserve(token, state);
        uint256 ratio = D3Common.getCollateralRatio(state);
        require(ratio >= state._INITIAL_MARGIN_RATIO_, Errors.BELOW_IM_RATIO);
        emit OwnerWithdraw(to, token, amount);
    }

    /// @notice Owner withdraw token when pool is end(closed).
    /// @param to Asset receiver.
    /// @param token Token to withdraw.
    /// @param amount Amount to Withdraw.
    /// @param state Pool state.
    function ownerWithdrawAfterPoolEnd(
        address to,
        address token,
        uint256 amount,
        Types.D3MMState storage state
    ) external {
        uint256 balance = state.ownerBalanceAfterPoolEnd[token];
        require(balance >= amount, Errors.BALANCE_NOT_ENOUGH);
        state.ownerBalanceAfterPoolEnd[token] -= amount;
        IERC20(token).safeTransfer(to, amount);
        emit OwnerWithdraw(to, token, amount);
    }

    /// @notice Owner closes pool.
    /// @param state Pool state.
    function ownerClosePool(Types.D3MMState storage state) external {
        D3Common.accrueInterests(state);
        for (uint256 i; i < state.tokenList.length; i++) {
            address token = state.tokenList[i];
            Types.AssetInfo storage info = state.assetInfo[token];
            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 d3TokenSupply = IERC20(info.d3Token).totalSupply();
            uint256 debtAmount = DecimalMath.mul(d3TokenSupply, info.accruedInterest);
            require(balance >= debtAmount, Errors.BALANCE_NOT_ENOUGH);
            state.ownerBalanceAfterPoolEnd[token] = balance - debtAmount;
            state.interestRate[token] = 0;
            info.maxDepositAmount = 0;
        }
        state._POOL_STATUS_ = Types.PoolStatus.End;
        emit OwnerClosePool();
    }

    // ---------- Pool Status ----------

    /// @notice Return the total USD value of the tokens in pool
    /// @param state pool state
    /// @return totalValue the total asset value in USD
    function getTotalAssetsValue(Types.D3MMState storage state) public view returns (uint256 totalValue) {
        return D3Common.getTotalAssetsValue(state);
    }

    /// @notice Return the total USD value of the debts
    /// @param state pool state
    /// @return totalDebt the total debt value in USD
    function getTotalDebtValue(Types.D3MMState storage state) public view returns (uint256 totalDebt) {
        return D3Common.getTotalDebtValue(state);
    }
}
