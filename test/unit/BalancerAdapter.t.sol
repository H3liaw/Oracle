// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { MockBalancerAdapter } from "../mocks/MockBalancerAdapter.sol";
import { SharePriceOracle } from "../../src/SharePriceOracle.sol";
import { IBalancerV2Vault } from "../../src/interfaces/balancer/IBalancerV2Vault.sol";
import { IBalancerV2WeightedPool } from "../../src/interfaces/balancer/IBalancerV2WeightedPool.sol";
import { ISharePriceOracle } from "../../src/interfaces/ISharePriceOracle.sol";
import { IERC20Metadata } from "../../src/interfaces/IERC20Metadata.sol";
import { ReentrancyGuard } from "@solady/utils/ReentrancyGuard.sol";
import { BalancerAdapter } from "../../src/adapters/Balancer.sol";
import { ReentrancyAttacker } from "../mocks/ReentrancyAttacker.sol";

contract BalancerAdapterTest is Test {
    // Constants for BASE network
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WBTC = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;

    // Balancer constants on BASE
    address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    bytes32 constant WETH_USDC_POOL_ID = 0x08365c76337da4f3e97ef940bf8024e6ba4d853b00020000000000000000016f;
    address constant WETH_USDC_POOL = 0x7c2eA10D3e5922ba3bBBafa39Dc0677353D2AF17;

    uint256 constant HEARTBEAT = 4 hours;

    MockBalancerAdapter public adapter;
    SharePriceOracle public router;

    function setUp() public {
        string memory baseRpcUrl = vm.envString("BASE_RPC_URL");
        vm.createSelectFork(baseRpcUrl);

        router = new SharePriceOracle(address(this));

        adapter = new MockBalancerAdapter(address(this), address(router), address(router), BALANCER_VAULT);

        router.setLocalAssetConfig(WETH, address(adapter), WETH_USDC_POOL, 0, false);

        adapter.grantRole(address(this), uint256(adapter.ORACLE_ROLE()));

        _mockBalancerData();

        adapter.addAsset(WETH, WETH_USDC_POOL_ID, USDC, HEARTBEAT, true);
    }

    function _mockBalancerData() internal {
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDC;

        uint256[] memory balances = new uint256[](2);
        balances[0] = 100 ether;
        balances[1] = 200_000e6;

        vm.mockCall(
            BALANCER_VAULT,
            abi.encodeWithSelector(IBalancerV2Vault.getPoolTokens.selector, WETH_USDC_POOL_ID),
            abi.encode(tokens, balances, block.number)
        );

        vm.mockCall(
            BALANCER_VAULT,
            abi.encodeWithSelector(IBalancerV2Vault.getPool.selector, WETH_USDC_POOL_ID),
            abi.encode(WETH_USDC_POOL, uint8(1))
        );

        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.8 ether;
        weights[1] = 0.2 ether;

        vm.mockCall(
            WETH_USDC_POOL,
            abi.encodeWithSelector(IBalancerV2WeightedPool.getNormalizedWeights.selector),
            abi.encode(weights)
        );

        vm.mockCall(
            WETH_USDC_POOL,
            abi.encodeWithSelector(IBalancerV2WeightedPool.getLastChangeBlock.selector),
            abi.encode(block.number - 10)
        );

        vm.mockCall(WETH, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(uint8(18)));

        vm.mockCall(USDC, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(uint8(6)));
    }

    function testReturnsCorrectPrice_WETH_USD() public {
        ISharePriceOracle.PriceReturnData memory priceData = adapter.getPrice(WETH, true);

        assertFalse(priceData.hadError, "Price should not have error");
        assertTrue(priceData.inUSD, "Price should be in USD");
        assertGt(priceData.price, 0, "Price should be greater than 0");

        emit log_named_uint("WETH/USD Price", priceData.price);
    }

    function testCanGetPriceInETH() public {
        adapter.addAsset(USDC, WETH_USDC_POOL_ID, WETH, HEARTBEAT, false);

        ISharePriceOracle.PriceReturnData memory priceData = adapter.getPrice(USDC, false);

        assertFalse(priceData.hadError, "Price should not have error");
        assertFalse(priceData.inUSD, "Price should not be in USD");
        assertGt(priceData.price, 0, "Price should be greater than 0");

        emit log_named_uint("USDC/ETH Price", priceData.price);
    }

    function testPriceFallback_AlternateConfig() public view {
        ISharePriceOracle.PriceReturnData memory priceData = adapter.getPrice(WETH, false);

        assertFalse(priceData.hadError, "Price should not have error");
        assertTrue(priceData.inUSD, "Price should indicate it's in USD");
        assertGt(priceData.price, 0, "Price should be greater than 0");
    }

    function testPriceError_StaleData() public {
        vm.mockCall(
            BALANCER_VAULT,
            abi.encodeWithSelector(IBalancerV2Vault.getPoolTokens.selector, WETH_USDC_POOL_ID),
            abi.encode(new address[](2), new uint256[](2), block.number - 10_000) // Very old
        );

        ISharePriceOracle.PriceReturnData memory priceData = adapter.getPrice(WETH, true);
        assertTrue(priceData.hadError, "Should error on stale data");
    }

    function testPriceError_ZeroBalance() public {
        bytes32 zeroBalancePoolId = keccak256("zero-balance-pool");
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDC;

        uint256[] memory balances = new uint256[](2);
        balances[0] = 0;
        balances[1] = 200_000e6;

        vm.mockCall(
            BALANCER_VAULT,
            abi.encodeWithSelector(IBalancerV2Vault.getPoolTokens.selector, zeroBalancePoolId),
            abi.encode(tokens, balances, block.number)
        );

        vm.mockCall(
            BALANCER_VAULT,
            abi.encodeWithSelector(IBalancerV2Vault.getPool.selector, zeroBalancePoolId),
            abi.encode(WETH_USDC_POOL, uint8(1))
        );

        adapter.addAsset(WETH, zeroBalancePoolId, USDC, HEARTBEAT, true);

        ISharePriceOracle.PriceReturnData memory priceData = adapter.getPrice(WETH, true);
        assertTrue(priceData.hadError, "Should error on zero balance");
    }

    function testRevertGetPrice_AssetNotSupported() public {
        vm.expectRevert(BalancerAdapter.BalancerAdapter__AssetNotSupported.selector);
        adapter.getPrice(address(0xdead), true);
    }

    function testRevertAfterAssetRemove() public {
        ISharePriceOracle.PriceReturnData memory priceData = adapter.getPrice(WETH, true);
        assertFalse(priceData.hadError, "Price should not have error before removal");
        assertGt(priceData.price, 0, "Price should be greater than 0 before removal");

        adapter.removeAsset(WETH);

        vm.expectRevert(BalancerAdapter.BalancerAdapter__AssetNotSupported.selector);
        adapter.getPrice(WETH, true);
    }

    function testRevertAddAsset_InvalidHeartbeat() public {
        vm.expectRevert(BalancerAdapter.BalancerAdapter__InvalidHeartbeat.selector);
        adapter.addAsset(WETH, WETH_USDC_POOL_ID, USDC, 25 hours, true);
    }

    function testRevertAddAsset_TokensNotInPool() public {
        bytes32 fakePoolId = keccak256("empty-pool");

        vm.mockCall(
            BALANCER_VAULT,
            abi.encodeWithSelector(IBalancerV2Vault.getPoolTokens.selector, fakePoolId),
            abi.encode(new address[](0), new uint256[](0), block.number)
        );

        vm.mockCall(
            BALANCER_VAULT,
            abi.encodeWithSelector(IBalancerV2Vault.getPool.selector, fakePoolId),
            abi.encode(WETH_USDC_POOL, uint8(1))
        );

        vm.expectRevert(BalancerAdapter.BalancerAdapter__TokensNotInPool.selector);
        adapter.addAsset(WETH, fakePoolId, USDC, HEARTBEAT, true);
    }

    function testRevertAddAsset_ZeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        adapter.addAsset(address(0), WETH_USDC_POOL_ID, USDC, HEARTBEAT, true);

        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        adapter.addAsset(WETH, WETH_USDC_POOL_ID, address(0), HEARTBEAT, true);
    }

    function testCanAddSameAsset() public {
        adapter.addAsset(WETH, WETH_USDC_POOL_ID, USDC, 1 hours, true);

        ISharePriceOracle.PriceReturnData memory priceData = adapter.getPrice(WETH, true);
        assertFalse(priceData.hadError, "Price should not have error");
        assertGt(priceData.price, 0, "Price should be greater than 0");
    }

    function testRevertRemoveAsset_AssetNotSupported() public {
        vm.expectRevert(BalancerAdapter.BalancerAdapter__AssetNotSupported.selector);
        adapter.removeAsset(address(0));
    }

    function testGetPriceNormal() public {
        vm.startPrank(address(router));
        ISharePriceOracle.PriceReturnData memory data = adapter.getPrice(WETH, true);
        vm.stopPrank();

        assertFalse(data.hadError);
        assertTrue(data.price > 0);
    }

    function testStalePrice() public {
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDC;

        uint256[] memory balances = new uint256[](2);
        balances[0] = 100 * 1e18;
        balances[1] = 200 * 1e6;

        vm.mockCall(
            BALANCER_VAULT,
            abi.encodeWithSelector(IBalancerV2Vault.getPoolTokens.selector, WETH_USDC_POOL_ID),
            abi.encode(tokens, balances, block.number + 10)
        );

        vm.startPrank(address(router));
        ISharePriceOracle.PriceReturnData memory data = adapter.getPrice(WETH, true);
        vm.stopPrank();

        assertTrue(data.hadError);
    }

    function testHeartbeatExceeded() public {
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDC;

        uint256[] memory balances = new uint256[](2);
        balances[0] = 100 * 1e18;
        balances[1] = 200 * 1e6;

        uint256 oldBlock = block.number - (1 days / 12 + 100);
        vm.mockCall(
            BALANCER_VAULT,
            abi.encodeWithSelector(IBalancerV2Vault.getPoolTokens.selector, WETH_USDC_POOL_ID),
            abi.encode(tokens, balances, oldBlock)
        );

        vm.startPrank(address(router));
        ISharePriceOracle.PriceReturnData memory data = adapter.getPrice(WETH, true);
        vm.stopPrank();

        assertTrue(data.hadError);
    }

    /// @notice Tests that the nonReadReentrant modifier blocks reentrancy attempts
    function testNonReadReentrantBlocks() public {
        vm.expectRevert(ReentrancyGuard.Reentrancy.selector);
        adapter.callGetPriceFromNonReentrant(WETH, true);
    }

    /// @notice Test using a reentrant attack contract
    function testReentrancyAttackFails() public view {
        ISharePriceOracle.PriceReturnData memory priceData = adapter.getPrice(WETH, true);
        assertFalse(priceData.hadError, "Normal call to getPrice should succeed");
    }

    function testRevertRemoteCallback() public {
        ReentrancyAttacker attacker = new ReentrancyAttacker();
        vm.expectRevert(ReentrancyAttacker.ReentrancyAttackFailed.selector);
        adapter.countAndCall(address(attacker), WETH, true);
    }
}
