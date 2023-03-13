/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "periphery/UserQuotaV3.sol";

contract UserQuotaV3Test is Test {
    UserQuotaV3 public userQuota;
    address public token1 = address(1111);
    address public token2 = address(2222);
    address public user1 = address(1);
    address public user2 = address(2);
    address[] public userList;
    uint256[] public quotaList;

    function setUp() public {
        userQuota = new UserQuotaV3();
        userList.push(user1);
        userList.push(user2);
        quotaList.push(200);
        quotaList.push(300);
    }

    // case 1. quota not enabled: unlimited amount
    function testQuotaNotEnabled() public {
        assertEq(userQuota.getUserQuota(user1, token1), type(uint256).max);
    }

    // case 2. quota enabled: 0 amount
    function testQuotaEnabled() public {
        userQuota.enableQuota(token1, true);
        assertEq(userQuota.getUserQuota(user1, token1), 0);  
    }

    // case 3. quota enabled, and quota is set
    function testQuotaSet() public {
        userQuota.enableQuota(token1, true);
        userQuota.setUserQuota(token1, userList, quotaList);
        assertEq(userQuota.getUserQuota(user1, token1), 200);  
    }

    // case 4. quota enabled, global and quota both set
    function testGlobalQuota() public {
        userQuota.enableQuota(token1, true);
        userQuota.setUserQuota(token1, userList, quotaList);
        userQuota.enableGlobalQuota(token1, true);
        assertEq(userQuota.getUserQuota(user1, token1), 0);  

        userQuota.setGlobalQuota(token1, 1000);
        assertEq(userQuota.getUserQuota(user1, token1), 1000);  
    }
}