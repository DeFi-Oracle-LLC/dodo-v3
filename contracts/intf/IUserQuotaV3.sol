/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

interface IUserQuotaV3 {
    function getUserQuota(address user, address token) external view returns (uint);
}