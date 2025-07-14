// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BalancerAdapter } from "../../src/adapters/Balancer.sol";
import { ReentrancyAttacker } from "./ReentrancyAttacker.sol";

contract MockBalancerAdapter is BalancerAdapter {
    constructor(
        address admin,
        address oracle,
        address oracleRouter,
        address balancerVault
    )
        BalancerAdapter(admin, oracle, oracleRouter, balancerVault)
    { }

    function callGetPriceFromNonReentrant(address asset, bool inUSD) external nonReentrant {
        this.getPrice(asset, inUSD);
    }

    function countAndCall(address attacker, address asset, bool inUSD) external nonReentrant {
        ReentrancyAttacker(attacker).callSender(this.getPrice.selector, asset, inUSD);
    }
}
