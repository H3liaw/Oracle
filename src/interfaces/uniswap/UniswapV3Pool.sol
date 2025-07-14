// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

/**
 * @title UniswapV3Pool
 * @notice Interface for Uniswap V3 Pool
 */
interface UniswapV3Pool {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when liquidity is removed from the pool
    /// @param owner The address that owns the liquidity
    /// @param tickLower The lower tick
    /// @param tickUpper The upper tick
    /// @param amount The amount of liquidity removed
    /// @param amount0 The amount of token0 removed
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when liquidity is collected from the pool
    /// @param owner The address that owns the liquidity
    /// @param recipient The address that receives the liquidity
    /// @param tickLower The lower tick
    /// @param tickUpper The upper tick
    /// @param amount0 The amount of token0 collected
    /// @param amount1 The amount of token1 collected
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /// @notice Emitted when protocol fees are collected from the pool
    /// @param sender The address that sends the fees
    /// @param recipient The address that receives the fees
    /// @param amount0 The amount of token0 collected
    /// @param amount1 The amount of token1 collected
    event CollectProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);

    /// @notice Emitted when a flash loan is executed
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// @notice Emitted when the observation cardinality is increased
    /// @param observationCardinalityNextOld The old observation cardinality
    /// @param observationCardinalityNextNew The new observation cardinality
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld, uint16 observationCardinalityNextNew
    );

    /// @notice Emitted when the pool is initialized
    /// @param sqrtPriceX96 The sqrt of the price
    /// @param tick The tick
    event Initialize(uint160 sqrtPriceX96, int24 tick);

    /// @notice Emitted when liquidity is minted to the pool
    /// @param sender The address that sends the liquidity
    /// @param owner The address that owns the liquidity
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when the fee protocol is set
    /// @param feeProtocol0Old The old fee protocol for token0
    /// @param feeProtocol1Old The old fee protocol for token1
    /// @param feeProtocol0New The new fee protocol for token0
    /// @param feeProtocol1New The new fee protocol for token1
    event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);

    /// @notice Emitted when a swap is executed
    /// @param sender The address that sends the swap
    /// @param recipient The address that receives the swap
    /// @param amount0 The amount of token0 swapped
    /// @param amount1 The amount of token1 swapped
    /// @param sqrtPriceX96 The sqrt of the price
    /// @param liquidity The liquidity
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when liquidity is burned from the pool
    /// @param tickLower The lower tick
    /// @param tickUpper The upper tick
    /// @param amount The amount of liquidity burned
    /// @param amount0 The amount of token0 burned
    /// @param amount1 The amount of token1 burned
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    )
        external
        returns (uint256 amount0, uint256 amount1);

    /// @notice Emitted when liquidity is collected from the pool
    /// @param recipient The address that receives the liquidity
    /// @param tickLower The lower tick
    /// @param tickUpper The upper tick
    /// @param amount0Requested The amount of token0 requested
    /// @param amount1Requested The amount of token1 requested
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    )
        external
        returns (uint128 amount0, uint128 amount1);

    /// @notice Emitted when protocol fees are collected from the pool
    /// @param recipient The address that receives the fees
    /// @param amount0Requested The amount of token0 requested
    /// @param amount1Requested The amount of token1 requested
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    )
        external
        returns (uint128 amount0, uint128 amount1);

    /// @notice Returns the factory address
    /// @return The factory address
    function factory() external view returns (address);

    /// @notice Returns the fee
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice Returns the fee growth global0X128
    /// @return The fee growth global0X128
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice Returns the fee growth global1X128
    /// @return The fee growth global1X128
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice Executes a flash loan
    /// @param recipient The address that receives the flash loan
    /// @param amount0 The amount of token0 to borrow
    /// @param amount1 The amount of token1 to borrow
    /// @param data Additional data to pass to the recipient
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes memory data) external;

    /// @notice Increases the observation cardinality
    /// @param observationCardinalityNext The new observation cardinality
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;

    /// @notice Initializes the pool
    /// @param sqrtPriceX96 The sqrt of the price
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Returns the liquidity
    /// @return The liquidity
    function liquidity() external view returns (uint128);

    /// @notice Returns the max liquidity per tick
    /// @return The max liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);

    /// @notice Mints liquidity to the pool
    /// @param recipient The address that receives the liquidity
    /// @param tickLower The lower tick
    /// @param tickUpper The upper tick
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes memory data
    )
        external
        returns (uint256 amount0, uint256 amount1);

    /// @notice Returns the observations
    function observations(uint256)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );

    /// @notice Returns the observations
    function observe(uint32[] memory secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    /// @notice Returns the positions
    function positions(bytes32)
        external
        view
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice Returns the protocol fees
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice Sets the fee protocol
    /// @param feeProtocol0 The fee protocol for token0
    /// @param feeProtocol1 The fee protocol for token1
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /// @notice Returns the slot0
    /// @return sqrtPriceX96 The sqrt of the price
    /// @return tick The tick
    /// @return observationIndex The observation index
    /// @return observationCardinality The observation cardinality
    /// @return observationCardinalityNext The observation cardinality next
    /// @return feeProtocol The fee protocol
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice Returns the snapshot cumulatives inside
    /// @param tickLower The lower tick
    /// @param tickUpper The upper tick
    /// @return tickCumulativeInside The tick cumulative inside
    /// @return secondsPerLiquidityInsideX128 The seconds per liquidity inside X128
    /// @return secondsInside The seconds inside
    function snapshotCumulativesInside(
        int24 tickLower,
        int24 tickUpper
    )
        external
        view
        returns (int56 tickCumulativeInside, uint160 secondsPerLiquidityInsideX128, uint32 secondsInside);

    /// @notice Swaps
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes memory data
    )
        external
        returns (int256 amount0, int256 amount1);

    /// @notice Returns the tick bitmap
    function tickBitmap(int16) external view returns (uint256);

    /// @notice Returns the tick spacing
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice Returns the ticks
    function ticks(int24)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice Returns the token0
    /// @return The token0
    function token0() external view returns (address);

    /// @notice Returns the token1
    /// @return The token1
    function token1() external view returns (address);
}
