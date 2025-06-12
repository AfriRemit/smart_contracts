# AfriRemit Platform 🌍

> **The First Global DEX for African Stablecoins** - Built on Lisk Blockchain

AfriRemit is a comprehensive decentralized finance (DeFi) ecosystem that bridges African and international financial markets through innovative blockchain solutions. Our platform enables seamless cross-border transactions, traditional savings groups, and real-world utility payments using African and international stablecoins.

## 🌟 Platform Overview

AfriRemit is the **first decentralized exchange (DEX) built on the Lisk blockchain** that enables **global access** to African and international stablecoins. We're revolutionizing how people interact with African currencies by providing:

- 🔄 **Cross-Border Stablecoin Swapping** - Direct swaps between African stablecoins (cNGN, cZAR, cKES, AFX) and international tokens (USDT, WETH, ETH, DAI)
- 💰 **AFX Stablecoin** - Our native Naira-pegged stablecoin for swaps, savings, and payments
- 🏦 **Digital Savings Groups** - On-chain rotational savings (Ajo/Esusu/Stokvel) with smart contract automation
- 📱 **Utility Payments** - Pay bills, airtime, and utilities using stablecoins
- 🔁 **On-Ramp/Off-Ramp** - Bank and mobile money integrations for NGN/cNGN, KES/cKES, and NGN/AFX

---

## 🎯 Problem Statement

Despite the rise of stablecoins in Africa and globally, critical gaps persist:

- ❌ **Isolated Local Stablecoins** - Low liquidity and limited global exchange support
- 🌍 **Expensive Cross-Border Remittances** - High fees, long wait times, centralized systems
- 🔗 **No Global African Stablecoin DEX** - Users can't trade cNGN or cZAR with global tokens
- 🧱 **Informal Savings Groups** - Lack transparency, automation, and security
- 💳 **Limited Crypto Utility Payments** - Especially for local bills and services

---

## ✨ Our Solution & Uniqueness

### 🔄 **AfriSwap - Token Exchange Engine**
**The core DEX functionality enabling global stablecoin access**

#### Key Features:
- **Multi-Token Support**: Native ↔ ERC20 and ERC20 ↔ ERC20 swaps
- **African Stablecoin Focus**: cNGN, cZAR, cKES, cGHS integrated with USDT, WETH, ETH, DAI
- **Competitive Fees**: 0.020% swap fee (20 basis points)
- **Liquidity Incentives**: 80% of fees distributed to liquidity providers
- **Lisk-Optimized**: Built specifically for Lisk blockchain infrastructure

#### Supported Operations:
```solidity
// Native ↔ ERC20: Direct swaps between native tokens and ERC20 tokens
// ERC20 ↔ ERC20: Cross-token swaps between different ERC20 tokens
// Liquidity Management: Add and remove liquidity from pools
// Reward Claims: Withdraw earned rewards from liquidity provision
```

#### Fee Structure:
- **Swap Fee**: 0.020% per transaction
- **Provider Rewards**: 80% of collected fees
- **Platform Revenue**: 17% of collected fees  
- **Burn Mechanism**: 3% of collected fees (deflationary)

### 💰 **AFX Stablecoin - Naira-Pegged Stability**
**Our native hybrid-collateralized stablecoin maintaining 1:1 peg with Nigerian Naira**

#### Core Features:
- **Dual Collateral System**: Backed by both fiat reserves (NGN) and approved crypto assets
- **Dynamic Collateral Ratios**: Automatic adjustment based on market conditions
- **Integrated Price Oracle**: Real-time price feeds for accurate valuation
- **Over-Collateralization**: Crypto-backed positions require over-collateralization
- **Emergency Liquidation**: Automated liquidation for unsafe positions
- **Automated Rebalancing**: Protocol maintains optimal fiat/crypto backing ratios

#### Minting Options:
```solidity
// Fiat-Backed Minting
function mintWithFiat() // Mint AFX using NGN reserves
function depositFiatAndMint() // Add fiat and mint in one transaction

// Crypto-Collateralized Minting  
function depositAndMint() // Deposit crypto collateral and mint AFX
function burnAndWithdraw() // Burn AFX and withdraw collateral
```

#### Security Features:
- **Role-Based Access**: Minters, burners, oracles, liquidators, fiat depositors
- **Blacklisting Capability**: Compliance and security controls
- **Emergency Controls**: Pausable contract with emergency withdrawal
- **Liquidation Protection**: Automated liquidation of unsafe positions

### 🏦 **AjoEsusu Savings - Digital Rotating Savings Groups**
**Traditional African savings systems powered by smart contracts**

#### Revolutionary Features:
- **Agent-Based System**: Trusted community members manage savings groups
- **Multi-Token Support**: Compatible with cNGN, cZAR, cGHS, cKES, USDT, WETH, AFX
- **Automated Payouts**: Smart contract handles calculations and distributions
- **Reputation System**: Performance-based scoring for agents and members
- **Invite Code Security**: Secure group joining through agent-generated codes
- **Flexible Schedules**: Customizable contribution frequencies

#### Core Functionality:
```solidity
// User Registration & Agent System
function registerUser(string memory _name)
function registerAsAjoAgent(string memory _name, string memory _contactInfo)

// Group Management
function createGroup(...) // Agents create savings groups
function joinGroupWithCode(uint256 _groupId, string memory _inviteCode)

// Savings Operations
function contribute(uint256 _groupId) // Make contributions
function claimPayout(uint256 _groupId) // Claim when it's your turn
```

#### Group Structure:
- **Flexible Group Sizes**: 2-20 members
- **Customizable Schedules**: Minutes to months (demo-friendly)
- **Multiple Currencies**: Support for 8+ African and international tokens
- **Automated Management**: Smart contract handles rotation and payments

---

## 🚀 Technical Architecture

### Deployment Networks
- **Primary Network**: Lisk Sepolia (Testnet)
- **Production Ready**: Lisk Mainnet
- **Oracle Strategy**: Manual price management with oracle-ready architecture

### Smart Contract Stack
```solidity
// Core Contracts
- Swap.sol          // DEX and liquidity management
- AfriStable.sol        // AFX stablecoin protocol  
- Savings.sol   // Rotating savings groups

// Supporting Infrastructure
- TestPriceFeed.sol     // Price oracle system
- TestnetToken.sol      // Supported ERC20 tokens
```

### Supported Tokens
```javascript
const supportedTokens = {
    international: ["USDT", "WETH", "ETH", "DAI"],
    african: ["cNGN", "cZAR", "cKES", "cGHS"],
    native: ["AFX", "AFR"]
};
```

### Oracle Infrastructure
**Lisk-Optimized Price Management**

Since Chainlink is not currently available on Lisk, our system features:
- **Current**: Manual price management by authorized oracles
- **Future-Ready**: Seamless integration when Chainlink becomes available
- **No Redeployment**: Toggle between manual and oracle pricing
- **Hybrid Support**: Multiple price source options

```solidity
// Oracle Management
function togglePriceSource(address _tokenAddress, bool _useOracle)
function setAggregator(address _tokenAddress, address _aggregatorAddress) 
function updateMockPrice(address _tokenAddress, int256 _newPrice)
```

---

## 💼 Revenue Model

### 1. **Swap Fees**
- Low fee on every token/stablecoin swap (0.020%)
- Competitive with major DEXs while supporting African liquidity

### 2. **AFX Staking and Liquidity Yield**
- Protocol revenue from staked AFX positions
- Liquidity pool rewards and farming opportunities

### 3. **Savings Group Automation Fees**
- Small management fees for premium Ajo/Esusu features
- Agent registration and performance bonuses

### 4. **Utility Payment Processing**
- Commission from bill payments, airtime, and utility transactions
- Partnership revenue with service providers

### 5. **On-Ramp/Off-Ramp Partner Fees**
- Transaction fee-sharing from fiat integrations
- Mobile money and bank partnership revenue

### 6. **API & White-label Solutions**
- Enterprise partnerships with fintechs
- Backend integration services for stablecoin access

---

## 🛠️ Getting Started

### Prerequisites
```bash
# Development Environment
- Solidity ^0.8.19
- OpenZeppelin Contracts
- Foundry development framework
- Node.js & npm/yarn

# Blockchain Infrastructure  
- Lisk Sepolia testnet access
- Supported ERC20 token contracts
- Web3 wallet (MetaMask, WalletConnect)
```

### Quick Start Deployment
```javascript
// 1. Deploy AFX Stablecoin
const afxStablecoin = await deploy("AfriStable", [
    priceFeedAddress,
    supportedCollaterals
]);

// 2. Deploy AjoEsusu Savings
const ajoEsusu = await deploy("AjoEsusuSavings", [
    tokenAddresses,
    tokenNames
]);

// 3. Deploy AfriSwap DEX
const afriSwap = await deploy("AfriSwap", [
    afxStablecoin.address,
    priceFeedAddress
]);

// 4. Configure token support
await afriSwap.addSupportedTokens(tokenList);
await ajoEsusu.setSupportedTokens(tokenList);
```

### Frontend Integration Example
```javascript
// Connect to AfriRemit platform
const afriRemit = new AfriRemitSDK({
    network: 'lisk-sepolia',
    contracts: {
        swap: '0x...',
        savings: '0x...',
        stablecoin: '0x...'
    }
});

// Execute swap
const swapResult = await afriRemit.swap({
    from: 'cNGN',
    to: 'USDT', 
    amount: '1000',
    slippage: 0.5
});

// Join savings group
await afriRemit.savings.joinGroup({
    groupId: 123,
    inviteCode: 'AJO123456'
});

// Mint AFX stablecoin
await afriRemit.stablecoin.mint({
    type: 'fiat',
    amount: '50000', // NGN
    recipient: userAddress
});
```

---

### User Dashboard Functions
```solidity
// Portfolio Management
function getUserPortfolio(address user) // Complete user portfolio
function getUserActiveGroups(address user) // Active savings groups
function getUserSwapHistory(address user) // Transaction history
function getUserAFXPosition(address user) // AFX holdings and debt
```

---

## 🔐 Security & Compliance

### Security Features
- **Multi-Signature Controls**: Critical operations require multiple signatures
- **Reentrancy Protection**: All financial functions protected
- **Access Control**: Role-based permissions throughout platform
- **Emergency Pause**: Platform-wide emergency controls
- **Audit Ready**: Code structure optimized for security audits

### Compliance Features
- **KYC Integration Ready**: User verification system hooks
- **Blacklist Management**: Address blocking for compliance
- **Transaction Monitoring**: All operations logged and traceable
- **Regulatory Reporting**: Built-in reporting capabilities

### Risk Management
```solidity
// AFX Stablecoin Risk Controls
function liquidatePosition(address user) // Liquidate unsafe positions
function emergencyPause() // Emergency platform pause
function updateCollateralRequirements() // Dynamic risk adjustment

// Savings Group Risk Controls  
function detectDefault(uint256 groupId, address member) // Default detection
function penalizeReputation(address user) // Reputation penalties
function emergencyGroupReolution(uint256 groupId) // Emergency group closure
```

---

## 🌍 Real-World Use Cases

### For Individual Users
1. **Cross-Border Remittances**: Send cNGN to family, they receive local currency
2. **Savings Goals**: Join digital Ajo groups for disciplined saving
3. **Utility Payments**: Pay electricity, internet, airtime with stablecoins
4. **Investment**: Provide liquidity and earn fees from swaps

### For Businesses  
1. **Payment Processing**: Accept African stablecoins for goods/services
2. **Treasury Management**: Hedge between local and international currencies
3. **Employee Payments**: Pay salaries in stable, local currencies
4. **Supply Chain**: Efficient B2B payments across African borders

### For Financial Institutions
1. **White-label Integration**: Embed AfriRemit's swap functionality
2. **Liquidity Provision**: Earn yield on institutional capital
3. **Customer On-boarding**: Offer stablecoin services to customers
4. **Risk Management**: Hedge foreign exchange exposure

---

## 🛣️ Roadmap & Future Development

### Phase 1: Core Platform (Q2 2025) ✅
- [x] AfriSwap DEX deployment on Lisk
- [x] AFX stablecoin launch  
- [x] AjoEsusu savings groups
- [x] Basic mobile app

### Phase 2: Enhanced Features (Q3 2025)
- [ ] Advanced trading features (limit orders, stop-loss)
- [ ] NFT marketplace integration
- [ ] Enhanced mobile money integration
- [ ] Multi-language support

### Phase 3: Ecosystem Expansion (Q4 2025)  
- [ ] Additional African stablecoins (cUGX, cTZS)
- [ ] DeFi lending and borrowing
- [ ] Insurance products integration
- [ ] Enterprise API suite

### Phase 4: Global Scale (Q1 2026)
- [ ] Multi-chain deployment
- [ ] Institutional trading tools
- [ ] Advanced derivatives
- [ ] AI-powered financial advisory

---

**AfriRemit** - *Bridging African Finance with Global DeFi* 🌍

> Built with ❤️ for financial inclusion and powered by Lisk blockchain technology

---

*This documentation is maintained by the AfriRemit team. For the latest updates, visit our official channels.*
