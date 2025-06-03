# AfriRemit

A decentralized automated market maker (AMM) and liquidity protocol built on Ethereum-compatible blockchains (LISK), enabling seamless token swaps and liquidity provision with integrated fee distribution and tokenomics.

## Overview

AfriRemit is a comprehensive DeFi protocol that combines:
- **Automated Market Making**: Efficient token swapping with dynamic pricing
- **Liquidity Provision**: Earn rewards by providing liquidity to trading pairs
- **Tokenomics**: Built-in fee distribution, rewards, and token burning mechanisms
- **Multi-token Support**: Native cryptocurrency and ERC-20 token compatibility

## Key Features

### 🔄 Token Swapping
- Support for three swap types:
  - Native Token ↔ ERC-20 Token
  - ERC-20 Token ↔ Native Token  
  - ERC-20 Token ↔ ERC-20 Token
- Dynamic pricing through integrated price feeds
- 0.20% swap fee structure
- Minimum swap amount: 100 WEI

### 💧 Liquidity Provision
- Provide liquidity to earn trading fees
- Automatic liquidity provider registration
- Proportional reward distribution based on contribution
- Flexible liquidity removal

### 💰 Fee Distribution & Tokenomics
- **80%** of fees → Liquidity providers (proportional rewards)
- **17%** of fees → Platform profit
- **3%** of fees → Token burning (deflationary mechanism)
- All fees converted to AFRI_COIN tokens

### 🏊 Liquidity Pools
- Dynamic pool creation and management
- Bidirectional token pair support
- Real-time pool size tracking
- Efficient liquidity aggregation

## Smart Contract Architecture

### Core Components

#### Structs
- **Pool**: Represents a trading pair with associated liquidity
- **Liquid**: Individual liquidity positions within pools
- **Provider**: User profiles for liquidity providers

#### Key Functions

**Swapping**
```solidity
function swap(address token0, address token1, uint256 amount0) external payable returns (uint256)
```

**Liquidity Management**
```solidity
function provideLiquidity(uint poolId, uint256 amount0) external payable
function removeLiquidity(uint id) external
```

**Pool Operations**
```solidity
function createPool(address token0, address token1) external returns (uint)
function getPoolSize(address token0, address token1) external view returns (uint256, uint256)
```

**Price Estimation**
```solidity
function estimate(address token0, address token1, uint256 amount0) external view returns (uint256)
```

## Getting Started

### Prerequisites
- Solidity ^0.7.0 <0.9.0
- OpenZeppelin contracts
- Chainlink CCIP contracts
- Compatible price feed oracle

### Deployment Parameters
```solidity
constructor(address _priceAPI, address _AFRI_COIN)
```
- `_priceAPI`: Address of the price feed oracle contract
- `_AFRI_COIN`: Address of the platform's native token

### Initial Setup
1. Deploy price feed oracle
2. Deploy AFRI_COIN token contract
3. Deploy Swap contract with oracle and token addresses
4. Create initial liquidity pools
5. Configure swap fees (if different from default 0.20%)

## Usage Examples

### Swapping Tokens
```javascript
// Native to ERC-20
await swapContract.swap(
  nativeTokenAddress,
  erc20TokenAddress,
  amount,
  { value: amount }
);

// ERC-20 to ERC-20
await erc20Contract.approve(swapAddress, amount);
await swapContract.swap(token0Address, token1Address, amount);
```

### Providing Liquidity
```javascript
// For native token pairs
await swapContract.provideLiquidity(
  poolId,
  amount,
  { value: nativeAmount }
);

// For ERC-20 pairs
await token0Contract.approve(swapAddress, amount0);
await token1Contract.approve(swapAddress, amount1);
await swapContract.provideLiquidity(poolId, amount0);
```

## Fee Structure

| Component | Percentage | Destination |
|-----------|------------|-------------|
| Liquidity Providers | 80% | Proportional rewards |
| Platform Profit | 17% | Platform treasury |
| Token Burning | 3% | Deflationary burn |

## Security Features

- **Access Control**: Owner-only administrative functions
- **Provider Verification**: Registered provider requirements
- **Balance Validation**: Sufficient liquidity checks
- **Reentrancy Protection**: Secure external calls
- **Input Validation**: Minimum amount requirements

## Administrative Functions

### Owner-Only Operations
- Update swap fees
- Create new trading pools
- Withdraw platform earnings
- Execute token burning
- Manage contract parameters

### Provider Management
- Automatic registration system
- Profile customization (auto-staking preferences)
- Earnings withdrawal
- Liquidity position tracking

## Events & Monitoring

The contract emits comprehensive events for:
- Swap transactions
- Liquidity provision/removal
- Fee distribution
- Administrative actions

## Token Integration

AfriRemit integrates with:
- **xIERC20**: Extended ERC-20 interface with burning capability
- **TestPriceFeed**: Oracle integration for price data
- **Native Token**: Blockchain's native cryptocurrency

## Development & Testing

### Local Development
1. Clone the repository
2. Install dependencies
3. Configure test environment
4. Deploy to local blockchain
5. Run comprehensive tests

### Testnet Deployment
1. Configure testnet parameters
2. Deploy price feed oracle
3. Deploy token contracts
4. Deploy and verify Swap contract
5. Initialize liquidity pools



## License

This project is licensed under GPL-3.0 - see the [LICENSE](LICENSE) file for details.

## Security Considerations

- Smart contracts are unaudited - use at your own risk
- Test thoroughly on testnets before mainnet deployment
- Consider professional security audits for production use
- Monitor for potential vulnerabilities and updates

DEPLOYED_ADDRESS = 0X233433DJDJFHDJFHDFKDJFKJD
