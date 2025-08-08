// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/MultiSigWallet.sol";

contract DeployMultiSig is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get owners from environment variables
        address[] memory owners = new address[](3);
        owners[0] = vm.envAddress("OWNER_1");
        owners[1] = vm.envAddress("OWNER_2");
        owners[2] = vm.envAddress("OWNER_3");
        
        // Required confirmations (default to 2)
        uint256 requiredConfirmations = vm.envOr("REQUIRED_CONFIRMATIONS", uint256(2));
        
        vm.startBroadcast(deployerPrivateKey);
        
        MultiSigWallet multiSig = new MultiSigWallet(owners, requiredConfirmations);
        
        vm.stopBroadcast();
        
        console.log("MultiSigWallet Deployed:", address(multiSig));
        console.log("Required Confirmations:", requiredConfirmations);
        console.log("Owners:");
        for (uint i = 0; i < owners.length; i++) {
            console.log("  Owner", i + 1, ":", owners[i]);
        }
    }
} 