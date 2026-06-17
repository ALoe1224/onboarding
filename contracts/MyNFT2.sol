// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    /// NFTの所有者が変わったときに発行されるイベント。
    /// mint時は from が address(0)、burn時は to が address(0) になる。

    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    /// 特定のNFTについて、操作を許可するアドレスが設定されたときに発行されるイベント。

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    /// ownerが持つすべてのNFTについて、operatorに操作権限を与える/取り消すときに発行されるイベント。

    function balanceOf(address owner) external view returns (uint256);
    /// ownerがNFTを何個持っているかを返す。

    function ownerOf(uint256 tokenId) external view returns (address);
    /// tokenIdのNFTを誰が持っているかを返す。

    function approve(address to, uint256 tokenId) external;
    /// tokenIdのNFTを、toが操作できるように許可する。

    function getApproved(uint256 tokenId) external view returns (address);
    /// tokenIdのNFTについて、操作を許可されているアドレスを返す。

    function setApprovalForAll(address operator, bool approved) external;
    /// 自分が持つすべてのNFTについて、operatorに操作権限を与える/取り消す。

    function isApprovedForAll(address owner, address operator) external view returns (bool);
    /// operatorがownerのNFT全体を操作できるかを返す。

    function transferFrom(address from, address to, uint256 tokenId) external;
    /// NFTをfromからtoへ移動する。
}

contract MyNFT2 is IERC721{
    mapping(uint256 => address) private _owners;
    /// tokenIdごとの所有者を管理する。
    /// _owners[tokenId] が address(0) なら、そのNFTはまだ存在しない。

    mapping(address => uint256) private _balances;
    /// 各アドレスが持っているNFTの個数を管理する。

    mapping(uint256 => address) private _tokenApprovals;
    /// tokenIdごとに、操作を許可されたアドレスを管理する。

    mapping(address => mapping(address => bool)) private _operatorApprovals;
    /// _operatorApprovals[owner][operator] で、operatorがownerのNFT全体を操作できるか管理する。

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view returns (string memory) {
        return _name;
    }
    /// NFTコレクションの名前を返す。

    function symbol() public view returns (string memory) {
        return _symbol;
    }
    /// NFTコレクションのシンボルを返す。

    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "NFT: balance query for zero address");

        return _balances[owner];
    }
    /// 指定したアドレスがNFTを何個持っているか返す。

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = _owners[tokenId];

        require(owner != address(0), "NFT: owner query for nonexistent token");

        return owner;
    }
    /// tokenIdのNFTを誰が持っているか返す。

    function approve(address to, uint256 tokenId) public override {
        address owner = ownerOf(tokenId);

        require(to != owner, "NFT: approval to current owner");
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "NFT: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }
    /// tokenIdのNFTについて、toに操作権限を与える。
    /// 所有者、または全体承認されたoperatorだけが実行できる。

    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), "NFT: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }
    /// tokenIdのNFTについて、操作を許可されているアドレスを返す。

    function setApprovalForAll(address operator, bool approved) public override {
        require(operator != msg.sender, "NFT: approve to caller");

        _operatorApprovals[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }
    /// 自分が持つすべてのNFTについて、operatorに操作権限を与える/取り消す。

    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    /// operatorがownerのNFT全体を操作できるか返す。

    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "NFT: caller is not owner nor approved"
        );

        _transfer(from, to, tokenId);
    }
    /// NFTをfromからtoへ移動する。
    /// 所有者、approveされた人、または全体承認されたoperatorだけが実行できる。

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
    /// NFTを新しく発行する。 

    function burn(uint256 tokenId) public {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "NFT: caller is not owner nor approved"
        );

        _burn(tokenId);
    }
    /// NFTを焼却する。
    /// 所有者、approveされた人、または全体承認されたoperatorだけが実行できる。

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }
    /// tokenIdのNFTが存在するか確認する。

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);

        return (
            spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender)
        );
    }
    /// spenderがtokenIdのNFTを操作できるか確認する。

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "NFT: transfer from incorrect owner");
        require(to != address(0), "NFT: transfer to zero address");

        _beforeTokenTransfer(from, to, tokenId);

        delete _tokenApprovals[tokenId];
        /// 転送後は、以前のapproveを消す。

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }
    /// NFTの所有者を変更する内部関数。

    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "NFT: mint to zero address");
        require(!_exists(tokenId), "NFT: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }
    /// NFTを発行する内部関数。

    function _burn(uint256 tokenId) internal {
        address owner = ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        delete _tokenApprovals[tokenId];
        /// 焼却するNFTのapprove情報を消す。

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }
    /// NFTを焼却する内部関数。

    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;

        emit Approval(ownerOf(tokenId), to, tokenId);
    }
    /// tokenIdのNFTについて、toに操作権限を与える内部関数。

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}
    /// 転送・発行・焼却の直前に呼ばれる空の関数。
    /// 送信制限やログ追加など、後から処理を追加したいときに使える。
}y
