// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IOracle} from "./IOracle.sol";
import {IRiskGovernor} from "./IRiskGovernor.sol";

interface IRiskConfigs {
    enum InterestMode {
        Dampened,
        Normal,
        Intensified
    }

    event RiskGovernorAppointed(IRiskGovernor riskGovernorNext);
    event RiskGovernorConfirmed(IRiskGovernor riskGovernor);
    event InterestModeUpdated(InterestMode interestMode);
    event FeeRateUpdated(uint32 feeRateUD18);
    event MaxDebtRatioUpdated(uint64 maxDebtRatioUD18);
    event MaxExchangeRateAdjRatioUpdated(uint64 maxExchangeRateAdjRatioUD18);
    event AssetMarginReqRatioUpdated(address indexed asset, uint64 marginReqRatioUD18);
    event AssetOracleUpdated(address indexed asset, IOracle oracle, bytes oracleData);

    error UnauthorizedRiskOperation();
    error InvalidFeeRate();
    error InvalidMaxDebtRatio();
    error InvalidMaxExchangeRateAdjRatio();
    error InvalidAssetMarginReqRatio();

    function appointNextRiskGovernor(IRiskGovernor riskGovernorNext) external;
    function confirmRiskGovernor() external;

    function setInterestMode(InterestMode interestMode) external;
    function setFeeRate(uint32 feeRateUD18) external;
    function setMaxDebtRatio(uint64 maxDebtRatioUD18) external;
    function setMaxExchangeRateAdjRatio(uint64 maxExchangeRateAdjRatioUD18) external;
    function setAssetMarginReqRatio(address asset, uint64 marginReqRatioUD18) external;
    function setAssetOracle(address asset, IOracle oracle, bytes calldata oracleData) external;

    function interestMode() external view returns (InterestMode interestMode);
    function feeRate() external view returns (uint32 feeRateUD18);
    function maxDebtRatio() external view returns (uint64 maxDebtRatioUD18);
    function maxExchangeRateAdjRatio() external view returns (uint64 maxExchangeRateAdjRatioUD18);
    function riskParamsOf(address asset)
        external
        view
        returns (uint64 marginReqRatioUD18, IOracle oracle, bytes memory oracleData);
}
