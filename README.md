# AfriRemit

A comprehensive DeFi platform designed for seamless cross-border transactions and decentralized financial services in Africa and beyond.

## Overview

AfriRemit is a multi-featured decentralized finance (DeFi) ecosystem that provides various financial services including token swapping, liquidity provision, and cross-border remittance solutions. The platform is built on blockchain technology to offer transparent, efficient, and cost-effective financial services.

## Features

### 🔄 Token Swapping
The Swap contract is one of AfriRemit's core features, enabling users to:
- Swap between native tokens and ERC20 tokens and vice-versa
- Swap between different ERC20 tokens
- Benefit from competitive exchange rates
- Pay minimal transaction fees (0.020% on successful swaps)

### 💧 Liquidity Provision
- Users can become liquidity providers and earn rewards
- Support for multiple token pairs
- Automated reward distribution based on contribution ratio
- Flexible liquidity management with add/remove capabilities

### 💰 Rewards System
- **80%** of swap fees distributed to liquidity providers
- **17%** retained as platform profit
- **3%** allocated for token burning (deflationary mechanism)
- Automatic reward calculation based on liquidity contribution

## Smart Contract Architecture

### Swap Contract
The main swap contract handles:
- Token exchange operations
- Liquidity pool management
- Fee distribution
- Provider reward calculations

### TestPriceFeed Contract
An advanced price feed system designed for Lisk blockchain deployment:

#### Current Deployment Status
- **Network**: Lisk Sepolia (Testnet)
- **Oracle Support**: Chainlink is not currently available on Lisk networks
- **Price Management**: Currently using manual price updates with oracle-ready architecture

#### Flexible Price Source Management
The price feed is designed with adaptability in mind:
- **Manual Price Setting**: Initially supports manual price updates for testing and development
- **Oracle Integration**: Seamlessly integrates with Chainlink price feeds when available
- **Hybrid Approach**: Can toggle between manual and oracle-based pricing per token
- **Mock Aggregators**: Supports mock price feeds for testing environments

#### Oracle Transition Capability
Since Chainlink is not currently supported on Lisk Sepolia (where AfriRemit is deployed) and Lisk Mainnet, the system is designed for future oracle integration:
- Currently operates with manual price setting due to lack of Chainlink support on Lisk
- Ready to switch to live oracle data when Chainlink or other oracle providers become available on Lisk
- Maintains price accuracy through manual updates until oracle infrastructure is available
- Future-proof design that won't require contract redeployment when oracles become supported

#### Key Price Feed Features
- Support for multiple token pairs
- Configurable decimal precision
- Real-time price updates via oracles
- Fallback to manual pricing when needed
- Event logging for price updates and oracle changes

## Technical Specifications

### Supported Operations
- **Native ↔ ERC20**: Direct swaps between native blockchain tokens and ERC20 tokens
- **ERC20 ↔ ERC20**: Cross-token swaps between different ERC20 tokens
- **Liquidity Management**: Add and remove liquidity from pools
- **Reward Claims**: Withdraw earned rewards from liquidity provision

### Fee Structure
- **Swap Fee**: 0.020% (20 basis points) per transaction
- **Provider Rewards**: 80% of collected fees
- **Platform Revenue**: 17% of collected fees
- **Burn Mechanism**: 3% of collected fees (deflationary)

### Security Features
- Owner-controlled administrative functions
- Provider authentication system
- Minimum transaction limits (100 WEI)
- Pool size validation before swaps
- Secure token transfer mechanisms

## Getting Started

### Prerequisites
- Solidity ^0.8.0
- Chainlink contracts for price feeds
- OpenZeppelin contracts for security

### Deployment
1. Deploy the TestPriceFeed contract first
2. Deploy the main Swap contract with required parameters
3. Configure token pairs and price feeds
4. Set up initial liquidity pools

### Usage
1. **Swapping**: Call the `swap()` function with desired token pair and amount
2. **Providing Liquidity**: Use `provideLiquidity()` to add funds to pools
3. **Claiming Rewards**: Call `withDrawEarnings()` to claim accumulated rewards
4. **Pool Management**: Admins can create new pools and update parameters

## Price Feed Architecture for Lisk

The AfriRemit price feed system is specifically designed to address the current limitations of oracle infrastructure on Lisk:

### Current State (Lisk Sepolia)
- **Manual Price Management**: Prices are currently set manually due to lack of Chainlink support
- **Admin-Controlled Updates**: Platform administrators update token prices as needed
- **Reliable Operation**: Ensures consistent pricing despite oracle limitations

### Future Oracle Integration
Since Chainlink is not yet available on Lisk Sepolia or Lisk Mainnet, the system is built with forward compatibility:

```solidity
// Ready for future oracle integration
function togglePriceSource(address _tokenAddress, bool _useOracle) external onlyOwner

// Will be used when Chainlink becomes available on Lisk
function setAggregator(address _tokenAddress, address _aggregatorAddress) external onlyOwner

// Current method for price management on Lisk
function updateMockPrice(address _tokenAddress, int256 _newPrice) external onlyOwner
```

### Benefits of This Approach
- **No Redeployment Needed**: When oracles become available on Lisk, simply toggle the price source
- **Seamless Transition**: Switch from manual to oracle pricing without disrupting operations
- **Network-Specific Design**: Tailored for Lisk's current infrastructure limitations
- **Future-Proof**: Ready for Lisk ecosystem growth and oracle provider adoption

## Future Enhancements

- **AfriStable (AFX) Stablecoin (Hybrid Collateralized: Fiat + Crypto)**
  - Enables saving features
  - Purchase AFX stablecoin using:
    - **Fiat** (e.g., via stablecoins like USDC or through a fiat gateway for off-chain NGN)
    - **Crypto** (e.g., ETH, BTC, etc.)
    - **Or both**, in a defined ratio (e.g., 50% fiat / 50% crypto)
  - **Redeem and Burn** mechanism:
    - Users return AFX to redeem collateral
    - Upon burning AFX:
      - They receive the original collateral mix  
      - Or choose payout in either **crypto** or **fiat** (based on initial deposit)






