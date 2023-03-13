// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {ID3MM} from "intf/ID3MM.sol";
import {ID3Token} from "intf/ID3Token.sol";
import {ID3Oracle} from "intf/ID3Oracle.sol";
import {InitializableOwnable} from "lib/InitializableOwnable.sol";
import {ICloneFactory} from "lib/CloneFactory.sol";
import {Errors} from "lib/Errors.sol";

/**
 * @title D3MMFactory
 * @author DODO Breeder
 * @notice This factory contract is used to create/register D3MM pools.
 */
contract D3MMFactory is InitializableOwnable {
    address public _D3_LOGIC_;
    address public _D3TOKEN_LOGIC_;
    address public _CLONE_FACTORY_;
    address public _ORACLE_;
    address public _MAINTAINER_;
    address public _FEE_RATE_MODEL_;

    mapping(address => address[]) internal _POOL_REGISTER_;
    mapping(address => bool) public _LIQUIDATOR_WHITELIST_;
    mapping(address => bool) public _ROUTER_WHITELIST_;
    mapping(address => bool) public _POOL_WHITELIST_;
    address[] internal _POOLS_;

    // ============ Events ============

    event D3Birth(address newD3, address creator);
    event AddLiquidator(address liquidator);
    event RemoveLiquidator(address liquidator);
    event AddRouter(address router);
    event RemoveRouter(address router);
    event AddD3(address d3Pool);
    event RemoveD3(address d3Pool);

    // ============ Constructor Function ============

    constructor(
        address d3Logic,
        address d3TokenLogic,
        address cloneFactory,
        address maintainer,
        address feeModel
    ) {
        _D3_LOGIC_ = d3Logic;
        _D3TOKEN_LOGIC_ = d3TokenLogic;
        _CLONE_FACTORY_ = cloneFactory;
        _FEE_RATE_MODEL_ = feeModel;
        _MAINTAINER_ = maintainer;
        initOwner(msg.sender);
    }

    // ============ Admin Function ============

    /// @notice Set new D3MM template
    function setD3Logic(address d3Logic) external onlyOwner {
        _D3_LOGIC_ = d3Logic;
    }

    /// @notice Set new CloneFactory contract address
    function setCloneFactory(address cloneFactory) external onlyOwner {
        _CLONE_FACTORY_ = cloneFactory;
    }

    /// @notice Set new oracle
    function setOracle(address oracle) external onlyOwner {
        _ORACLE_ = oracle;
    }

    /// @notice Set new pool maintainer account
    function setMaintainer(address maintainer) external onlyOwner {
        _MAINTAINER_ = maintainer;
    }

    /// @notice Set new FeeModel contract address
    function setFeeModel(address feeModel) external onlyOwner {
        _FEE_RATE_MODEL_ = feeModel;
    }

    /// @notice Unregister D3MM pool
    function removeD3(address d3Pool) external onlyOwner {
        address creator = ID3MM(d3Pool).getCreator();
        address[] storage pools = _POOL_REGISTER_[creator];
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i] == d3Pool) {
                pools[i] = pools[pools.length - 1];
                pools.pop();
                break;
            }
        }
        for (uint256 i = 0; i < _POOLS_.length; i++) {
            if (_POOLS_[i] == d3Pool) {
                _POOLS_[i] = _POOLS_[_POOLS_.length - 1];
                _POOLS_.pop();
                break;
            }
        }
        _POOL_WHITELIST_[d3Pool] = false;
        emit RemoveD3(d3Pool);
    }

    /// @notice Register D3MM pool
    function addD3(address d3Pool) public onlyOwner {
        address creator = ID3MM(d3Pool).getCreator();
        _POOL_REGISTER_[creator].push(d3Pool);
        _POOLS_.push(d3Pool);
        _POOL_WHITELIST_[d3Pool] = true;
        emit AddD3(d3Pool);
    }

    /// @notice Add liquidator address to whitelist
    function addLiquidator(address liquidator) external onlyOwner {
        _LIQUIDATOR_WHITELIST_[liquidator] = true;
        emit AddLiquidator(liquidator);
    }

    /// @notice Remove a liquidator address from whitelist
    function removeLiquidator(address liquidator) external onlyOwner {
        _LIQUIDATOR_WHITELIST_[liquidator] = false;
        emit RemoveLiquidator(liquidator);
    }

    /// @notice Add a router address to whitelist
    function addRouter(address router) external onlyOwner {
        _ROUTER_WHITELIST_[router] = true;
        emit AddRouter(router);
    }

    /// @notice Remove a router address from whitelist
    function removeRouter(address router) external onlyOwner {
        _ROUTER_WHITELIST_[router] = false;
        emit RemoveRouter(router);
    }

    // ============ Breed DODO Function ============

    /// @notice Create new D3MM pool, and register it
    /// @param creator The creator who creates the pool, which will be the default owner of the pool
    /// @param tokens The tokens will be listed in the pool
    /// @param epochStartTime The timestamp at which the epoch is started. This start time should be earlier than current time.
    /// @param epochDuration The duration of an epoch
    /// @param IM Initial Margin Ratio
    /// @param MM Maintenance Margin Ratio
    /// @return newPool The address of the newly created pool
    function breedDODO(
        address creator,
        address[] calldata tokens,
        uint256 epochStartTime,
        uint256 epochDuration,
        uint256 IM,
        uint256 MM
    ) external onlyOwner returns (address newPool) {
        require(epochStartTime < block.timestamp, Errors.INVALID_EPOCH_STARTTIME);
        newPool = ICloneFactory(_CLONE_FACTORY_).clone(_D3_LOGIC_);
        address[] memory d3Tokens = new address[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            require(ID3Oracle(_ORACLE_).isFeasible(tokens[i]), Errors.TOKEN_NOT_ON_WHITELIST);
            address d3Token = createDToken(tokens[i], newPool);
            d3Tokens[i] = d3Token;
        }
        bytes memory mixData = abi.encode(
            IM,
            MM,
            _MAINTAINER_,
            _FEE_RATE_MODEL_
        );
        ID3MM(newPool).init(
            creator,
            address(this),
            _ORACLE_,
            epochStartTime,
            epochDuration,
            tokens,
            d3Tokens,
            mixData
        );

        addD3(newPool);
        emit D3Birth(newPool, creator);
        return newPool;
    }

    /// @notice Create D3Token for a pool
    /// @param token The original(underlying) token address
    /// @param pool The pool address
    /// @return The newly created D3Token address
    function createDToken(address token, address pool) public returns (address) {
        address d3Token = ICloneFactory(_CLONE_FACTORY_).clone(_D3TOKEN_LOGIC_);
        ID3Token(d3Token).init(token, pool);
        return d3Token;
    }

    // ============ View Functions ============

    /// @notice Get all the pools created by an account
    /// @param creator The account address of the creator
    /// @return A list of pools
    function getPoolsOfCreator(address creator) external view returns (address[] memory) {
        return _POOL_REGISTER_[creator];
    }

    /// @notice Get all the pools registered in the factory
    /// @return A list of pools
    function getPools() external view returns (address[] memory) {
        return _POOLS_;
    }
}
