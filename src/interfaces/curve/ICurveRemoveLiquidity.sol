//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICurveRemoveLiquidity
 * @notice Interface for Curve Remove Liquidity
 */
interface ICurveRemoveLiquidity {
    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Removes liquidity from the pool
    /// @param _tokenAmount The amount of token to remove
    /// @param _amounts The amounts of each token to remove
    function remove_liquidity(uint256 _tokenAmount, uint256[2] calldata _amounts) external view;

    /// @notice Removes liquidity from the pool
    /// @param _tokenAmount The amount of token to remove
    /// @param _amounts The amounts of each token to remove
    function remove_liquidity(uint256 _tokenAmount, uint256[3] calldata _amounts) external view;

    /// @notice Removes liquidity from the pool
    /// @param _tokenAmount The amount of token to remove
    /// @param _amounts The amounts of each token to remove
    function remove_liquidity(uint256 _tokenAmount, uint256[4] calldata _amounts) external view;
}
