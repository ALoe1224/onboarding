// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ShareRegistry is ERC721, Ownable {
    struct ShareRecord {
        bytes32 workHash;
        address issuer;
        address recipient;
        bytes32 shareSalt;
        bytes32 watermarkCommitment;  // keccak256(watermarkId) - 公開IDの整合性確認用
        uint256 parentTokenId;         // 親トークンID (初回は0)
        uint64 issuedAt;
        bool active;
        bool exists;
    }

    mapping(bytes16 => uint256) public tokenIdByWatermarkId;
    mapping(bytes32 => uint256) public tokenIdByCommitment;  // watermarkCommitment => tokenId
    mapping(bytes32 => address) public workOwners;
    mapping(uint256 => ShareRecord) public shareRecordsByTokenId;  // tokenId => ShareRecord
    
    uint256 private nextTokenId = 1;

    event WorkRegistered(bytes32 indexed workHash, address indexed owner);
    event ShareRegistered(
        bytes16 indexed watermarkId,
        bytes32 indexed watermarkCommitment,
        uint256 indexed tokenId,
        bytes32 workHash,
        address recipient,
        address issuer,
        uint256 parentTokenId,
        uint64 issuedAt
    );
    event ShareRevoked(bytes16 indexed watermarkId, address indexed issuer, uint64 revokedAt);

    constructor() ERC721("ShareNFT", "SHARE") Ownable() {}

    function registerWork(bytes32 workHash) external {
        require(workHash != bytes32(0), "invalid workHash");
        require(workOwners[workHash] == address(0), "work already registered");

        workOwners[workHash] = msg.sender;
        emit WorkRegistered(workHash, msg.sender);
    }

    function registerShare(
        bytes16 watermarkId,
        bytes32 workHash,
        address recipient,
        bytes32 shareSalt,
        bytes32 watermarkCommitment,
        uint256 parentTokenId
    ) external onlyOwner {
        require(watermarkId != bytes16(0), "invalid watermarkId");
        require(recipient != address(0), "invalid recipient");
        require(shareSalt != bytes32(0), "invalid salt");
        require(workHash != bytes32(0), "invalid workHash");
        require(workOwners[workHash] == msg.sender, "work is not registered by issuer");
        require(tokenIdByWatermarkId[watermarkId] == 0, "watermarkId already registered");
        require(watermarkCommitment != bytes32(0), "invalid watermarkCommitment");
        require(watermarkCommitment == keccak256(abi.encodePacked(watermarkId)), "commitment mismatch");
        require(tokenIdByCommitment[watermarkCommitment] == 0, "commitment already used");
        
        // 親トークンIDの確認 (0でない場合)
        if (parentTokenId != 0) {
            require(shareRecordsByTokenId[parentTokenId].exists, "parent token does not exist");
            require(shareRecordsByTokenId[parentTokenId].workHash == workHash, "parent workHash mismatch");
        }

        uint256 tokenId = nextTokenId++;
        address issuer = msg.sender;

        ShareRecord memory record = ShareRecord({
            workHash: workHash,
            issuer: issuer,
            recipient: recipient,
            shareSalt: shareSalt,
            watermarkCommitment: watermarkCommitment,
            parentTokenId: parentTokenId,
            issuedAt: uint64(block.timestamp),
            active: true,
            exists: true
        });

        shareRecordsByTokenId[tokenId] = record;
        tokenIdByWatermarkId[watermarkId] = tokenId;
        tokenIdByCommitment[watermarkCommitment] = tokenId;

        // NFTをmint (recipient所有にする)
        _mint(recipient, tokenId);

        emit ShareRegistered(
            watermarkId,
            watermarkCommitment,
            tokenId,
            workHash,
            recipient,
            issuer,
            parentTokenId,
            uint64(block.timestamp)
        );
    }

    function getShare(bytes16 watermarkId)
        external
        view
        returns (
            bytes32 workHash,
            address issuer,
            address recipient,
            bytes32 shareSalt,
            bytes32 watermarkCommitment,
            uint256 parentTokenId,
            uint64 issuedAt,
            bool active
        )
    {
        uint256 tokenId = tokenIdByWatermarkId[watermarkId];
        require(tokenId != 0, "share not found");
        ShareRecord storage record = shareRecordsByTokenId[tokenId];
        return (
            record.workHash,
            record.issuer,
            record.recipient,
            record.shareSalt,
            record.watermarkCommitment,
            record.parentTokenId,
            record.issuedAt,
            record.active
        );
    }

    // watermarkCommitmentからtokenIdを取得
    function getTokenIdByCommitment(bytes32 commitment) external view returns (uint256) {
        return tokenIdByCommitment[commitment];
    }

    // tokenIdから共有情報を取得
    function getShareByTokenId(uint256 tokenId)
        external
        view
        returns (ShareRecord memory)
    {
        require(shareRecordsByTokenId[tokenId].exists, "token not found");
        return shareRecordsByTokenId[tokenId];
    }

    // tokenIdから親トークンIDを取得
    function getParentTokenId(uint256 tokenId) external view returns (uint256) {
        require(shareRecordsByTokenId[tokenId].exists, "token not found");
        return shareRecordsByTokenId[tokenId].parentTokenId;
    }

    // 共有ツリーを辿る
    function getSharePath(uint256 tokenId) external view returns (uint256[] memory) {
        require(shareRecordsByTokenId[tokenId].exists, "token not found");

        uint256 pathLength = 0;
        uint256 current = tokenId;
        while (current != 0) {
            pathLength++;
            current = shareRecordsByTokenId[current].parentTokenId;
        }

        uint256[] memory path = new uint256[](pathLength);
        current = tokenId;
        for (uint256 i = 0; current != 0; i++) {
            path[i] = current;
            current = shareRecordsByTokenId[current].parentTokenId;
        }

        return path;
    }

    function revokeShare(bytes16 watermarkId) external onlyOwner {
        uint256 tokenId = tokenIdByWatermarkId[watermarkId];
        require(tokenId != 0, "share not found");
        ShareRecord storage record = shareRecordsByTokenId[tokenId];
        require(record.active, "already revoked");

        record.active = false;
        emit ShareRevoked(watermarkId, msg.sender, uint64(block.timestamp));
    }

    // NFT転送を禁止 (共有記録を保護するため)
    function transferFrom(address from, address to, uint256 tokenId)
        public
        override
    {
        revert("ShareNFT transfers are not allowed");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId)
        public
        override
    {
        revert("ShareNFT transfers are not allowed");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
    {
        revert("ShareNFT transfers are not allowed");
    }
}
