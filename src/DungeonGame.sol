// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GoldToken.sol";
import "./HeroNFT.sol";

contract DungeonGame {
    GoldToken public goldToken;
    HeroNFT public heroNFT;
    address public owner;

    // ─────────────────────────────────────────
    //  常量
    // ─────────────────────────────────────────
    uint256 public constant MINT_PRICE = 0.01 ether; // 铸造费用
    uint256 public constant UPGRADE_COST = 100 ether; // 升级消耗（100 GOLD）
    uint256 public constant BATTLE_COOLDOWN = 1 hours; // 战斗冷却

    // ─────────────────────────────────────────
    //  地下城怪物配置
    // ─────────────────────────────────────────
    struct Monster {
        string name;
        uint16 attack;
        uint16 defense;
        uint16 hp;
        uint32 expReward;
        uint256 goldReward; // 单位：ether（GOLD代币）
    }

    Monster[] public monsters; // 地下城关卡

    // ─────────────────────────────────────────
    //  装备配置
    // ─────────────────────────────────────────
    struct Equipment {
        string name;
        uint16 attackBonus;
        uint256 price; // GOLD价格
    }

    Equipment[] public equipments;

    // ─────────────────────────────────────────
    //  玩家状态
    // ─────────────────────────────────────────
    mapping(uint256 => uint256) public lastBattleTime; // tokenId => 时间戳
    mapping(uint256 => uint8) public heroEquipment; // tokenId => equipmentId

    // ─────────────────────────────────────────
    //  事件
    // ─────────────────────────────────────────
    event HeroMinted(address indexed player, uint256 tokenId);
    event BattleResult(
        address indexed player, uint256 heroId, uint8 monsterId, bool won, uint256 goldEarned, uint32 expEarned
    );
    event EquipmentBought(uint256 heroId, uint8 equipmentId);

    // ─────────────────────────────────────────
    //  构造函数
    // ─────────────────────────────────────────
    constructor(address _goldToken, address _heroNFT) {
        goldToken = GoldToken(_goldToken);
        heroNFT = HeroNFT(_heroNFT);
        owner = msg.sender;

        // 初始化怪物
        monsters.push(Monster("Slime", 10, 5, 30, 50, 5 ether));
        monsters.push(Monster("Goblin", 25, 15, 60, 100, 10 ether));
        monsters.push(Monster("Skeleton", 40, 30, 100, 200, 20 ether));
        monsters.push(Monster("Troll", 70, 50, 200, 400, 40 ether));
        monsters.push(Monster("Dungeon Lord", 120, 80, 500, 1000, 100 ether));

        // 初始化装备
        equipments.push(Equipment("Iron Sword", 20, 50 ether));
        equipments.push(Equipment("Steel Sword", 50, 150 ether));
        equipments.push(Equipment("Magic Staff", 80, 300 ether));
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ─────────────────────────────────────────
    //  铸造英雄
    // ─────────────────────────────────────────
    function mintHero(string calldata name, uint8 heroClass) external payable returns (uint256) {
        require(msg.value >= MINT_PRICE, "Insufficient ETH");

        uint256 tokenId = heroNFT.mintHero(msg.sender, name, heroClass);
        emit HeroMinted(msg.sender, tokenId);
        return tokenId;
    }

    // ─────────────────────────────────────────
    //  战斗系统（CEI 模式）
    // ─────────────────────────────────────────
    function battle(uint256 heroId, uint8 monsterId) external {
        // ── Checks ──
        require(heroNFT.ownerOf(heroId) == msg.sender, "Not your hero");
        require(monsterId < monsters.length, "Invalid monster");
        require(block.timestamp >= lastBattleTime[heroId] + BATTLE_COOLDOWN, "Hero is resting");

        // ── Effects（先更新状态，防重入）──
        lastBattleTime[heroId] = block.timestamp;

        Monster memory monster = monsters[monsterId];
        uint256 heroAttack = heroNFT.getTotalAttack(heroId);
        (,,,, uint16 defense, uint16 hp,,) = _getHeroStats(heroId);

        // 战斗计算
        // 回合制简化：双方轮流攻击，计算谁先死
        bool won = _calculateBattle(heroAttack, defense, hp, monster.attack, monster.defense, monster.hp);

        uint256 goldEarned = 0;
        uint32 expEarned = 0;

        if (won) {
            goldEarned = monster.goldReward;
            expEarned = monster.expReward;
        } else {
            // 失败也给少量经验
            expEarned = monster.expReward / 5;
        }

        emit BattleResult(msg.sender, heroId, monsterId, won, goldEarned, expEarned);

        // ── Interactions（最后与外部合约交互）──
        if (expEarned > 0) {
            heroNFT.gainExp(heroId, expEarned);
        }
        if (goldEarned > 0) {
            goldToken.mintReward(msg.sender, goldEarned);
        }
    }

    // ─────────────────────────────────────────
    //  回合制战斗计算
    // ─────────────────────────────────────────
    function _calculateBattle(
        uint256 heroAtk,
        uint256 heroDef,
        uint256 heroHp,
        uint256 monAtk,
        uint256 monDef,
        uint256 monHp
    ) internal pure returns (bool heroWins) {
        // 计算每回合净伤害（最低造成1点伤害）
        uint256 heroDmg = heroAtk > monDef ? heroAtk - monDef : 1;
        uint256 monDmg = monAtk > heroDef ? monAtk - heroDef : 1;

        // 计算各自需要几回合击杀对方
        uint256 roundsToKillMon = (monHp + heroDmg - 1) / heroDmg;
        uint256 roundsToKillHero = (heroHp + monDmg - 1) / monDmg;

        // 英雄先手，回合数少于等于怪物则胜利
        return roundsToKillMon <= roundsToKillHero;
    }

    // ─────────────────────────────────────────
    //  购买装备
    // ─────────────────────────────────────────
    function buyEquipment(uint256 heroId, uint8 equipmentId) external {
        require(heroNFT.ownerOf(heroId) == msg.sender, "Not your hero");
        require(equipmentId < equipments.length, "Invalid equipment");

        Equipment memory equip = equipments[equipmentId];

        // 消耗 GOLD 代币
        goldToken.burnFrom(msg.sender, equip.price);

        // 更新英雄装备（同一部位只能装一件）
        heroEquipment[heroId] = equipmentId;
        heroNFT.setEquipmentBonus(heroId, equip.attackBonus);

        emit EquipmentBought(heroId, equipmentId);
    }

    // ─────────────────────────────────────────
    //  查询：战斗冷却剩余时间
    // ─────────────────────────────────────────
    function getCooldownRemaining(uint256 heroId) external view returns (uint256) {
        uint256 readyAt = lastBattleTime[heroId] + BATTLE_COOLDOWN;
        if (block.timestamp >= readyAt) return 0;
        return readyAt - block.timestamp;
    }

    // ─────────────────────────────────────────
    //  内部：解构英雄属性
    // ─────────────────────────────────────────
    function _getHeroStats(uint256 heroId)
        internal
        view
        returns (
            string memory name,
            uint8 heroClass,
            uint8 level,
            uint16 attack,
            uint16 defense,
            uint16 hp,
            uint32 exp,
            uint16 eqBonus
        )
    {
        HeroNFT.Hero memory h = heroNFT.getHero(heroId); // 改这里
        return (h.name, h.heroClass, h.level, h.attack, h.defense, h.hp, h.exp, heroNFT.equipmentBonus(heroId));
    }

    // ─────────────────────────────────────────
    //  提取 ETH（铸造费）
    // ─────────────────────────────────────────
    function withdraw() external onlyOwner {
        (bool ok,) = owner.call{value: address(this).balance}("");
        require(ok, "Transfer failed");
    }
}
