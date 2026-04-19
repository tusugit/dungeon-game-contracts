// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GoldToken is ERC20, Ownable {
    address public gameContract;

    constructor() ERC20("Gold", "GOLD") Ownable(msg.sender) {}

    modifier onlyGame() {
        require(msg.sender == gameContract, "Only game contract");
        _;
    }

    function setGameContract(address _game) external onlyOwner {
        gameContract = _game;
    }

    // 只有游戏合约可以铸造奖励
    function mintReward(address to, uint256 amount) external onlyGame {
        _mint(to, amount);
    }

    // 只有游戏合约可以销毁（升级消耗）
    function burnFrom(address from, uint256 amount) public onlyGame {
        _burn(from, amount);
    }
}
