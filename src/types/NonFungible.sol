// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC721} from "forge-std/interfaces/IERC721.sol";

type NonFungible is address;

using {equals as ==} for NonFungible global;

function equals(NonFungible a, NonFungible b) pure returns (bool) {
    return NonFungible.unwrap(a) == NonFungible.unwrap(b);
}

library NonFungibleLibrary {
    function transfer(NonFungible self, address to, uint256 item) internal {
        IERC721(NonFungible.unwrap(self)).safeTransferFrom(address(this), to, item);
    }

    function ownerOf(NonFungible self, uint256 item) internal view returns (address) {
        return IERC721(NonFungible.unwrap(self)).ownerOf(item);
    }
}
