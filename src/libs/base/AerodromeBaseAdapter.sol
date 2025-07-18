// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ISharePriceOracle } from "../../interfaces/ISharePriceOracle.sol";
import { BaseOracleAdapter } from "./BaseOracleAdapter.sol";

/**
 * @title AerodromeBaseAdapter
 * @notice Base adapter for Aerodrome pools
 * @dev Provides price data from Aerodrome pools to the SharePriceOracle
 */
contract AerodromeBaseAdapter is BaseOracleAdapter {
    /// TYPES ///

    /// @notice Stores configuration data for Aerodrome pools.
    /// @param pool Aerodrome pool address.
    /// @param baseToken Underlying token0 address.
    /// @param baseTokenDecimals Underlying decimals for token0.
    /// @param quoteTokenDecimals Underlying decimals for token1.
    /// @param granularity Granularity for the pool.
    struct AdapterData {
        address pool;
        address baseToken;
        uint8 baseTokenDecimals;
        uint8 quoteTokenDecimals;
        uint256 granularity;
    }

    /// STORAGE ///

    /// @notice Adapter configuration data for pricing an asset.
    /// @dev Stable pool address => AdapterData.
    mapping(address => AdapterData) public adapterData;

    ISharePriceOracle public oracleRouter;

    /// EVENTS ///

    event AerodromePoolAssetAdded(address asset, AdapterData assetConfig, bool isUpdate);
    event AerodromePoolAssetRemoved(address asset);

    /// ERRORS ///

    error AerodromeAdapter__AssetIsNotSupported();
    error AerodromeAdapter__InvalidAsset();
    error AerodromeAdapter__InvalidPoolAddress();
    error AerodromeAdapter__InvalidGranularity();
    error AerodromeAdapter__BaseAndQuoteTokenDecimalsAreSame();

    /// CONSTRUCTOR ///

    constructor(
        address _admin,
        address _oracle,
        address _oracleRouter
    )
        BaseOracleAdapter(_admin, _oracle, _oracleRouter)
    {
        oracleRouter = ISharePriceOracle(_oracleRouter);
    }

    /// EXTERNAL FUNCTIONS ///

    /// @notice Retrieves the price of `asset` from Aerodrome pool
    /// @dev Price is returned in USD or ETH depending on 'inUSD' parameter.
    /// @param asset The address of the asset for which the price is needed.
    /// @param inUSD A boolean to determine if the price should be returned in
    ///              USD or not.
    /// @return pData A structure containing the price, error status,
    ///                         and the quote format of the price.
    function getPrice(
        address asset,
        bool inUSD
    )
        external
        view
        virtual
        override
        returns (ISharePriceOracle.PriceReturnData memory pData)
    { }

    /// @notice Helper function for pricing support for `asset`,
    ///         an lp token for a Univ2 style stable liquidity pool.
    /// @dev Should be called before `OracleRouter:addAssetPriceFeed`
    ///      is called.
    /// @param asset The address of the lp token to add pricing support for.
    function addAsset(address asset, AdapterData memory data) public virtual {
        // Make sure `asset` is not trying to price denominated in itself.
        if (asset == data.baseToken) {
            revert AerodromeAdapter__InvalidAsset();
        }

        if (data.granularity == 0) revert AerodromeAdapter__InvalidGranularity();

        // Save adapter data and update mapping that we support `asset` now.
        adapterData[asset] = data;

        // Check whether this is new or updated support for `asset`.
        bool isUpdate;
        if (isSupportedAsset[asset]) {
            isUpdate = true;
        }

        isSupportedAsset[asset] = true;
        emit AerodromePoolAssetAdded(asset, data, isUpdate);
    }

    /// @notice Helper function to remove a supported asset from the adapter.
    /// @dev Calls back into oracle router to notify it of its removal.
    ///      Requires that `asset` is currently supported.
    /// @param asset The address of the supported asset to remove from
    ///              the adapter.
    function removeAsset(address asset) external override {
        // Validate that `asset` is currently supported.
        if (!isSupportedAsset[asset]) {
            revert AerodromeAdapter__AssetIsNotSupported();
        }

        // Wipe config mapping entries for a gas refund.
        // Notify the adapter to stop supporting the asset.
        delete isSupportedAsset[asset];
        delete adapterData[asset];

        // Notify the oracle router that we are going to stop supporting
        // the asset.
        ISharePriceOracle(ORACLE_ROUTER_ADDRESS).notifyFeedRemoval(asset);
    }
}
