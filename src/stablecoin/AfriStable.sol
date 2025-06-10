// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {Events} from "../libraries/Events.sol";


/**
 * @title AfriStable (AFX) - Hybrid Collateralized Nigerian Naira Stablecoin
 * @dev A hybrid stablecoin backed by both fiat reserves and crypto collateral
 * @notice Combines centralized fiat backing with decentralized crypto collateral
 * 
 * Key Features:
 * - Dual collateral system: Fiat reserves + Crypto collateral
 * - Dynamic collateral ratios based on market conditions
 * - Integrated price oracle for real-time valuations
 * - Over-collateralization for crypto assets
 * - Emergency liquidation mechanisms
 * - Automated rebalancing capabilities
 */
contract AfriStable is ERC20, Ownable, Pausable, ReentrancyGuard {
    
    // ============ INTERFACES ============
    IPriceFeed public priceFeed;
    
    // ============ STATE VARIABLES ============
    
    /// @notice Current exchange rate: 1 AFX = X NGN (scaled by 1e18)
    uint256 public ngnExchangeRate = 1e18;
    
    /// @notice Total fiat reserves in NGN equivalent (scaled by 1e18)
    uint256 public totalFiatReserves;
    
    /// @notice Target ratio of fiat backing (in basis points, 10000 = 100%)
    uint256 public targetFiatRatio = 6000; // 60% fiat backing target
    
    /// @notice Minimum fiat ratio before rebalancing (in basis points)
    uint256 public minimumFiatRatio = 4000; // 40% minimum
    
    /// @notice Maximum fiat ratio before rebalancing (in basis points)
    uint256 public maximumFiatRatio = 8000; // 80% maximum
    
    /// @notice Over-collateralization ratio for crypto assets (in basis points)
    uint256 public cryptoCollateralRatio = 15000; // 150% over-collateralized
    
    /// @notice Liquidation threshold for crypto collateral (in basis points)
    uint256 public liquidationThreshold = 12000; // 120% - liquidate if below
    
    /// @notice Stability fee rate for crypto collateral positions (annual, in basis points)
    uint256 public stabilityFeeRate = 200; // 2% annual
    
    /// @notice Minimum mint amounts
    uint256 public minimumMintAmount = 995e15;
    uint256 public maximumMintAmount = 1000000e18;
    
    /// @notice Fee rates
    uint256 public mintFeeRate = 50; // 0.5%
    uint256 public burnFeeRate = 50; // 0.5%
    
    // ============ STRUCTS ============
    
    struct CollateralAsset {
        address tokenAddress;
        uint256 totalDeposited;
        uint256 collateralRatio; // Required over-collateralization ratio
        uint256 liquidationThreshold;
        bool isActive;
        uint256 debtCeiling; // Maximum AFX that can be minted against this collateral
        uint256 currentDebt; // Current AFX minted against this collateral
    }
    
    struct UserPosition {
        uint256 collateralAmount;
        uint256 debtAmount; // AFX minted against this collateral
        uint256 lastFeeUpdate; // Timestamp of last stability fee update
        uint256 accruedFees; // Accumulated stability fees
    }
    
    // ============ CONSTANTS ============

/// @notice Default collateral ratio for all supported tokens (150%)
uint256 public constant DEFAULT_COLLATERAL_RATIO = 15000;

/// @notice Default liquidation threshold for all supported tokens (120%)
uint256 public constant DEFAULT_LIQUIDATION_THRESHOLD = 12000;

/// @notice Default debt ceiling for each supported token (1M AFX)
uint256 public constant DEFAULT_DEBT_CEILING = 1000000e18;


    // ============ MAPPINGS ============
    
    /// @notice Supported collateral assets
    mapping(address => CollateralAsset) public collateralAssets;
    address[] public supportedCollaterals;
    
    
    /// @notice User positions for each collateral type
    mapping(address => mapping(address => UserPosition)) public userPositions; // user => collateral => position
    
    /// @notice Authorization mappings
    mapping(address => bool) public minters;
    mapping(address => bool) public burners;
    mapping(address => bool) public blacklisted;
    mapping(address => bool) public priceOracles;
    mapping(address => bool) public liquidators;
    mapping(string => bool) public processedTransactions;
    mapping(address => bool) public fiatDepositors;

  
    
    // ============ MODIFIERS ============
    modifier onlyFiatDepositor() {
    require(fiatDepositors[msg.sender] || msg.sender == owner(), "AFX: Not authorized for fiat deposits");
    _;
    }
    
    modifier onlyMinter() {
        require(minters[msg.sender] || msg.sender == owner(), "AFX: Not authorized to mint");
        _;
    }
    
    modifier onlyBurner() {
        require(burners[msg.sender] || msg.sender == owner(), "AFX: Not authorized to burn");
        _;
    }
    
    modifier onlyOracle() {
        require(priceOracles[msg.sender] || msg.sender == owner(), "AFX: Not authorized oracle");
        _;
    }
    
    modifier onlyLiquidator() {
        require(liquidators[msg.sender] || msg.sender == owner(), "AFX: Not authorized liquidator");
        _;
    }
    
    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "AFX: Address is blacklisted");
        _;
    }
    
    modifier validCollateral(address collateral) {
        require(collateralAssets[collateral].isActive, "AFX: Invalid collateral");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
constructor(
    address _priceFeed,
    address[] memory initialCollaterals
) ERC20("AfriStable", "AFX") Ownable(msg.sender) {
    priceFeed = IPriceFeed(_priceFeed);
    
    // Grant initial roles
    minters[msg.sender] = true;
    burners[msg.sender] = true;
    priceOracles[msg.sender] = true;
    liquidators[msg.sender] = true;
    
    // Initialize supported collaterals with default parameters
    if (initialCollaterals.length > 0) {
        _initializeCollaterals(initialCollaterals);
    }
}



      
    
    // ============ FIAT-BACKED MINTING ============
    
    /**
     * @notice Mint AFX tokens backed by fiat reserves
     */
    function mintWithFiat(address to, uint256 amount)
        external
        onlyMinter
        whenNotPaused
        nonReentrant
        notBlacklisted(to)
    {
        require(amount >= minimumMintAmount && amount <= maximumMintAmount, "AFX: Invalid amount");
        
        uint256 ngnValue = (amount * ngnExchangeRate) / 1e18;
        uint256 fee = (ngnValue * mintFeeRate) / 10000;
        uint256 requiredReserves = ngnValue + fee;
        
        require(totalFiatReserves >= requiredReserves, "AFX: Insufficient fiat reserves");
        
        // Check if fiat backing ratio stays within limits after mint
        uint256 newTotalSupply = totalSupply() + amount;
        uint256 newFiatRatio = (totalFiatReserves * 10000) / ((newTotalSupply * ngnExchangeRate) / 1e18);
        require(newFiatRatio >= minimumFiatRatio, "AFX: Would breach minimum fiat ratio");
        
        totalFiatReserves -= ngnValue;
        _mint(to, amount);
        
        emit Events.TokensMinted(to, amount, ngnValue, fee);
    }

    /**
    * @notice Accept fiat deposit and mint AFX tokens
    */
    function depositFiatAndMint(uint256 ngnAmount, address to) 
    external 
    whenNotPaused 
    onlyFiatDepositor
    nonReentrant 
    notBlacklisted(to)
    
{
    require(ngnAmount > 0, "AFX: Invalid NGN amount");
    
    // Add fiat reserves first
    totalFiatReserves += ngnAmount;

    // Calculate AFX amount to mint
    uint256 afxAmount = (ngnAmount * 1e18) / ngnExchangeRate;
    uint256 fee = (afxAmount * mintFeeRate) / 10000;
    uint256 netAmount = afxAmount - fee;

    require(netAmount >= minimumMintAmount, "AFX: Below minimum mint");
    require(netAmount <= maximumMintAmount, "AFX: Above maximum mint");

    _mint(to, netAmount);
    if (fee > 0) {
        _mint(owner(), fee); // Mint fee to treasury
    }

    emit Events.TokensMinted(to, netAmount, ngnAmount, fee);
}
    
   
    /**
    * @notice Callback for external fiat payment confirmation
    */
    function confirmFiatDeposit(
        address user,
        uint256 ngnAmount,
        string calldata transactionRef
    ) 
        external 
        onlyFiatDepositor 
        whenNotPaused 
    {
    // Verify transaction hasn't been processed
    require(!processedTransactions[transactionRef], "AFX: Already processed");
    processedTransactions[transactionRef] = true;
    
    // Add reserves and mint
    totalFiatReserves += ngnAmount;
    uint256 afxAmount = (ngnAmount * 1e18) / ngnExchangeRate;
    uint256 fee = (afxAmount * mintFeeRate) / 10000;
    uint256 netAmount = afxAmount - fee;
    
    _mint(user, netAmount);
    _mint(owner(), fee);
    
    emit Events.FiatDepositConfirmed(user, ngnAmount, afxAmount, transactionRef);
    }


    // ============ CRYPTO-COLLATERALIZED MINTING ============
    
    /**
     * @notice Deposit collateral and mint AFX tokens
     */
    function mintWithCrypto(
        address collateral,
        uint256 collateralAmount,
        uint256 mintAmount
    )
        internal
        whenNotPaused
        nonReentrant
        notBlacklisted(msg.sender)
        validCollateral(collateral)
    {
        require(mintAmount > 0, "AFX: Invalid mint amount");
        
        CollateralAsset storage asset = collateralAssets[collateral];
        require(asset.currentDebt + mintAmount <= asset.debtCeiling, "AFX: Exceeds debt ceiling");
        
        // Transfer collateral from user
        IERC20(collateral).transferFrom(msg.sender, address(this), collateralAmount);
        
        // Update user position
        UserPosition storage position = userPositions[msg.sender][collateral];
        
        // Collect any accrued stability fees first
        _collectStabilityFee(msg.sender, collateral);
        
        position.collateralAmount += collateralAmount;
        position.debtAmount += mintAmount;
        
        // Check collateralization ratio
        require(_isPositionSafe(msg.sender, collateral), "AFX: Insufficient collateralization");
        
        // Update global state
        asset.totalDeposited += collateralAmount;
        asset.currentDebt += mintAmount;
        
        // Mint tokens
        _mint(msg.sender, mintAmount);
        
        emit Events.CollateralDeposited(msg.sender, collateral, collateralAmount);
        emit Events.CryptoMint(msg.sender, collateral, collateralAmount, mintAmount);
    }
    


/**
 * @notice Simplified crypto deposit and mint in one transaction
 */
function depositAndMint(address collateral, uint256 collateralAmount)
    external
    whenNotPaused
    notBlacklisted(msg.sender)
    validCollateral(collateral)
{
    // Calculate maximum safe mint amount
    uint256 collateralPrice = priceFeed.getLatestPrice(collateral);
    uint256 collateralValue = (collateralAmount * collateralPrice) / 1e18;
    uint256 maxMintValue = (collateralValue * 10000) / collateralAssets[collateral].collateralRatio;
    uint256 maxMintAmount = (maxMintValue * 1e18) / ngnExchangeRate;
    
    // Use 90% of max to provide safety buffer
    uint256 safeMintAmount = (maxMintAmount * 9000) / 10000;
    
    mintWithCrypto(collateral, collateralAmount, safeMintAmount);
}

    /**
     * @notice Burn AFX and withdraw collateral
     */
    function burnAndWithdraw(
        address collateral,
        uint256 burnAmount,
        uint256 withdrawAmount
    )
        external
        whenNotPaused
        nonReentrant
        notBlacklisted(msg.sender)
        validCollateral(collateral)
    {
        UserPosition storage position = userPositions[msg.sender][collateral];
        require(position.debtAmount >= burnAmount, "AFX: Insufficient debt to burn");
        require(position.collateralAmount >= withdrawAmount, "AFX: Insufficient collateral");
        
        // Collect stability fees
        _collectStabilityFee(msg.sender, collateral);
        
        // Burn tokens
        _burn(msg.sender, burnAmount);
        
        // Update position
        position.debtAmount -= burnAmount;
        position.collateralAmount -= withdrawAmount;
        
        // Check if remaining position is safe (if any debt remains)
        if (position.debtAmount > 0) {
            require(_isPositionSafe(msg.sender, collateral), "AFX: Position becomes unsafe");
        }
        
        // Update global state
        CollateralAsset storage asset = collateralAssets[collateral];
        asset.totalDeposited -= withdrawAmount;
        asset.currentDebt -= burnAmount;
        
        // Transfer collateral back to user
        IERC20(collateral).transfer(msg.sender, withdrawAmount);
        
        emit Events.CryptoBurn(msg.sender, collateral, burnAmount, withdrawAmount);
        emit Events.CollateralWithdrawn(msg.sender, collateral, withdrawAmount);
    }
    
    // ============ LIQUIDATION SYSTEM ============
    
    /**
     * @notice Liquidate an unsafe position
     */
    function liquidate(
        address user,
        address collateral,
        uint256 debtToCover
    )
        external
        onlyLiquidator
        whenNotPaused
        nonReentrant
        validCollateral(collateral)
    {
        require(!_isPositionSafe(user, collateral), "AFX: Position is safe");
        
        UserPosition storage position = userPositions[user][collateral];
        require(position.debtAmount > 0, "AFX: No debt to liquidate");
        
        // Collect any outstanding fees first
        _collectStabilityFee(user, collateral);
        
        uint256 actualDebtToCover = debtToCover > position.debtAmount ? position.debtAmount : debtToCover;
        
        // Calculate collateral to seize (with liquidation bonus)
        uint256 collateralPrice = priceFeed.getLatestPrice(collateral);
        uint256 debtValueInCollateral = (actualDebtToCover * ngnExchangeRate * 1e18) / (collateralPrice * 1e18);
        uint256 liquidationBonus = (debtValueInCollateral * 500) / 10000; // 5% liquidation bonus
        uint256 collateralToSeize = debtValueInCollateral + liquidationBonus;
        
        require(collateralToSeize <= position.collateralAmount, "AFX: Not enough collateral");
        
        // Update position
        position.debtAmount -= actualDebtToCover;
        position.collateralAmount -= collateralToSeize;
        
        // Update global state
        CollateralAsset storage asset = collateralAssets[collateral];
        asset.totalDeposited -= collateralToSeize;
        asset.currentDebt -= actualDebtToCover;
        
        // Transfer collateral to liquidator (they need to provide AFX to burn)
        _burn(msg.sender, actualDebtToCover);
        IERC20(collateral).transfer(msg.sender, collateralToSeize);
        
        emit Events.Liquidation(user, collateral, collateralToSeize, actualDebtToCover);
    }
    
    // ============ STABILITY FEE SYSTEM ============
    
    /**
     * @notice Collect accrued stability fees for a position
     */
    function _collectStabilityFee(address user, address collateral) internal {
        UserPosition storage position = userPositions[user][collateral];
        
        if (position.debtAmount == 0 || position.lastFeeUpdate == 0) {
            position.lastFeeUpdate = block.timestamp;
            return;
        }
        
        uint256 timeElapsed = block.timestamp - position.lastFeeUpdate;
        uint256 annualFee = (position.debtAmount * stabilityFeeRate) / 10000;
        uint256 feeAccrued = (annualFee * timeElapsed) / 365 days;
        
        if (feeAccrued > 0) {
            position.accruedFees += feeAccrued;
            position.debtAmount += feeAccrued;
            
            // Mint stability fees to treasury/owner
            _mint(owner(), feeAccrued);
            
            emit Events.FeeCollected(feeAccrued, address(this), block.timestamp);
        }
        
        position.lastFeeUpdate = block.timestamp;
    }
    
    /**
     * @notice Check if a position is safely collateralized
     */
    function _isPositionSafe(address user, address collateral) internal view returns (bool) {
        UserPosition storage position = userPositions[user][collateral];
        
        if (position.debtAmount == 0) return true;
        
        uint256 collateralPrice = priceFeed.getLatestPrice(collateral);
        uint256 collateralValue = (position.collateralAmount * collateralPrice) / 1e18;
        uint256 debtValue = (position.debtAmount * ngnExchangeRate) / 1e18;
        
        uint256 currentRatio = (collateralValue * 10000) / debtValue;
        return currentRatio >= collateralAssets[collateral].liquidationThreshold;
    }


//=============== ESTIMATION ==============
   /**
 * @notice Main estimation function for frontend - calculates AFX output for any input
 * @param inputToken Address of input token (address(0) for fiat/NGN)
 * @param inputAmount Amount of input token/fiat
 * @return outputAmount AFX tokens user will receive
 */
function estimateTokenOutput(address inputToken, uint256 inputAmount)
    external
    view
    returns (uint256 outputAmount)
{
    if (inputToken == address(0)) {
        // Fiat deposit (NGN)
        return _estimateFromFiat(inputAmount);
    } else {
        // Crypto collateral deposit
        return _estimateFromCrypto(inputToken, inputAmount);
    }
}

/**
 * @notice Internal function to estimate AFX from fiat
 */
function _estimateFromFiat(uint256 ngnAmount) 
    internal 
    view 
    returns (uint256 outputAmount) 
{
    if (ngnAmount == 0) {
        return 0;
    }
        
    uint256 afxAmount = (ngnAmount * 1e18) / ngnExchangeRate;
    uint256 fee = (afxAmount * mintFeeRate) / 10000;
    outputAmount = afxAmount - fee;
        
    if (outputAmount < minimumMintAmount) {
        return 0;
    }
        
    if (outputAmount > maximumMintAmount) {
        return 0;
    }
        
    // Check if enough fiat reserves (assuming this deposit adds to reserves)
    uint256 requiredReserves = ngnAmount;
    if (totalFiatReserves < requiredReserves) {
        return 0;
    }
        
    return outputAmount;
}

/**
 * @notice Internal function to estimate AFX from crypto
 */
function _estimateFromCrypto(address collateral, uint256 collateralAmount)
    internal
    view
    returns (uint256 outputAmount)
{
    if (!collateralAssets[collateral].isActive) {
        return 0;
    }
        
    if (collateralAmount == 0) {
        return 0;
    }
        
    CollateralAsset storage asset = collateralAssets[collateral];
    uint256 collateralPrice = priceFeed.getLatestPrice(collateral);
        
    if (collateralPrice == 0) {
        return 0;
    }
        
    uint256 collateralValue = (collateralAmount * collateralPrice) / 1e18;
        
    // Calculate safe mint amount (90% of max for safety buffer)
    uint256 maxMintValue = (collateralValue * 10000) / asset.collateralRatio;
    uint256 maxMintAmount = (maxMintValue * 1e18) / ngnExchangeRate;
    outputAmount = (maxMintAmount * 9000) / 10000; // 90% for safety
        
    // Check debt ceiling
    if (asset.currentDebt + outputAmount > asset.debtCeiling) {
        uint256 remainingCeiling = asset.debtCeiling > asset.currentDebt ? 
            asset.debtCeiling - asset.currentDebt : 0;
        if (remainingCeiling == 0) {
            return 0;
        }
        outputAmount = remainingCeiling;
    }
        
    if (outputAmount < minimumMintAmount) {
        return 0;
    }
        
    return outputAmount;
}
    
    // ============ REBALANCING SYSTEM ============
    
    /**
     * @notice Trigger rebalancing between fiat and crypto backing
     */
    function rebalance() external onlyOwner whenNotPaused {
        uint256 totalSupplyValue = (totalSupply() * ngnExchangeRate) / 1e18;
        uint256 currentFiatRatio = totalSupplyValue > 0 ? (totalFiatReserves * 10000) / totalSupplyValue : 0;
        
        if (currentFiatRatio < minimumFiatRatio || currentFiatRatio > maximumFiatRatio) {
            // Simplified rebalancing logic for demo: Adjust fiat reserves to target ratio
            // In a real system, this would involve more complex mechanisms like selling/buying collateral.
            uint256 targetFiatReserves = (totalSupplyValue * targetFiatRatio) / 10000;
            if (totalFiatReserves < targetFiatReserves) {
                // Simulate adding fiat reserves to reach target (e.g., from off-chain operations)
                // For a demo, this might represent a manual injection or an automated process.
                totalFiatReserves = targetFiatReserves;
            } else if (totalFiatReserves > targetFiatReserves) {
                // Simulate reduction of fiat reserves (e.g., by buying crypto collateral)
                // For a demo, this would just be a state change.
                totalFiatReserves = targetFiatReserves;
            }
            emit Events.RebalanceTriggered(currentFiatRatio, targetFiatRatio);
        }
    }
    
    // ============ COLLATERAL MANAGEMENT ============
    
    /**
 * @notice Add a new collateral asset with default parameters
 */
function addCollateralAsset(address tokenAddress) external onlyOwner {
    require(tokenAddress != address(0), "AFX: Invalid token address");
    require(!collateralAssets[tokenAddress].isActive, "AFX: Collateral already exists");
    
    collateralAssets[tokenAddress] = CollateralAsset({
        tokenAddress: tokenAddress,
        totalDeposited: 0,
        collateralRatio: DEFAULT_COLLATERAL_RATIO,
        liquidationThreshold: DEFAULT_LIQUIDATION_THRESHOLD,
        isActive: true,
        debtCeiling: DEFAULT_DEBT_CEILING,
        currentDebt: 0
    });
    
    supportedCollaterals.push(tokenAddress);
    
    emit Events.CollateralAssetAdded(tokenAddress, DEFAULT_COLLATERAL_RATIO, DEFAULT_DEBT_CEILING);
}

/**
 * @notice Add multiple collateral assets at once
 */
function addCollateralAssets(address[] memory tokenAddresses) external onlyOwner {
    for (uint256 i = 0; i < tokenAddresses.length; i++) {
        require(tokenAddresses[i] != address(0), "AFX: Invalid token address");
        require(!collateralAssets[tokenAddresses[i]].isActive, "AFX: Collateral already exists");
        
        collateralAssets[tokenAddresses[i]] = CollateralAsset({
            tokenAddress: tokenAddresses[i],
            totalDeposited: 0,
            collateralRatio: DEFAULT_COLLATERAL_RATIO,
            liquidationThreshold: DEFAULT_LIQUIDATION_THRESHOLD,
            isActive: true,
            debtCeiling: DEFAULT_DEBT_CEILING,
            currentDebt: 0
        });
        
        supportedCollaterals.push(tokenAddresses[i]);
        
        emit Events.CollateralAssetAdded(tokenAddresses[i], DEFAULT_COLLATERAL_RATIO, DEFAULT_DEBT_CEILING);
    }
}

/**
 * @notice Update collateral parameters (admin function for flexibility)
 */
function updateCollateralAsset(
    address tokenAddress,
    uint256 collateralRatio,
    uint256 _liquidationThreshold,
    uint256 debtCeiling
) external onlyOwner validCollateral(tokenAddress) {
    require(collateralRatio >= 11000, "AFX: Collateral ratio too low");
    require(_liquidationThreshold < collateralRatio, "AFX: Invalid liquidation threshold");
    
    CollateralAsset storage asset = collateralAssets[tokenAddress];
    asset.collateralRatio = collateralRatio;
    asset.liquidationThreshold = _liquidationThreshold;
    asset.debtCeiling = debtCeiling;
    
    emit Events.CollateralAssetUpdated(tokenAddress, collateralRatio, _liquidationThreshold, debtCeiling);
}
   

    // ============ ORACLE AND PRICE FUNCTIONS ============
    
    /**
     * @notice Update the price feed contract
     */
    function setPriceFeed(address _priceFeed) external onlyOwner {
        require(_priceFeed != address(0), "AFX: Invalid price feed");
        priceFeed = IPriceFeed(_priceFeed);
    }
    
    /**
     * @notice Update NGN exchange rate
     */
    function updateExchangeRate(uint256 newRate) external onlyOracle whenNotPaused {
        require(newRate > 0, "AFX: Invalid exchange rate");
        uint256 oldRate = ngnExchangeRate;
        ngnExchangeRate = newRate;
        emit Events.ExchangeRateUpdated(oldRate, newRate);
    }
    
    // ============ RESERVES MANAGEMENT ============
    
    /**
     * @notice Add fiat reserves
     */
    function addFiatReserves(uint256 amount) external onlyOwner whenNotPaused {
        require(amount > 0, "AFX: Invalid amount");
        uint256 oldReserves = totalFiatReserves;
        totalFiatReserves += amount;
        emit Events.FiatReservesUpdated(oldReserves, totalFiatReserves);
    }
    
    /**
     * @notice Set fiat reserves (emergency function)
     */
    function setFiatReserves(uint256 newAmount) external onlyOwner whenNotPaused {
        // WARNING: This function allows arbitrary setting of fiat reserves and is highly risky in production.
        // It is included for demonstration purposes only to allow easy manipulation of fiat backing.
        // In a production environment, this function should be removed or secured with extreme caution (e.g., multi-sig, time-lock).
        uint256 oldReserves = totalFiatReserves;
        totalFiatReserves = newAmount;
        emit Events.FiatReservesUpdated(oldReserves, newAmount);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @notice Get comprehensive system health information
     */
    function getSystemHealth() external view returns (
        uint256 totalSupplyAmount,
        uint256 fiatReserves,
        uint256 totalCryptoValue,
        uint256 fiatBackingRatio,
        uint256 cryptoBackingRatio,
        uint256 totalBackingRatio
    ) {
        totalSupplyAmount = totalSupply();
        fiatReserves = totalFiatReserves;
        
        // Calculate total crypto collateral value
        uint256 cryptoValue = 0;
        for (uint256 i = 0; i < supportedCollaterals.length; i++) {
            address collateral = supportedCollaterals[i];
            CollateralAsset storage asset = collateralAssets[collateral];
            if (asset.isActive && asset.totalDeposited > 0) {
                uint256 price = priceFeed.getLatestPrice(collateral);
                cryptoValue += (asset.totalDeposited * price) / 1e18;
            }
        }
        totalCryptoValue = cryptoValue;
        
        uint256 totalValue = (totalSupplyAmount * ngnExchangeRate) / 1e18;
        
        if (totalValue > 0) {
            fiatBackingRatio = (fiatReserves * 10000) / totalValue;
            cryptoBackingRatio = (cryptoValue * 10000) / totalValue;
            totalBackingRatio = fiatBackingRatio + cryptoBackingRatio;
        }
    }
    
    /**
     * @notice Get user position information
     */
    function getUserPosition(address user, address collateral)
        external
        view
        returns (
            uint256 collateralAmount,
            uint256 debtAmount,
            uint256 collateralizationRatio,
            bool isSafe,
            uint256 maxWithdrawable
        )
    {
        UserPosition storage position = userPositions[user][collateral];
        collateralAmount = position.collateralAmount;
        debtAmount = position.debtAmount;
        
        if (debtAmount > 0) {
            uint256 collateralPrice = priceFeed.getLatestPrice(collateral);
            uint256 collateralValue = (collateralAmount * collateralPrice) / 1e18;
            uint256 debtValue = (debtAmount * ngnExchangeRate) / 1e18;
            collateralizationRatio = (collateralValue * 10000) / debtValue;
            isSafe = collateralizationRatio >= collateralAssets[collateral].liquidationThreshold;
            
            // Calculate max withdrawable collateral
            uint256 minCollateralValue = (debtValue * collateralAssets[collateral].collateralRatio) / 10000;
            uint256 minCollateralAmount = (minCollateralValue * 1e18) / collateralPrice;
            maxWithdrawable = collateralAmount > minCollateralAmount ? collateralAmount - minCollateralAmount : 0;
        } else {
            collateralizationRatio = type(uint256).max;
            isSafe = true;
            maxWithdrawable = collateralAmount;
        }
    }
    
    /**
     * @notice Get supported collaterals list
     */
    function getSupportedCollaterals() external view returns (address[] memory) {
        return supportedCollaterals;
    }
    
    // ============ ACCESS CONTROL ============
    
    function setMinter(address account, bool status) external onlyOwner {
        minters[account] = status;
        emit Events.MinterStatusUpdated(account, status);
    }
    
    function setBurner(address account, bool status) external onlyOwner {
        burners[account] = status;
        emit Events.BurnerStatusUpdated(account, status);
    }
    
    function setOracle(address account, bool status) external onlyOwner {
        priceOracles[account] = status;
        emit Events.OracleStatusUpdated(account, status);
    }
    
    function setLiquidator(address account, bool status) external onlyOwner {
        liquidators[account] = status;
        emit Events.LiquidatorStatusUpdated(account, status);
    }
    
    function setBlacklist(address account, bool status) external onlyOwner {
        blacklisted[account] = status;
        emit Events.BlacklistStatusUpdated(account, status);
    }
    
    // ============ PARAMETER UPDATES ============
    
    function setStabilityFeeRate(uint256 newRate) external onlyOwner {
        require(newRate <= 2000, "AFX: Fee rate too high"); // Max 20% annual
        stabilityFeeRate = newRate;
        emit Events.StabilityFeeRateUpdated(stabilityFeeRate, newRate);
    }
    
    function setTargetFiatRatio(uint256 newRatio) external onlyOwner {
        require(newRatio >= 1000 && newRatio <= 9000, "AFX: Invalid ratio");
        targetFiatRatio = newRatio;
        emit Events.TargetFiatRatioUpdated(targetFiatRatio, newRatio);
    }
    
    function setFiatRatioLimits(uint256 minRatio, uint256 maxRatio) external onlyOwner {
        require(minRatio < maxRatio, "AFX: Invalid limits");
        require(minRatio >= 1000 && maxRatio <= 9000, "AFX: Ratios out of range");
        minimumFiatRatio = minRatio;
        maximumFiatRatio = maxRatio;
        emit Events.FiatRatioLimitsUpdated(minimumFiatRatio, maximumFiatRatio, minRatio, maxRatio);
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // ============ TRANSFER OVERRIDES ============
    
    function transfer(address to, uint256 amount)
        public
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        returns (bool)
    {
        return super.transfer(to, amount);
    }
    
    function transferFrom(address from, address to, uint256 amount)
        public
        override
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(to)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 18;
    }

  //===================== HELPER FUNCTION ====================//
/**
 * @notice Helper function to initialize multiple collateral assets with default parameters
 */
function _initializeCollaterals(address[] memory tokenAddresses) internal {
    for (uint256 i = 0; i < tokenAddresses.length; i++) {
        require(tokenAddresses[i] != address(0), "AFX: Invalid token address");
        
        collateralAssets[tokenAddresses[i]] = CollateralAsset({
            tokenAddress: tokenAddresses[i],
            totalDeposited: 0,
            collateralRatio: DEFAULT_COLLATERAL_RATIO,
            liquidationThreshold: DEFAULT_LIQUIDATION_THRESHOLD,
            isActive: true,
            debtCeiling: DEFAULT_DEBT_CEILING,
            currentDebt: 0
        });
        
        supportedCollaterals.push(tokenAddresses[i]);
        
        emit Events.CollateralAssetAdded(tokenAddresses[i], DEFAULT_COLLATERAL_RATIO, DEFAULT_DEBT_CEILING);
    }
}
}