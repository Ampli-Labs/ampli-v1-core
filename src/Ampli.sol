// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {IAmpli} from "./interfaces/IAmpli.sol";
import {Constants} from "./libraries/Constants.sol";
import {DeflatorsLibrary} from "./libraries/DeflatorsLibrary.sol";
import {ExchangeRateLibrary} from "./libraries/ExchangeRateLibrary.sol";
import {LockLibrary} from "./libraries/LockLibrary.sol";
import {PositionLibrary} from "./libraries/PositionLibrary.sol";
import {BaseHook, IPoolManager, Hooks, PoolKey} from "./modules/externals/BaseHook.sol";
import {FungibleToken} from "./modules/FungibleToken.sol";
import {NonFungibleTokenReceiver} from "./modules/NonFungibleTokenReceiver.sol";
import {RiskConfigs, IRiskGovernor} from "./modules/RiskConfigs.sol";

contract Ampli is IAmpli, BaseHook, FungibleToken, NonFungibleTokenReceiver, RiskConfigs {
    struct InstanceParams {
        IPoolManager poolManager;
        uint24 poolSwapFee;
        int24 poolTickSpacing;
        string tokenName;
        string tokenSymbol;
        uint8 tokenDecimals;
        IRiskGovernor riskGovernor;
        InterestMode interestMode;
    }

    using LockLibrary for LockLibrary.Lock;
    using DeflatorsLibrary for DeflatorsLibrary.Deflators;
    using ExchangeRateLibrary for ExchangeRateLibrary.ExchangeRate;
    using PositionLibrary for PositionLibrary.Position;

    uint256 private constant GLOBAL_POSITION_ID = 0;
    address private immutable s_self;
    PoolKey private s_poolKey;

    LockLibrary.Lock private s_lock;
    DeflatorsLibrary.Deflators private s_deflators;
    ExchangeRateLibrary.ExchangeRate private s_exchangeRate;

    mapping(uint256 => PositionLibrary.Position) private s_positions;

    constructor(InstanceParams memory params)
        BaseHook(
            params.poolManager,
            Hooks.Permissions(false, false, true, false, true, false, true, true, false, false, false, false, false, false)
        )
        FungibleToken(params.tokenName, params.tokenSymbol, params.tokenDecimals)
        RiskConfigs(params.riskGovernor, params.interestMode)
    {
        s_self = address(this);
        s_poolKey = PoolKey(
            CurrencyLibrary.NATIVE, Currency.wrap(address(this)), params.poolSwapFee, params.poolTickSpacing, this
        );
        s_poolManager.initialize(s_poolKey, Constants.ONE_Q96, "");

        s_deflators.initialize();
        s_exchangeRate.initialize(Constants.ONE_UD18);

        s_positions[GLOBAL_POSITION_ID].open(address(this), address(0));
    }
}
