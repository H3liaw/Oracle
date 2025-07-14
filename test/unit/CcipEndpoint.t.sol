// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/CCIPEndpoint.sol";
import "../../src/interfaces/ISharePriceOracle.sol";
import "../../src/SharePriceOracle.sol";
import "../../src/interfaces/ICCIPEndpoint.sol";
import { CcipClient } from "../../src/libs/CcipClient.sol";
import { BaseTest } from "../base/BaseTest.t.sol";
import { ChainlinkAdapter } from "../../src/adapters/Chainlink.sol";
import { ICCIPEndpoint } from "../../src/interfaces/ICCIPEndpoint.sol";

contract MaxCCIPEndpoint_Test is BaseTest {
    // CCIP router addresses
    address constant BASE_ROUTER = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;
    address constant POLYGON_ROUTER = 0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe;

    // Chain selectors
    uint64 constant BASE_CHAIN_SELECTOR = 15_971_525_489_660_198_786;
    uint64 constant POLYGON_CHAIN_SELECTOR = 4_051_577_828_743_386_545;

    // Link token addresses
    address constant BASE_LINK = 0xd403D1624DAEF243FbcBd4A80d8A6F36afFe32b2;
    address constant POLYGON_LINK = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39;

    // address constant VAULT = 0xA70b9595bad8EdbEfa9F416ee36061b1fA8d1160;

    // Constants for BASE network
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WBTC = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;

    //constants for POLYGON network
    address constant USDC_POLYGON = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address constant WETH_POLYGON = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address constant WBTC_POLYGON = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;

    // Chainlink price feed addresses on BASE
    address constant BASE_ETH_USD_FEED = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address constant BASE_BTC_USD_FEED = 0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E;

    // Chainlink price feed addresses on POLYGON
    address constant POLYGON_ETH_USD_FEED = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
    address constant POLYGON_BTC_USD_FEED = 0xc907E116054Ad103354f2D350FD2514433D57F6f;

    // Heartbeat values
    uint256 constant ETH_HEARTBEAT = 1200; // 20 minutes
    uint256 constant BTC_HEARTBEAT = 1200; // 20 minutes

    // Contracts
    MaxCCIPEndpoint public baseEndpoint;
    MaxCCIPEndpoint public polygonEndpoint;
    SharePriceOracle public baseOracle;
    SharePriceOracle public polygonOracle;
    IERC4626 public vault;

    address public admin;
    string[] public CHAINS = ["BASE", "POLYGON"];
    uint256[] public FORK_BLOCKS = [29_532_162, 70_862_067];

    event SharePricesSent(uint64 indexed dstChainSelector, address[] vaults);

    function setUp() public {
        // Create address for admin
        admin = makeAddr("admin");
        vm.label(admin, "Admin");

        // Setup multi-chain environment with forks
        _setUp(CHAINS, FORK_BLOCKS);

        vault = IERC4626(0xA70b9595bad8EdbEfa9F416ee36061b1fA8d1160);
        vm.makePersistent(address(vault));

        // Make router addresses persistent between forks
        vm.makePersistent(BASE_ROUTER);
        vm.makePersistent(POLYGON_ROUTER);
        vm.makePersistent(BASE_LINK);
        vm.makePersistent(POLYGON_LINK);

        // Setup BASE chain
        switchTo("BASE");

        // Deploy mock oracle on BASE
        baseOracle = new SharePriceOracle(admin);
        vm.label(address(baseOracle), "Base Oracle");

        // Deploy MaxCCIPEndpoint on BASE
        baseEndpoint = new MaxCCIPEndpoint(admin, BASE_ROUTER, address(baseOracle));
        vm.label(address(baseEndpoint), "Base MaxCCIPEndpoint");

        // Fund the endpoint contract
        vm.deal(address(baseEndpoint), 1 ether);
        vm.deal(admin, 10 ether);

        // Setup POLYGON chain
        switchTo("POLYGON");

        // Deploy mock oracle on POLYGON
        polygonOracle = new SharePriceOracle(admin);
        vm.label(address(polygonOracle), "Polygon Oracle");

        // Deploy MaxCCIPEndpoint on POLYGON
        polygonEndpoint = new MaxCCIPEndpoint(admin, POLYGON_ROUTER, address(polygonOracle));
        vm.label(address(polygonEndpoint), "Polygon MaxCCIPEndpoint");

        // Fund the endpoint contract
        vm.deal(address(polygonEndpoint), 1 ether);
        vm.deal(admin, 10 ether);

        // Configure allowlists on both chains
        switchTo("BASE");
        vm.startPrank(admin);

        ChainlinkAdapter baseAdapter = new ChainlinkAdapter(admin, address(baseOracle), address(baseOracle));

        baseOracle.grantRole(address(baseEndpoint), baseOracle.ENDPOINT_ROLE());

        baseOracle.setLocalAssetConfig(WETH, address(baseAdapter), BASE_ETH_USD_FEED, 0, true);
        baseOracle.setLocalAssetConfig(WBTC, address(baseAdapter), BASE_BTC_USD_FEED, 0, true);
        baseOracle.setLocalAssetConfig(USDC, address(baseAdapter), BASE_ETH_USD_FEED, 0, true);

        // Setup adapter
        baseAdapter.grantRole(admin, uint256(baseAdapter.ORACLE_ROLE()));

        baseAdapter.addAsset(WETH, BASE_ETH_USD_FEED, ETH_HEARTBEAT, true);
        baseAdapter.addAsset(WBTC, BASE_BTC_USD_FEED, BTC_HEARTBEAT, true);
        baseAdapter.addAsset(USDC, BASE_ETH_USD_FEED, ETH_HEARTBEAT, true);

        baseEndpoint.allowlistDestinationChain(POLYGON_CHAIN_SELECTOR, true);
        baseEndpoint.allowlistSourceChain(POLYGON_CHAIN_SELECTOR, true);
        baseEndpoint.allowlistSender(address(polygonEndpoint), true);

        baseOracle.setCrossChainAssetMapping(137, USDC_POLYGON, USDC);
        baseOracle.setCrossChainAssetMapping(137, WETH_POLYGON, WETH);
        baseOracle.setCrossChainAssetMapping(137, WBTC_POLYGON, WBTC);

        address[] memory assets = new address[](3);
        assets[0] = WETH;
        assets[1] = WBTC;
        assets[2] = USDC;
        bool[] memory inUSD = new bool[](3);
        inUSD[0] = true;
        inUSD[1] = true;
        inUSD[2] = true;
        baseOracle.batchUpdatePrices(assets, inUSD);
        vm.stopPrank();

        switchTo("POLYGON");
        vm.startPrank(admin);

        ChainlinkAdapter polygonAdapter = new ChainlinkAdapter(admin, address(polygonOracle), address(polygonOracle));
        polygonAdapter.grantRole(admin, uint256(polygonAdapter.ORACLE_ROLE()));

        polygonOracle.grantRole(address(polygonEndpoint), polygonOracle.ENDPOINT_ROLE());

        polygonAdapter.addAsset(WETH_POLYGON, POLYGON_ETH_USD_FEED, ETH_HEARTBEAT, true);
        polygonAdapter.addAsset(WBTC_POLYGON, POLYGON_BTC_USD_FEED, BTC_HEARTBEAT, true);
        polygonAdapter.addAsset(USDC_POLYGON, POLYGON_ETH_USD_FEED, ETH_HEARTBEAT, true);

        polygonOracle.setLocalAssetConfig(WETH_POLYGON, address(polygonAdapter), POLYGON_ETH_USD_FEED, 0, true);
        polygonOracle.setLocalAssetConfig(WBTC_POLYGON, address(polygonAdapter), POLYGON_BTC_USD_FEED, 0, true);
        polygonOracle.setLocalAssetConfig(USDC_POLYGON, address(polygonAdapter), POLYGON_ETH_USD_FEED, 0, true);

        polygonEndpoint.allowlistDestinationChain(BASE_CHAIN_SELECTOR, true);
        polygonEndpoint.allowlistSourceChain(BASE_CHAIN_SELECTOR, true);
        polygonEndpoint.allowlistSourceChain(POLYGON_CHAIN_SELECTOR, true);
        polygonEndpoint.allowlistSender(address(baseEndpoint), true);

        // Set up cross-chain asset mappings for POLYGON
        polygonOracle.setCrossChainAssetMapping(8453, USDC, USDC_POLYGON);
        polygonOracle.setCrossChainAssetMapping(8453, WETH, WETH_POLYGON);
        polygonOracle.setCrossChainAssetMapping(8453, WBTC, WBTC_POLYGON);

        address[] memory assets_pol = new address[](3);
        assets_pol[0] = WETH_POLYGON;
        assets_pol[1] = WBTC_POLYGON;
        assets_pol[2] = USDC_POLYGON;
        bool[] memory inUSD_pol = new bool[](3);
        inUSD_pol[0] = true;
        inUSD_pol[1] = true;
        inUSD_pol[2] = true;
        polygonOracle.batchUpdatePrices(assets_pol, inUSD_pol);

        vm.stopPrank();
    }

    function test_sendSharePricesCCIP() public {
        // Start on BASE chain
        switchTo("BASE");

        address[] memory vaults = new address[](1);
        vaults[0] = address(vault);
        address rewardsDelegate = makeAddr("rewardsDelegate");

        ISharePriceOracle.VaultReport[] memory expectedReports = baseOracle.getSharePrices(vaults, rewardsDelegate);
        bytes memory message = abi.encode(expectedReports);

        vm.prank(admin);
        bytes32 sentMessageId = baseEndpoint.sendSharePrices{ value: 0.1 ether }(
            POLYGON_CHAIN_SELECTOR, address(polygonEndpoint), vaults, rewardsDelegate, 200_000, true
        );

        switchTo("POLYGON");

        CcipClient.Any2EVMMessage memory mockReceivedMessage = CcipClient.Any2EVMMessage({
            messageId: sentMessageId,
            sourceChainSelector: BASE_CHAIN_SELECTOR,
            sender: abi.encode(address(baseEndpoint)),
            data: message,
            destTokenAmounts: new CcipClient.EVMTokenAmount[](0)
        });

        vm.prank(POLYGON_ROUTER);
        polygonEndpoint.ccipReceive(mockReceivedMessage);

        ISharePriceOracle.VaultReport memory report = polygonOracle.getLatestSharePriceReport(8453, address(vaults[0]));

        (uint248 price, uint8 decimals, uint64 timestamp,) = polygonOracle.storedSharePrices(address(vaults[0]));

        assertEq(price, report.sharePrice);
        assertEq(decimals, report.assetDecimals);
        assertEq(timestamp, report.lastUpdate);
        assertEq(report.vaultAddress, address(vaults[0]));
        assertEq(report.chainId, 8453);
        assertEq(report.rewardsDelegate, rewardsDelegate);
    }

    function test_setOracle() public {
        switchTo("BASE");
        address newOracle = makeAddr("newOracle");

        vm.prank(admin);
        baseEndpoint.setOracle(newOracle);

        assertEq(address(baseEndpoint.oracle()), newOracle);
    }

    function test_setOracle_revertZeroAddress() public {
        switchTo("BASE");

        vm.prank(admin);
        vm.expectRevert(MaxCCIPEndpoint.InvalidInput.selector);
        baseEndpoint.setOracle(address(0));
    }

    function test_setOracle_revertNonOwner() public {
        switchTo("BASE");
        address newOracle = makeAddr("newOracle");

        vm.prank(makeAddr("nonOwner"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        baseEndpoint.setOracle(newOracle);
    }

    function test_allowlistOperations() public {
        switchTo("BASE");
        uint64 newChainSelector = 123_456_789;
        address newSender = makeAddr("newSender");

        vm.startPrank(admin);

        baseEndpoint.allowlistDestinationChain(newChainSelector, true);
        assertTrue(baseEndpoint.allowlistedDestinationChains(newChainSelector));

        baseEndpoint.allowlistDestinationChain(newChainSelector, false);
        assertFalse(baseEndpoint.allowlistedDestinationChains(newChainSelector));

        baseEndpoint.allowlistSourceChain(newChainSelector, true);
        assertTrue(baseEndpoint.allowlistedSourceChains(newChainSelector));

        baseEndpoint.allowlistSourceChain(newChainSelector, false);
        assertFalse(baseEndpoint.allowlistedSourceChains(newChainSelector));

        baseEndpoint.allowlistSender(newSender, true);
        assertTrue(baseEndpoint.allowlistedSenders(newSender));

        baseEndpoint.allowlistSender(newSender, false);
        assertFalse(baseEndpoint.allowlistedSenders(newSender));

        vm.stopPrank();
    }

    function test_sendSharePrices_revertUnallowlistedChain() public {
        switchTo("POLYGON");
        uint64 unallowlistedChain = 123_456_789;
        address[] memory vaults = new address[](1);
        vaults[0] = address(vault);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(MaxCCIPEndpoint.DestinationChainNotAllowlisted.selector, unallowlistedChain)
        );
        polygonEndpoint.sendSharePrices{ value: 0.1 ether }(
            unallowlistedChain, address(baseEndpoint), vaults, makeAddr("rewardsDelegate"), 200_000, true
        );
    }

    function test_sendSharePrices_revertInvalidReceiver() public {
        switchTo("BASE");
        address[] memory vaults = new address[](1);
        vaults[0] = address(vault);

        vm.prank(admin);
        vm.expectRevert(MaxCCIPEndpoint.ZeroAddress.selector);
        baseEndpoint.sendSharePrices{ value: 0.1 ether }(
            POLYGON_CHAIN_SELECTOR, address(0), vaults, makeAddr("rewardsDelegate"), 200_000, true
        );
    }

    function test_ccipReceive_revertUnallowlistedSource() public {
        switchTo("POLYGON");
        uint64 unallowlistedChain = 123_456_789;

        CcipClient.Any2EVMMessage memory mockMessage = CcipClient.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: unallowlistedChain,
            sender: abi.encode(address(baseEndpoint)),
            data: abi.encode(new ISharePriceOracle.VaultReport[](0)),
            destTokenAmounts: new CcipClient.EVMTokenAmount[](0)
        });

        vm.prank(POLYGON_ROUTER);
        vm.expectRevert(abi.encodeWithSelector(MaxCCIPEndpoint.SourceChainNotAllowlisted.selector, unallowlistedChain));
        polygonEndpoint.ccipReceive(mockMessage);
    }

    function test_ccipReceive_revertUnallowlistedSender() public {
        switchTo("POLYGON");
        address unallowlistedSender = makeAddr("unallowlistedSender");

        CcipClient.Any2EVMMessage memory mockMessage = CcipClient.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BASE_CHAIN_SELECTOR,
            sender: abi.encode(unallowlistedSender),
            data: abi.encode(new ISharePriceOracle.VaultReport[](0)),
            destTokenAmounts: new CcipClient.EVMTokenAmount[](0)
        });

        vm.prank(POLYGON_ROUTER);
        vm.expectRevert(abi.encodeWithSelector(MaxCCIPEndpoint.SenderNotAllowlisted.selector, unallowlistedSender));
        polygonEndpoint.ccipReceive(mockMessage);
    }

    function test_receive() public {
        switchTo("BASE");
        uint256 initialBalance = address(baseEndpoint).balance;
        uint256 sendAmount = 1 ether;

        (bool success,) = address(baseEndpoint).call{ value: sendAmount }("");
        assertTrue(success);
        assertEq(address(baseEndpoint).balance, initialBalance + sendAmount);
    }

    function test_supportsInterface() public {
        switchTo("BASE");

        assertTrue(baseEndpoint.supportsInterface(type(IAny2EVMMessageReceiver).interfaceId));

        assertTrue(baseEndpoint.supportsInterface(type(IERC165).interfaceId));

        assertFalse(baseEndpoint.supportsInterface(bytes4(keccak256("unsupported()"))));
    }

    function test_sendSharePrices_revertInsufficientFunds() public {
        switchTo("BASE");
        address[] memory vaults = new address[](1);
        vaults[0] = address(vault);

        vm.prank(admin);
        vm.expectRevert(MaxCCIPEndpoint.InsufficientFunds.selector);
        baseEndpoint.sendSharePrices{ value: 0 }(
            POLYGON_CHAIN_SELECTOR, address(polygonEndpoint), vaults, makeAddr("rewardsDelegate"), 200_000, true
        );
    }

    function test_sendSharePrices_revertInvalidRouter() public {
        switchTo("BASE");
        address[] memory vaults = new address[](1);
        vaults[0] = address(vault);

        vm.prank(makeAddr("nonRouter"));
        vm.expectRevert(abi.encodeWithSelector(MaxCCIPEndpoint.InvalidRouter.selector, makeAddr("nonRouter")));
        baseEndpoint.ccipReceive(
            CcipClient.Any2EVMMessage({
                messageId: bytes32(0),
                sourceChainSelector: POLYGON_CHAIN_SELECTOR,
                sender: abi.encode(address(polygonEndpoint)),
                data: abi.encode(new ISharePriceOracle.VaultReport[](0)),
                destTokenAmounts: new CcipClient.EVMTokenAmount[](0)
            })
        );
    }

    function test_refundETH() public {
        switchTo("BASE");
        uint256 initialBalance = address(baseEndpoint).balance;
        uint256 refundAmount = 0.5 ether;
        address refundTo = makeAddr("refundTo");

        vm.prank(admin);
        baseEndpoint.refundETH(refundAmount, refundTo);

        assertEq(address(baseEndpoint).balance, initialBalance - refundAmount);
        assertEq(refundTo.balance, refundAmount);
    }

    function test_refundETH_revertZeroAddress() public {
        switchTo("BASE");
        vm.prank(admin);
        vm.expectRevert(MaxCCIPEndpoint.ZeroAddress.selector);
        baseEndpoint.refundETH(0.5 ether, address(0));
    }

    function test_refundETH_revertInvalidAmount() public {
        switchTo("BASE");
        vm.prank(admin);
        vm.expectRevert(MaxCCIPEndpoint.InvalidInput.selector);
        baseEndpoint.refundETH(0, makeAddr("refundTo"));
    }

    function test_refundETH_revertInsufficientFunds() public {
        switchTo("BASE");
        vm.prank(admin);
        vm.expectRevert(MaxCCIPEndpoint.InvalidInput.selector);
        baseEndpoint.refundETH(address(baseEndpoint).balance + 1, makeAddr("refundTo"));
    }

    function test_refundETH_revertNonOwner() public {
        switchTo("BASE");
        vm.prank(makeAddr("nonOwner"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        baseEndpoint.refundETH(0.5 ether, makeAddr("refundTo"));
    }

    function test_constructor_revertZeroAddress() public {
        vm.expectRevert(MaxCCIPEndpoint.ZeroAddress.selector);
        new MaxCCIPEndpoint(address(0), BASE_ROUTER, address(baseOracle));

        vm.expectRevert(MaxCCIPEndpoint.ZeroAddress.selector);
        new MaxCCIPEndpoint(admin, address(0), address(baseOracle));

        vm.expectRevert(MaxCCIPEndpoint.ZeroAddress.selector);
        new MaxCCIPEndpoint(admin, BASE_ROUTER, address(0));
    }

    function test_ccipReceive_revertInvalidRouter() public {
        switchTo("POLYGON");
        CcipClient.Any2EVMMessage memory mockMessage = CcipClient.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BASE_CHAIN_SELECTOR,
            sender: abi.encode(address(baseEndpoint)),
            data: abi.encode(new ISharePriceOracle.VaultReport[](0)),
            destTokenAmounts: new CcipClient.EVMTokenAmount[](0)
        });

        vm.prank(makeAddr("nonRouter"));
        vm.expectRevert(abi.encodeWithSelector(MaxCCIPEndpoint.InvalidRouter.selector, makeAddr("nonRouter")));
        polygonEndpoint.ccipReceive(mockMessage);
    }

    function test_ccipReceive_revertInvalidMessage() public {
        switchTo("POLYGON");
        CcipClient.Any2EVMMessage memory mockMessage = CcipClient.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BASE_CHAIN_SELECTOR,
            sender: abi.encode(address(baseEndpoint)),
            data: abi.encode("invalid data"),
            destTokenAmounts: new CcipClient.EVMTokenAmount[](0)
        });

        vm.prank(POLYGON_ROUTER);
        vm.expectRevert();
        polygonEndpoint.ccipReceive(mockMessage);
    }

    function test_ccipReceive_revertInvalidChainId() public {
        switchTo("POLYGON");
        ISharePriceOracle.VaultReport[] memory reports = new ISharePriceOracle.VaultReport[](1);
        reports[0] = ISharePriceOracle.VaultReport({
            chainId: 137,
            vaultAddress: address(vault),
            asset: address(0),
            assetDecimals: 18,
            sharePrice: 1e18,
            lastUpdate: uint64(block.timestamp),
            rewardsDelegate: address(0)
        });

        CcipClient.Any2EVMMessage memory mockMessage = CcipClient.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BASE_CHAIN_SELECTOR,
            sender: abi.encode(address(baseEndpoint)),
            data: abi.encode(reports),
            destTokenAmounts: new CcipClient.EVMTokenAmount[](0)
        });

        vm.prank(POLYGON_ROUTER);
        vm.expectRevert(abi.encodeWithSelector(SharePriceOracle.InvalidChainId.selector));
        polygonEndpoint.ccipReceive(mockMessage);
    }

    function test_ccipReceive_revertNoValidPrice() public {
        switchTo("POLYGON");
        ISharePriceOracle.VaultReport[] memory reports = new ISharePriceOracle.VaultReport[](1);
        reports[0] = ISharePriceOracle.VaultReport({
            chainId: 8453, // BASE chain ID
            vaultAddress: address(vault),
            asset: address(0),
            assetDecimals: 18,
            sharePrice: 0, // Invalid price
            lastUpdate: uint64(block.timestamp),
            rewardsDelegate: address(0)
        });

        CcipClient.Any2EVMMessage memory mockMessage = CcipClient.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BASE_CHAIN_SELECTOR,
            sender: abi.encode(address(baseEndpoint)),
            data: abi.encode(reports),
            destTokenAmounts: new CcipClient.EVMTokenAmount[](0)
        });

        vm.prank(POLYGON_ROUTER);
        vm.expectRevert(abi.encodeWithSelector(SharePriceOracle.NoValidPrice.selector));
        polygonEndpoint.ccipReceive(mockMessage);
    }

    function test_ccipReceive_revertZeroAddress() public {
        switchTo("POLYGON");
        ISharePriceOracle.VaultReport[] memory reports = new ISharePriceOracle.VaultReport[](1);
        reports[0] = ISharePriceOracle.VaultReport({
            chainId: 8453, // BASE chain ID
            vaultAddress: address(vault),
            asset: address(0),
            assetDecimals: 18,
            sharePrice: 1e18,
            lastUpdate: uint64(block.timestamp),
            rewardsDelegate: address(0)
        });

        CcipClient.Any2EVMMessage memory mockMessage = CcipClient.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BASE_CHAIN_SELECTOR,
            sender: abi.encode(address(baseEndpoint)),
            data: abi.encode(reports),
            destTokenAmounts: new CcipClient.EVMTokenAmount[](0)
        });

        vm.prank(POLYGON_ROUTER);
        vm.expectRevert(abi.encodeWithSelector(SharePriceOracle.ZeroAddress.selector));
        polygonEndpoint.ccipReceive(mockMessage);
    }

    function test_ccipReceive_revertExceedsMaxReports() public {
        switchTo("POLYGON");
        ISharePriceOracle.VaultReport[] memory reports = new ISharePriceOracle.VaultReport[](11); // Exceeds MAX_REPORTS
        for (uint256 i = 0; i < 11; i++) {
            reports[i] = ISharePriceOracle.VaultReport({
                chainId: 8453, // BASE chain ID
                vaultAddress: address(vault),
                asset: address(0),
                assetDecimals: 18,
                sharePrice: 1e18,
                lastUpdate: uint64(block.timestamp),
                rewardsDelegate: address(0)
            });
        }

        CcipClient.Any2EVMMessage memory mockMessage = CcipClient.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BASE_CHAIN_SELECTOR,
            sender: abi.encode(address(baseEndpoint)),
            data: abi.encode(reports),
            destTokenAmounts: new CcipClient.EVMTokenAmount[](0)
        });

        vm.prank(POLYGON_ROUTER);
        vm.expectRevert(abi.encodeWithSelector(SharePriceOracle.ExceedsMaxReports.selector));
        polygonEndpoint.ccipReceive(mockMessage);
    }

    function test_ccipReceive_revertAssetNotConfigured() public {
        switchTo("POLYGON");
        ISharePriceOracle.VaultReport[] memory reports = new ISharePriceOracle.VaultReport[](1);
        reports[0] = ISharePriceOracle.VaultReport({
            chainId: 8453,
            vaultAddress: address(vault),
            asset: makeAddr("unconfiguredAsset"),
            assetDecimals: 18,
            sharePrice: 1e18,
            lastUpdate: uint64(block.timestamp),
            rewardsDelegate: address(0)
        });

        CcipClient.Any2EVMMessage memory mockMessage = CcipClient.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BASE_CHAIN_SELECTOR,
            sender: abi.encode(address(baseEndpoint)),
            data: abi.encode(reports),
            destTokenAmounts: new CcipClient.EVMTokenAmount[](0)
        });

        vm.prank(POLYGON_ROUTER);
        vm.expectRevert(
            abi.encodeWithSelector(SharePriceOracle.AssetNotConfigured.selector, makeAddr("unconfiguredAsset"))
        );
        polygonEndpoint.ccipReceive(mockMessage);
    }
}
