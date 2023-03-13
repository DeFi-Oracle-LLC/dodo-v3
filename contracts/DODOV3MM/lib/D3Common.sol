// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "lib/Types.sol";
import "lib/Errors.sol";
import "lib/DecimalMath.sol";
import "intf/ID3Token.sol";
import "intf/ID3Oracle.sol";

/**
 * @author  DODO
 * @title   D3Common
 * @dev     This contract contains common code for D3MM.
 */

library D3Common {
    /// @notice update accrued interests
    /// @param state pool state
    function accrueInterests(Types.D3MMState storage state) internal {
        uint256 currentTimestamp = block.timestamp;
        if (currentTimestamp == state.accrualTimestamp) {
            return;
        }

        uint256 timeDelta = currentTimestamp - state.accrualTimestamp;
        for (uint256 i = 0; i < state.tokenList.length; i++) {
            address token = state.tokenList[i];
            uint256 interestRate = state.interestRate[token];
            if (interestRate > 0) {
                state.assetInfo[token].accruedInterest = DecimalMath.mul(
                    state.assetInfo[token].accruedInterest,
                    timeDelta * interestRate / Types.SECONDS_PER_YEAR + Types.ONE
                );
            }
        }

        state.accrualTimestamp = currentTimestamp;
    }

    /// @notice Return the total USD value of the tokens in pool
    /// @param state pool state
    /// @return totalValue the total asset value in USD
    function getTotalAssetsValue(Types.D3MMState storage state) internal view returns (uint256 totalValue) {
        for (uint8 i = 0; i < state.tokenList.length; i++) {
            address token = state.tokenList[i];
            uint256 price = ID3Oracle(state._ORACLE_).getPrice(token);
            totalValue += DecimalMath.mul(IERC20(token).balanceOf(address(this)), price);
        }
    }

    /// @notice Return the total USD value of the debts
    /// @param state pool state
    /// @return totalDebt the total debt value in USD
    function getTotalDebtValue(Types.D3MMState storage state) internal view returns (uint256 totalDebt) {
        uint256 timeDelta = block.timestamp - state.accrualTimestamp;
        for (uint8 i = 0; i < state.tokenList.length; i++) {
            address token = state.tokenList[i];
            uint256 interestRate = state.interestRate[token];
            totalDebt += DecimalMath.mul(
                DecimalMath.mul(
                    ID3Token(state.assetInfo[token].d3Token).totalSupply(),
                    state.assetInfo[token].accruedInterest + (timeDelta * interestRate) / Types.SECONDS_PER_YEAR
                ),
                ID3Oracle(state._ORACLE_).getPrice(token)
            );
        }
    }

    /// @notice Return the collateral ratio
    /// @dev if totalAsset >= totalDebt, collateral ratio = (totalAsset - totalDebt) / totalAsset
    /// @dev if totalAsset < totalDebt, collateral ratio = 0
    /// @param state pool state
    /// @return collateralRatio the current collateral ratio
    function getCollateralRatio(Types.D3MMState storage state) internal view returns (uint256 collateralRatio) {
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

    /// @notice update token reserve
    /// @param token the token address
    /// @param state pool state
    function updateReserve(address token, Types.D3MMState storage state) internal returns (uint256 balance) {
        balance = IERC20(token).balanceOf(address(this));
        state.assetInfo[token].reserve = balance;
    }

    /// @notice Return current epoch number
    /// @param state pool state
    /// @return epoch the current epoch number
    function currentEpoch(Types.D3MMState storage state) internal view returns (uint256 epoch) {
        epoch = (block.timestamp - state._EPOCH_START_TIME_) / state._EPOCH_DURATION_;
    }
}
