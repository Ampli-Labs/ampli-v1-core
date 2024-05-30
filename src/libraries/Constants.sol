// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

library Constants {
    uint160 internal constant ONE_Q96 = 2 ** 96;
    uint160 internal constant MAX_SQRT_PRICE_Q96 = 1461446703485210103287273052203988822378723970342;

    uint64 internal constant ONE_UD18 = 1e18;
    uint32 internal constant ONE_BILLIONTH_UD18 = 1e9;
}
