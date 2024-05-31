// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice Interface for unlock callbacks.
interface IUnlockCallback {
    /// @notice Callback during an unlock operation.
    /// @param data Additional data for the callback
    /// @return result The result of the callback
    function unlockCallback(bytes calldata data) external returns (bytes memory result);
}
