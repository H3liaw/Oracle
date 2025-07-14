// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IMessagingChannel {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a nonce is skipped
    /// @param srcEid The source eid
    /// @param sender The sender
    /// @param receiver The receiver
    /// @param nonce The nonce
    event InboundNonceSkipped(uint32 srcEid, bytes32 sender, address receiver, uint64 nonce);

    /// @notice Emitted when a packet is nilified
    event PacketNilified(uint32 srcEid, bytes32 sender, address receiver, uint64 nonce, bytes32 payloadHash);

    /// @notice Emitted when a packet is burnt
    event PacketBurnt(uint32 srcEid, bytes32 sender, address receiver, uint64 nonce, bytes32 payloadHash);

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the eid
    /// @return The eid
    function eid() external view returns (uint32);

    /// @notice Skips a nonce
    /// @param _oapp The oapp
    /// @param _srcEid The source eid
    /// @param _sender The sender
    /// @param _nonce The nonce
    function skip(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce) external;

    /// @notice Nilifies a packet
    /// @param _oapp The oapp
    /// @param _srcEid The source eid
    /// @param _sender The sender
    /// @param _nonce The nonce
    /// @param _payloadHash The payload hash
    function nilify(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _payloadHash) external;

    /// @notice Burns a packet
    /// @param _oapp The oapp
    /// @param _srcEid The source eid
    /// @param _sender The sender
    /// @param _nonce The nonce
    /// @param _payloadHash The payload hash
    function burn(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _payloadHash) external;

    /// @notice Returns the next guid
    /// @param _sender The sender
    /// @param _dstEid The destination eid
    /// @param _receiver The receiver
    /// @return The next guid
    function nextGuid(address _sender, uint32 _dstEid, bytes32 _receiver) external view returns (bytes32);

    /// @notice Returns the inbound nonce
    /// @param _receiver The receiver
    /// @param _srcEid The source eid
    /// @param _sender The sender
    /// @return The inbound nonce
    function inboundNonce(address _receiver, uint32 _srcEid, bytes32 _sender) external view returns (uint64);

    /// @notice Returns the outbound nonce
    /// @param _sender The sender
    function outboundNonce(address _sender, uint32 _dstEid, bytes32 _receiver) external view returns (uint64);

    /// @notice Returns the inbound payload hash
    /// @param _receiver The receiver
    /// @param _srcEid The source eid
    /// @param _sender The sender
    /// @param _nonce The nonce
    /// @return The inbound payload hash
    function inboundPayloadHash(
        address _receiver,
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce
    )
        external
        view
        returns (bytes32);

    /// @notice Returns the lazy inbound nonce
    /// @param _receiver The receiver
    /// @param _srcEid The source eid
    /// @param _sender The sender
    /// @return The lazy inbound nonce
    function lazyInboundNonce(address _receiver, uint32 _srcEid, bytes32 _sender) external view returns (uint64);
}
