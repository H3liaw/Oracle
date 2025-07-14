// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { CcipClient } from "../libs/CcipClient.sol";

/**
 * @title IAny2EVMMessageReceiver
 * @notice Interface for Any2EVM Message Receiver
 */
interface IAny2EVMMessageReceiver {
    /// @notice Called by the Router to deliver a message.
    /// @param message CCIP Message
    /// @dev Note ensure you check the msg.sender is the OffRampRouter
    /// @notice Called by the Router to deliver a message.
    /// If this reverts, any token transfers also revert. The message
    /// will move to a FAILED state and become available for manual execution.
    /// @param message CCIP Message
    /// @dev Note ensure you check the msg.sender is the OffRampRouter
    function ccipReceive(CcipClient.Any2EVMMessage calldata message) external;
}
