// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {InitializableOwnable} from "lib/InitializableOwnable.sol";
import {IUserQuotaV3} from "intf/IUserQuotaV3.sol";

/// @title UserQuotaV3
/// @notice This contract is used to set/get user's quota, i.e., determine the amount of token user can deposit into the pool.
contract UserQuotaV3 is InitializableOwnable, IUserQuotaV3 {
    // token => bool
    mapping(address => bool) public isUsingQuota;
    // token => bool
    mapping(address => bool) public isGlobalQuota;
    // token => quota
    mapping(address => uint256) public gloablQuota;
    // token => (user => quota)
    mapping(address => mapping(address => uint256)) public userQuota;

    constructor() {
        initOwner(msg.sender);
    }

    /// @notice Set user quota
    /// @param token The token address
    /// @param users The list of user addresses
    /// @param quotas The list of quota corresponding to the user list
    function setUserQuota(address token, address[] calldata users, uint256[] calldata quotas) external onlyOwner {
        require(users.length == quotas.length, "PARAMS_LENGTH_NOT_MATCH");
        for (uint256 i = 0; i < users.length; i++) {
            userQuota[token][users[i]] = quotas[i];
        }
    }

    /// @notice Enable quota for a token
    function enableQuota(address token, bool status) external onlyOwner {
        isUsingQuota[token] = status;
    }

    /// @notice Enable global quota for a token
    function enableGlobalQuota(address token, bool status) external onlyOwner {
        isGlobalQuota[token] = status;
    }

    /// @notice Set global quota for a token
    /// @notice Global quota means every user has the same quota
    function setGlobalQuota(address token, uint256 amount) external onlyOwner {
        gloablQuota[token] = amount;
    }

    /// @notice Get the user quota for a token
    function getUserQuota(address user, address token) external view override returns (uint256) {
        if (isUsingQuota[token]) {
            if (isGlobalQuota[token]) {
                return gloablQuota[token];
            } else {
                return userQuota[token][user];
            }
        } else {
            return type(uint256).max;
        }
    }
}
