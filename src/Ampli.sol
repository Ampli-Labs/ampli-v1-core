// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IAmpli} from "./interfaces/IAmpli.sol";
import {PositionLibrary} from "./libraries/PositionLibrary.sol";
import {FungibleToken} from "./modules/FungibleToken.sol";
import {NonFungibleTokenReceiver} from "./modules/NonFungibleTokenReceiver.sol";
import {RiskConfigs, IRiskGovernor} from "./modules/RiskConfigs.sol";

contract Ampli is IAmpli, FungibleToken, NonFungibleTokenReceiver, RiskConfigs {
    struct InstanceParams {
        string tokenName;
        string tokenSymbol;
        uint8 tokenDecimals;
        IRiskGovernor riskGovernor;
        InterestMode interestMode;
    }

    using PositionLibrary for PositionLibrary.Position;

    uint256 private constant GLOBAL_POSITION_ID = 0;

    mapping(uint256 => PositionLibrary.Position) private s_positions;

    constructor(InstanceParams memory params)
        FungibleToken(params.tokenName, params.tokenSymbol, params.tokenDecimals)
        RiskConfigs(params.riskGovernor, params.interestMode)
    {
        s_positions[GLOBAL_POSITION_ID].open(address(this), address(0));
    }
}
