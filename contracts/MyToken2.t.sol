// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MyToken2 } from "./MyToken2.sol";
import { Test } from "forge-std/Test.sol";

contract MyToken2Test is Test {
    MyToken2 token;

    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);

    uint256 initialSupply = 1000 * 10 ** 18;

    function setUp() public {
        token = new MyToken2("MyToken", "MTK", 1000);
    }

    /// デプロイ時の正常系

    function testInitialSupplyIsAssignedToOwner() public view {
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(owner), initialSupply);
    }

    function testTokenNameSymbolDecimals() public view {
        assertEq(token.name(), "MyToken");
        assertEq(token.symbol(), "MTK");
        assertEq(token.decimals(), 18);
    }

    /// transferの正常系

    function testTransferSuccess() public {
        uint256 amount = 100 * 10 ** 18;

        bool result = token.transfer(user1, amount);

        assertTrue(result);
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(owner), initialSupply - amount);
    }

    /// transferのエラーケース

    function testTransferFailsWhenBalanceIsInsufficient() public {
        uint256 amount = 1 * 10 ** 18;

        vm.prank(user1);

        vm.expectRevert();
        token.transfer(user2, amount);
    }

    function testTransferFailsToZeroAddress() public {
        uint256 amount = 1 * 10 ** 18;

        vm.expectRevert();
        token.transfer(address(0), amount);
    }

    /// approveの正常系

    function testApproveSuccess() public {
        uint256 amount = 200 * 10 ** 18;

        bool result = token.approve(user1, amount);

        assertTrue(result);
        assertEq(token.allowance(owner, user1), amount);
    }

    /// approveのエラーケース

    function testApproveFailsToZeroAddress() public {
        uint256 amount = 100 * 10 ** 18;

        vm.expectRevert();
        token.approve(address(0), amount);
    }

    /// transferFromの正常系

    function testTransferFromSuccess() public {
        uint256 amount = 100 * 10 ** 18;

        token.approve(user1, amount);

        vm.prank(user1);
        bool result = token.transferFrom(owner, user2, amount);

        assertTrue(result);
        assertEq(token.balanceOf(user2), amount);
        assertEq(token.balanceOf(owner), initialSupply - amount);
        assertEq(token.allowance(owner, user1), 0);
    }

    /// transferFromのエラーケース

    function testTransferFromFailsWhenAllowanceIsInsufficient() public {
        uint256 amount = 100 * 10 ** 18;

        vm.prank(user1);

        vm.expectRevert();
        token.transferFrom(owner, user2, amount);
    }

    function testTransferFromFailsWhenBalanceIsInsufficient() public {
        uint256 amount = 2000 * 10 ** 18;

        token.approve(user1, amount);

        vm.prank(user1);

        vm.expectRevert();
        token.transferFrom(owner, user2, amount);
    }

    function testTransferFromFailsToZeroAddress() public {
        uint256 amount = 100 * 10 ** 18;

        token.approve(user1, amount);

        vm.prank(user1);

        vm.expectRevert();
        token.transferFrom(owner, address(0), amount);
    }
}