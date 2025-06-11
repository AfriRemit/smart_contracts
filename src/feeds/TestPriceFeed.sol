// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./MockV3Aggregator.sol";

/**
 * @title Enhanced TestPriceFeed
 * @notice Price feed contract with both manual and oracle-based price updates
 */
contract TestPriceFeed is OwnerIsCreator {
    // Existing mappings and variables
    mapping(address => uint256) Price;
    mapping(address => bool) isTokenTradeable;
    mapping(address => AggregatorV3Interface) public tokenToAggregator;
    mapping(address => MockV3Aggregator) public tokenToMockAggregator;
    mapping(address => bool) public useOracle; // true = use oracle, false = use manual price
        
    uint256 _decimal = 8;
    uint256 NATIVE_PRICE = 511100000000000000;
   // uint256 BENZ_RATE = 511100000000000000;
    address public NATIVE_TOKEN;
  
    // Events
    event PriceUpdated(address indexed token, uint256 newPrice);
    event OracleSet(address indexed token, address indexed aggregator);
    event MockAggregatorCreated(address indexed token, address indexed mockAggregator);
    
    constructor(address _nativeToken) {
        // Constructor: Ensure NATIVE_TOKEN is derived securely or validated if passed as an argument.
        NATIVE_TOKEN = _nativeToken; 
        
    }
    
    /**
     * @notice Create a mock aggregator for a token (testing purposes)
     * @param _tokenAddress Token address
     * @param _initialPrice Initial price for the mock
     * @param _decimals Decimals for the price feed
     */
    function createMockAggregator(
        address _tokenAddress,
        int256 _initialPrice,
        uint8 _decimals
    ) external onlyOwner {
        // Input validation: Ensure token address is not zero and initial price is reasonable.
        require(_tokenAddress != address(0), "TestPriceFeed: Token address cannot be zero.");
        // require(_initialPrice > 0, "TestPriceFeed: Initial price must be positive."); // Depending on allowing zero/negative prices in mock
        // Access Control: This function is onlyOwner and meant for testing. In production, mock aggregators should not be creatable by owner after deployment.
        MockV3Aggregator mockAggregator = new MockV3Aggregator(_decimals, _initialPrice);
        tokenToMockAggregator[_tokenAddress] = mockAggregator;
        tokenToAggregator[_tokenAddress] = AggregatorV3Interface(address(mockAggregator));
        useOracle[_tokenAddress] = true;
        
        emit MockAggregatorCreated(_tokenAddress, address(mockAggregator));
    }
    
    /**
     * @notice Set a real Chainlink aggregator for a token
     * @param _tokenAddress Token address
     * @param _aggregatorAddress Chainlink aggregator address
     */
    function setAggregator(address _tokenAddress, address _aggregatorAddress) external onlyOwner {
        // Input validation: Ensure token and aggregator addresses are not zero.
        require(_tokenAddress != address(0), "TestPriceFeed: Token address cannot be zero.");
        require(_aggregatorAddress != address(0), "TestPriceFeed: Aggregator address cannot be zero.");
        // Security: For production, consider validating _aggregatorAddress against a whitelist of trusted Chainlink feeds.
        // Access Control: For critical updates like setting a real oracle, consider implementing a timelock to prevent immediate malicious changes.
        tokenToAggregator[_tokenAddress] = AggregatorV3Interface(_aggregatorAddress);
        useOracle[_tokenAddress] = true;
        
        emit OracleSet(_tokenAddress, _aggregatorAddress);
    }
    
    /**
     * @notice Update price in mock aggregator
     * @param _tokenAddress Token address
     * @param _newPrice New price to set
     */
    function updateMockPrice(address _tokenAddress, int256 _newPrice) external onlyOwner {
        // Input validation: Ensure token address is not zero.
        require(_tokenAddress != address(0), "TestPriceFeed: Token address cannot be zero.");
        require(address(tokenToMockAggregator[_tokenAddress]) != address(0), "Mock aggregator not set");
        // Security: Manual price updates are centralized and risky in production. Ensure this is only for testing or a highly controlled environment.
        tokenToMockAggregator[_tokenAddress].updateAnswer(_newPrice);
        
        emit PriceUpdated(_tokenAddress, uint256(_newPrice));
    }
    
    /**
     * @notice Toggle between oracle and manual price for a token
     * @param _tokenAddress Token address
     * @param _useOracle True to use oracle, false to use manual price
     */
    function togglePriceSource(address _tokenAddress, bool _useOracle) external onlyOwner {
        // Input validation: Ensure token address is not zero.
        require(_tokenAddress != address(0), "TestPriceFeed: Token address cannot be zero.");
        // Access Control: Toggling price sources is a critical operation. Consider a timelock for production to prevent malicious or accidental switches.
        useOracle[_tokenAddress] = _useOracle;
    }
    
    /**
     * @notice Get the latest price from oracle or manual setting
     * @param _tokenAddress Token address
     * @return Latest price
     */
    function getLatestPrice(address _tokenAddress) public view returns (uint256) {
        // Input validation: Ensure token address is not zero.
        require(_tokenAddress != address(0), "TestPriceFeed: Token address cannot be zero.");

        if (useOracle[_tokenAddress] && address(tokenToAggregator[_tokenAddress]) != address(0)) {
            (, int256 price, , uint256 updatedAt,) = tokenToAggregator[_tokenAddress].latestRoundData();
            require(price > 0, "Invalid price from oracle");
            // Security: Add staleness check for oracle data.
            // Define MAX_PRICE_FEED_AGE constant (e.g., 3600 for 1 hour).
            uint256 MAX_PRICE_FEED_AGE = 3600; // Define max age for price feed data (e.g., 1 hour in seconds).
            require(block.timestamp - updatedAt <= MAX_PRICE_FEED_AGE, "TestPriceFeed: Oracle price is stale."); // Implemented staleness check.
            return uint256(price);
        } else {
            // Security: Relying on manual price exposes centralization risk. This path should ideally be removed or heavily restricted in production.
            return Price[_tokenAddress];
        }
    }
    
    /**
     * @notice Enhanced getTokenPrice that uses oracle when available
     */
    // Gas Efficiency: This function is redundant as it simply calls getLatestPrice. Removed it and directly calling getLatestPrice instead.
    /*
    function getTokenPrice(address _TokenAddress) public view returns (uint256) {
        return getLatestPrice(_TokenAddress);
    }
    */

   

    function getExchangeRate(
        address baseAddress, 
        address quoteAddress
    ) internal view returns (int256) {
        // Input validation: Ensure base and quote addresses are not zero.
        require(baseAddress != address(0), "TestPriceFeed: Base token address cannot be zero.");
        require(quoteAddress != address(0), "TestPriceFeed: Quote token address cannot be zero.");
        require(_decimal > uint8(0) && _decimal <= uint8(18), "Unsupported Decimals");

        uint256 _decimals = 10**_decimal;
        uint256 basePrice = getLatestPrice(baseAddress); // Now uses oracle when available
        uint256 baseDecimals = 18;
        int256 _basePrice = scalePrice(basePrice, baseDecimals, _decimal);

        uint256 quotePrice = getLatestPrice(quoteAddress); // Now uses oracle when available
        uint256 quoteDecimals = 18;
        int256 _quotePrice = scalePrice(quotePrice, quoteDecimals, _decimal);

        // Precision: Be mindful of potential precision loss in division operations.
        // Consider using a fixed-point math library for high-precision calculations if financial accuracy is paramount.
        // For simplicity and to avoid introducing new dependencies, direct integer arithmetic is retained, but precision loss is noted.
        return (_basePrice * int256(_decimals)) / _quotePrice;
    }
 
    function scalePrice(
        uint256 _price,
        uint256 _priceDecimals,
        uint256 _decimals
    ) private pure returns (int256) {
        // Precision: Ensure sufficient precision is maintained during scaling operations, especially for token prices.
        if (_priceDecimals < _decimals) {
            return int256(_price * 10**(_decimals - _priceDecimals));
        } else if (_priceDecimals > _decimals) {
            return int256(_price / 10**(_priceDecimals - _decimals));
        }
        return int256(_price);
    }

    function estimate(
        address token0,
        address token1,
        uint256 amount0
    ) external view returns (uint256) {
        // Input validation: Ensure token addresses are not zero and amount0 is positive.
        require(token0 != address(0), "TestPriceFeed: token0 address cannot be zero.");
        require(token1 != address(0), "TestPriceFeed: token1 address cannot be zero.");
        require(amount0 > 0, "TestPriceFeed: Input amount must be positive.");
        int256 _rate = getExchangeRate(token0, token1);
        // Precision: Ensure proper handling of division to avoid loss of precision.
        return (amount0 * uint256(_rate)) / (10 ** 8);
    }


function getNativeToken() external view returns (address) {
    return NATIVE_TOKEN;
}   

    /**
     * @notice Get aggregator address for a token
     */
    function getAggregator(address _tokenAddress) external view returns (address) {
        // Input validation: Ensure token address is not zero.
        require(_tokenAddress != address(0), "TestPriceFeed: Token address cannot be zero.");
        return address(tokenToAggregator[_tokenAddress]);
    }
    
    /**
     * @notice Check if token uses oracle for pricing
     */
    function isUsingOracle(address _tokenAddress) external view returns (bool) {
        // Input validation: Ensure token address is not zero.
        require(_tokenAddress != address(0), "TestPriceFeed: Token address cannot be zero.");
        return useOracle[_tokenAddress];
    }
}