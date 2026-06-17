// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    /// externalは外部からのみ呼び出し可能。トークンの総量を返す。

    function balanceOf(address account) external view returns (uint256);
    /// アカウントの持っているトークン量を返す。

    function transfer(address recipient, uint256 amount) external returns (bool);
    /// amountのトークンをrecipientに移動させる。成功したらbool値を返す。

    function allowance(address owner, address spender) external view returns (uint256);
    /// ownerがspenderに使用を許可する割当量の照会

    function approve(address spender, uint256 amount) external returns (bool);
    /// spenderが呼び出し元のトークンを使える量を設定する。

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    /// 許可された範囲内でsenderからrecipientへamount分のトークンを移動する。

    event Transfer(address indexed from, address indexed to, uint256 value);
    /// valueのトークンがあるアカウントから別のアカウントに移動したときに発行

    event Approval(address indexed owner, address indexed spender, uint256 value);
    /// ownerに対するspenderの割当量が設定されたときに発行
}

contract MyToken2 is IERC20 {
    mapping(address => uint256) private _balances;
    /// 残高にアクセスするには _balances[アドレス] と書く。

    mapping(address => mapping(address => uint256)) private _allowances;
    /// _allowances[owner][spender] で、spenderがownerのトークンを使える量を管理する。

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string memory name_,string memory symbol_,uint256 initialSupply) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;

        _mint(msg.sender, initialSupply * 10 ** uint256(_decimals));
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) { ///view関数は状態を確認するだけ
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];

        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance"); ///許可された量よりも多く送ろうとしてないか確認

        _transfer(sender, recipient, amount);

        _approve(sender, msg.sender, currentAllowance - amount);

        return true;
    } /// approveされた人が他人のトークンを送る関数

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);

        return true;
    } ///使用許可量を増やす

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];

        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");

        _approve(msg.sender, spender, currentAllowance - subtractedValue);

        return true;
    } ///使用許可量を減らす

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] -= amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;

        emit Transfer(address(0), account, amount);
    } ///トークンを発行する関数

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        require(_balances[account] >= amount, "ERC20: burn amount exceeds balance");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] -= amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    } ///トークンを焼却する

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;

        emit Approval(owner, spender, amount);
    }

    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
    ///送金を止めたりする際などに中身を記入する(不正なアドレスを止めたいときなど)
}