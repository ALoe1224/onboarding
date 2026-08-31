// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ShareRegistry } from "./ShareRegistry.sol";
import { Test } from "forge-std/Test.sol";

contract ShareRegistryTest is Test {
    ShareRegistry registry;
    address owner = address(0xABCD);
    address recipient = address(0xBEEF);
    address other = address(0xC0FFEE);

    bytes32 constant WORK_HASH = keccak256("example-work");
    bytes32 constant SHARE_SALT = keccak256("example-salt");
    string constant VERSION = "WM_SHARE_V1";

    function _blake2s128(bytes memory input) internal pure returns (bytes16) {
        // Solidity does not have native BLAKE2s, so this test mirrors the JS
        // implementation by using the exact same logical inputs and keeping the
        // output size at 128 bits for the registry key.
        return bytes16(keccak256(input));
    }

    function setUp() public {
        registry = new ShareRegistry();
        registry.transferOwnership(owner);
    }

    function test_RegisterWorkSucceeds() public {
        vm.prank(owner);
        registry.registerWork(WORK_HASH);

        assertEq(registry.workOwners(WORK_HASH), owner);
    }

    function test_RegisterWorkCannotDuplicate() public {
        vm.prank(owner);
        registry.registerWork(WORK_HASH);

        vm.prank(owner);
        vm.expectRevert("work already registered");
        registry.registerWork(WORK_HASH);
    }

    function test_RegisterShareRequiresOwner() public {
        bytes16 watermarkId = _blake2s128(abi.encode(VERSION, WORK_HASH, recipient, uint256(0), SHARE_SALT));
        bytes32 watermarkCommitment = keccak256(abi.encodePacked(watermarkId));

        vm.prank(other);
        vm.expectRevert("Ownable: caller is not the owner");
        registry.registerShare(watermarkId, WORK_HASH, recipient, SHARE_SALT, watermarkCommitment, 0);
    }

    function test_RegisterShareSucceeds() public {
        bytes16 watermarkId = _blake2s128(abi.encode(VERSION, WORK_HASH, recipient, uint256(0), SHARE_SALT));
        bytes32 watermarkCommitment = keccak256(abi.encodePacked(watermarkId));

        vm.prank(owner);
        registry.registerWork(WORK_HASH);

        vm.prank(owner);
        registry.registerShare(watermarkId, WORK_HASH, recipient, SHARE_SALT, watermarkCommitment, 0);

        ShareRegistry.ShareRecord memory record = registry.getShareByTokenId(1);

        assertEq(record.workHash, WORK_HASH);
        assertEq(record.recipient, recipient);
        assertEq(record.shareSalt, SHARE_SALT);
        assertTrue(record.active);
        assertGt(record.issuedAt, 0);
        assertEq(record.parentTokenId, 0);
    }

    function test_RegisterShareCannotDuplicateWatermarkId() public {
        bytes16 watermarkId = _blake2s128(abi.encode(VERSION, WORK_HASH, recipient, uint256(0), SHARE_SALT));
        bytes32 watermarkCommitment = keccak256(abi.encodePacked(watermarkId));

        vm.prank(owner);
        registry.registerWork(WORK_HASH);

        vm.prank(owner);
        registry.registerShare(watermarkId, WORK_HASH, recipient, SHARE_SALT, watermarkCommitment, 0);

        vm.prank(owner);
        vm.expectRevert("watermarkId already registered");
        registry.registerShare(watermarkId, WORK_HASH, recipient, SHARE_SALT, watermarkCommitment, 0);
    }

    function test_GetTokenIdByPublicWatermarkId() public {
        bytes16 watermarkId = _blake2s128(abi.encode(VERSION, WORK_HASH, recipient, uint256(0), SHARE_SALT));
        bytes32 watermarkCommitment = keccak256(abi.encodePacked(watermarkId));

        vm.prank(owner);
        registry.registerWork(WORK_HASH);

        vm.prank(owner);
        registry.registerShare(watermarkId, WORK_HASH, recipient, SHARE_SALT, watermarkCommitment, 0);

        assertEq(registry.tokenIdByWatermarkId(watermarkId), 1);
    }

    function test_GetTokenIdByCommitment() public {
        bytes16 watermarkId = _blake2s128(abi.encode(VERSION, WORK_HASH, recipient, uint256(0), SHARE_SALT));
        bytes32 watermarkCommitment = keccak256(abi.encodePacked(watermarkId));

        vm.prank(owner);
        registry.registerWork(WORK_HASH);

        vm.prank(owner);
        registry.registerShare(watermarkId, WORK_HASH, recipient, SHARE_SALT, watermarkCommitment, 0);

        uint256 tokenId = registry.getTokenIdByCommitment(watermarkCommitment);
        assertEq(tokenId, 1);
    }

    function test_GetSharePathForSingleToken() public {
        bytes16 watermarkId = _blake2s128(abi.encode(VERSION, WORK_HASH, recipient, uint256(0), SHARE_SALT));
        bytes32 watermarkCommitment = keccak256(abi.encodePacked(watermarkId));

        vm.prank(owner);
        registry.registerWork(WORK_HASH);

        vm.prank(owner);
        registry.registerShare(watermarkId, WORK_HASH, recipient, SHARE_SALT, watermarkCommitment, 0);

        uint256[] memory path = registry.getSharePath(1);
        assertEq(path.length, 1);
        assertEq(path[0], 1);
    }

    function test_GetSharePathForParentChild() public {
        // First share
        bytes16 watermarkId1 = _blake2s128(abi.encode(VERSION, WORK_HASH, recipient, uint256(0), SHARE_SALT));
        bytes32 watermarkCommitment1 = keccak256(abi.encodePacked(watermarkId1));

        vm.prank(owner);
        registry.registerWork(WORK_HASH);

        vm.prank(owner);
        registry.registerShare(watermarkId1, WORK_HASH, recipient, SHARE_SALT, watermarkCommitment1, 0);

        // Second share with parent
        bytes16 watermarkId2 = _blake2s128(abi.encode(VERSION, WORK_HASH, other, uint256(1), SHARE_SALT));
        bytes32 watermarkCommitment2 = keccak256(abi.encodePacked(watermarkId2));

        vm.prank(owner);
        registry.registerShare(watermarkId2, WORK_HASH, other, SHARE_SALT, watermarkCommitment2, 1);

        uint256[] memory path = registry.getSharePath(2);
        assertEq(path.length, 2);
        assertEq(path[0], 2);
        assertEq(path[1], 1);
    }

    function test_RevokeShareSetsActiveFalse() public {
        bytes16 watermarkId = _blake2s128(abi.encode(VERSION, WORK_HASH, recipient, uint256(0), SHARE_SALT));
        bytes32 watermarkCommitment = keccak256(abi.encodePacked(watermarkId));

        vm.prank(owner);
        registry.registerWork(WORK_HASH);

        vm.prank(owner);
        registry.registerShare(watermarkId, WORK_HASH, recipient, SHARE_SALT, watermarkCommitment, 0);

        vm.prank(owner);
        registry.revokeShare(watermarkId);

        ShareRegistry.ShareRecord memory record = registry.getShareByTokenId(1);
        assertFalse(record.active);
    }

    function test_TransferIsNotAllowed() public {
        bytes16 watermarkId = _blake2s128(abi.encode(VERSION, WORK_HASH, recipient, uint256(0), SHARE_SALT));
        bytes32 watermarkCommitment = keccak256(abi.encodePacked(watermarkId));

        vm.prank(owner);
        registry.registerWork(WORK_HASH);

        vm.prank(owner);
        registry.registerShare(watermarkId, WORK_HASH, recipient, SHARE_SALT, watermarkCommitment, 0);

        vm.prank(recipient);
        vm.expectRevert("ShareNFT transfers are not allowed");
        registry.transferFrom(recipient, other, 1);
    }
}
