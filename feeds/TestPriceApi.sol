// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";

//TODO: Add comments, pass feed contract address as param to constructor, import interface file

// DAI/USDT     998550000000000000

// NEAR/USDT   1004700000000000000


//AAVE/USDT     62810000000000000000

//UNI/USDT     4078300000000000000

//COMP/USDT   40630000000000000000

//1000000000000000000


/*  

aave 98920000000000000000
link 1522500000
uni 5200600000000000000
comp 53200000000000000000
trx 105130000000000000
dai 999400000000000000
near 1457000000000000000


[LINK,  DAI, NEAR , COMP, TRX , AAVE]
*/
          
/*
[1522500000000000000,999400000000000000,1457000000000000000,53200000000000000000,105130000000000000,98920000000000000000]
] 
*/
//0x57623d612f6bce1d848bc6023125feb2100f8f9f,[0x3de9fd008de2dba0dde425c2059380122c7cb189,0xd54e1379c3c1b400818a7bc2dcfecc5e3f7d884b,0x543879308a813b3d1fee5bd84fde861d537699f8,0x232aad86ef0cdc03cf3f39f6f37aa42af4b0f1fb,0x73398b0b3176456dcaee855d9c723288bc512f9e,0x312e2ab846e7c0e8a5faebb19efd01f5e946a54c],[1522500000000000000,999400000000000000,1457000000000000000,53200000000000000000,105130000000000000,98920000000000000000]
//[0x3de9fd008de2dba0dde425c2059380122c7cb189,0xd54e1379c3c1b400818a7bc2dcfecc5e3f7d884b,0x543879308a813b3d1fee5bd84fde861d537699f8,0x232aad86ef0cdc03cf3f39f6f37aa42af4b0f1fb,0x73398b0b3176456dcaee855d9c723288bc512f9e,0x312e2ab846e7c0e8a5faebb19efd01f5e946a54c]
//GOERLI
 //[0xD652D9C2d166FEfa0886c70d9461C2F2965b65e6,0x61e99C5F3883A548Dd3907F8A0B4a9B05c195289,0x5fB5A81A495Ec9842016001fBF3745f40B7de7cc,0x47f887ff5FA94df0Bc1F6E9bF18Da8F2F77a09FF,0x882F92ad461530C065F136f8dF49397C2956d489,0xF04866F98a77481d9a46958948692897c98D37b1]
contract TestPriceFeed is OwnerIsCreator {
    mapping(address => uint256) Price;

    uint256 _decimal = 8;

    uint256 NATIVE_PRICE= 511100000000000000;

    uint256 BENZ_RATE=  511100000000000000;

    address public NATIVE_TOKEN = NATIVE_TOKEN = address(uint160(uint256(keccak256(abi.encodePacked("Shard")))));
 
      // Mapping of token addresses to their tradeability status
mapping(address => bool)  isTokenTradeable;

address []   TradeableTokenAddresses;    
    constructor(address _BENZ_TOKEN_ADDRESS, address [] memory _tokenAddresses, uint256 [] memory _prices){
        // Set Native Token to Native Price
     Price[NATIVE_TOKEN]= NATIVE_PRICE;
     Price[_BENZ_TOKEN_ADDRESS]= BENZ_RATE;
     
     isTokenTradeable[NATIVE_TOKEN]= true;
     isTokenTradeable[_BENZ_TOKEN_ADDRESS]= true;
     TradeableTokenAddresses.push(NATIVE_TOKEN);
     TradeableTokenAddresses.push(_BENZ_TOKEN_ADDRESS);
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
