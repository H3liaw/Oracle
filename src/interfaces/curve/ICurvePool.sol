// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

/**
 * @title ICurvePool
 * @notice Interface for Curve Pool
 */
interface ICurvePool {
    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the balance of the token at index `i`
    /// @param i The index of the token
    /// @return The balance of the token
    function balances(uint256 i) external view returns (uint256);

    /// @notice Returns the address of the token at index `i`
    /// @param i The index of the token
    /// @return The address of the token
    function coins(uint256 i) external view returns (address);

    /// @notice Returns the virtual price of the pool
    function get_virtual_price() external view returns (uint256);

    /// @notice Claims the admin fees for the pool
    /// @dev For USDT/WETH/WBTC
    function claim_admin_fees() external;

    /// @notice Withdraws the admin fees for the pool
    /// @dev For USDT/WETH/WBTC
    function withdraw_admin_fees() external;

    /// @notice Returns the gamma of the pool
    /// @return The gamma of the pool
    function gamma() external view returns (uint256);

    /// @notice Returns the A of the pool
    /// @return The A of the pool
    function A() external view returns (uint256);

    /// @notice Returns the lp price of the pool
    /// @return The lp price of the pool
    function lp_price() external view returns (uint256);

    /// @notice Returns the price oracle of the pool
    /// @return The price oracle of the pool
    function price_oracle() external view returns (uint256);

    /// @notice Returns the price oracle of the pool at index `i`
    /// @param i The index of the token
    /// @return The price oracle of the pool at index `i`
    function price_oracle(uint256 i) external view returns (uint256);

    /// @notice Exchanges the token at index `i` for the token at index `j`
    /// @param i The index of the token to exchange
    /// @param j The index of the token to receive
    /// @param dx The amount of token to exchange
    /// @param min_dy The minimum amount of token to receive
    /// @return The amount of token received
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns (uint256);

    /// @notice Returns the stored rates of the pool
    /// @return The stored rates of the pool
    function stored_rates() external view returns (uint256[2] memory);

    /// @notice Returns the amount of token received for the given amount of token
    /// @param from The index of the token to exchange
    /// @param to The index of the token to receive
    /// @param _from_amount The amount of token to exchange
    function get_dy(uint256 from, uint256 to, uint256 _from_amount) external view returns (uint256);
}
