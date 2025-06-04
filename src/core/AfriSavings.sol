// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../src/core/AfriCoin.sol";

/**
 * @title AfriSavings
 * @dev High-yield savings/staking contract with flexible lock periods and rewards
 * Features:
 * - Multiple lock periods with different APY rates
 * - Compound interest calculations
 * - Early withdrawal with penalties
 * - Flexible reward distribution
 * - NFT receipt tokens for savings positions
 * - Emergency pause functionality
 */
contract AfriSavings is ReentrancyGuard, Ownable, Pausable {
    using Address for address payable;
    
    enum SavingsStatus { ACTIVE, COMPLETED, EARLY_WITHDRAWN }
    
    struct SavingsAccount {
        uint256 id;
        address owner;
        uint256 principal;
        uint256 lockPeriod;
        uint256 startTime;
        uint256 endTime;
        uint256 apy; // in basis points (e.g., 500 = 5%)
        uint256 accruedRewards;
        uint256 lastRewardCalculation;
        SavingsStatus status;
        bool autoRenew;
        bytes32 metadataHash; // IPFS hash for additional data
    }
    
    struct LockTier {
        uint256 lockPeriod;
        uint256 apy;
        uint256 minAmount;
        uint256 maxAmount;
        bool active;
        string name;
        string description;
    }
    
    struct RewardDistribution {
        uint256 totalRewardsDistributed;
        uint256 timestamp;
        uint256 totalStakedAtDistribution;
        bytes32 merkleRoot; // For future merkle tree distributions
    }
    
    // State variables
    AfriCoin public immutable afriCoin;
    
    mapping(uint256 => SavingsAccount) public savingsAccounts;
    mapping(address => uint256[]) public userSavingsIds;
    mapping(uint256 => LockTier) public lockTiers;
    mapping(address => uint256) public userTotalStaked;
    mapping(address => uint256) public userTotalRewards;
    mapping(uint256 => RewardDistribution) public rewardDistributions;
    
    uint256 public nextSavingsId = 1;
    uint256 public nextDistributionId = 1;
    uint256 public totalStaked;
    uint256 public totalRewardsDistributed;
    uint256 public emergencyWithdrawalPenalty = 1000; // 10% in basis points
    uint256 public platformFeeRate = 200; // 2% of rewards
    address public rewardTreasury;
    uint256 public minSavingsAmount = 0.01 ether;
    bool public compoundingEnabled = true;
    
    // Default lock tiers
    uint256[] public defaultLockPeriods = [30 days, 90 days, 180 days, 365 days];
    uint256[] public defaultAPYs = [500, 650, 750, 800]; // 5%, 6.5%, 7.5%, 8%
    
    // Events
    event SavingsCreated(
        uint256 indexed savingsId,
        address indexed user,
        uint256 amount,
        uint256 lockPeriod,
        uint256 apy,
        uint256 endTime
    );
    
    event RewardsCompounded(
        uint256 indexed savingsId,
        uint256 rewardAmount,
        uint256 newPrincipal
    );
    
    event SavingsWithdrawn(
        uint256 indexed savingsId,
        address indexed user,
        uint256 principal,
        uint256 rewards,
        bool isEarlyWithdrawal
    );
    
    event RewardsDistributed(
        uint256 indexed distributionId,
        uint256 totalAmount,
        uint256 totalStakers
    );
    
    event LockTierUpdated(
        uint256 indexed tierId,
        uint256 lockPeriod,
        uint256 apy,
        bool active
    );
    
    event AutoRenewToggled(
        uint256 indexed savingsId,
        bool autoRenew
    );
    
    // Modifiers
    modifier validSavingsId(uint256 savingsId) {
        require(savingsAccounts[savingsId].owner != address(0), "Savings account does not exist");
        _;
    }
    
    modifier onlySavingsOwner(uint256 savingsId) {
        require(savingsAccounts[savingsId].owner == msg.sender, "Not savings owner");
        _;
    }
    
    constructor(
        address _afriCoin,
        address _rewardTreasury
    ) {
        require(_afriCoin != address(0), "Invalid AfriCoin address");
        require(_rewardTreasury != address(0), "Invalid reward treasury");
        
        afriCoin = AfriCoin(_afriCoin);
        rewardTreasury = _rewardTreasury;
        
        // Initialize default lock tiers
        _initializeDefaultTiers();
    }
    
    /**
     * @dev Create a new savings account
     */
    function createSavings(
        uint256 lockPeriod,
        bool autoRenew,
        bytes32 metadataHash
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        require(msg.value >= minSavingsAmount, "Amount below minimum");
        
        LockTier memory tier = _getLockTier(lockPeriod);
        require(tier.active, "Lock period not supported");
        require(msg.value >= tier.minAmount, "Amount below tier minimum");
        require(tier.maxAmount == 0 || msg.value <= tier.maxAmount, "Amount above tier maximum");
        
        uint256 savingsId = nextSavingsId++;
        uint256 endTime = block.timestamp + lockPeriod;
        
        savingsAccounts[savingsId] = SavingsAccount({
            id: savingsId,
            owner: msg.sender,
            principal: msg.value,
            lockPeriod: lockPeriod,
            startTime: block.timestamp,
            endTime: endTime,
            apy: tier.apy,
            accruedRewards: 0,
            lastRewardCalculation: block.timestamp,
            status: SavingsStatus.ACTIVE,
            autoRenew: autoRenew,
            metadataHash: metadataHash
        });
        
        userSavingsIds[msg.sender].push(savingsId);
        userTotalStaked[msg.sender] += msg.value;
        totalStaked += msg.value;
        
        // Mint AFRC tokens as initial bonus (platform specific logic)
        uint256 initialBonus = _calculateInitialBonus(msg.value, lockPeriod);
        if (initialBonus > 0) {
            afriCoin.mint(msg.sender, initialBonus);
        }
        
        emit SavingsCreated(savingsId, msg.sender, msg.value, lockPeriod, tier.apy, endTime);
        
        return savingsId;
    }
    
    /**
     * @dev Compound rewards for a savings account
     */
    function compoundRewards(uint256 savingsId) 
        external 
        nonReentrant 
        validSavingsId(savingsId) 
        whenNotPaused 
    {
        require(compoundingEnabled, "Compounding disabled");
        
        SavingsAccount storage savings = savingsAccounts[savingsId];
        require(savings.status == SavingsStatus.ACTIVE, "Savings not active");
        require(block.timestamp < savings.endTime, "Lock period ended");
        
        uint256 pendingRewards = _calculatePendingRewards(savingsId);
        if (pendingRewards > 0) {
            savings.accruedRewards += pendingRewards;
            savings.principal += pendingRewards;
            savings.lastRewardCalculation = block.timestamp;
            
            totalStaked += pendingRewards;
            userTotalStaked[savings.owner] += pendingRewards;
            
            emit RewardsCompounded(savingsId, pendingRewards, savings.principal);
        }
    }
    
    /**
     * @dev Withdraw savings after lock period
     */
    function withdrawSavings(uint256 savingsId) 
        external 
        nonReentrant 
        validSavingsId(savingsId) 
        onlySavingsOwner(savingsId) 
        whenNotPaused 
    {
        SavingsAccount storage savings = savingsAccounts[savingsId];
        require(savings.status == SavingsStatus.ACTIVE, "Savings not active");
        require(block.timestamp >= savings.endTime, "Lock period not ended");
        
        uint256 principal = savings.principal;
        uint256 finalRewards = _calculatePendingRewards(savingsId);
        uint256 totalRewards = savings.accruedRewards + finalRewards;
        
        // Apply platform fee on rewards
        uint256 platformFee = (totalRewards * platformFeeRate) / 10000;
        uint256 userRewards = totalRewards - platformFee;
        
        // Update state
        savings.status = SavingsStatus.COMPLETED;
        savings.accruedRewards = totalRewards;
        userTotalStaked[msg.sender] -= savings.principal;
        totalStaked -= savings.principal;
        userTotalRewards[msg.sender] += userRewards;
        
        // Transfer ETH back to user
        payable(msg.sender).sendValue(principal);
        
        // Mint AFRC rewards to user
        if (userRewards > 0) {
            afriCoin.mint(msg.sender, userRewards);
        }
        
        // Transfer platform fee
        if (platformFee > 0) {
            afriCoin.mint(rewardTreasury, platformFee);
        }
        
        emit SavingsWithdrawn(savingsId, msg.sender, principal, userRewards, false);
        
        // Auto-renew if enabled
        if (savings.autoRenew) {
            _autoRenewSavings(savingsId, principal);
        }
    }
    
    /**
     * @dev Emergency withdraw with penalty
     */
    function emergencyWithdraw(uint256 savingsId) 
        external 
        nonReentrant 
        validSavingsId(savingsId) 
        onlySavingsOwner(savingsId) 
        whenNotPaused 
    {
        SavingsAccount storage savings = savingsAccounts[savingsId];
        require(savings.status == SavingsStatus.ACTIVE, "Savings not active");
        require(block.timestamp < savings.endTime, "Use regular withdraw");
        
        uint256 principal = savings.principal;
        uint256 penalty = (principal * emergencyWithdrawalPenalty) / 10000;
        uint256 withdrawAmount = principal - penalty;
        
        // Update state
        savings.status = SavingsStatus.EARLY_WITHDRAWN;
        userTotalStaked[msg.sender] -= principal;
        totalStaked -= principal;
        
        // Transfer reduced amount to user
        payable(msg.sender).sendValue(withdrawAmount);
        
        // Penalty goes to reward treasury
        payable(rewardTreasury).sendValue(penalty);
        
        emit SavingsWithdrawn(savingsId, msg.sender, withdrawAmount, 0, true);
    }
    
    /**
     * @dev Toggle auto-renewal for a savings account
     */
    function toggleAutoRenew(uint256 savingsId) 
        external 
        validSavingsId(savingsId) 
        onlySavingsOwner(savingsId) 
    {
        SavingsAccount storage savings = savingsAccounts[savingsId];
        savings.autoRenew = !savings.autoRenew;
        emit AutoRenewToggled(savingsId, savings.autoRenew);
    }
    
    /**
     * @dev Batch withdraw multiple completed savings
     */
    function batchWithdraw(uint256[] calldata savingsIds) external nonReentrant whenNotPaused {
        for (uint256 i = 0; i < savingsIds.length; i++) {
            if (savingsAccounts[savingsIds[i]].owner == msg.sender &&
                savingsAccounts[savingsIds[i]].status == SavingsStatus.ACTIVE &&
                block.timestamp >= savingsAccounts[savingsIds[i]].endTime) {
                
                _internalWithdraw(savingsIds[i]);
            }
        }
    }
    
    /**
     * @dev Distribute rewards to all active savers
     */
    function distributeRewards(uint256 rewardAmount) 
        external 
        onlyOwner 
        nonReentrant 
    {
        require(rewardAmount > 0, "Invalid reward amount");
        require(totalStaked > 0, "No active stakes");
        
        // Transfer reward tokens to this contract
        afriCoin.transferFrom(msg.sender, address(this), rewardAmount);
        
        uint256 distributionId = nextDistributionId++;
        rewardDistributions[distributionId] = RewardDistribution({
            totalRewardsDistributed: rewardAmount,
            timestamp: block.timestamp,
            totalStakedAtDistribution: totalStaked,
            merkleRoot: bytes32(0) // For future use
        });
        
        totalRewardsDistributed += rewardAmount;
        
        emit RewardsDistributed(distributionId, rewardAmount, _getActiveStakersCount());
    }
    
    /**
     * @dev Get user's savings account IDs
     */
    function getUserSavingsIds(address user) external view returns (uint256[] memory) {
        return userSavingsIds[user];
    }
    
    /**
     * @dev Get savings account details
     */
    function getSavingsAccount(uint256 savingsId) 
        external 
        view 
        returns (SavingsAccount memory account, uint256 pendingRewards) 
    {
        account = savingsAccounts[savingsId];
        pendingRewards = _calculatePendingRewards(savingsId);
    }
    
    /**
     * @dev Get user statistics
     */
    function getUserStats(address user) 
        external 
        view 
        returns (
            uint256 totalStaked_,
            uint256 totalRewards_,
            uint256 activeAccounts,
            uint256 totalValue
        ) 
    {
        totalStaked_ = userTotalStaked[user];
        totalRewards_ = userTotalRewards[user];
        
        uint256[] memory userIds = userSavingsIds[user];
        for (uint256 i = 0; i < userIds.length; i++) {
            if (savingsAccounts[userIds[i]].status == SavingsStatus.ACTIVE) {
                activeAccounts++;
                totalValue += savingsAccounts[userIds[i]].principal;
                totalValue += _calculatePendingRewards(userIds[i]);
            }
        }
    }
    
    /**
     * @dev Get platform statistics
     */
    function getPlatformStats() 
        external 
        view 
        returns (
            uint256 totalStaked_,
            uint256 totalRewardsDistributed_,
            uint256 activeAccounts,
            uint256 totalAccounts,
            uint256 averageAPY
        ) 
    {
        totalStaked_ = totalStaked;
        totalRewardsDistributed_ = totalRewardsDistributed;
        totalAccounts = nextSavingsId - 1;
        
        // Calculate active accounts and average APY
        uint256 totalAPY = 0;
        for (uint256 i = 1; i < nextSavingsId; i++) {
            if (savingsAccounts[i].status == SavingsStatus.ACTIVE) {
                activeAccounts++;
                totalAPY += savingsAccounts[i].apy;
            }
        }
        
        if (activeAccounts > 0) {
            averageAPY = totalAPY / activeAccounts;
        }
    }
    
    /**
     * @dev Get available lock tiers
     */
    function getActiveLockTiers() external view returns (LockTier[] memory) {
        uint256 activeCount = 0;
        
        // Count active tiers
        for (uint256 i = 0; i < defaultLockPeriods.length; i++) {
            if (lockTiers[defaultLockPeriods[i]].active) {
                activeCount++;
            }
        }
        
        LockTier[] memory activeTiers = new LockTier[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < defaultLockPeriods.length; i++) {
            if (lockTiers[defaultLockPeriods[i]].active) {
                activeTiers[index] = lockTiers[defaultLockPeriods[i]];
                index++;
            }
        }
        
        return activeTiers;
    }
    
    /**
     * @dev Calculate pending rewards for a savings account
     */
    function _calculatePendingRewards(uint256 savingsId) internal view returns (uint256) {
        SavingsAccount memory savings = savingsAccounts[savingsId];
        
        if (savings.status != SavingsStatus.ACTIVE) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - savings.lastRewardCalculation;
        if (timeElapsed == 0) {
            return 0;
        }
        
        // Calculate rewards based on APY
        uint256 annualRewards = (savings.principal * savings.apy) / 10000;
        uint256 rewards = (annualRewards * timeElapsed) / 365 days;
        
        return rewards;
    }
    
    /**
     * @dev Internal withdraw function
     */
    function _internalWithdraw(uint256 savingsId) internal {
        SavingsAccount storage savings = savingsAccounts[savingsId];
        
        uint256 principal = savings.principal;
        uint256 finalRewards = _calculatePendingRewards(savingsId);
        uint256 totalRewards = savings.accruedRewards + finalRewards;
        
        uint256 platformFee = (totalRewards * platformFeeRate) / 10000;
        uint256 userRewards = totalRewards - platformFee;
        
        savings.status = SavingsStatus.COMPLETED;
        savings.accruedRewards = totalRewards;
        userTotalStaked[savings.owner] -= principal;
        totalStaked -= principal;
        userTotalRewards[savings.owner] += userRewards;
        
        payable(savings.owner).sendValue(principal);
        
        if (userRewards > 0) {
            afriCoin.mint(savings.owner, userRewards);
        }
        
        if (platformFee > 0) {
            afriCoin.mint(rewardTreasury, platformFee);
        }
        
        emit SavingsWithdrawn(savingsId, savings.owner, principal, userRewards, false);
    }
    
    /**
     * @dev Auto-renew a savings account
     */
    function _autoRenewSavings(uint256 oldSavingsId, uint256 amount) internal {
        SavingsAccount memory oldSavings = savingsAccounts[oldSavingsId];
        
        uint256 newSavingsId = nextSavingsId++;
        uint256 endTime = block.timestamp + oldSavings.lockPeriod;
        
        savingsAccounts[newSavingsId] = SavingsAccount({
            id: newSavingsId,
            owner: oldSavings.owner,
            principal: amount,
            lockPeriod: oldSavings.lockPeriod,
            startTime: block.timestamp,
            endTime: endTime,
            apy: oldSavings.apy,
            accruedRewards: 0,
            lastRewardCalculation: block.timestamp,
            status: SavingsStatus.ACTIVE,
            autoRenew: oldSavings.autoRenew,
            metadataHash: oldSavings.metadataHash
        });
        
        userSavingsIds[oldSavings.owner].push(newSavingsId);
        userTotalStaked[oldSavings.owner] += amount;
        totalStaked += amount;
        
        emit SavingsCreated(newSavingsId, oldSavings.owner, amount, oldSavings.lockPeriod, oldSavings.apy, endTime);
    }
    
    /**
     * @dev Get lock tier information
     */
    function _getLockTier(uint256 lockPeriod) internal view returns (LockTier memory) {
        return lockTiers[lockPeriod];
    }
    
    /**
     * @dev Calculate initial bonus tokens
     */
    function _calculateInitialBonus(uint256 amount, uint256 lockPeriod) internal pure returns (uint256) {
        // Bonus calculation: longer lock = more bonus
        uint256 bonusRate = 0;
        
        if (lockPeriod >= 365 days) {
            bonusRate = 1000; // 10%
        } else if (lockPeriod >= 180 days) {
            bonusRate = 500; // 5%
        } else if (lockPeriod >= 90 days) {
            bonusRate = 250; // 2.5%
        } else if (lockPeriod >= 30 days) {
            bonusRate = 100; // 1%
        }
        
        return (amount * bonusRate) / 10000;
    }
    
    /**
     * @dev Get count of active stakers
     */
    function _getActiveStakersCount() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 1; i < nextSavingsId; i++) {
            if (savingsAccounts[i].status == SavingsStatus.ACTIVE) {
                count++;
            }
        }
        return count;
    }
    
    /**
     * @dev Initialize default lock tiers
     */
    function _initializeDefaultTiers() internal {
        string[] memory tierNames = new string[](4);
        tierNames[0] = "Starter";
        tierNames[1] = "Builder"; 
        tierNames[2] = "Growth";
        tierNames[3] = "Premium";
        
        string[] memory descriptions = new string[](4);
        descriptions[0] = "Short-term savings with good returns";
        descriptions[1] = "Medium-term growth opportunity";
        descriptions[2] = "Higher returns for patient savers";
        descriptions[3] = "Maximum returns for long-term commitment";
        
        for (uint256 i = 0; i < defaultLockPeriods.length; i++) {
            lockTiers[defaultLockPeriods[i]] = LockTier({
                lockPeriod: defaultLockPeriods[i],
                apy: defaultAPYs[i],
                minAmount: minSavingsAmount,
                maxAmount: 0, // No maximum
                active: true,
                name: tierNames[i],
                description: descriptions[i]
            });
        }
    }
    
    // Admin functions
    function updateLockTier(
        uint256 lockPeriod,
        uint256 apy,
        uint256 minAmount,
        uint256 maxAmount,
        bool active,
        string calldata name,
        string calldata description
    ) external onlyOwner {
        lockTiers[lockPeriod] = LockTier({
            lockPeriod: lockPeriod,
            apy: apy,
            minAmount: minAmount,
            maxAmount: maxAmount,
            active: active,
            name: name,
            description: description
        });
        
        emit LockTierUpdated(lockPeriod, lockPeriod, apy, active);
    }
    
    function setEmergencyWithdrawalPenalty(uint256 newPenalty) external onlyOwner {
        require(newPenalty <= 2000, "Penalty too high"); // Max 20%
        emergencyWithdrawalPenalty = newPenalty;
    }
    
    function setPlatformFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000, "Fee too high"); // Max 10%
        platformFeeRate = newFeeRate;
    }
    
    function setMinSavingsAmount(uint256 newMinAmount) external onlyOwner {
        minSavingsAmount = newMinAmount;
    }
    
    function setCompoundingEnabled(bool enabled) external onlyOwner {
        compoundingEnabled = enabled;
    }
    
    function setRewardTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury address");
        rewardTreasury = newTreasury;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // Emergency functions
    function emergencyWithdrawContract() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    receive() external payable {
        // Allow contract to receive ETH
    }
}