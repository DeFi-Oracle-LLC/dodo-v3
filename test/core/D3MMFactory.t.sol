/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "../Context.t.sol";

contract D3MMFactoryTest is Context {
    function setUp() public {
        createD3MMFactory();
    }

    function testSetD3Logic() public {
        d3Factory.setD3Logic(address(2));
        assertEq(d3Factory._D3_LOGIC_(), address(2));
    }

    function testSetCloneFactory() public {
        d3Factory.setCloneFactory(address(2));
        assertEq(d3Factory._CLONE_FACTORY_(), address(2));
    }

    function testSetOracle() public {
        d3Factory.setOracle(address(2));
        assertEq(d3Factory._ORACLE_(), address(2));
    }

    function testAddD3() public {
        createD3MM();
        assertEq(d3Factory.getPoolsOfCreator(poolCreator)[0], address(d3MM));
        assertEq(d3Factory.getPools()[0], address(d3MM));
    }

    function testRemoveD3() public {
        createD3MM();
        d3Factory.removeD3(address(d3MM));
        assertEq(d3Factory.getPoolsOfCreator(poolCreator).length, 0);
        assertEq(d3Factory.getPools().length, 0);

        createD3MM();
        address d3MM2 = d3Factory.breedDODO(
            poolCreator, // market maker account
            tokens, // token list
            1 days, // epoch start time
            7 days, // epoch duration
            4e17, // IM
            2e17 // MM
        );

        d3Factory.removeD3(d3MM2);
        assertEq(d3Factory.getPoolsOfCreator(poolCreator).length, 1);
        assertEq(d3Factory.getPools().length, 1);
    }

    function testRemoveLiquidator() public {
        assertEq(d3Factory._LIQUIDATOR_WHITELIST_(liquidator), true);
        d3Factory.removeLiquidator(liquidator);
        assertEq(d3Factory._LIQUIDATOR_WHITELIST_(liquidator), false);
    }

    function testRemoveRouter() public {
        address routerAddress = address(liquidationRouter);
        assertEq(d3Factory._ROUTER_WHITELIST_(routerAddress), true);
        d3Factory.removeRouter(routerAddress);
        assertEq(d3Factory._ROUTER_WHITELIST_(routerAddress), false);
    }

    function testBreedDODOWrongParamters() public {
        resetTokenList();
        vm.expectRevert(bytes(Errors.INVALID_EPOCH_STARTTIME));
        d3Factory.breedDODO(
            poolCreator,
            tokens,
            1 days, // epoch start time
            7 days, // epoch duration
            4e17, // IM
            2e17 // MM
        );
        tokens[2] = address(1);
        vm.warp(2 days);
        vm.expectRevert(bytes(Errors.TOKEN_NOT_ON_WHITELIST));
        d3Factory.breedDODO(
            poolCreator,
            tokens,
            1 days, // epoch start time
            7 days, // epoch duration
            4e17, // IM
            2e17 // MM
        );
    }
}
