// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721TokenReceiver} from "forge-std/interfaces/IERC721.sol";

interface IAmpli is IERC20, IERC721TokenReceiver {}
