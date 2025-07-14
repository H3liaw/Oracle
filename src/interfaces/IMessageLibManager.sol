// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

/**
 * @title SetConfigParam
 * @notice Struct for Set Config Param
 */
struct SetConfigParam {
    uint32 eid;
    uint32 configType;
    bytes config;
}

/**
 * @title IMessageLibManager
 * @notice Interface for Message Lib Manager
 */
interface IMessageLibManager {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct for Timeout
    struct Timeout {
        address lib;
        uint256 expiry;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a library is registered
    event LibraryRegistered(address newLib);

    /// @notice Emitted when a default send library is set
    event DefaultSendLibrarySet(uint32 eid, address newLib);

    /// @notice Emitted when a default receive library is set
    event DefaultReceiveLibrarySet(uint32 eid, address newLib);

    /// @notice Emitted when a default receive library timeout is set
    event DefaultReceiveLibraryTimeoutSet(uint32 eid, address oldLib, uint256 expiry);

    /// @notice Emitted when a send library is set
    event SendLibrarySet(address sender, uint32 eid, address newLib);

    /// @notice Emitted when a receive library is set
    event ReceiveLibrarySet(address receiver, uint32 eid, address newLib);

    /// @notice Emitted when a receive library timeout is set
    event ReceiveLibraryTimeoutSet(address receiver, uint32 eid, address oldLib, uint256 timeout);

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a library
    /// @param _lib The library to register
    function registerLibrary(address _lib) external;

    /// @notice Returns if a library is registered
    /// @param _lib The library to check
    /// @return True if the library is registered, false otherwise
    function isRegisteredLibrary(address _lib) external view returns (bool);

    /// @notice Returns the registered libraries
    /// @return The registered libraries
    function getRegisteredLibraries() external view returns (address[] memory);

    /// @notice Sets the default send library
    /// @param _eid The eid
    /// @param _newLib The new library
    function setDefaultSendLibrary(uint32 _eid, address _newLib) external;

    /// @notice Returns the default send library
    /// @param _eid The eid
    /// @return The default send library
    function defaultSendLibrary(uint32 _eid) external view returns (address);

    /// @notice Sets the default receive library
    /// @param _eid The eid
    /// @param _newLib The new library
    /// @param _gracePeriod The grace period
    function setDefaultReceiveLibrary(uint32 _eid, address _newLib, uint256 _gracePeriod) external;

    /// @notice Returns the default receive library
    /// @param _eid The eid
    function defaultReceiveLibrary(uint32 _eid) external view returns (address);

    /// @notice Sets the default receive library timeout
    /// @param _eid The eid
    /// @param _lib The library
    /// @param _expiry The expiry
    function setDefaultReceiveLibraryTimeout(uint32 _eid, address _lib, uint256 _expiry) external;

    /// @notice Returns the default receive library timeout
    /// @param _eid The eid
    function defaultReceiveLibraryTimeout(uint32 _eid) external view returns (address lib, uint256 expiry);

    /// @notice Returns if an eid is supported
    /// @param _eid The eid
    /// @return True if the eid is supported, false otherwise
    function isSupportedEid(uint32 _eid) external view returns (bool);

    /// @notice Returns if a receive library is valid
    /// @param _receiver The receiver
    /// @param _eid The eid
    function isValidReceiveLibrary(address _receiver, uint32 _eid, address _lib) external view returns (bool);

    /// ------------------- OApp interfaces -------------------

    /// @notice Sets the send library
    /// @param _oapp The oapp
    /// @param _eid The eid
    /// @param _newLib The new library
    function setSendLibrary(address _oapp, uint32 _eid, address _newLib) external;

    /// @notice Returns the send library
    function getSendLibrary(address _sender, uint32 _eid) external view returns (address lib);

    /// @notice Returns if a default send library is set
    /// @param _sender The sender
    /// @param _eid The eid
    /// @return True if the default send library is set, false otherwise
    function isDefaultSendLibrary(address _sender, uint32 _eid) external view returns (bool);

    /// @notice Sets the receive library
    /// @param _oapp The oapp
    function setReceiveLibrary(address _oapp, uint32 _eid, address _newLib, uint256 _gracePeriod) external;

    /// @notice Returns the receive library
    function getReceiveLibrary(address _receiver, uint32 _eid) external view returns (address lib, bool isDefault);

    /// @notice Sets the receive library timeout
    /// @param _oapp The oapp
    function setReceiveLibraryTimeout(address _oapp, uint32 _eid, address _lib, uint256 _expiry) external;

    /// @notice Returns the receive library timeout
    function receiveLibraryTimeout(
        address _receiver,
        uint32 _eid
    )
        external
        view
        returns (address lib, uint256 expiry);

    /// @notice Sets the config
    /// @param _oapp The oapp
    /// @param _lib The library
    /// @param _params The params
    function setConfig(address _oapp, address _lib, SetConfigParam[] calldata _params) external;

    /// @notice Returns the config
    /// @param _oapp The oapp
    function getConfig(
        address _oapp,
        address _lib,
        uint32 _eid,
        uint32 _configType
    )
        external
        view
        returns (bytes memory config);
}
