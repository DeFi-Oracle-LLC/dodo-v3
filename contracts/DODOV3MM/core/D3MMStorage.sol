// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "lib/Types.sol";
import "lib/Errors.sol";
import "lib/InitializableOwnable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract D3Storage is ReentrancyGuard, InitializableOwnable {
    Types.D3MMState internal state;

    // ============= Events ==========
    event SetUserQuota(address indexed userQuota);
    event SetMaxDeposit(address indexed token, uint256 amount);
    event LpDeposit(address indexed lp, address indexed token, uint256 amount);
    event OwnerDeposit(address indexed token, uint256 amount);
    event OwnerWithdraw(address indexed to, address indexed token, uint256 amount);
    // use operatorIndex to distinct different setting, 1 = setNewToken, 2 = setTokensPrice, 3 = setNSPriceSlot,
    // 4 = setStablePriceSlot, 5 = setTokensAmounts, 6 = setTokensKs
    event SetPoolInfo(uint256 indexed operatorIndex);

    // sellOrNot = 0 means sell, 1 means buy.
    event Swap(
        address to,
        address fromToken,
        address toToken,
        uint256 payFromAmount,
        uint256 receiveToAmount,
        uint256 sellOrNot
    );
}
