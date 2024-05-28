// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

type Fungible is address;

using {equals as ==} for Fungible global;

function equals(Fungible a, Fungible b) pure returns (bool) {
    return Fungible.unwrap(a) == Fungible.unwrap(b);
}

library FungibleLibrary {
    Fungible public constant NATIVE = Fungible.wrap(address(0));

    error FungibleTransferFailed();

    function transfer(Fungible self, address to, uint256 amount) internal {
        if (self == NATIVE) {
            (bool success,) = to.call{value: amount}("");
            if (!success) revert FungibleTransferFailed();
        } else {
            // accomodate non-standard ERC20s that do not return a boolean
            (bool success, bytes memory data) =
                Fungible.unwrap(self).call(abi.encodeCall(IERC20.transfer, (to, amount)));
            if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert FungibleTransferFailed();
        }
    }

    function balanceOf(Fungible self, address owner) internal view returns (uint256) {
        return self == NATIVE ? owner.balance : IERC20(Fungible.unwrap(self)).balanceOf(owner);
    }
}
