// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {mulDiv, mulDiv18, sqrt} from "prb-math/Common.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IAmpli} from "./interfaces/IAmpli.sol";
import {IUnlockCallback} from "./interfaces/callbacks/IUnlockCallback.sol";
import {Constants} from "./libraries/Constants.sol";
import {DeflatorsLibrary} from "./libraries/DeflatorsLibrary.sol";
import {ExchangeRateLibrary} from "./libraries/ExchangeRateLibrary.sol";
import {LockLibrary} from "./libraries/LockLibrary.sol";
import {PositionLibrary, Fungible} from "./libraries/PositionLibrary.sol";
import {BaseHook, IPoolManager, Hooks, PoolKey, BalanceDelta} from "./modules/externals/BaseHook.sol";
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

    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using LockLibrary for LockLibrary.Lock;
    using DeflatorsLibrary for DeflatorsLibrary.Deflators;
    using ExchangeRateLibrary for ExchangeRateLibrary.ExchangeRate;
    using PositionLibrary for PositionLibrary.Position;

    error NoDelegateCall();

    uint256 private constant GLOBAL_POSITION_ID = 0;
    address private immutable s_self;
    PoolKey private s_poolKey;

    LockLibrary.Lock private s_lock;
    DeflatorsLibrary.Deflators private s_deflators;
    ExchangeRateLibrary.ExchangeRate private s_exchangeRate;

    mapping(uint256 => PositionLibrary.Position) private s_positions;

    modifier noDelegateCall() {
        if (address(this) != s_self) revert NoDelegateCall();
        _;
    }

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

    function unlock(bytes calldata callbackData) external returns (bytes memory callbackResult) {
        s_lock.unlock();

        (uint256 sqrtPriceX96,,,) = s_poolManager.getSlot0(s_poolKey.toId());
        _disburseInterest();
        _adjustExchangeRate(sqrtPriceX96, false);

        callbackResult = IUnlockCallback(msg.sender).unlockCallback(callbackData);

        uint256[] memory exposedPositions = s_lock.exposedItems;
        for (uint256 i = 0; i < exposedPositions.length; i++) {
            PositionLibrary.Position storage s_position = s_positions[exposedPositions[i]];
            (uint256 value, uint256 marginReq) =
                s_position.appraise(this, Fungible.wrap(address(this)), s_exchangeRate.currentUD18);
            uint256 debt = s_position.nominalDebt(s_deflators.interestAndFeeUD18);

            if (value < marginReq + debt || debt > mulDiv18(value, maxDebtRatio())) {
                revert PositionAtRisk(exposedPositions[i]);
            }
        }
        delete s_lock.exposedItems;

        s_lock.lock();
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata /*hookData*/
    ) external override noDelegateCall poolManagerOnly returns (bytes4) {
        if (sender != address(this)) {
            (uint256 sqrtPriceX96, int24 tick,,) = s_poolManager.getSlot0(key.toId());

            if (tick >= params.tickLower && tick <= params.tickUpper) {
                _disburseInterest();
            }
            _adjustExchangeRate(sqrtPriceX96, false);
        }

        return this.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata /*hookData*/
    ) external override noDelegateCall poolManagerOnly returns (bytes4) {
        if (sender != address(this)) {
            (uint256 sqrtPriceX96, int24 tick,,) = s_poolManager.getSlot0(key.toId());

            if (tick >= params.tickLower && tick <= params.tickUpper) {
                _disburseInterest();
            }
            _adjustExchangeRate(sqrtPriceX96, false);
        }

        return this.beforeRemoveLiquidity.selector;
    }

    function beforeSwap(
        address sender,
        PoolKey calldata, /*key*/
        IPoolManager.SwapParams calldata, /*params*/
        bytes calldata /*hookData*/
    ) external override noDelegateCall poolManagerOnly returns (bytes4, BeforeSwapDelta, uint24) {
        if (sender != address(this)) {
            _disburseInterest();
        }

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams memory params,
        BalanceDelta delta,
        bytes calldata /*hookData*/
    ) external override noDelegateCall poolManagerOnly returns (bytes4, int128) {
        if (sender != address(this)) {
            IPoolManager poolManager = s_poolManager;
            (uint256 sqrtPriceX96,, uint24 protocolFee, uint24 lpFee) = poolManager.getSlot0(key.toId());

            if (sqrtPriceX96 <= Constants.ONE_Q96) {
                uint128 amount = _amountBeforeFee(_amountBeforeFee(uint128(delta.amount0()), lpFee), protocolFee);

                params = IPoolManager.SwapParams(false, -int128(amount), Constants.MAX_SQRT_PRICE_Q96 - 1);
                delta = poolManager.swap(s_poolKey, params, "");

                _mint(address(poolManager), amount);
                poolManager.settle(Currency.wrap(address(this)));
                poolManager.take(CurrencyLibrary.NATIVE, address(this), uint128(delta.amount0()));

                (sqrtPriceX96,,,) = poolManager.getSlot0(key.toId());
            }

            _adjustExchangeRate(sqrtPriceX96, true);
        }

        return (this.afterSwap.selector, 0);
    }

    function _disburseInterest() private {
        InterestMode interestMode = interestMode();
        uint256 exchangeRateUD18 = s_exchangeRate.currentUD18;
        uint256 annualInterestRateUD18 = (
            interestMode == InterestMode.Intensified
                ? mulDiv18(exchangeRateUD18, exchangeRateUD18)
                : (interestMode == InterestMode.Normal ? exchangeRateUD18 : sqrt(exchangeRateUD18))
        ) - Constants.ONE_UD18;
        uint256 interestRateUD18 = annualInterestRateUD18 / Constants.SECONDS_PER_YEAR;
        (uint256 interestDeflatorGrowthUD18,) = s_deflators.grow(interestRateUD18, feeRate());

        if (interestDeflatorGrowthUD18 > 0) {
            uint256 interest = mulDiv18(s_positions[GLOBAL_POSITION_ID].realDebt, interestDeflatorGrowthUD18);

            IPoolManager poolManager = s_poolManager;
            poolManager.donate(s_poolKey, 0, interest, "");
            _mint(address(poolManager), interest);
            poolManager.settle(Currency.wrap(address(this)));
        }
    }

    function _adjustExchangeRate(uint256 sqrtPriceX96, bool hasSqrtPriceChanged) private {
        uint256 targetExchangeRateUD18 =
            mulDiv(mulDiv(sqrtPriceX96, sqrtPriceX96, Constants.ONE_Q96), Constants.ONE_UD18, Constants.ONE_Q96);
        assert(targetExchangeRateUD18 > Constants.ONE_UD18); // target exchange rate must always be greater than 1

        s_exchangeRate.adjust(targetExchangeRateUD18, hasSqrtPriceChanged, maxExchangeRateAdjRatio());
    }

    function _amountBeforeFee(uint128 amount, uint24 fee) private pure returns (uint128) {
        uint256 amountBeforeFee = mulDiv(amount, Constants.ONE_PIPS, Constants.ONE_PIPS - fee) + 1;
        assert(amountBeforeFee < type(uint128).max);

        return uint128(amountBeforeFee);
    }
}
