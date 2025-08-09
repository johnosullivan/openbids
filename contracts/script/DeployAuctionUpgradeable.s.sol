// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {AuctionProxyFactory} from "../src/AuctionProxyFactory.sol";
import {AuctionUpgradeable} from "../src/AuctionUpgradeable.sol";

/**
 * How to run:
 *  1) Set env vars:
 *     - PRIVATE_KEY: deployer EOA key
 *     - OWNER: owner address for the proxy (typically your multisig address)
 *  2) Execute:
 *     forge script script/DeployAuctionUpgradeable.s.sol:DeployAuctionUpgradeable \
 *       --broadcast --rpc-url $RPC_URL
 */
contract DeployAuctionUpgradeable is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("MULTISIG");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy factory and then deploy the Auction proxy owned by `owner`
        AuctionProxyFactory factory = new AuctionProxyFactory();
        (address implementation, address proxy) = factory.deployAuction(owner);

        console.log("AuctionUpgradeable implementation:", implementation);
        console.log("AuctionUpgradeable proxy:", proxy);
        console.log("Proxy owner (should be multisig):", owner);

        // Optional: sanity cast to interact if needed during the same broadcast
        AuctionUpgradeable auction = AuctionUpgradeable(proxy);
        // Example (commented): create an ETH auction immediately after deploy
        // uint64 nowTs = uint64(block.timestamp);
        // auction.createAuction(payable(owner), nowTs, nowTs + 3 days, 1 ether);

        vm.stopBroadcast();
    }
}

