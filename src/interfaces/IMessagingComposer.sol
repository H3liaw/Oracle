// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

/**
 * @title IMessagingComposer
 * @notice Interface for Messaging Composer
 */
interface IMessagingComposer {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a compose is sent
    event ComposeSent(address from, address to, bytes32 guid, uint16 index, bytes message);

    /// @notice Emitted when a compose is delivered
    event ComposeDelivered(address from, address to, bytes32 guid, uint16 index);

    /// @notice Emitted when a LzCompose alert is triggered
    event LzComposeAlert(
        address indexed from,
        address indexed to,
        address indexed executor,
        bytes32 guid,
        uint16 index,
        uint256 gas,
        uint256 value,
        bytes message,
        bytes extraData,
        bytes reason
    );

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the compose queue
    function composeQueue(
        address _from,
        address _to,
        bytes32 _guid,
        uint16 _index
    )
        external
        view
        returns (bytes32 messageHash);

    /// @notice Sends a compose
    /// @param _to The to address
    /// @param _guid The guid
    /// @param _index The index
    /// @param _message The message
    function sendCompose(address _to, bytes32 _guid, uint16 _index, bytes calldata _message) external;

    /// @notice LzComposes a message
    /// @param _from The from address
    /// @param _to The to address
    /// @param _guid The guid
    /// @param _index The index
    /// @param _message The message
    /// @param _extraData The extra data
    function lzCompose(
        address _from,
        address _to,
        bytes32 _guid,
        uint16 _index,
        bytes calldata _message,
        bytes calldata _extraData
    )
        external
        payable;
}
