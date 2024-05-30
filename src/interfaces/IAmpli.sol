// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721TokenReceiver} from "forge-std/interfaces/IERC721.sol";
import {Fungible} from "../types/Fungible.sol";
import {NonFungible} from "../types/NonFungible.sol";
import {IRiskConfigs} from "./IRiskConfigs.sol";

interface IAmpli is IERC20, IERC721TokenReceiver, IRiskConfigs {
    event PositionOpened(uint256 indexed positionId, address indexed owner, address indexed originator);
    event PositionClosed(uint256 indexed positionId);
    event FungibleDeposited(
        uint256 indexed positionId, address indexed operator, Fungible indexed fungible, uint256 amount
    );
    event FungibleWithdrawn(
        uint256 indexed positionId, address indexed recipient, Fungible indexed fungible, uint256 amount
    );
    event NonFungibleDeposited(
        uint256 indexed positionId, address indexed operator, NonFungible indexed nonFungible, uint256 item
    );
    event NonFungibleWithdrawn(
        uint256 indexed positionId, address indexed recipient, NonFungible indexed nonFungible, uint256 item
    );
    event Borrow(uint256 indexed positionId, address indexed recipient, uint256 nominalAmount, uint256 realAmount);
    event Repay(uint256 indexed positionId, uint256 nominalAmount, uint256 realAmount);
    event Liquidate(
        uint256 indexed positionId,
        address indexed operator,
        address indexed recipient,
        uint256 relief,
        uint256 shortfall
    );
    event Exchange(address indexed operator, address indexed recipient, uint256 nativeAmount, uint256 amount);
    event Settle(address indexed operator, uint256 amount);
    event Collect(address indexed recipient, uint256 nativeAmount);

    error UnauthorizedPositionOperation();
    error PositionDoesNotExist();
    error PositionNotAtRisk();
    error PositionAtRisk(uint256 positionId);
    error FungibleAmountNotRecieved();
    error FungibleBalanceInsufficient();
    error NonFungibleItemNotRecieved();
    error NonFungibleItemAlreadyDeposited();
    error NonFungibleItemNotInPosition();
    error InsufficientSurplus();

    function unlock(bytes calldata callbackData) external returns (bytes memory callbackResult);

    function openPosition(address originator) external returns (uint256 positionId);
    function closePosition(uint256 positionId) external;

    function depositFungible(uint256 positionId, Fungible fungible, uint256 amount) external payable;
    function withdrawFungible(uint256 positionId, Fungible fungible, uint256 amount, address recipient) external;
    function depositNonFungible(uint256 positionId, NonFungible nonFungible, uint256 item) external;
    function withdrawNonFungible(uint256 positionId, NonFungible nonFungible, uint256 item, address recipient)
        external;

    function borrow(uint256 positionId, uint256 amount, address recipient) external;
    function repay(uint256 positionId, uint256 amount) external;
    function liquidate(uint256 positionId, address recipient) external returns (uint256 shortfall);

    function exchange(address recipient) external payable;
    function settle() external;
    function collect(address recipient, uint256 amount) external;
}
