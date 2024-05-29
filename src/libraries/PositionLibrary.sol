// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {mulDiv18} from "prb-math/Common.sol";
import {IRiskConfigs, IOracle} from "../interfaces/IRiskConfigs.sol";
import {Fungible} from "../types/Fungible.sol";
import {NonFungible} from "../types/NonFungible.sol";

library PositionLibrary {
    struct FungibleAsset {
        uint256 index; // one-based index of the fungible in the fungibles array.
        uint256 balance;
    }

    struct NonFungibleAsset {
        uint256 index; // one-based index of the non-fungible in the non-fungibles array.
        uint256[] items;
        mapping(uint256 => uint256) itemIndices; // one-based index of the item in the items array.
    }

    struct Position {
        address owner;
        address originator;
        uint256 realDebt; // sum of outstanding debts deflated to a common point in time.
        Fungible[] fungibles;
        mapping(Fungible => FungibleAsset) fungibleAssets;
        NonFungible[] nonFungibles;
        mapping(NonFungible => NonFungibleAsset) nonFungibleAssets;
    }

    using PositionLibrary for PositionLibrary.Position;

    error PositionAlreadyExists();
    error PositionIsNotEmpty();
    error PositionAlreadyContainsNonFungibleItem();
    error PositionDoesNotContainNonFungibleItem();

    function open(Position storage s_self, address owner, address originator) internal {
        if (s_self.exists()) revert PositionAlreadyExists();

        s_self.owner = owner;
        if (originator != address(0)) {
            s_self.originator = originator;
        }
    }

    function close(Position storage s_self) internal {
        if (!s_self.isEmpty()) revert PositionIsNotEmpty();

        delete s_self.owner;
        delete s_self.originator;
    }

    function addFungible(Position storage s_self, Fungible fungible, uint256 amount) internal {
        FungibleAsset storage s_fungibleAsset = s_self.fungibleAssets[fungible];
        uint256 oldBalance = s_fungibleAsset.balance;

        if (oldBalance == 0) {
            s_self.fungibles.push(fungible);
            s_fungibleAsset.index = s_self.fungibles.length;
        }
        s_fungibleAsset.balance = oldBalance + amount; // overflow desired
    }

    function removeFungible(Position storage s_self, Fungible fungible, uint256 amount) internal {
        FungibleAsset storage s_fungibleAsset = s_self.fungibleAssets[fungible];
        uint256 newBalance = s_fungibleAsset.balance - amount; // underflow desired

        if (newBalance == 0) {
            uint256 index = s_fungibleAsset.index;
            uint256 lastIndex = s_self.fungibles.length;
            assert(index > 0 && index <= lastIndex); // sanity check

            // underflow or index out of bounds not possible
            unchecked {
                if (index != lastIndex) {
                    Fungible lastFungible = s_self.fungibles[lastIndex - 1];

                    s_self.fungibles[index - 1] = lastFungible;
                    s_self.fungibleAssets[lastFungible].index = index;
                }
            }
            s_self.fungibles.pop();
            delete s_self.fungibleAssets[fungible];
        } else {
            s_fungibleAsset.balance = newBalance;
        }
    }

    function addNonFungible(Position storage s_self, NonFungible nonFungible, uint256 item) internal {
        NonFungibleAsset storage s_nonFungibleAsset = s_self.nonFungibleAssets[nonFungible];
        if (s_nonFungibleAsset.itemIndices[item] != 0) revert PositionAlreadyContainsNonFungibleItem();
        uint256 itemsCount = s_nonFungibleAsset.items.length;

        if (itemsCount == 0) {
            s_self.nonFungibles.push(nonFungible);
            s_nonFungibleAsset.index = s_self.nonFungibles.length;
        }
        s_nonFungibleAsset.items.push(item);
        s_nonFungibleAsset.itemIndices[item] = itemsCount + 1;
    }

    function removeNonFungible(Position storage s_self, NonFungible nonFungible, uint256 item) internal {
        NonFungibleAsset storage s_nonFungibleAsset = s_self.nonFungibleAssets[nonFungible];
        if (s_nonFungibleAsset.itemIndices[item] == 0) revert PositionDoesNotContainNonFungibleItem();
        uint256 itemsCount = s_nonFungibleAsset.items.length;

        if (itemsCount == 1) {
            uint256 index = s_nonFungibleAsset.index;
            uint256 lastIndex = s_self.nonFungibles.length;
            assert(index > 0 && index <= lastIndex); // sanity check

            // underflow or index out of bounds not possible
            unchecked {
                if (index != lastIndex) {
                    NonFungible lastNonFungible = s_self.nonFungibles[lastIndex - 1];

                    s_self.nonFungibles[index - 1] = lastNonFungible;
                    s_self.nonFungibleAssets[lastNonFungible].index = index;
                }
            }
            s_self.nonFungibles.pop();
            delete s_nonFungibleAsset.itemIndices[item]; // extra hygiene
            delete s_self.nonFungibleAssets[nonFungible];
        } else {
            uint256 itemIndex = s_nonFungibleAsset.itemIndices[item];
            uint256 lastItemIndex = itemsCount;
            assert(itemIndex > 0 && itemIndex <= lastItemIndex); // sanity check

            // underflow or index out of bounds not possible
            unchecked {
                if (itemIndex != lastItemIndex) {
                    uint256 lastItem = s_nonFungibleAsset.items[lastItemIndex - 1];

                    s_nonFungibleAsset.items[itemIndex - 1] = lastItem;
                    s_nonFungibleAsset.itemIndices[lastItem] = itemIndex;
                }
            }
            s_nonFungibleAsset.items.pop();
            delete s_nonFungibleAsset.itemIndices[item];
        }
    }

    function exists(Position storage s_self) internal view returns (bool) {
        return s_self.owner != address(0);
    }

    function isEmpty(Position storage s_self) internal view returns (bool) {
        return s_self.realDebt == 0 && s_self.fungibles.length == 0 && s_self.nonFungibles.length == 0;
    }

    function nominalDebt(Position storage s_self, uint256 deflatorUD18) internal view returns (uint256) {
        return mulDiv18(s_self.realDebt, deflatorUD18) + 1;
    }

    function appraise(
        Position storage s_self,
        IRiskConfigs riskConfigs,
        Fungible quoteFungible,
        uint256 exchangeRateUD18
    ) internal view returns (uint256 value, uint256 marginReq) {
        uint256 baseValue;
        uint256 baseMarginReq;

        Fungible[] memory fungibles = s_self.fungibles;
        for (uint256 i = 0; i < fungibles.length; i++) {
            Fungible fungible = fungibles[i];
            uint256 amount = s_self.fungibleAssets[fungible].balance;

            if (fungible == quoteFungible) {
                value += amount;
            } else {
                (uint256 baseValue_, uint256 baseMarginReq_) = _appraiseFungibleInNative(fungible, amount, riskConfigs);

                baseValue += baseValue_;
                baseMarginReq += baseMarginReq_;
            }
        }

        NonFungible[] memory nonFungibles = s_self.nonFungibles;
        for (uint256 i = 0; i < nonFungibles.length; i++) {
            NonFungible nonFungible = nonFungibles[i];
            (uint64 marginReqRatioUD18, IOracle oracle, bytes memory oracleData) =
                riskConfigs.riskParamsOf(NonFungible.unwrap(nonFungible));

            if (address(oracle) == address(0)) continue;
            uint256[] memory items = s_self.nonFungibleAssets[nonFungible].items;

            if (marginReqRatioUD18 != 0) {
                for (uint256 j = 0; j < items.length; j++) {
                    uint256 baseValue_ = oracle.quoteNonFungibleInNative(nonFungible, items[j], oracleData);

                    baseValue += baseValue_;
                    baseMarginReq += mulDiv18(baseValue_, marginReqRatioUD18) + 1;
                }
            } else {
                for (uint256 j = 0; j < items.length; j++) {
                    (Fungible[] memory fungibles_, uint256[] memory amounts) =
                        oracle.decomposeNonFungible(nonFungible, items[j], oracleData);

                    for (uint256 k = 0; k < fungibles_.length; k++) {
                        if (fungibles_[k] == quoteFungible) {
                            value += amounts[k];
                        } else {
                            (uint256 baseValue_, uint256 baseMarginReq_) =
                                _appraiseFungibleInNative(fungibles_[k], amounts[k], riskConfigs);

                            baseValue += baseValue_;
                            baseMarginReq += baseMarginReq_;
                        }
                    }
                }
            }
        }

        value += mulDiv18(baseValue, exchangeRateUD18);
        marginReq += mulDiv18(baseMarginReq, exchangeRateUD18) + 1;
    }

    function _appraiseFungibleInNative(Fungible fungible, uint256 amount, IRiskConfigs riskConfigs)
        private
        view
        returns (uint256 valueInNative, uint256 marginReqInNative)
    {
        (uint64 marginReqRatioUD18, IOracle oracle, bytes memory oracleData) =
            riskConfigs.riskParamsOf(Fungible.unwrap(fungible));

        if (address(oracle) != address(0)) {
            valueInNative = oracle.quoteFungibleInNative(fungible, amount, oracleData);
            marginReqInNative = mulDiv18(valueInNative, marginReqRatioUD18) + 1;
        }
    }
}
