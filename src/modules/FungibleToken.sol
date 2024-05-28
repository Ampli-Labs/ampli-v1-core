// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC165} from "forge-std/interfaces/IERC165.sol";

abstract contract FungibleToken is IERC20, IERC165 {
    struct OwnerData {
        uint256 balance;
        mapping(address => uint256) allowances;
    }

    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 private s_totalSupply;
    mapping(address => OwnerData) private s_ownerData;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC20).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        s_ownerData[msg.sender].allowances[spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 currentAllowance = s_ownerData[from].allowances[msg.sender];

        // do not reduce if given unlimited allowance
        if (currentAllowance != type(uint256).max) {
            s_ownerData[from].allowances[msg.sender] = currentAllowance - amount; // underflow desired
        }
        _transfer(from, to, amount);

        return true;
    }

    function totalSupply() public view returns (uint256) {
        return s_totalSupply;
    }

    function balanceOf(address owner) public view returns (uint256) {
        return s_ownerData[owner].balance;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return s_ownerData[owner].allowances[spender];
    }

    function _mint(address to, uint256 amount) internal {
        _transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        _transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) {
            s_totalSupply += amount; // overflow desired
        } else {
            s_ownerData[from].balance -= amount; // underflow desired
        }

        // over/underflow not possible
        unchecked {
            if (to == address(0)) {
                s_totalSupply -= amount;
            } else {
                s_ownerData[to].balance += amount;
            }
        }

        emit Transfer(from, to, amount);
    }
}
