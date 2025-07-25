// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AerodromeBaseAdapter } from "../libs/base/AerodromeBaseAdapter.sol";
import { ISharePriceOracle } from "../interfaces/ISharePriceOracle.sol";
import { IAerodromeV1Pool } from "../interfaces/aerodrome/IAerodromeV1Pool.sol";
import { IERC20Metadata } from "../interfaces/IERC20Metadata.sol";

/**
 * @title AerodromeV1Adapter
 * @notice Adapter for Aerodrome V1 pools
 * @dev Provides price data from Aerodrome V1 pools to the SharePriceOracle
 */
contract AerodromeV1Adapter is AerodromeBaseAdapter {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the AerodromeV1Adapter
     * @param _admin Address that will have admin privileges
     * @param _oracle Address that will have oracle privileges
     * @param _oracleRouter Address of the Oracle Router contract
     */
    constructor(
        address _admin,
        address _oracle,
        address _oracleRouter
    )
        AerodromeBaseAdapter(_admin, _oracle, _oracleRouter)
    { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the price of `asset` from Aerodrome pool using TWAP
    /// @dev Price is returned in USD or ETH depending on 'inUSD' parameter.
    /// @param asset The address of the asset for which the price is needed.
    /// @param inUSD A boolean to determine if the price should be returned in
    ///              USD or not.
    /// @return pData A structure containing the price, error status,
    ///                       and the quote format of the price.
    function getPrice(
        address asset,
        bool inUSD
    )
        external
        view
        virtual
        override
        returns (ISharePriceOracle.PriceReturnData memory pData)
    {
        // Validate we support pricing `asset`.
        if (!isSupportedAsset[asset]) {
            revert AerodromeAdapter__AssetIsNotSupported();
        }

        AdapterData memory data = adapterData[asset];

        // Get underlying token prices.
        (uint256 basePrice, bool errorCode) = oracleRouter.getPrice(data.baseToken, inUSD);
        if (errorCode) {
            pData.hadError = true;
            return pData;
        }

        uint256 price =
            IAerodromeV1Pool(data.pool).quote(asset, uint256(1 * (10 ** data.quoteTokenDecimals)), data.granularity);

        price = (price * basePrice) / WAD;

        if (_checkOracleOverflow(price)) {
            pData.hadError = true;
            return pData;
        }

        pData.inUSD = inUSD;
        pData.price = uint240(price);
    }

    /// @notice Helper function for pricing support for `asset`,
    ///         an lp token for a Univ2 style stable liquidity pool.
    /// @dev Should be called before `OracleRouter:addAssetPriceFeed`
    ///      is called.
    /// @param asset The address of the lp token to add pricing support for.
    function addAsset(address asset, AdapterData memory data) public override {
        _checkOraclePermissions();

        if (IERC20Metadata(asset).decimals() != data.quoteTokenDecimals) {
            revert AerodromeAdapter__InvalidAsset();
        }

        if (!isAeroPool(data.pool)) {
            revert AerodromeAdapter__InvalidPoolAddress();
        }

        super.addAsset(asset, data);
    }

    /// @notice Checks if the pool is an Aerodrome V1 pool
    /// @param pool The address of the pool to check
    /// @return True if the pool is an Aerodrome V1 pool, false otherwise
    function isAeroPool(address pool) public view returns (bool) {
        try IAerodromeV1Pool(pool).token0() returns (address) {
            return true;
        } catch {
            return false;
        }
    }
}
