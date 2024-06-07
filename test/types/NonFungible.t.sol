// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {NonFungible} from "../../src/types/NonFungible.sol";
import {TestERC721} from "../utils/TestERC721.sol";
import {TestNonFungibleOwner} from "../utils/TestNonFungibleOwner.sol";

contract NonFungibleTest is Test {
    TestNonFungibleOwner owner1 = new TestNonFungibleOwner();
    TestNonFungibleOwner owner2 = new TestNonFungibleOwner();

    TestERC721 testERC721 = new TestERC721();
    NonFungible nonFungible = NonFungible.wrap(address(testERC721));

    function testFuzz_Transfer(uint256 item) public {
        testERC721.mint(address(owner1), item);

        owner1.transfer(nonFungible, address(owner2), item);
        assertEq(nonFungible.ownerOf(item), address(owner2));

        vm.expectRevert("WRONG_FROM");
        owner1.transfer(nonFungible, address(owner2), item);
    }

    function testFuzz_OwnerOf(uint256 item) public {
        item = bound(item, 0, type(uint256).max - 1);

        testERC721.mint(address(owner1), item);
        assertEq(nonFungible.ownerOf(item), address(owner1));

        vm.expectRevert("NOT_MINTED");
        nonFungible.ownerOf(item + 1);
    }

    function testFuzz_equals(address a, address b) public pure {
        assertEq(a == b, NonFungible.wrap(a) == NonFungible.wrap(b));
    }
}
