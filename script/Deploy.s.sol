// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GoldToken} from "../src/GoldToken.sol";
import {HeroNFT} from "../src/HeroNFT.sol";
import {DungeonGame} from "../src/DungeonGame.sol";

contract Deploy is Script {
    function run() external {
        // uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        // vm.startBroadcast(deployerKey);
        vm.startBroadcast();

        // 1. 部署代币和NFT
        GoldToken gold = new GoldToken();
        HeroNFT   nft  = new HeroNFT();

        // 2. 部署游戏主合约
        DungeonGame game = new DungeonGame(address(gold), address(nft));

        // 3. 授权
        gold.setGameContract(address(game));
        nft.setGameContract(address(game));

        vm.stopBroadcast();

        // 打印地址，部署后复制到前端
        console.log("GoldToken:", address(gold));
        console.log("HeroNFT:  ", address(nft));
        console.log("Game:     ", address(game));
    }
}