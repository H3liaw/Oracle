// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import { Origin } from "./ILayerZeroEndpointV2.sol";

/**
 * @title ILayerZeroReceiver
 * @notice Interface for LayerZero Receiver
 */
interface ILayerZeroReceiver {
    /// @notice Returns if the path is allowed to be initialized
    /// @param _origin The origin of the message
    function allowInitializePath(Origin calldata _origin) external view returns (bool);

    /// @notice Returns the next nonce
    /// @param _eid The eid
    /// @param _sender The sender
    /// @return The next nonce
    function nextNonce(uint32 _eid, bytes32 _sender) external view returns (uint64);

    /// @notice Receives a message
    /// @param _origin The origin of the message
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    )
        external
        payable;
}
