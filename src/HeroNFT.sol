// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HeroNFT is ERC721, Ownable {
    address public gameContract;

    struct Hero {
        string name;
        uint8  level;      // 等级 1-100
        uint16 attack;     // 攻击力
        uint16 defense;    // 防御力
        uint16 hp;         // 生命值
        uint32 exp;        // 经验值
        uint8  heroClass;  // 0=战士 1=法师 2=射手
    }

    uint256 private _tokenIdCounter;
    mapping(uint256 => Hero) public heroes;

    // 每个英雄的装备加成
    mapping(uint256 => uint16) public equipmentBonus;

    event HeroMinted(address indexed owner, uint256 tokenId, Hero hero);
    event HeroLevelUp(uint256 tokenId, uint8 newLevel);

    constructor() ERC721("DungeonHero", "HERO") Ownable(msg.sender) {}

    modifier onlyGame() {
        require(msg.sender == gameContract, "Only game contract");
        _;
    }

    function setGameContract(address _game) external onlyOwner {
        gameContract = _game;
    }

    // 铸造英雄（属性伪随机，生产环境用 Chainlink VRF）
    function mintHero(
        address to,
        string calldata name,
        uint8 heroClass
    ) external onlyGame returns (uint256) {
        require(heroClass <= 2, "Invalid class");

        uint256 tokenId = _tokenIdCounter++;
        
        // 用区块信息生成伪随机数（测试用，生产用VRF）
        uint256 rand = uint256(keccak256(abi.encodePacked(
            block.timestamp, block.prevrandao, to, tokenId
        )));

        Hero memory hero;
        hero.name      = name;
        hero.level     = 1;
        hero.heroClass = heroClass;
        hero.exp       = 0;

        // 不同职业基础属性不同
        if (heroClass == 0) {       // 战士：高血量高防御
            hero.attack  = uint16(50 + (rand % 20));
            hero.defense = uint16(40 + ((rand >> 8) % 20));
            hero.hp      = uint16(200 + ((rand >> 16) % 50));
        } else if (heroClass == 1) { // 法师：高攻击低防御
            hero.attack  = uint16(80 + (rand % 30));
            hero.defense = uint16(20 + ((rand >> 8) % 10));
            hero.hp      = uint16(120 + ((rand >> 16) % 30));
        } else {                     // 射手：均衡
            hero.attack  = uint16(65 + (rand % 25));
            hero.defense = uint16(30 + ((rand >> 8) % 15));
            hero.hp      = uint16(150 + ((rand >> 16) % 40));
        }

        heroes[tokenId] = hero;
        _safeMint(to, tokenId);

        emit HeroMinted(to, tokenId, hero);
        return tokenId;
    }
    
    function getHero(uint256 tokenId) external view returns (Hero memory) {
        return heroes[tokenId];
    }

    // 游戏合约调用：增加经验
    function gainExp(uint256 tokenId, uint32 amount) external onlyGame {
        Hero storage hero = heroes[tokenId];
        hero.exp += amount;

        // 自动升级检查（每级需要 level * 100 经验）
        uint32 expNeeded = uint32(hero.level) * 100;
        if (hero.exp >= expNeeded && hero.level < 100) {
            hero.exp -= expNeeded;
            hero.level += 1;
            // 升级加属性
            hero.attack  += uint16(hero.heroClass == 1 ? 8 : 5);
            hero.defense += uint16(hero.heroClass == 0 ? 6 : 3);
            hero.hp      += uint16(hero.heroClass == 0 ? 20 : 10);
            emit HeroLevelUp(tokenId, hero.level);
        }
    }

    // 装备加成（由游戏合约写入）
    function setEquipmentBonus(uint256 tokenId, uint16 bonus) external onlyGame {
        equipmentBonus[tokenId] = bonus;
    }

    // 获取英雄总攻击力（含装备）
    function getTotalAttack(uint256 tokenId) external view returns (uint256) {
        return heroes[tokenId].attack + equipmentBonus[tokenId];
    }
}