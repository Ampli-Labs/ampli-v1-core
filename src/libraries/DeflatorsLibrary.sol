// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {mulDiv18} from "prb-math/Common.sol";
import {UD60x18, powu} from "prb-math/UD60x18.sol";
import {Constants} from "./Constants.sol";

library DeflatorsLibrary {
    struct Deflators {
        uint256 interestUD18;
        uint256 interestAndFeeUD18;
        uint256 lastGrowthTimestamp;
    }

    error DeflatorsAlreadyInitialized();

    function initialize(Deflators storage s_self) internal {
        if (s_self.lastGrowthTimestamp != 0) revert DeflatorsAlreadyInitialized();

        s_self.interestUD18 = Constants.ONE_UD18;
        s_self.interestAndFeeUD18 = Constants.ONE_UD18;
        s_self.lastGrowthTimestamp = block.timestamp;
    }

    function grow(Deflators storage s_self, uint256 interestRateUD18, uint256 feeRateUD18)
        internal
        returns (uint256 interestDeflatorGrowthUD18, uint256 interestAndFeeDeflatorGrowthUD18)
    {
        uint256 timeElapsed = block.timestamp - s_self.lastGrowthTimestamp;

        if (timeElapsed > 0) {
            uint256 interestDeflatorUD18 = s_self.interestUD18;
            interestDeflatorGrowthUD18 = mulDiv18(interestDeflatorUD18, _compoundRate(interestRateUD18, timeElapsed));
            s_self.interestUD18 = interestDeflatorUD18 + interestDeflatorGrowthUD18;

            uint256 interestAndFeeDeflatorUD18 = s_self.interestAndFeeUD18;
            interestAndFeeDeflatorGrowthUD18 =
                mulDiv18(interestAndFeeDeflatorUD18, _compoundRate(interestRateUD18 + feeRateUD18, timeElapsed));
            s_self.interestAndFeeUD18 = interestAndFeeDeflatorUD18 + interestAndFeeDeflatorGrowthUD18;

            s_self.lastGrowthTimestamp = block.timestamp;
        }
    }

    function _compoundRate(uint256 rateUD18, uint256 power) private pure returns (uint256) {
        return UD60x18.unwrap(powu(UD60x18.wrap(Constants.ONE_UD18 + rateUD18), power)) - Constants.ONE_UD18;
    }
}
