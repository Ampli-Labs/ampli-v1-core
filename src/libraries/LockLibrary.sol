// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

library LockLibrary {
    struct Lock {
        bool isUnlocked;
        uint256[] exposedItems;
    }

    error LockNotUnlocked();

    function unlock(Lock storage s_self) internal {
        s_self.isUnlocked = true;
    }

    function lock(Lock storage s_self) internal {
        s_self.isUnlocked = false;
    }

    function expose(Lock storage s_self, uint256 item) internal {
        if (!s_self.isUnlocked) revert LockNotUnlocked();

        uint256[] memory exposedItems = s_self.exposedItems;
        for (uint256 i = 0; i < exposedItems.length; i++) {
            if (exposedItems[i] == item) {
                return;
            }
        }

        s_self.exposedItems.push(item);
    }
}
