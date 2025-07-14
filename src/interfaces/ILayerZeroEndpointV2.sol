// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import { IMessageLibManager } from "./IMessageLibManager.sol";
import { IMessagingComposer } from "./IMessagingComposer.sol";
import { IMessagingChannel } from "./IMessagingChannel.sol";
import { IMessagingContext } from "./IMessagingContext.sol";

/*//////////////////////////////////////////////////////////////
                                STRUCTS
//////////////////////////////////////////////////////////////*/

/**
 * @title MessagingParams
 * @notice Struct for Messaging Params
 */
struct MessagingParams {
    uint32 dstEid;
    bytes32 receiver;
    bytes message;
    bytes options;
    bool payInLzToken;
}

/**
 * @title MessagingReceipt
 * @notice Struct for Messaging Receipt
 */
struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

/**
 * @title MessagingFee
 * @notice Struct for Messaging Fee
 */
struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

/**
 * @title Origin
 * @notice Struct for Origin
 */
struct Origin {
    uint32 srcEid;
    bytes32 sender;
    uint64 nonce;
}

/**
 * @title ILayerZeroEndpointV2
 * @notice Interface for LayerZero Endpoint V2
 */
interface ILayerZeroEndpointV2 is IMessageLibManager, IMessagingComposer, IMessagingChannel, IMessagingContext {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a packet is sent
    event PacketSent(bytes encodedPayload, bytes options, address sendLibrary);

    /// @notice Emitted when a packet is verified
    event PacketVerified(Origin origin, address receiver, bytes32 payloadHash);

    /// @notice Emitted when a packet is delivered
    event PacketDelivered(Origin origin, address receiver);

    /// @notice Emitted when a LzReceive alert is triggered
    event LzReceiveAlert(
        address indexed receiver,
        address indexed executor,
        Origin origin,
        bytes32 guid,
        uint256 gas,
        uint256 value,
        bytes message,
        bytes extraData,
        bytes reason
    );

    /// @notice Emitted when the LzToken is set
    event LzTokenSet(address token);

    /// @notice Emitted when the delegate is set
    event DelegateSet(address sender, address delegate);

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Quotes the fee for a message
    /// @param _params The messaging parameters
    /// @param _sender The sender of the message
    /// @return The messaging fee
    function quote(MessagingParams calldata _params, address _sender) external view returns (MessagingFee memory);

    /// @notice Sends a message
    /// @param _params The messaging parameters
    function send(
        MessagingParams calldata _params,
        address _refundAddress
    )
        external
        payable
        returns (MessagingReceipt memory);

    /// @notice Verifies a message
    /// @param _origin The origin of the message
    /// @param _receiver The receiver of the message
    /// @param _payloadHash The payload hash
    function verify(Origin calldata _origin, address _receiver, bytes32 _payloadHash) external;

    /// @notice Returns if the message is verifiable
    /// @param _origin The origin of the message
    function verifiable(Origin calldata _origin, address _receiver) external view returns (bool);

    /// @notice Returns if the message is initializable
    /// @param _origin The origin of the message
    /// @param _receiver The receiver of the message
    function initializable(Origin calldata _origin, address _receiver) external view returns (bool);

    /// @notice Receives a message
    /// @param _origin The origin of the message
    /// @param _receiver The receiver of the message
    function lzReceive(
        Origin calldata _origin,
        address _receiver,
        bytes32 _guid,
        bytes calldata _message,
        bytes calldata _extraData
    )
        external
        payable;

    /// @notice Clears a message
    /// @param _oapp The oapp that is clearing the message
    /// @param _origin The origin of the message
    /// @param _guid The guid of the message
    /// @param _message The message
    function clear(address _oapp, Origin calldata _origin, bytes32 _guid, bytes calldata _message) external;

    /// @notice Sets the LzToken
    /// @param _lzToken The LzToken
    function setLzToken(address _lzToken) external;

    /// @notice Returns the LzToken
    /// @return The LzToken
    function lzToken() external view returns (address);

    /// @notice Returns the native token
    /// @return The native token
    function nativeToken() external view returns (address);

    /// @notice Sets the delegate
    /// @param _delegate The delegate
    function setDelegate(address _delegate) external;
}
