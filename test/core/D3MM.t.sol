/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "../Context.t.sol";

contract D3MMTest is Context {
    address[] public tokenList;
    address[] public d3TokenList;

    function setUp() public {
        contextBasic();
    }

    function testInit() public {
        tokenList.push(address(4));
        d3TokenList.push(address(5));
        {
            // epoch duration >= 1 day && epoch duration <= 1 month
            d3MM = new D3MM();
            bytes memory mixData = abi.encode(1, 2, poolCreator, address(feeRate));
            vm.expectRevert(bytes(Errors.WRONG_EPOCH_DURATION));
            d3MM.init(address(1), address(2), address(3), 1, 1 days - 1, tokenList, d3TokenList, mixData);//1, 2, poolCreator, address(feeRate));

            d3MM = new D3MM();
            mixData = abi.encode(1, 2, poolCreator, address(feeRate));
            vm.expectRevert(bytes(Errors.WRONG_EPOCH_DURATION));
            d3MM.init(address(1), address(2), address(3), 1, 30 days + 1, tokenList, d3TokenList, mixData);//1, 2, poolCreator, address(feeRate));
        }

        {
            // MM < 1e18 && MM > 0
            d3MM = new D3MM();
            bytes memory mixData = abi.encode( 1, 1e18, poolCreator, address(feeRate));
            vm.expectRevert(bytes(Errors.WRONG_MM_RATIO));
            d3MM.init(address(1), address(2), address(3), 1, 1 days, tokenList, d3TokenList, mixData);//1, 1e18, poolCreator, address(feeRate));

            d3MM = new D3MM();
            mixData = abi.encode( 1, 0, poolCreator, address(feeRate));
            vm.expectRevert(bytes(Errors.WRONG_MM_RATIO));
            d3MM.init(address(1), address(2), address(3), 1, 1 days, tokenList, d3TokenList, mixData);//1, 0, poolCreator, address(feeRate));
        }

        {
            // IM < 1e18 && IM > MM
            d3MM = new D3MM();
            bytes memory mixData = abi.encode(1e18, 2e17, poolCreator, address(feeRate));
            vm.expectRevert(bytes(Errors.WRONG_IM_RATIO));
            d3MM.init(address(1), address(2), address(3), 1, 1 days, tokenList, d3TokenList, mixData); //1e18, 2e17, poolCreator, address(feeRate));

            d3MM = new D3MM();
            mixData = abi.encode(1e17, 2e17, poolCreator, address(feeRate));
            vm.expectRevert(bytes(Errors.WRONG_IM_RATIO));
            d3MM.init(address(1), address(2), address(3), 1, 1 days, tokenList, d3TokenList, mixData);//1e17, 2e17, poolCreator, address(feeRate));
        }

        {
            // tokenList must have same length with dTokenList
            d3MM = new D3MM();
            tokenList.push(address(6));
            bytes memory mixData = abi.encode(4e17, 2e17, poolCreator, address(feeRate));
            vm.expectRevert(bytes(Errors.ARRAY_NOT_MATCH));
            d3MM.init(address(1), address(2), address(3), 1, 1 days, tokenList, d3TokenList, mixData);//4e17, 2e17, poolCreator, address(feeRate));
        }

        {
            // all parameter correct
            d3MM = new D3MM();
            tokenList.pop();
            bytes memory mixData = abi.encode(4e17, 2e17, poolCreator, address(feeRate));
            d3MM.init(address(1), address(2), address(3), 1, 1 days, tokenList, d3TokenList, mixData);
        }
        
    }

    function testGetD3MMInfo() public {
        (
            address _creator,
            address _oracle,
            uint256 _epochStartTime,
            uint256 _epochDuration,
            ,
            uint256 IM,
            uint256 MM
        ) = d3MM.getD3MMInfo();
        assertEq(_creator, poolCreator);
        assertEq(_oracle, address(oracle));
        assertEq(_epochStartTime, 1 days);
        assertEq(_epochDuration, 7 days);
        assertEq(IM, 4e17);
        assertEq(MM, 2e17);
    }

    function testGetCreator() public {
        assertEq(d3MM.getCreator(), poolCreator);
    }

    function testGetTokenReserve() public {
        assertEq(d3MM.getTokenReserve(address(token1)), 0);
        ownerDeposit(address(token1), 1000);
        assertEq(d3MM.getTokenReserve(address(token1)), 1000);
    }

    function testGetNextEpochInfo() public {
        contextPoolOngoing();
        (, uint256 rate) = d3MM.getNextEpoch(address(token1));
        assertEq(rate, 4e17);
    }

    function testGetWithdrawInfo() public {
        contextPoolOngoing();
        vm.prank(user1);
        d3MM.lpRequestWithdraw(address(token1), 1000 * 1e8);
        Types.WithdrawInfo memory info = d3MM.getWithdrawInfo(0);
        assertEq(info.user, user1);
        assertEq(info.token, address(token1));
        assertEq(info.d3TokenAmount, 1000 * 1e8);
        assertEq(info.deadline, block.timestamp + 86400 * 7);
    }

    function testVersion() public {
        assertEq(d3MM.version(), "D3MM 1.0.0");
    }
}
