// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";



contract TestPriceFeed is OwnerIsCreator {
    mapping(address => uint256) Price;

    uint256 _decimal = 8;

    uint256 NATIVE_PRICE= 511100000000000000;

    uint256 AFRI_COIN_RATE=  511100000000000000;

    address public NATIVE_TOKEN = NATIVE_TOKEN = address(uint160(uint256(keccak256(abi.encodePacked("Shard")))));
 
      // Mapping of token addresses to their tradeability status
mapping(address => bool)  isTokenTradeable;

address []   TradeableTokenAddresses;    
    constructor(address _AFRI_COIN_ADDRESS, address [] memory _tokenAddresses, uint256 [] memory _prices){
        // Set Native Token to Native Price
     Price[NATIVE_TOKEN]= NATIVE_PRICE;
     Price[_AFRI_COIN_ADDRESS]= AFRI_COIN_RATE;
     
     isTokenTradeable[NATIVE_TOKEN]= true;
     isTokenTradeable[_AFRI_COIN_ADDRESS]= true;
     TradeableTokenAddresses.push(NATIVE_TOKEN);
     TradeableTokenAddresses.push(_AFRI_COIN_ADDRESS);
     testnetHelper(_tokenAddresses,_prices);
    }


 

 // Mark a token as tradeable and assign it an index
    function markTokenAsTradeable(address [] memory _tokenAddresses, uint256 [] memory _prices) external onlyOwner {
        require(_tokenAddresses.length == _prices.length, "Arrays must be of the same length");

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            address tokenAddress = _tokenAddresses[i];
            uint256 price = _prices[i];

            // Call an internal function to set the price, or set it directly here
            setTokenPrice(tokenAddress, price);
            
            // Mark the token as tradeable
            isTokenTradeable[tokenAddress] = true;

            // Push the token to the Tradeable Token Addresses Array
            TradeableTokenAddresses.push(tokenAddress);
        }
    }

     function testnetHelper(address [] memory _tokenAddresses, uint256 [] memory _prices) private onlyOwner {
        require(_tokenAddresses.length == _prices.length, "Arrays must be of the same length");

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            address tokenAddress = _tokenAddresses[i];
            uint256 price = _prices[i];

            // Call an internal function to set the price, or set it directly here
            setTokenPrice(tokenAddress, price);
            
            // Mark the token as tradeable
            isTokenTradeable[tokenAddress] = true;

            // Push the token to the Tradeable Token Addresses Array
            TradeableTokenAddresses.push(tokenAddress);
        }
    }

      
    // Check if a list of tokens is tradeable
function areTokensTradeable(address[] memory _tokenDesired) external view returns (bool isTrue) {
    // Check if each desired token is tradeable
    for (uint256 i = 0; i < _tokenDesired.length; i++) {
        if (!isTokenTradeable[_tokenDesired[i]]) {
            return false; // Desired token is not tradeable
        }
    }
    
    return true;
}

function checkTokenTradeable(address _tokenAddress) external view returns (bool) {
    return isTokenTradeable[_tokenAddress];
}


function getTradeableTokenAddresses() public view returns (address [] memory){
    return TradeableTokenAddresses;
}
 
    function setTokenPrice(address _TokenAddress, uint256 _Price) internal {
                   Price[_TokenAddress] = _Price;
    }


    function getTokenPrice(address _TokenAddress) public  view returns (uint256){
            return Price[_TokenAddress];
    }


    function getExchangeRate(address baseAddress, address quoteAddress)
        internal
        view
        
        returns (int256)
    {
      

        // validate the base token decimals
        require(_decimal > uint8(0) && _decimal <= uint8(18), "Unsupported Decimals");

        uint256 _decimals = 10**_decimal;

        // extract only the base token price from the returns
        uint256 basePrice = Price[baseAddress];

        // get the base token decimals
        uint256 baseDecimals = 18;

        // get the base token price
        int256 _basePrice= scalePrice(basePrice, baseDecimals, _decimal);

        // extract only the quote token price from the returns
        uint256 quotePrice =  Price[quoteAddress];

        // get the quote token decimals
        uint256 quoteDecimals =  18;

        // get the quote token price
        int256 _quotePrice = scalePrice(quotePrice, quoteDecimals, _decimal);

        return (_basePrice * int256(_decimals)) / _quotePrice;
    }


 
   
 function scalePrice(
        uint256 _price,
        uint256 _priceDecimals,
        uint256 _decimals
    )  private pure returns (int256) {
        // scale the price to ensure a accurate price

        if (_priceDecimals < _decimals) {
            return int256( _price * 10**(_decimals - _priceDecimals));
        } else if (_priceDecimals > _decimals) {
            return int256( _price /  10**(_priceDecimals - _decimals));
        }

        return int256(_price);
    }


  // Public view function to provide the estimate
    function estimate(
        address token0,
        address token1,
        uint256 amount0 // in wei
    ) external  view returns (uint256) {
        int256 _rate = getExchangeRate(token0, token1);
        return (amount0 * uint256(_rate)) / (10 ** 8);
    }


function getNativeToken() external view returns(address) {
    return NATIVE_TOKEN;
}







}
