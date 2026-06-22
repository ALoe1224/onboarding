// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MyNFT2 } from "./MyNFT2.sol";
import { Test } from "forge-std/Test.sol";

contract MyNFT2Test is Test {
    MyNFT2 nft;

    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address operator = address(0x3);

    uint256 tokenId = 1;

    function setUp() public {
        nft = new MyNFT2("MyNFT", "MNFT");
    }

    /// デプロイ時の正常系

    function testNFTNameAndSymbol() public view {
        assertEq(nft.name(), "MyNFT");
        assertEq(nft.symbol(), "MNFT");
    }

    function testInitialBalanceIsZero() public view {
        assertEq(nft.balanceOf(owner), 0);
        assertEq(nft.balanceOf(user1), 0);
    }

    /// mintの正常系

    function testMintSuccess() public {
        nft.mint(user1, tokenId);

        assertEq(nft.ownerOf(tokenId), user1);
        assertEq(nft.balanceOf(user1), 1);
    }

    /// mintのエラーケース

    function testMintFailsToZeroAddress() public {
        vm.expectRevert("NFT: mint to zero address");
        nft.mint(address(0), tokenId);
    }

    function testMintFailsWhenTokenIdAlreadyExists() public {
        nft.mint(user1, tokenId);

        vm.expectRevert("NFT: token already minted");
        nft.mint(user2, tokenId);
    }

    /// balanceOf・ownerOfのエラーケース

    function testBalanceOfFailsForZeroAddress() public {
        vm.expectRevert("NFT: balance query for zero address");
        nft.balanceOf(address(0));
    }

    function testOwnerOfFailsForNonexistentToken() public {
        vm.expectRevert("NFT: owner query for nonexistent token");
        nft.ownerOf(tokenId);
    }

    /// approveの正常系

    function testApproveSuccess() public {
        nft.mint(owner, tokenId);

        nft.approve(user1, tokenId);

        assertEq(nft.getApproved(tokenId), user1);
    }

    function testApprovedAddressCanTransfer() public {
        nft.mint(owner, tokenId);
        nft.approve(user1, tokenId);

        vm.prank(user1);
        nft.transferFrom(owner, user2, tokenId);

        assertEq(nft.ownerOf(tokenId), user2);
        assertEq(nft.balanceOf(owner), 0);
        assertEq(nft.balanceOf(user2), 1);
        assertEq(nft.getApproved(tokenId), address(0));
    }

    /// approveのエラーケース

    function testApproveFailsWhenCallerIsNotOwner() public {
        nft.mint(owner, tokenId);

        vm.prank(user1);
        vm.expectRevert("NFT: approve caller is not owner nor approved for all");
        nft.approve(user2, tokenId);
    }

    function testApproveFailsToCurrentOwner() public {
        nft.mint(owner, tokenId);

        vm.expectRevert("NFT: approval to current owner");
        nft.approve(owner, tokenId);
    }

    function testGetApprovedFailsForNonexistentToken() public {
        vm.expectRevert("NFT: approved query for nonexistent token");
        nft.getApproved(tokenId);
    }

    /// setApprovalForAllの正常系

    function testSetApprovalForAllSuccess() public {
        nft.setApprovalForAll(operator, true);

        assertTrue(nft.isApprovedForAll(owner, operator));
    }

    function testSetApprovalForAllCanBeCancelled() public {
        nft.setApprovalForAll(operator, true);
        nft.setApprovalForAll(operator, false);

        assertFalse(nft.isApprovedForAll(owner, operator));
    }

    function testOperatorCanTransfer() public {
        nft.mint(owner, tokenId);
        nft.setApprovalForAll(operator, true);

        vm.prank(operator);
        nft.transferFrom(owner, user1, tokenId);

        assertEq(nft.ownerOf(tokenId), user1);
        assertEq(nft.balanceOf(owner), 0);
        assertEq(nft.balanceOf(user1), 1);
    }

    function testOperatorCanApproveAnotherAddress() public {
        nft.mint(owner, tokenId);
        nft.setApprovalForAll(operator, true);

        vm.prank(operator);
        nft.approve(user1, tokenId);

        assertEq(nft.getApproved(tokenId), user1);
    }

    /// setApprovalForAllのエラーケース

    function testSetApprovalForAllFailsToCaller() public {
        vm.expectRevert("NFT: approve to caller");
        nft.setApprovalForAll(owner, true);
    }

    /// transferFromの正常系

    function testOwnerCanTransfer() public {
        nft.mint(owner, tokenId);

        nft.transferFrom(owner, user1, tokenId);

        assertEq(nft.ownerOf(tokenId), user1);
        assertEq(nft.balanceOf(owner), 0);
        assertEq(nft.balanceOf(user1), 1);
    }

    /// transferFromのエラーケース

    function testTransferFailsWhenCallerHasNoPermission() public {
        nft.mint(owner, tokenId);

        vm.prank(user1);
        vm.expectRevert("NFT: caller is not owner nor approved");
        nft.transferFrom(owner, user2, tokenId);
    }

    function testTransferFailsFromIncorrectOwner() public {
        nft.mint(owner, tokenId);

        vm.expectRevert("NFT: transfer from incorrect owner");
        nft.transferFrom(user1, user2, tokenId);
    }

    function testTransferFailsToZeroAddress() public {
        nft.mint(owner, tokenId);

        vm.expectRevert("NFT: transfer to zero address");
        nft.transferFrom(owner, address(0), tokenId);
    }

    /// burnの正常系

    function testOwnerCanBurn() public {
        nft.mint(owner, tokenId);

        nft.burn(tokenId);

        assertEq(nft.balanceOf(owner), 0);

        vm.expectRevert("NFT: owner query for nonexistent token");
        nft.ownerOf(tokenId);
    }

    function testApprovedAddressCanBurn() public {
        nft.mint(owner, tokenId);
        nft.approve(user1, tokenId);

        vm.prank(user1);
        nft.burn(tokenId);

        assertEq(nft.balanceOf(owner), 0);

        vm.expectRevert("NFT: owner query for nonexistent token");
        nft.ownerOf(tokenId);
    }

    function testOperatorCanBurn() public {
        nft.mint(owner, tokenId);
        nft.setApprovalForAll(operator, true);

        vm.prank(operator);
        nft.burn(tokenId);

        assertEq(nft.balanceOf(owner), 0);

        vm.expectRevert("NFT: owner query for nonexistent token");
        nft.ownerOf(tokenId);
    }

    /// burnのエラーケース

    function testBurnFailsWhenCallerHasNoPermission() public {
        nft.mint(owner, tokenId);

        vm.prank(user1);
        vm.expectRevert("NFT: caller is not owner nor approved");
        nft.burn(tokenId);
    }

    function testBurnFailsForNonexistentToken() public {
        vm.expectRevert("NFT: owner query for nonexistent token");
        nft.burn(tokenId);
    }
}
