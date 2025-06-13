# AfriRemit 🌍

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
- **Default Protection**: Automatic detection and handling of member defaults
- **Frontend Ready**: Comprehensive view functions for easy integration with web interfaces

#### Core Functionality:
```solidity
// User Registration & Agent System
function registerUser(string memory _name)
function registerAsAjoAgent(string memory _name, string memory _contactInfo)

// Group Management
function createGroup(...) // Agents create savings groups
function joinGroupWithCode(uint256 _groupId, string memory _inviteCode)
function generateInviteCode(uint256 _groupId, uint256 _maxUses, uint256 _validityDays)

// Savings Operations
function contribute(uint256 _groupId) // Make contributions
function claimPayout(uint256 _groupId) // Claim when it's your turn
```

#### Advanced Group Features:
- **Flexible Group Sizes**: 2-20 members (configurable)
- **Customizable Schedules**: Minutes to months (demo-friendly)
- **Multiple Currencies**: Support for 8+ African and international tokens
- **Automated Management**: Smart contract handles rotation and payments
- **Reputation Tracking**: Built-in scoring system for members and agents
- **Emergency Controls**: Pause functionality and emergency withdrawals

#### Detailed Data Structures:

**SavingsGroup Structure:**
```solidity
struct SavingsGroup {
    uint256 groupId;
    string name;
    string description;
    address creator;
    string creatorName;
    IERC20 token;
    uint256 contributionAmount;
    uint256 contributionFrequency;
    uint256 maxMembers;
    uint256 currentMembers;
    uint256 currentRound;
    uint256 totalRounds;
    uint256 creationTime;
    uint256 lastRoundStartTime;
    uint256 totalContributed;
    uint256 totalPaidOut;
    bool isActive;
    bool isCompleted;
    address[] members;
    mapping(address => bool) hasMember;
    mapping(uint256 => address) roundRecipients;
    mapping(address => uint256) memberContributions;
    mapping(address => bool) hasReceivedPayout;
    mapping(address => uint256) lastContributionTime;
}
```

**MemberInfo Structure:**
```solidity
struct MemberInfo {
    string name;
    uint256 totalContributions;
    uint256 totalReceived;
    uint256 activeGroups;
    uint256 completedGroups;
    bool hasRegistered;
    bool hasDefaulted;
    uint256 reputationScore; // 0-100 scale
    uint256 joinDate;
    uint256 lastActivity;
}
```

**AjoAgent Structure:**
```solidity
struct AjoAgent {
    string name;
    string contactInfo;
    uint256 totalGroupsCreated;
    uint256 activeGroups;
    uint256 completedGroups;
    uint256 reputationScore;
    bool isActive;
    uint256 registrationTime;
    uint256 totalFeesEarned;
}
```

#### Reputation System Details:
- **Initial Score**: Members start with 75 reputation points
- **Success Bonus**: +10 points for completing a savings group
- **Default Penalty**: -20 points for missing contributions
- **Agent Requirements**: Minimum 70 reputation to register as agent
- **Joining Requirements**: Minimum 50 reputation to join groups
- **Agent Deactivation**: Agents deactivated if reputation falls below 30

#### Platform Economics:
- **Platform Fees**: 0.5% (50/10000) of each payout by default
- **Configurable Fees**: Owner can adjust fees (maximum 10%)
- **Agent Registration**: Configurable fee for becoming an agent
- **Fee Collection**: Fees collected per token type
- **Owner Withdrawal**: Accumulated fees can be withdrawn by owner

#### Comprehensive View Functions for Frontend Integration:

**Group Discovery Functions:**
```solidity
function getGroupSummary(uint256 _groupId) external view returns (GroupSummary memory)
function getGroupDetails(uint256 _groupId) external view returns (/* multiple return values */)
function getAllActiveGroups() external view returns (GroupSummary[] memory)
function getJoinableGroups() external view returns (GroupSummary[] memory)
function getUserGroups(address _user) external view returns (uint256[] memory)
```

**Status Checking Functions:**
```solidity
function getUserContributionStatus(uint256 _groupId, address _user) external view returns (ContributionStatus memory)
function getCurrentRecipient(uint256 _groupId) external view returns (address recipient, string memory name)
function getNextContributionTime(uint256 _groupId) external view returns (uint256)
function getRemainingTimeForContribution(uint256 _groupId) external view returns (uint256)
```

**Agent Management Functions:**
```solidity
function getAjoAgentInfo(address _agent) external view returns (AjoAgent memory)
function getAllActiveAgents() external view returns (address[] memory)
function getAgentGroups(address _agent) external view returns (uint256[] memory)
function validateInviteCode(uint256 _groupId, string memory _inviteCode) external view returns (bool)
```

#### Smart Contract Events:
The system emits comprehensive events for frontend monitoring and user notifications:

```solidity
event GroupCreated(uint256 indexed groupId, address indexed creator, string name, address token, uint256 contributionAmount);
event MemberJoined(uint256 indexed groupId, address indexed member, string memberName);
event ContributionMade(uint256 indexed groupId, address indexed member, uint256 amount, uint256 round);
event PayoutDistributed(uint256 indexed groupId, address indexed recipient, uint256 amount, uint256 round);
event RoundStarted(uint256 indexed groupId, uint256 round, address indexed recipient);
event GroupCompleted(uint256 indexed groupId, uint256 totalContributed, uint256 totalPaidOut);
event DefaultDetected(uint256 indexed groupId, address indexed defaulter, uint256 round);
event AjoAgentRegistered(address indexed agent, string name);
event InviteCodeGenerated(uint256 indexed groupId, string codeId, uint256 maxUses, uint256 validityDays);
```

#### Time Settings (Demo-Optimized):
For demonstration and testing purposes, the contract uses shortened time periods:
- **Minimum Contribution Frequency**: 60 seconds (adjustable for production)
- **Grace Period**: 5 minutes for late contributions
- **Maximum Invite Code Validity**: 30 days
- **Default Detection**: Automatic after grace period expires

These settings can be easily adjusted for production deployment with realistic timeframes (weekly, monthly contributions).

---

## 🚀 Technical Architecture

### Deployment Networks
- **Primary Network**: Lisk Sepolia (Testnet)
- **Production Ready**: Lisk Mainnet
- **Oracle Strategy**: Manual price management with oracle-ready architecture

### Smart Contract Stack
```solidity
// Core Contracts (core/)
- Savings.sol            // Rotating savings groups
- Swap.sol               // DEX and liquidity management

// Stablecoin Module (stablecoin/)
- AfriStable.sol         // AFX stablecoin protocol

// Token Contracts (tokens/)
- TestnetToken.sol       // Supported ERC20 tokens

// Supporting Infrastructure (feeds/)
- MockV3Aggregator.sol   // Chainlink Aggregator
- TestPriceFeed.sol      // Price oracle system

```

### Supported Tokens
```javascript
const supportedTokens = {
    international: ["USDT", "WETH", "ETH", "DAI"],
    african: ["cNGN", "cZAR", "cKES", "cGHS"],
    native: ["AFX", "AFR"]
};

// Example deployment tokens for AjoEsusu
const supportedTokens = [
  "0x88a4e1125FF42e0010192544EAABd78Db393406e", // USDT
  "0xa01ada077F5C2DB68ec56f1a28694f4d495201c9", // WETH
  "0x207d9E20755fEe1924c79971A3e2d550CE6Ff2CB", // AFR
  "0xc5737615ed39b6B089BEDdE11679e5e1f6B9E768", // AFX
  "0x278ccC9E116Ac4dE6c1B2Ba6bfcC81F25ee48429", // cNGN
  "0x1255C3745a045f653E5363dB6037A2f854f58FBf", // cZAR
  "0x19a8a27E066DD329Ed78F500ca7B249D40241dC4", // cGHS
  "0x291ca1891b41a25c161fDCAE06350E6a524068d5"  // cKES
];

const tokenNames = [
  "USDT", "WETH", "AFR", "AFX", "cNGN", "cZAR", "cGHS", "cKES"
];
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

### Prerequisites & Installation

```bash
# 🧱 Development Environment
- Solidity ^0.8.19
- OpenZeppelin Contracts
- Chainlink Contracts
- Foundry
- Node.js and npm (optional, for scripts or frontend integration)

# 🚀 Installation Steps

# 1. Clone the repository
git clone https://github.com/AfriRemit/smart_contracts.git
cd smart_contracts

# 2. Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 3. Install dependencies
# OpenZeppelin Contracts
forge install OpenZeppelin/openzeppelin-contracts

# Chainlink Contracts
forge install smartcontractkit/chainlink-brownie-contracts

# 4. Compile contracts
forge build

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
- Platform fees from AjoEsusu groups (0.5% of payouts by default)
- Agent registration fees (configurable)
- Performance bonuses for high-reputation agents

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

## 🔐 Security & Compliance

### Security Features
- **Multi-Signature Controls**: Critical operations require multiple signatures
- **Reentrancy Protection**: All financial functions protected with ReentrancyGuard
- **Access Control**: Role-based permissions throughout platform using OpenZeppelin's Ownable
- **Emergency Pause**: Platform-wide emergency controls with Pausable functionality
- **Audit Ready**: Code structure optimized for security audits

### AjoEsusu-Specific Security:
- **Invite Code System**: Secure group joining through agent-generated codes
- **Reputation-Based Access**: Minimum reputation requirements prevent abuse
- **Default Detection**: Automatic identification of non-contributing members
- **Emergency Withdrawal**: Owner can recover funds in critical situations
- **Agent Verification**: Registration requirements and reputation tracking

### Compliance Features
- **KYC Integration Ready**: User verification system hooks
- **Blacklist Management**: Address blocking for compliance (AFX stablecoin)
- **Transaction Monitoring**: All operations logged and traceable through events
- **Regulatory Reporting**: Built-in reporting capabilities

### Risk Management
```solidity
// AFX Stablecoin Risk Controls
function liquidatePosition(address user) // Liquidate unsafe positions
function emergencyPause() // Emergency platform pause
function updateCollateralRequirements() // Dynamic risk adjustment

// AjoEsusu Risk Controls
function emergencyWithdraw(uint256 _groupId, address _token) // Emergency fund recovery
function deactivateAgent(address _agent) // Manually deactivate problematic agents
function pause() / unpause() // Emergency pause functionality
```

---

## 🌍 Real-World Use Cases

### For Individual Users
1. **Cross-Border Remittances**: Send cNGN to family, they receive local currency
2. **Savings Goals**: Join digital Ajo groups for disciplined saving with trusted agents
3. **Utility Payments**: Pay electricity, internet, airtime with stablecoins
4. **Investment**: Provide liquidity and earn fees from swaps
5. **Community Savings**: Participate in traditional rotating savings with modern security

### For Ajo Agents
1. **Community Leadership**: Manage savings groups for friends, family, and community
2. **Fee Income**: Earn from successful group completions and management
3. **Reputation Building**: Build trust through transparent, automated group management
4. **Scalable Operations**: Manage multiple groups simultaneously through smart contracts

### For Businesses  
1. **Payment Processing**: Accept African stablecoins for goods/services
2. **Treasury Management**: Hedge between local and international currencies
3. **Employee Payments**: Pay salaries in stable, local currencies
4. **Supply Chain**: Efficient B2B payments across African borders
5. **Employee Savings Programs**: Offer structured savings plans through AjoEsusu

### for Financial Institutions
1. **White-label Integration**: Embed AfriRemit's swap and savings functionality
2. **Liquidity Provision**: Earn yield on institutional capital
3. **Customer On-boarding**: Offer stablecoin and savings services to customers
4. **Risk Management**: Hedge foreign exchange exposure
5. **Digital Transformation**: Modernize traditional savings products

---

## 🛣️ Roadmap & Future Development

### Phase 1: Core Platform (Q2 2025) ✅
- [x] AfriSwap DEX deployment on Lisk
- [x] AFX stablecoin launch  
- [x] AjoEsusu savings groups with full agent system
- [] Comprehensive reputation system
- [] Basic mobile app

### Phase 2: Enhanced Features (Q3 2025)
- [ ] Advanced trading features (limit orders, stop-loss)
- [ ] Enhanced AjoEsusu features (group insurance, flexible scheduling)
- [ ] NFT marketplace integration
- [ ] Enhanced mobile money integration
- [ ] Multi-language support
- [ ] Agent dashboard and management tools

### Phase 3: Ecosystem Expansion (Q4 2025)  
- [ ] Additional African stablecoins (cUGX, cTZS)
- [ ] DeFi lending and borrowing integrated with savings
- [ ] Insurance products for savings groups
- [ ] Enterprise API suite for AjoEsusu integration
- [ ] Cross-group lending and borrowing features

### Phase 4: Global Scale (Q1 2026)
- [ ] Multi-chain deployment for savings groups
- [ ] Institutional AjoEsusu products
- [ ] AI-powered savings recommendations
- [ ] Advanced derivatives and yield farming
- [ ] Global expansion of agent network

---

## 📚 Developer Resources

### Key Documentation Files
- **Smart Contract Documentation**: Comprehensive Solidity documentation
- **API Reference**: Complete function reference for all contracts
- **Integration Guide**: Step-by-step integration for frontend developers
- **Security Best Practices**: Guidelines for secure implementation

### Example Usage Patterns

**Frontend Integration Example:**
```javascript
// Get all joinable groups
const joinableGroups = await ajoEsusuContract.getJoinableGroups();

// Check user's contribution status
const status = await ajoEsusuContract.getUserContributionStatus(groupId, userAddress);

// Get current recipient
const [recipient, name] = await ajoEsusuContract.getCurrentRecipient(groupId);

// Monitor events
ajoEsusuContract.on('ContributionMade', (groupId, member, amount, round) => {
    console.log(`Contribution made: ${amount} by ${member} in group ${groupId}`);
});
```

---

## ⚠️ Important Notes & Disclaimers

### Production Considerations
- **Security Audits**: All contracts require thorough security auditing before mainnet deployment
- **Gas Optimization**: Consider gas costs and optimization for mainnet deployment
- **Time Parameters**: Adjust demo-friendly time settings to production-appropriate periods
- **Oracle Integration**: Implement proper price oracles for production use
- **Compliance**: Ensure regulatory compliance in target jurisdictions

### Demo Configuration
- **Shortened Timeframes**: Current implementation uses minutes/hours for demo purposes
- **Test Tokens**: Uses test tokens for demonstration - replace with production tokens
- **Manual Oracles**: Price feeds managed manually - integrate with Chainlink when available
- **Simplified KYC**: Basic user registration - enhance for production compliance

### Risk Warnings
- **Smart Contract Risk**: As with all DeFi protocols, smart contract risks exist
- **Regulatory Risk**: Regulatory landscape for DeFi continues to evolve
- **Market Risk**: Stablecoin values may fluctuate despite stability mechanisms
- **Technical Risk**: Blockchain and oracle dependencies may affect functionality

---

**AfriRemit** - *Bridging African Finance with Global DeFi* 🌍

> Built with ❤️ for financial inclusion and powered by Lisk blockchain technology. 
> Featuring the most comprehensive implementation of traditional African savings systems on blockchain.

---

*This documentation is maintained by the AfriRemit team.*

## 🔗 Related Links

- [OpenZeppelin Contracts](https://openzeppelin.com/contracts/)
- [Lisk Documentation](https://lisk.com/documentation)
- [Solidity Documentation](https://docs.soliditylang.org/)
- [Foundry Framework](https://book.getfoundry.sh/)

