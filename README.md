# Dungeon Game Contracts

链上区块链 RPG 游戏合约，部署于 Sepolia 测试网。

## 合约地址
- GoldToken: `0x7117ebFC6B5096A8e381f89cF7229b5e89967EC0`
- HeroNFT:   `0x7ae08b23E2B2D8405675547a49C19264f86e5EB3`
- Game:      `0x773aeEff019b1113Cd1A57BB1F7F72B5E8cAf802`

## 架构
- GoldToken (ERC-20) — 游戏代币，仅游戏合约可铸造/销毁
- HeroNFT (ERC-721) — 英雄 NFT，含升级/装备系统
- DungeonGame — 核心逻辑，CEI 模式，冷却机制

## 安全分析
发现前端预测攻击漏洞：玩家可链下模拟 pure 函数战斗结果后选择性提交。
修复方案：block.prevrandao 随机扰动 / commit-reveal / Chainlink VRF

## 快速开始
\```bash
forge install
forge test -vv
\```