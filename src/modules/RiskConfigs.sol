// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IRiskConfigs, IRiskGovernor, IOracle} from "../interfaces/IRiskConfigs.sol";
import {Constants} from "../libraries/Constants.sol";

abstract contract RiskConfigs is IRiskConfigs {
    struct AssetRiskParams {
        uint256 index; // one-based index of the asset in the assets array.
        uint64 marginReqRatioUD18;
        IOracle oracle;
        bytes oracleData;
    }

    IRiskGovernor private s_riskGovernor;
    IRiskGovernor private s_riskGovernorNext;

    InterestMode private s_interestMode;
    uint32 private s_feeRateUD18;
    uint64 private s_maxDebtRatioUD18;
    uint64 private s_maxExchangeRateAdjRatioUD18;
    address[] private s_assets;
    mapping(address => AssetRiskParams) private s_assetRiskParams;

    modifier riskGovernorOnly() {
        if (msg.sender != address(s_riskGovernor)) revert UnauthorizedRiskOperation();
        _;
    }

    constructor(IRiskGovernor riskGovernor, InterestMode interestMode_) {
        s_riskGovernor = riskGovernor;
        s_interestMode = interestMode_;

        emit RiskGovernorConfirmed(riskGovernor);
        emit InterestModeUpdated(interestMode_);
    }

    function appointNextRiskGovernor(IRiskGovernor riskGovernorNext) external riskGovernorOnly {
        s_riskGovernorNext = riskGovernorNext;

        emit RiskGovernorAppointed(riskGovernorNext);
    }

    function confirmRiskGovernor() external {
        IRiskGovernor riskGovernorNext = s_riskGovernorNext;
        if (msg.sender != address(riskGovernorNext)) revert UnauthorizedRiskOperation();

        s_riskGovernor = riskGovernorNext;
        delete s_riskGovernorNext;

        emit RiskGovernorConfirmed(riskGovernorNext);
    }

    function setInterestMode(InterestMode interestMode_) external riskGovernorOnly {
        s_interestMode = interestMode_;

        emit InterestModeUpdated(interestMode_);
    }

    function setFeeRate(uint32 feeRateUD18) external riskGovernorOnly {
        if (feeRateUD18 > Constants.ONE_BILLIONTH_UD18) revert InvalidFeeRate();

        s_feeRateUD18 = feeRateUD18;

        emit FeeRateUpdated(feeRateUD18);
    }

    function setMaxDebtRatio(uint64 maxDebtRatioUD18) external riskGovernorOnly {
        if (maxDebtRatioUD18 > Constants.ONE_UD18) revert InvalidMaxDebtRatio();

        address[] memory assets = s_assets;
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 marginReqRatioUD18 = s_assetRiskParams[assets[i]].marginReqRatioUD18;

            if (marginReqRatioUD18 != 0 && marginReqRatioUD18 + maxDebtRatioUD18 < Constants.ONE_UD18) {
                revert InvalidMaxDebtRatio();
            }
        }

        s_maxDebtRatioUD18 = maxDebtRatioUD18;

        emit MaxDebtRatioUpdated(maxDebtRatioUD18);
    }

    function setMaxExchangeRateAdjRatio(uint64 maxExchangeRateAdjRatioUD18) external riskGovernorOnly {
        if (maxExchangeRateAdjRatioUD18 == 0 || maxExchangeRateAdjRatioUD18 > Constants.ONE_UD18) {
            revert InvalidMaxExchangeRateAdjRatio();
        }

        s_maxExchangeRateAdjRatioUD18 = maxExchangeRateAdjRatioUD18;

        emit MaxExchangeRateAdjRatioUpdated(maxExchangeRateAdjRatioUD18);
    }

    function setAssetMarginReqRatio(address asset, uint64 marginReqRatioUD18) external riskGovernorOnly {
        if (
            address(s_assetRiskParams[asset].oracle) == address(0) || marginReqRatioUD18 > Constants.ONE_UD18
                || (marginReqRatioUD18 != 0 && marginReqRatioUD18 + s_maxDebtRatioUD18 < Constants.ONE_UD18)
        ) revert InvalidAssetMarginReqRatio();

        s_assetRiskParams[asset].marginReqRatioUD18 = marginReqRatioUD18;

        emit AssetMarginReqRatioUpdated(asset, marginReqRatioUD18);
    }

    function setAssetOracle(address asset, IOracle oracle, bytes calldata oracleData) external riskGovernorOnly {
        if (address(oracle) == address(0)) {
            uint256 index = s_assetRiskParams[asset].index;
            uint256 lastIndex = s_assets.length;
            assert(index > 0 && index <= lastIndex); // sanity check

            // underflow or index out of bounds not possible
            unchecked {
                if (index != lastIndex) {
                    address lastAsset = s_assets[lastIndex - 1];

                    s_assets[index - 1] = lastAsset;
                    s_assetRiskParams[lastAsset].index = index;
                }
            }
            s_assets.pop();
            delete s_assetRiskParams[asset];
        } else {
            if (address(s_assetRiskParams[asset].oracle) == address(0)) {
                s_assets.push(asset);
                s_assetRiskParams[asset].index = s_assets.length;
            }

            s_assetRiskParams[asset].oracle = oracle;
            s_assetRiskParams[asset].oracleData = oracleData;
        }

        emit AssetOracleUpdated(asset, oracle, oracleData);
    }

    function interestMode() public view returns (InterestMode) {
        return s_interestMode;
    }

    function feeRate() public view returns (uint32) {
        return s_feeRateUD18;
    }

    function maxDebtRatio() public view returns (uint64) {
        return s_maxDebtRatioUD18;
    }

    function maxExchangeRateAdjRatio() public view returns (uint64) {
        return s_maxExchangeRateAdjRatioUD18;
    }

    function riskParamsOf(address asset) public view returns (uint64, IOracle, bytes memory) {
        AssetRiskParams storage riskParams = s_assetRiskParams[asset];

        return (riskParams.marginReqRatioUD18, riskParams.oracle, riskParams.oracleData);
    }
}
