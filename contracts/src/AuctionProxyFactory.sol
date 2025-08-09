// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AuctionUpgradeable} from "./AuctionUpgradeable.sol";

/**
 * @title AuctionProxyFactory
 * @dev Simple factory to deploy a new AuctionUpgradeable implementation and ERC1967Proxy.
 * Designed to be called by a multisig wallet which will be set as the owner of the proxy.
 */
contract AuctionProxyFactory {
    event AuctionDeployed(address indexed implementation, address indexed proxy, address indexed owner);

    function deployAuction(address owner)
        external
        returns (address implementation, address proxy)
    {
        AuctionUpgradeable impl = new AuctionUpgradeable();
        bytes memory initData = abi.encodeCall(AuctionUpgradeable.initialize, (owner));
        ERC1967Proxy p = new ERC1967Proxy(address(impl), initData);

        emit AuctionDeployed(address(impl), address(p), owner);
        return (address(impl), address(p));
    }
}

