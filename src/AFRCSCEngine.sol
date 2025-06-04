// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { OracleLib } from "./libraries/OracleLib.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AFRCStableCoin } from "./AFRCStableCoin.sol";

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

/*
 * @title DSCEngine
 * @author Patrick Collins (modified for hybrid-collateralized stablecoin)
 *
 * The system is designed to maintain a 1 token == $1 peg using hybrid collateral (fiat + crypto).
 * This stablecoin has the properties:
 * - Exogenously Collateralized (fiat via tokenized stablecoins or gateway, crypto via WETH/WBTC)
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by fiat (e.g., USDC, NGNToken) and crypto (e.g., WETH, WBTC).
 *
 * The system enforces a 50% fiat / 50% crypto collateral ratio and requires 150% over-collateralization.
 *
 * @notice This contract handles minting and redeeming AFRO tokens, as well as depositing and withdrawing collateral.
 * @notice Supports tokenized fiat (e.g., USDC, NGNToken) and crypto (e.g., WETH, WBTC).
 */
contract AFRCSCEngine is ReentrancyGuard {
    ///////////////////
    // Errors
    ///////////////////
    error DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__InvalidCollateralRatio();
    error DSCEngine__InsufficientReserves(address token);

    ///////////////////
    // Types
    ///////////////////
    using OracleLib for AggregatorV3Interface;

    ///////////////////
    // State Variables
    ///////////////////
    AFRCStableCoin private immutable i_dsc;

    uint256 private constant LIQUIDATION_THRESHOLD = 66; // 150% over-collateralization
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% bonus for liquidators
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;
    uint256 private constant COLLATERAL_RATIO_PRECISION = 100;
    uint256 private constant MIN_FIAT_RATIO = 50; // 50% fiat collateral
    uint256 private constant MIN_CRYPTO_RATIO = 50; // 50% crypto collateral

    /// @dev Mapping of token address to price feed address
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    /// @dev Mapping of token address to whether it is fiat-backed (e.g., USDC, NGNToken)
    mapping(address collateralToken => bool isFiat) private s_isFiatToken;
    /// @dev Amount of collateral deposited by user
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;
    /// @dev Amount of DSC (AFRO) minted by user
    mapping(address user => uint256 amount) private s_DSCMinted;
    /// @dev List of supported collateral tokens
    address[] private s_collateralTokens;

    ///////////////////
    // Events
    ///////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount);
    event CollateralRedeemedAs(address indexed user, address indexed fromToken, address indexed toToken, uint256 amount);

    ///////////////////
    // Modifiers
    ///////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed(token);
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        bool[] memory isFiatFlags,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length || tokenAddresses.length != isFiatFlags.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_isFiatToken[tokenAddresses[i]] = isFiatFlags[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = AFRCStableCoin(dscAddress);
    }

    ///////////////////
    // External Functions
    ///////////////////
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    function redeemCollateralForDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToBurn
    ) external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) {
        _burnDsc(amountDscToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external moreThanZero(amountCollateral) nonReentrant isAllowedToken(tokenCollateralAddress) {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateralAs(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        address desiredToken
    ) external moreThanZero(amountCollateral) nonReentrant isAllowedToken(tokenCollateralAddress) isAllowedToken(desiredToken) {
        uint256 usdValue = _getUsdValue(tokenCollateralAddress, amountCollateral);
        uint256 desiredTokenAmount = getTokenAmountFromUsd(desiredToken, usdValue);
        if (IERC20(desiredToken).balanceOf(address(this)) < desiredTokenAmount) {
            revert DSCEngine__InsufficientReserves(desiredToken);
        }
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, address(this));
        bool success = IERC20(desiredToken).transfer(msg.sender, desiredTokenAmount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        emit CollateralRedeemedAs(msg.sender, tokenCollateralAddress, desiredToken, desiredTokenAmount);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(uint256 amount) external moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function liquidate(
        address collateral,
        address user,
        uint256 debtToCover
    ) external isAllowedToken(collateral) moreThanZero(debtToCover) nonReentrant {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        _redeemCollateral(collateral, tokenAmountFromDebtCovered + bonusCollateral, user, msg.sender);
        _burnDsc(debtToCover, user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function depositFiatViaGateway(
        uint256 fiatAmount,
        address fiatToken
    ) external moreThanZero(fiatAmount) isAllowedToken(fiatToken) nonReentrant {
        require(s_isFiatToken[fiatToken], "Token must be fiat-backed");
        // Placeholder: Assume fiat gateway transfers fiatToken (e.g., NGNToken) to this contract
        // In practice, integrate with an oracle or trusted fiat gateway to verify off-chain fiat deposit
        bool success = IERC20(fiatToken).transferFrom(msg.sender, address(this), fiatAmount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        s_collateralDeposited[msg.sender][fiatToken] += fiatAmount;
        emit CollateralDeposited(msg.sender, fiatToken, fiatAmount);
        _enforceCollateralRatio(msg.sender, fiatToken, fiatAmount);
    }

    ///////////////////
    // Public Functions
    ///////////////////
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) public moreThanZero(amountCollateral) nonReentrant isAllowedToken(tokenCollateralAddress) {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _enforceCollateralRatio(msg.sender, tokenCollateralAddress, amountCollateral);
    }

    ///////////////////
    // Private Functions
    ///////////////////
    function _redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        address from,
        address to
    ) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    function _enforceCollateralRatio(address user, address tokenCollateralAddress, uint256 amountCollateral) private view {
        uint256 totalCollateralValue = getAccountCollateralValue(user);
        uint256 fiatCollateralValue = _getFiatCollateralValue(user);
        uint256 cryptoCollateralValue = totalCollateralValue - fiatCollateralValue;
        uint256 newCollateralValue = _getUsdValue(tokenCollateralAddress, amountCollateral);
        uint256 newTotalFiatValue = fiatCollateralValue + (s_isFiatToken[tokenCollateralAddress] ? newCollateralValue : 0);
        uint256 newTotalCryptoValue = cryptoCollateralValue + (s_isFiatToken[tokenCollateralAddress] ? 0 : newCollateralValue);
        if (totalCollateralValue > 0) {
            require(
                (newTotalFiatValue * COLLATERAL_RATIO_PRECISION) / totalCollateralValue >= MIN_FIAT_RATIO,
                "Fiat collateral below 50%"
            );
            require(
                (newTotalCryptoValue * COLLATERAL_RATIO_PRECISION) / totalCollateralValue >= MIN_CRYPTO_RATIO,
                "Crypto collateral below 50%"
            );
        }
    }

    ///////////////////
    // Private & Internal View & Pure Functions
    ///////////////////
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function _getFiatCollateralValue(address user) private view returns (uint256) {
        uint256 fiatCollateralValue = 0;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            if (s_isFiatToken[token]) {
                uint256 amount = s_collateralDeposited[user][token];
                fiatCollateralValue += _getUsdValue(token, amount);
            }
        }
        return fiatCollateralValue;
    }

    function _calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    ) internal pure returns (uint256) {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ///////////////////
    // External & Public View & Pure Functions
    ///////////////////
    function calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    ) external pure returns (uint256) {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    function getUsdValue(address token, uint256 amount) external view returns (uint256) {
        return _getUsdValue(token, amount);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getDsc() external view returns (address) {
        return address(i_dsc);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function isFiatToken(address token) external view returns (bool) {
        return s_isFiatToken[token];
    }
}