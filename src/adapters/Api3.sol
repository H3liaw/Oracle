// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOracleAdapter } from "../libs/base/BaseOracleAdapter.sol";
import { Bytes32Helper } from "../libs/Bytes32Helper.sol";
import { ISharePriceOracle } from "../interfaces/ISharePriceOracle.sol";
import { IProxy } from "../interfaces/api3/IProxy.sol";

/**
 * @title Api3Adapter
 * @notice Adapter for Api3 price feeds
 * @dev Provides price data from Api3 price feeds to the SharePriceOracle
 */
contract Api3Adapter is BaseOracleAdapter {
    /*//////////////////////////////////////////////////////////////
                              TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Stores configuration data for API3 price sources.
    /// @param proxyFeed The current proxy's feed address.
    /// @param dapiName The bytes32 encoded name of the price feed.
    /// @param isConfigured Whether the asset is configured or not.
    ///                     false = unconfigured; true = configured.
    /// @param heartbeat The max amount of time between price updates.
    ///                  0 defaults to using DEFAULT_HEART_BEAT.
    /// @param max The max valid price of the asset.
    ///            0 defaults to use proxy max price reduced by ~10%.
    /// @param min The min valid price of the asset.
    ///            0 defaults to use proxy min price increased by ~10%.
    struct AdapterData {
        IProxy proxyFeed;
        bytes32 dapiName;
        bool isConfigured;
        uint256 heartbeat;
        uint256 max;
        uint256 min;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice If zero is specified for an Api3 asset heartbeat,
    ///         this value is used instead.
    uint256 public constant DEFAULT_HEART_BEAT = 1 days;

    /// @notice Chain WETH address
    address public immutable WETH;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Adaptor configuration data for pricing an asset.
    /// @dev Api3 Adaptor Data for pricing in gas token.
    mapping(address => AdapterData) public adapterDataNonUSD;

    /// @notice Adaptor configuration data for pricing an asset.
    /// @dev Api3 Adaptor Data for pricing in USD.
    mapping(address => AdapterData) public adapterDataUSD;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Api3AssetAdded(address asset, AdapterData assetConfig, bool isUpdate);
    event Api3AssetRemoved(address asset);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Api3Adapter__AssetNotSupported();
    error Api3Adapter__InvalidHeartbeat();
    error Api3Adapter__DAPINameError();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _admin,
        address _oracle,
        address _oracleRouter,
        address _weth
    )
        BaseOracleAdapter(_admin, _oracle, _oracleRouter)
    {
        WETH = _weth;
    }

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieves the price of a given asset
     * @dev Uses Api3 oracles to fetch the price data.
     *      Price is returned in USD or ETH depending on 'inUSD' parameter.
     * @param asset The address of the asset for which the price is needed.
     * @param inUSD A boolean to determine if the price should be returned in
     *              USD or not.
     * @return A structure containing the price, error status,
     *         and the quote format of the price.
     */
    function getPrice(
        address asset,
        bool inUSD
    )
        external
        view
        override
        returns (ISharePriceOracle.PriceReturnData memory)
    {
        // Validate we support pricing `asset`.
        if (!isSupportedAsset[asset]) {
            revert Api3Adapter__AssetNotSupported();
        }

        if (inUSD) {
            return _getPriceInUSD(asset);
        }

        return _getPriceInETH(asset);
    }

    /// @notice Add a Api3 Price Feed as an asset.
    /// @dev Should be called before `OracleRouter:addAssetPriceFeed`
    ///      is called.
    /// @param asset The address of the token to add pricing support for.
    /// @param ticker The ticker of the token to add pricing for.
    /// @param proxyFeed Api3 proxy feed to use for pricing `asset`.
    /// @param heartbeat Api3 heartbeat to use when validating prices
    ///                  for `asset`. 0 = `DEFAULT_HEART_BEAT`.
    /// @param inUSD Whether the price feed is in USD (inUSD = true)
    ///              or ETH (inUSD = false).
    function addAsset(address asset, string memory ticker, address proxyFeed, uint256 heartbeat, bool inUSD) external {
        _checkOraclePermissions();

        if (heartbeat != 0) {
            if (heartbeat > DEFAULT_HEART_BEAT) {
                revert Api3Adapter__InvalidHeartbeat();
            }
        }

        bytes32 dapiName = Bytes32Helper.stringToBytes32(ticker);

        // Validate that the dAPI name matches the proxyFeed's name
        if (dapiName != IProxy(proxyFeed).dapiName()) {
            revert Api3Adapter__DAPINameError();
        }

        AdapterData storage data;

        if (inUSD) {
            data = adapterDataUSD[asset];
        } else {
            data = adapterDataNonUSD[asset];
        }

        data.heartbeat = heartbeat != 0 ? heartbeat : DEFAULT_HEART_BEAT;

        // Add a ~10% buffer to maximum and minimum prices
        data.max = (uint256(int256(type(int224).max)) * 9) / 10;
        data.min = WAD / 1000; // 0.001 in 18 decimals
        data.dapiName = dapiName;
        data.proxyFeed = IProxy(proxyFeed);
        data.isConfigured = true;

        bool isUpdate = isSupportedAsset[asset];
        isSupportedAsset[asset] = true;

        emit Api3AssetAdded(asset, data, isUpdate);
    }

    /// @notice Removes a supported asset from the adaptor.
    /// @dev Calls back into Oracle Router to notify it of its removal.
    ///      Requires that `asset` is currently supported.
    /// @param asset The address of the supported asset to remove from
    ///              the adaptor.
    function removeAsset(address asset) external override {
        _checkOraclePermissions();

        // Validate that `asset` is currently supported.
        if (!isSupportedAsset[asset]) {
            revert Api3Adapter__AssetNotSupported();
        }

        // Notify the adaptor to stop supporting the asset.
        delete isSupportedAsset[asset];

        // Wipe config mapping entries for a gas refund.
        delete adapterDataUSD[asset];
        delete adapterDataNonUSD[asset];

        // Notify the Oracle Router that we are going to stop supporting the asset.
        ISharePriceOracle(ORACLE_ROUTER_ADDRESS).notifyFeedRemoval(asset);

        emit Api3AssetRemoved(asset);
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the price of a given asset in USD.
    /// @param asset The address of the asset for which the price is needed.
    /// @return A structure containing the price, error status,
    ///         and the quote format of the price (USD).
    function _getPriceInUSD(address asset) internal view returns (ISharePriceOracle.PriceReturnData memory) {
        if (adapterDataUSD[asset].isConfigured) {
            return _parseData(adapterDataUSD[asset], true);
        }

        return _parseData(adapterDataNonUSD[asset], false);
    }

    /// @notice Retrieves the price of a given asset in ETH.
    /// @param asset The address of the asset for which the price is needed.
    /// @return A structure containing the price, error status,
    ///         and the quote format of the price (ETH).
    function _getPriceInETH(address asset) internal view returns (ISharePriceOracle.PriceReturnData memory) {
        if (adapterDataNonUSD[asset].isConfigured) {
            return _parseData(adapterDataNonUSD[asset], false);
        }

        return _parseData(adapterDataUSD[asset], true);
    }

    /// @notice Parses the api3 feed data for pricing of an asset.
    /// @dev Calls read() from Api3 to get the latest data
    ///      for pricing and staleness.
    /// @param data Api3 feed details.
    /// @param inUSD A boolean to denote if the price is in USD.
    /// @return pData A structure containing the price, error status,
    ///               and the currency of the price.
    function _parseData(
        AdapterData memory data,
        bool inUSD
    )
        internal
        view
        returns (ISharePriceOracle.PriceReturnData memory pData)
    {
        (int256 price, uint256 updatedAt) = data.proxyFeed.read();

        if (price <= 0) {
            pData.hadError = true;
            return pData;
        }

        uint256 rawPrice = uint256(price);

        if (rawPrice > type(uint240).max) {
            rawPrice = type(uint240).max;
        }

        pData.price = uint240(rawPrice);
        pData.hadError = _verifyData(rawPrice, updatedAt, data.max, data.min, data.heartbeat);
        pData.inUSD = inUSD;
    }

    /// @notice Validates the feed data based on various constraints.
    /// @dev Checks if the value is within a specific range
    ///      and if the data is not outdated.
    /// @param value The value that is retrieved from the feed data.
    /// @param timestamp The time at which the value was last updated.
    /// @param max The maximum limit of the value.
    /// @param min The minimum limit of the value.
    /// @param heartbeat The maximum allowed time difference between
    ///                  current time and 'timestamp'.
    /// @return A boolean indicating whether the feed data had an error
    ///         (true = error, false = no error).
    function _verifyData(
        uint256 value,
        uint256 timestamp,
        uint256 max,
        uint256 min,
        uint256 heartbeat
    )
        internal
        view
        returns (bool)
    {
        // Check minimum value
        if (value < min) {
            return true;
        }

        // Check maximum value
        if (value > max) {
            return true;
        }

        // Check staleness
        if (block.timestamp - timestamp > heartbeat) {
            return true;
        }

        return false;
    }
}
