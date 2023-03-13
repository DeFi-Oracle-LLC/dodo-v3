/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;
pragma experimental ABIEncoderV2;

import {InitializableOwnable} from "lib/InitializableOwnable.sol";

interface IFeeRateImpl {
    function getFeeRate(address pool, address trader) external view returns (uint256);
}

interface IFeeRateModel {
    function getFeeRate(address trader) external view returns (uint256);
}

contract MockFeeRateModel is InitializableOwnable, IFeeRateModel {
    address public feeRateImpl;

    function setFeeProxy(address _feeRateImpl) public onlyOwner {
        feeRateImpl = _feeRateImpl;
    }
    
    function getFeeRate(address trader) external view override returns (uint256) {
        if(feeRateImpl == address(0))
            return 0;
        return IFeeRateImpl(feeRateImpl).getFeeRate(msg.sender,trader);
    }

    function testSucess() public {}
}

contract MockFeeRateImpl is IFeeRateImpl {
    address public feeRateImpl;
    
    function getFeeRate(address /* pool */, address /* trader */) external pure override returns (uint256) {
        return 10**15; // 0.001 = 0.1%
    }

    function testSucess() public {}
}