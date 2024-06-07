// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @notice Library for constants used throughout the protocol.
library Constants {
    /// @notice Constant for representing 1 in Q96 notation.
    uint160 internal constant ONE_Q96 = 0x1000000000000000000000000;
    /// @notice Constant for representing max sqrt price in Q96 notation.
    uint160 internal constant MAX_SQRT_PRICE_Q96 = 1461446703485210103287273052203988822378723970342;

    /// @notice Constant for representing 1 in UD18 notation.
    uint64 internal constant ONE_UD18 = 1e18;
    /// @notice Constant for representing 1 / 1,000,000,000 in UD18 notation.
    uint32 internal constant ONE_BILLIONTH_UD18 = 1e9;

    /// @notice Constant for representing 1 in pips notation.
    uint256 internal constant ONE_PIPS = 1000000;

    /// @notice Constant for representing seconds in a year.
    uint256 internal constant SECONDS_PER_YEAR = 31536000;
}
