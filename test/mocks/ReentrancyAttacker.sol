// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ReentrancyAttacker {
    error ReentrancyAttackFailed();

    function callSender(bytes4 selector, address asset, bool inUSD) external {
        (bool success,) = msg.sender.call(abi.encodeWithSelector(selector, asset, inUSD));
        if (!success) revert ReentrancyAttackFailed();
    }
}
