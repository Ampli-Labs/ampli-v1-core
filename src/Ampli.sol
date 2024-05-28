// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IAmpli} from "./interfaces/IAmpli.sol";
import {FungibleToken} from "./modules/FungibleToken.sol";
import {NonFungibleTokenReceiver} from "./modules/NonFungibleTokenReceiver.sol";

contract Ampli is IAmpli, FungibleToken, NonFungibleTokenReceiver {
    struct InstanceParams {
        string tokenName;
        string tokenSymbol;
        uint8 tokenDecimals;
    }

    constructor(InstanceParams memory params)
        FungibleToken(params.tokenName, params.tokenSymbol, params.tokenDecimals)
    {}
}
