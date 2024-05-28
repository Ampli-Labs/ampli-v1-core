// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC721TokenReceiver} from "forge-std/interfaces/IERC721.sol";

abstract contract NonFungibleTokenReceiver is IERC721TokenReceiver {
    function onERC721Received(address, /*operator*/ address, /*from*/ uint256, /*tokenId*/ bytes calldata /*data*/ )
        external
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
