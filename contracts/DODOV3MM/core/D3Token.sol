// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "lib/InitializableOwnable.sol";
import "intf/IERC20.sol";

/// @title D3Token
/// @notice When LP deposit token into D3MM pool, they receive certain amount of corresponding D3Token.
/// @notice D3Token acts as an interest bearing LP token.
contract D3Token is InitializableOwnable {
    address public originToken;
    string private _symbol;
    string private _name;

    uint256 public totalSupply;
    mapping(address => uint256) internal balances;
    mapping(address => uint256) internal locked;
    mapping(address => mapping(address => uint256)) internal allowed;

    // ============ Events ============

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event Mint(address indexed user, uint256 value);

    event Burn(address indexed user, uint256 value);

    // ============ Functions ============

    function init(address token, address pool) external {
        initOwner(pool);
        originToken = token;
        _symbol = string.concat("d3", IERC20(token).symbol());
        _name = string.concat(_symbol, "_", addressToShortString(pool));
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function decimals() public view returns (uint8) {
        return IERC20(originToken).decimals();
    }

    /// @dev Transfer token for a specified address
    /// @param to The address to transfer to.
    /// @param amount The amount to be transferred.

    function transfer(address to, uint256 amount) public returns (bool) {
        require(amount <= balances[msg.sender] - locked[msg.sender], "BALANCE_NOT_ENOUGH");

        balances[msg.sender] = balances[msg.sender] - amount;
        balances[to] = balances[to] + amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @dev Gets the balance of the specified address.
    /// @param owner The address to query the the balance of.
    /// @return balance An uint256 representing the amount owned by the passed address.
    function balanceOf(address owner) external view returns (uint256 balance) {
        return balances[owner];
    }

    /// @dev Gets the locked amount of the specified address.
    /// @param owner The address to query the the locked amount.
    /// @return An uint256 representing the amount locked by the passed address.
    function lockedOf(address owner) external view returns (uint256) {
        return locked[owner];
    }

    /// @dev Transfer tokens from one address to another
    /// @param from address The address which you want to send tokens from
    /// @param to address The address which you want to transfer to
    /// @param amount uint256 the amount of tokens to be transferred
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(amount <= balances[from] - locked[from], "BALANCE_NOT_ENOUGH");
        require(amount <= allowed[from][msg.sender], "ALLOWANCE_NOT_ENOUGH");

        balances[from] = balances[from] - amount;
        balances[to] = balances[to] + amount;
        allowed[from][msg.sender] = allowed[from][msg.sender] - amount;
        emit Transfer(from, to, amount);
        return true;
    }

    /// @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    /// @param spender The address which will spend the funds.
    /// @param amount The amount of tokens to be spent.
    function approve(address spender, uint256 amount) public returns (bool) {
        allowed[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @dev Function to check the amount of tokens that an owner allowed to a spender.
    /// @param owner address The address which owns the funds.
    /// @param spender address The address which will spend the funds.
    /// @return A uint256 specifying the amount of tokens still available for the spender.
    function allowance(address owner, address spender) public view returns (uint256) {
        return allowed[owner][spender];
    }

    function mint(address user, uint256 value) external onlyOwner {
        balances[user] = balances[user] + value;
        totalSupply = totalSupply + value;
        emit Mint(user, value);
        emit Transfer(address(0), user, value);
    }

    function burn(address user, uint256 value) external onlyOwner {
        balances[user] = balances[user] - value;
        totalSupply = totalSupply - value;
        emit Burn(user, value);
        emit Transfer(user, address(0), value);
    }

    /// @notice Lock certain amount of D3Token for user
    /// @notice The locked amount cannot be transferred
    /// @param user The user account address
    /// @param value The amount of D3Token to lock
    function lock(address user, uint256 value) external onlyOwner {
        locked[user] += value;
    }

    /// @notice Unlock certain amount of D3Token for user
    /// @param user The user account address
    /// @param value The amount of D3Token to unlock
    function unlock(address user, uint256 value) external onlyOwner {
        locked[user] -= value;
    }

    /// @notice Convert the address to a shorter string
    function addressToShortString(address _addr) public pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(8);
        for (uint256 i = 0; i < 4; i++) {
            str[i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[1 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
}
