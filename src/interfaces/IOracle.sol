// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Fungible} from "../types/Fungible.sol";
import {NonFungible} from "../types/NonFungible.sol";

interface IOracle {
    function quoteFungibleInNative(Fungible fungible, uint256 amount, bytes calldata data)
        external
        view
        returns (uint256 valueInNative);
    function quoteNonFungibleInNative(NonFungible nonFungible, uint256 item, bytes calldata data)
        external
        view
        returns (uint256 valueInNative);

    function decomposeNonFungible(NonFungible nonFungible, uint256 item, bytes calldata data)
        external
        view
        returns (Fungible[] memory fungibles, uint256[] memory amounts);
}
