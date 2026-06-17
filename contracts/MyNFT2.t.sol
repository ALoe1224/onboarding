// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MyNFT2.sol";

contract MyNFT2Test is Test {
    MyNFT2 nft;

    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address operator = address(0x4);

    function setUp() public {
        nft = new MyNFT2("MyNFT2", "MNFT2");
    }

    // name と symbol が正しく設定されているか
    function testNameAndSymbol() public view {
        assertEq(nft.name(), "MyNFT2");
        assertEq(nft.symbol(), "MNFT2");
    }

    // mint すると所有者と残高が正しく変わるか
    function testMint() public {
        nft.mint(owner, 1);

        assertEq(nft.ownerOf(1), owner);
        assertEq(nft.balanceOf(owner), 1);
    }

    // mint 時に Transfer イベントが発行されるか
    function testMintEmitsTransferEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC721.Transfer(address(0), owner, 1);

        nft.mint(owner, 1);
    }

    // 0アドレスには mint できない
    function testCannotMintToZeroAddress() public {
        vm.expectRevert("NFT: mint to zero address");
        nft.mint(address(0), 1);
    }

    // 同じ tokenId は二重に mint できない
    function testCannotMintSameTokenIdTwice() public {
        nft.mint(owner, 1);

        vm.expectRevert("NFT: token already minted");
        nft.mint(user1, 1);
    }

    // 存在しない tokenId の ownerOf は失敗する
    function testOwnerOfNonexistentTokenReverts() public {
        vm.expectRevert("NFT: owner query for nonexistent token");
        nft.ownerOf(999);
    }

    // balanceOf に 0アドレスを指定すると失敗する
    function testBalanceOfZeroAddressReverts() public {
        vm.expectRevert("NFT: balance query for zero address");
        nft.balanceOf(address(0));
    }

    // 所有者は transferFrom できる
    function testOwnerCanTransfer() public {
        nft.mint(owner, 1);

        vm.prank(owner);
        nft.transferFrom(owner, user1, 1);

        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.balanceOf(owner), 0);
        assertEq(nft.balanceOf(user1), 1);
    }

    // 所有者でない人は transferFrom できない
    function testNonOwnerCannotTransfer() public {
        nft.mint(owner, 1);

        vm.prank(user1);
        vm.expectRevert("NFT: caller is not owner nor approved");
        nft.transferFrom(owner, user2, 1);
    }

    // from が現在の所有者でない場合は transferFrom できない
    function testCannotTransferFromIncorrectOwner() public {
        nft.mint(owner, 1);

        vm.prank(owner);
        vm.expectRevert("NFT: transfer from incorrect owner");
        nft.transferFrom(user1, user2, 1);
    }

    // 0アドレスには transfer できない
    function testCannotTransferToZeroAddress() public {
        nft.mint(owner, 1);

        vm.prank(owner);
        vm.expectRevert("NFT: transfer to zero address");
        nft.transferFrom(owner, address(0), 1);
    }

    // approve された人は transferFrom できる
    function testApprovedAddressCanTransfer() public {
        nft.mint(owner, 1);

        vm.prank(owner);
        nft.approve(user1, 1);

        assertEq(nft.getApproved(1), user1);

        vm.prank(user1);
        nft.transferFrom(owner, user2, 1);

        assertEq(nft.ownerOf(1), user2);
    }

    // approve すると Approval イベントが発行される
    function testApproveEmitsApprovalEvent() public {
        nft.mint(owner, 1);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC721.Approval(owner, user1, 1);

        nft.approve(user1, 1);
    }

    // 所有者本人には approve できない
    function testCannotApproveCurrentOwner() public {
        nft.mint(owner, 1);

        vm.prank(owner);
        vm.expectRevert("NFT: approval to current owner");
        nft.approve(owner, 1);
    }

    // 所有者でも operator でもない人は approve できない
    function testNonOwnerCannotApprove() public {
        nft.mint(owner, 1);

        vm.prank(user1);
        vm.expectRevert("NFT: approve caller is not owner nor approved for all");
        nft.approve(user2, 1);
    }

    // 存在しない tokenId の getApproved は失敗する
    function testGetApprovedForNonexistentTokenReverts() public {
        vm.expectRevert("NFT: approved query for nonexistent token");
        nft.getApproved(999);
    }

    // setApprovalForAll で operator に全体承認できる
    function testSetApprovalForAll() public {
        vm.prank(owner);
        nft.setApprovalForAll(operator, true);

        assertTrue(nft.isApprovedForAll(owner, operator));
    }

    // operator は所有者のNFTを transferFrom できる
    function testOperatorCanTransfer() public {
        nft.mint(owner, 1);

        vm.prank(owner);
        nft.setApprovalForAll(operator, true);

        vm.prank(operator);
        nft.transferFrom(owner, user1, 1);

        assertEq(nft.ownerOf(1), user1);
    }

    // 自分自身を operator にはできない
    function testCannotApproveCallerAsOperator() public {
        vm.prank(owner);
        vm.expectRevert("NFT: approve to caller");
        nft.setApprovalForAll(owner, true);
    }

    // transfer 後は approve 情報が削除される
    function testApprovalIsClearedAfterTransfer() public {
        nft.mint(owner, 1);

        vm.prank(owner);
        nft.approve(user1, 1);

        vm.prank(owner);
        nft.transferFrom(owner, user2, 1);

        assertEq(nft.getApproved(1), address(0));
    }

    // 所有者は burn できる
    function testOwnerCanBurn() public {
        nft.mint(owner, 1);

        vm.prank(owner);
        nft.burn(1);

        assertEq(nft.balanceOf(owner), 0);

        vm.expectRevert("NFT: owner query for nonexistent token");
        nft.ownerOf(1);
    }

    // approve された人は burn できる
    function testApprovedAddressCanBurn() public {
        nft.mint(owner, 1);

        vm.prank(owner);
        nft.approve(user1, 1);

        vm.prank(user1);
        nft.burn(1);

        assertEq(nft.balanceOf(owner), 0);
    }

    // 権限がない人は burn できない
    function testNonOwnerCannotBurn() public {
        nft.mint(owner, 1);

        vm.prank(user1);
        vm.expectRevert("NFT: caller is not owner nor approved");
        nft.burn(1);
    }
}
