// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC721} from "forge-std/interfaces/IERC721.sol";

/// @notice Type fpr representing non-fungible assets.
type NonFungible is address;

using {equals as ==} for NonFungible global;

/// @notice Compares two non-fungibles for equality.
/// @param a The first non-fungible
/// @param b The second non-fungible
/// @return bool Whether the two non-fungibles are equal
function equals(NonFungible a, NonFungible b) pure returns (bool) {
    return NonFungible.unwrap(a) == NonFungible.unwrap(b);
}

/// @notice Library for working with non-fungibles, supports ERC721 tokens.
library NonFungibleLibrary {
    /// @notice Transfers a non-fungible item from the current contract to a recipient.
    /// @dev Uses the safe transfer method so a receiving smart contract must implement the IERC721TokenReceiver interface.
    /// @param self The non-fungible to transfer
    /// @param to The recipient of the transfer
    /// @param item The item to transfer
    function transfer(NonFungible self, address to, uint256 item) internal {
        IERC721(NonFungible.unwrap(self)).safeTransferFrom(address(this), to, item);
    }

    /// @notice Gets the owner of an item.
    /// @param self The non-fungible
    /// @param item The item to get the owner of
    /// @return address The owner of the item
    function ownerOf(NonFungible self, uint256 item) internal view returns (address) {
        return IERC721(NonFungible.unwrap(self)).ownerOf(item);
    }
}
