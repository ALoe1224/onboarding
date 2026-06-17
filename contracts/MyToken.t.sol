// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { MyToken } from "../contracts/MyToken.sol";

contract MyTokenTest is Test {
    MyToken token;

    address alice = address(0x123);
    address bob   = address(0x456);

    function setUp() public {
        token = new MyToken(1000 ether);
    }

    function testInitialSupplyAssignedToDeployer() public view{
        assertEq(token.totalSupply(), 1000 ether, "totalSupply should be 1000");
        assertEq(token.balanceOf(address(this)), 1000 ether, "deployer should own all tokens");
    }

    function testTransfer() public {
        token.transfer(alice, 100 ether);

        assertEq(token.balanceOf(address(this)), 900 ether, "deployer balance should decrease");
        assertEq(token.balanceOf(alice), 100 ether, "alice should receive tokens");
    }

    function testTransferBetweenUsers() public {
        token.transfer(alice, 200 ether);

        vm.prank(alice);
        token.transfer(bob, 50 ether);

        assertEq(token.balanceOf(alice), 150 ether, "alice should have 150");
        assertEq(token.balanceOf(bob), 50 ether, "bob should have 50");
    }
}