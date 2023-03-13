// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

library Errors {
    string public constant NOT_ALLOWED_LIQUIDATOR = "D3MM_NOT_ALLOWED_LIQUIDATOR";
    string public constant NOT_ALLOWED_ROUTER = "D3MM_NOT_ALLOWED_ROUTER";
    string public constant POOL_NOT_ONGOING = "D3MM_POOL_NOT_ONGOING";
    string public constant POOL_NOT_LIQUIDATING = "D3MM_POOL_NOT_LIQUIDATING";
    string public constant POOL_NOT_END = "D3MM_POOL_NOT_END";
    string public constant TOKEN_NOT_EXIST = "D3MM_TOKEN_NOT_EXIST";
    string public constant TOKEN_ALREADY_EXIST = "D3MM_TOKEN_ALREADY_EXIST";
    string public constant EXCEED_DEPOSIT_LIMIT = "D3MM_EXCEED_DEPOSIT_LIMIT";
    string public constant EXCEED_QUOTA = "D3MM_EXCEED_QUOTA";
    string public constant BELOW_IM_RATIO = "D3MM_BELOW_IM_RATIO";
    string public constant TOKEN_NOT_ON_WHITELIST = "D3MM_TOKEN_NOT_ON_WHITELIST";
    string public constant LATE_TO_CHANGE_EPOCH = "D3MM_LATE_TO_CHANGE_EPOCH";
    string public constant POOL_ALREADY_CLOSED = "D3MM_POOL_ALREADY_CLOSED";
    string public constant BALANCE_NOT_ENOUGH = "D3MM_BALANCE_NOT_ENOUGH";
    string public constant TOKEN_IS_OFFLIST = "D3MM_TOKEN_IS_OFFLIST";
    string public constant ABOVE_MM_RATIO = "D3MM_ABOVE_MM_RATIO";
    string public constant WRONG_MM_RATIO = "D3MM_WRONG_MM_RATIO";
    string public constant WRONG_IM_RATIO = "D3MM_WRONG_IM_RATIO";
    string public constant NOT_IN_LIQUIDATING = "D3MM_NOT_IN_LIQUIDATING";
    string public constant NOT_PASS_DEADLINE = "D3MM_NOT_PASS_DEADLINE";
    string public constant DISCOUNT_EXCEED_5 = "D3MM_DISCOUNT_EXCEED_5";
    string public constant MINRES_NOT_ENOUGH = "D3MM_MINRESERVE_NOT_ENOUGH";
    string public constant MAXPAY_NOT_ENOUGH = "D3MM_MAXPAYAMOUNT_NOT_ENOUGH";
    string public constant LIQUIDATION_NOT_DONE = "D3MM_LIQUIDATION_NOT_DONE";
    string public constant ROUTE_FAILED = "D3MM_ROUTE_FAILED";
    string public constant TOKEN_NOT_MATCH = "D3MM_TOKEN_NOT_MATCH";
    string public constant ASK_AMOUNT_EXCEED = "D3MM_ASK_AMOUTN_EXCEED";
    string public constant K_LIMIT = "D3MM_K_LIMIT_ERROR";
    string public constant ARRAY_NOT_MATCH = "D3MM_ARRAY_NOT_MATCH";
    string public constant WRONG_EPOCH_DURATION = "D3MM_WRONG_EPOCH_DURATION";
    string public constant WRONG_EXCUTE_EPOCH_UPDATE_TIME = "D3MM_WRONG_EXCUTE_EPOCH_UPDATE_TIME";
    string public constant INVALID_EPOCH_STARTTIME = "D3MM_INVALID_EPOCH_STARTTIME";
    string public constant PRICE_UP_BELOW_PRICE_DOWN = "D3MM_PRICE_UP_BELOW_PRICE_DOWN";
    string public constant AMOUNT_TOO_SMALL = "D3MM_AMOUNT_TOO_SMALL";
    string public constant FROMAMOUNT_NOT_ENOUGH = "D3MM_FROMAMOUNT_NOT_ENOUGH";
    string public constant HEARTBEAT_CHECK_FAIL = "D3MM_HEARTBEAT_CHECK_FAIL";
    string public constant HAVE_SET_TOKEN_INFO = "D3MM_HAVE_SET_TOKEN_INFO";

    string public constant RO_ORACLE_PROTECTION = "PMMRO_ORACLE_PRICE_PROTECTION";
    string public constant RO_VAULT_RESERVE = "PMMRO_VAULT_RESERVE_NOT_ENOUGH";
    string public constant RO_AMOUNT_ZERO = "PMMRO_AMOUNT_ZERO";
    string public constant RO_PRICE_ZERO = "PMMRO_PRICE_ZERO";
}
