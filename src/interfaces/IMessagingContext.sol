// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

/**
 * @title IMessagingContext
 * @notice Interface for Messaging Context
 */
interface IMessagingContext {
    /// @notice Returns if a message is being sent
    /// @return True if a message is being sent, false otherwise
    function isSendingMessage() external view returns (bool);

    /// @notice Returns the send context
    function getSendContext() external view returns (uint32 dstEid, address sender);
}
