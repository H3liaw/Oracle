# SharePriceOracle

A cross-chain oracle system for ERC4626 vault share prices, enabling secure and efficient price data transmission across different blockchain networks using LayerZero and CCIP protocol.

## Overview

SharePriceOracle is a multi-adapter oracle system that supports multiple price feeds and fallback mechanisms for cross-chain ERC4626 vault share price routing. It combines functionality of price oracle adapters and router capabilities to provide unified price conversion across chains.

## Key Features

- Multi-chain support
- Multiple oracle adapter integration (Chainlink, API3, Pyth, Aerodrome, Balancer)
- Fallback price feed mechanisms
- Cross-chain asset mapping
- Configurable price update heartbeats
- Sequencer uptime validation for L2 chains

## Architecture

### Core Components

1. **SharePriceOracle**: Main contract handling price routing and conversions
2. **LzEndpoint**: LayerZero endpoint integration for cross-chain communication
3. **CCIPEndpoint**: CCIP endpoint integration for cross-chain communication
4. **Oracle Adapters**: 
   - Chainlink
   - API3
   - Pyth
   - Balancer
   - Curve
   - Aerodrome

### Key Contracts

```solidity
SharePriceOracle.sol      // Main router contract
LzEndpoint.sol         // LayerZero endpoint handler
CCIPEndpoint.sol      // CCIP endpoint handler
adapters/
  Chainlink.sol          // Chainlink price feed adapter
  Api3.sol               // API3 price feed adapter
  Pyth.sol              // Pyth Network adapter
```

## Secure Key Management (Keystore)

**Do NOT add your private key to `.env` or commit it to version control.**

Instead, create a secure wallet keystore and use it with Foundry's `cast` and `forge` tools.

_Credits to Patrick Collins for the keystore workflow._

### Create a new wallet keystore

```bash
cast wallet import myKeystoreName --interactive
```
- Enter your wallet's private key when prompted.
- Provide a password to encrypt the keystore file.

⚠️ **Recommendation:**
Do not use a private key associated with real funds. Create a new wallet for deployment and testing.

## Deployment Process

The deployment process is handled through several scripts, which should be run in the following order:

1. **Initial Deployment** 
2. **Base Chain Configuration** 
3. **Peer Configuration** 
4. **Local Asset Addition**

## Configuration

The system uses several JSON configuration files for price feeds:

- `balancerPriceFeeds.json`: Balancer pool configurations
- `curvePriceFeeds.json`: Curve pool configurations
- `priceFeedConfig.json`: General price feed configurations
- `pythPriceFeed.json`: Pyth Network specific configurations


## Security

The contract implements several security features:

- Role-based access control
- Sequencer uptime validation for L2s
- Price feed heartbeat checks
- Multiple oracle fallback mechanisms

## Testing

Run the test suite:

```bash
forge test
```

## License

MIT
