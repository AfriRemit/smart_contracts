// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

//TODO: Add comments, pass feed contract address as param to constructor, import interface file

//interface to interact with price feed, refer to documentation https://supraoracles.com/docs/get-started
import "../interfaces/ISupraSValueFeed.sol";

 
contract priceFeed {
    
    uint public price;
    uint public decimals;
    uint public rounds;
     
    uint8 _decimal=8;
 
    ISupraSValueFeed sValueFeed;

    //GOERLI 0x5B059e343E88840895e82Fc8706cc888E0f6714D
  
   // address constant SHARDEUM_priceFeed= 0xED2d2Da27b27A32dc80a4cb76CF8c8F65B64F90F;
 
    constructor(address _NETWORK_FEED_ADDRESS){
        sValueFeed = ISupraSValueFeed(_NETWORK_FEED_ADDRESS);
        
       
    }
 
   
 
    function unpack(bytes32 data) internal pure returns(uint256[4] memory) {
        uint256[4] memory info;

        info[0] = bytesToUint256(abi.encodePacked(data >> 192));       // round
        info[1] = bytesToUint256(abi.encodePacked(data << 64 >> 248)); // decimal
        info[2] = bytesToUint256(abi.encodePacked(data << 72 >> 192)); // timestamp
        info[3] = bytesToUint256(abi.encodePacked(data << 136 >> 160)); // price

        return info;
    }


    function bytesToUint256(bytes memory _bs) internal pure returns (uint256 value) {
        require(_bs.length == 32, "bytes length is not 32.");
        assembly {
            value := mload(add(_bs, 0x20))
        }
    }

     

 
   function getPrice(uint64 _index) internal view returns(uint256)   {
 //get the price data for eth_usdt
        (bytes32 val,)= sValueFeed.getSvalue(_index);
      
        uint256[4] memory decoded = unpack(val);
        //Grab the price from the returned decoded array 
        uint Price = decoded[3];
       
        return Price;
   }

   function getPriceRate(uint64 _index) external view returns(uint256)   {
 //get the price data for eth_usdt
        (bytes32 val,)= sValueFeed.getSvalue(_index);
      
        uint256[4] memory decoded = unpack(val);
        //Grab the price from the returned decoded array 
        uint Price = decoded[3];
       
        return Price;
   }

function getDecimals(uint64 _index) internal view returns (uint) {
       (bytes32 val,)= sValueFeed.getSvalue(_index);

        //unpack the values
        uint256[4] memory decoded = unpack(val);
        uint _decimals = decoded[1];
       
        return _decimals;
         
}

  /// @notice Get the exchange rate value and availability status for a single trading pair.
    /// @param _pairIndex The index of the trading pair.
    /// @return The exchange rate value and a flag indicating if the value is available or not.
    function getSvalue(uint64 _pairIndex)
        external
        view
        returns (bytes32)
    {
  (bytes32 val,) =  sValueFeed.getSvalue(_pairIndex);        
     return (val);
    }


   function getExchangeRate(uint64 baseIndex, uint64 quoteIndex)
        external
        view
        returns (int256)
    {
      

        // validate the base token decimals
        require(_decimal > uint8(0) && _decimal <= uint8(18), "Unsupported Decimals");

        uint256 _decimals = 10**_decimal;

        // extract only the base token price from the returns
        uint256 basePrice = getPrice(baseIndex);

        // get the base token decimals
        uint256 baseDecimals = getDecimals(baseIndex);

        // get the base token price
        int256 _basePrice= scalePrice(basePrice, baseDecimals, _decimal);

        // extract only the quote token price from the returns
        uint256 quotePrice =  getPrice(quoteIndex);

        // get the quote token decimals
        uint256 quoteDecimals =  getDecimals(quoteIndex);

        // get the quote token price
        int256 _quotePrice = scalePrice(quotePrice, quoteDecimals, _decimal);

        return (_basePrice * int256(_decimals)) / _quotePrice;
    }


 
   
 function scalePrice(
        uint256 _price,
        uint256 _priceDecimals,
        uint256 _decimals
    ) internal pure returns (int256) {
        // scale the price to ensure a accurate price

        if (_priceDecimals < _decimals) {
            return int256( _price * 10**(_decimals - _priceDecimals));
        } else if (_priceDecimals > _decimals) {
            return int256( _price /  10**(_priceDecimals - _decimals));
        }

        return int256(_price);
    }






function getRounds() external returns (uint) {
       (bytes32 val,)= sValueFeed.getSvalue(1);

        //unpack the values
        uint256[4] memory decoded = unpack(val);
        uint _rounds = decoded[0];
        rounds= _rounds;
        return rounds;
         
}

 






    
 
}