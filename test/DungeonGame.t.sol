// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GoldToken.sol";
import "../src/HeroNFT.sol";
import "../src/DungeonGame.sol";

contract DungeonGameTest is Test {
    GoldToken gold;
    HeroNFT nft;
    DungeonGame game;

    address alice = makeAddr("alice");

    function setUp() public {
        gold = new GoldToken();
        nft = new HeroNFT();
        game = new DungeonGame(address(gold), address(nft));

        // 授权游戏合约
        gold.setGameContract(address(game));
        nft.setGameContract(address(game));

        vm.deal(alice, 1 ether);

        // 把时间推到足够大，避免冷却检查失败
        vm.warp(1 days);
    }

    function test_MintHero() public {
        vm.prank(alice);
        uint256 tokenId = game.mintHero{value: 0.01 ether}("Arthur", 0);

        assertEq(nft.ownerOf(tokenId), alice);
        HeroNFT.Hero memory hero = nft.getHero(tokenId); // 改这里
        assertEq(hero.level, 1);
        assertEq(hero.heroClass, 0); // 战士
    }

    function test_Battle_Win() public {
        vm.prank(alice);
        uint256 tokenId = game.mintHero{value: 0.01 ether}("Arthur", 0);

        // 战斗史莱姆（最弱怪物）
        vm.prank(alice);
        game.battle(tokenId, 0);

        // 应该获得 GOLD
        assertGt(gold.balanceOf(alice), 0);
    }

    function test_BattleCooldown() public {
        vm.prank(alice);
        uint256 tokenId = game.mintHero{value: 0.01 ether}("Arthur", 0);

        vm.prank(alice);
        game.battle(tokenId, 0);

        // 立即再次战斗应该失败
        vm.prank(alice);
        vm.expectRevert("Hero is resting");
        game.battle(tokenId, 0);

        // 等待1小时后可以再战
        vm.warp(block.timestamp + 1 hours);
        vm.prank(alice);
        game.battle(tokenId, 0); // 不应该 revert
    }

    function test_BuyEquipment() public {
        vm.prank(alice);
        uint256 tokenId = game.mintHero{value: 0.01 ether}("Arthur", 0);

        // 先刷够 GOLD
        for (uint256 i = 0; i < 15; i++) {
            vm.prank(alice);
            game.battle(tokenId, 0);
            vm.warp(block.timestamp + 1 hours);
        }

        uint256 goldBefore = gold.balanceOf(alice);
        assertGt(goldBefore, 50 ether); // 足够买铁剑

        vm.prank(alice);
        game.buyEquipment(tokenId, 0); // 买铁剑

        // 装备加成应该生效
        assertEq(nft.equipmentBonus(tokenId), 20);
    }
}
