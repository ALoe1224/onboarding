// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// OpenZeppelinのERC20を使う
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {

    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") {
        // 最初の発行量をデプロイした人に付与
        _mint(msg.sender, initialSupply);
    }
}