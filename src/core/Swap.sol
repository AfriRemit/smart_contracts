// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;


import {Events} from "../libraries/Events.sol";
import {xIERC20} from "../interfaces/xIERC20.sol";
import {TestPriceFeed} from "../feeds/TestPriceApi.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";

contract Swap is OwnerIsCreator {
  

event Received(address, uint);

receive() external payable {
    emit Received(msg.sender, msg.value);
}
  TestPriceFeed private priceAPI;
    
   
    
    // contract admin
    uint256 private _platformProfit;
    uint256 private _burnableFees;

    // charges 0.20% fee on every successful swaps
    uint private swapFee = 20;

    // ids to avoid conflicts
    uint256 private POOL_ID;
    uint256 private LIQUID_ID;
    uint256 private PROVIDER_ID;

    // token contract address => pair index address
    // only in the token paired to USD format
  


    // is a member of the pairs mapping
    // but its the native pair MATIC not IERC20

    // paired address to USDT
   

    address public AFRI_COIN;
 
    // id => liquidity pools
    mapping(uint => Pool) public pools;
    // user address => provider data
    mapping(address => Provider) public providers;
    // id => liquids
    mapping(uint => Liquid) public liquids;

    // === Structs === //

    // pool consists of liquids
    // from n numbers providers
    struct Pool {
        uint id;
        address token0;
        address token1;
        uint[] liquids;
    }

    // liquid belongs to a provider
    // also belongs to a pool
    struct Liquid {
        uint id;
        uint poolId;
        uint256 amount0;
        uint256 amount1;
        address provider;
    }

    // provider properties
    // owns n numbers of liquids
    struct Provider {
        uint id;
        uint256 totalEarned;
        uint256 balance;
        bool autoStake;
        uint[] liquids;
    }

    constructor(address _priceApI,address _AFRI_COIN) {
        


// Initialize the priceAPI with the provided _priceAPI parameter.
priceAPI = TestPriceFeed(_priceApI);

// Set the AFRI_COIN to the provided _AFRI_COIN.
AFRI_COIN = _AFRI_COIN;

//CREATE POOL FOR NATIVE/AFRI_COIN
_createPool(priceAPI.getNativeToken(),_AFRI_COIN);

        //testnetHelper();
    }

    // calculates all the size of the liquids
    // in a pool of token pair
    function getPoolSize(
        address token0,
        address token1
    ) public view returns (uint256, uint256) {
        uint poolId = _findPool(token0, token1);
        return _poolSize(poolId);
    }

    // gets the exchanges rates for pair of tokens
    // with accordance to amount of tokens





    function estimate(
         address token0,
          address token1,
        uint256 amount0 // in wei
    ) public  view returns (uint256) {
        

        uint256 _rate = priceAPI.estimate(token0,token1,amount0);
        return _rate;
       
    }

    // returns the contract address
    function getContractAddress() public view returns (address) {
        return address(this);
    }

  
  

    // register as a provider
    function unlockedProviderAccount() public onlyGuest {
        // create new unique id
        PROVIDER_ID++;

        // provider with default entries
        providers[msg.sender] = Provider(
            PROVIDER_ID,
            providers[msg.sender].totalEarned,
            providers[msg.sender].balance,
            false,
            providers[msg.sender].liquids
        );
    }

    // === Swapping === //

    function swap(
        address token0,
        address token1,
        uint256 amount0
    ) public payable returns (uint256) {
        return doSwap(token0, token1, amount0, msg.sender);
    }

    function doSwap(
        address token0,
        address token1,
        uint256 amount0,
        address user
    ) public payable returns (uint256) {
        require(amount0 >= 100, "Amount to swap cannot be lesser than 100 WEI");

        uint256 amount1;
        uint256 _safeAmount0 = amount0;

        uint poolId = _findPool(token0, token1);
        require(pools[poolId].id > 0, "Pool does not exists");

        // SHM => ERC20
        if ( token0 == priceAPI.getNativeToken()) {

            require(msg.value  >= 100,"Native Currency cannot be lesser than 100 WEI ");
            
            _safeAmount0 = msg.value;
            amount1 = estimate(token0, token1, _safeAmount0);

            // check if contract has enough destination token liquid
            (, uint256 poolSizeToken1) = _poolSize(poolId);
            require(poolSizeToken1 >= amount1, "Insufficient Pool Size");

            uint256 fee = _transferSwappedTokens0(
                pools[poolId].token1,
                amount1,
                user
            );

            uint256 providersReward = ((fee * 80) / 100);
            uint256 burnFee= ((fee * 3) /100);
            _burnableFees += burnFee;
            uint256 contractProfit= fee - providersReward - burnFee;
            _platformProfit += contractProfit;
            
         
            

            _aggregateLiquids(
                _safeAmount0,
                amount1,
                poolSizeToken1,
                pools[poolId],
                providersReward
            );
        }
        // ERC20 => MATIC
        else if (token1 == priceAPI.getNativeToken()) {
            amount1 = estimate(token0, token1, _safeAmount0);

            // check if contract has enough destination token liquid
            (uint256 poolSizeToken1, ) = _poolSize(poolId);
            require(poolSizeToken1 >= amount1, "Insufficient Pool Size");

            uint256 fee = _transferSwappedTokens1(
                pools[poolId].token1,
                _safeAmount0,
                amount1,
                user
            );
          uint256 providersReward = ((fee * 80) / 100);
        
           uint256 burnFee= ((fee * 3) /100);

            _burnableFees += burnFee;
           
         uint256 contractProfit = fee - providersReward - burnFee;
            
            _platformProfit += contractProfit;
            

            _aggregateLiquids(
                _safeAmount0,
                amount1,
                poolSizeToken1,
                pools[poolId],
                providersReward
            );
        }
        // ERC20 => ERC2O
        else {
            amount1 = estimate(
                token0,
                token1,
                _safeAmount0
            );
            uint256 poolSizeToken1;
            if(pools[poolId].token0 == token1){
            (uint256 _poolSizeToken1,) = _poolSize(poolId);
            poolSizeToken1= _poolSizeToken1;

            }else if(pools[poolId].token1 == token1){
                (,uint256 _poolSizeToken1) = _poolSize(poolId);
                poolSizeToken1 =_poolSizeToken1;
            }

            require(poolSizeToken1 >= amount1, "Insufficient Pool Size");

            uint256 fee = _transferSwappedTokens2(
                token0,
                token1,
                _safeAmount0,
                amount1,
                user
            );

            uint256 providersReward = ((fee * 80) / 100);
            
            uint256 burnFee= ((fee * 3) /100);

             _burnableFees += burnFee;
            
            uint256 contractProfit= fee - providersReward - burnFee;
            
            _platformProfit += contractProfit;
            

            _aggregateLiquids(
                _safeAmount0,
                amount1,
                poolSizeToken1,
                pools[poolId],
                providersReward
            );
        }

        // store the swap data on-chain
        emit Events.FleepSwaped(
            amount0,
            amount1,
            token0,
            token1,
            block.timestamp
        );

        return amount1;
    }

    // === Providers === //

    function provideLiquidity(
        uint poolId,
        uint256 amount0
    ) public payable  {
        require(amount0 >= 100, "Amount cannot be lesser than 100 WEI");

        uint256 amount1;
        uint256 _safeAmount0 = amount0;

        if(providers[msg.sender].id == 0){
        unlockedProviderAccount();
        }

        if (pools[poolId].token0 == priceAPI.getNativeToken()) {
            require(msg.value > 100, "Matic cannot be lesser than 1OO WEI");
            // only in format of MATIC as pair subject
            // ex MATIC/XEND

            _safeAmount0 = msg.value;
            // get the estimate for token1
            amount1 = estimate(
                pools[poolId].token0,
                pools[poolId].token1,
                _safeAmount0
            );

            
            // stake token1 to smart contract
            xIERC20(pools[poolId].token1).transferFrom(
                msg.sender,
                address(this),
                amount1
            );
        } else {
            // get the estimate for token1
            amount1 = estimate(
                pools[poolId].token0,
                pools[poolId].token1,
                _safeAmount0
            );
            // stake tokens to smart contract
            xIERC20(pools[poolId].token0).transferFrom(
                msg.sender,
                address(this),
                _safeAmount0
            );
            xIERC20(pools[poolId].token1).transferFrom(
                msg.sender,
                address(this),
                amount1
            );
        }

        uint liquidId = _liquidIndex(poolId, msg.sender);

        if (liquidId > 0) {
            // if liquid exist increment the amount
            liquids[liquidId].amount0 += _safeAmount0;
            liquids[liquidId].amount1 += amount1;
        } else {
            // otherwise create the new liquid
            _createLiquid(poolId, _safeAmount0, amount1, msg.sender);
        }

        // store the liquidity data on-chain
        emit Events.LiquidProvided(
            pools[poolId].token0,
            pools[poolId].token1,
            _safeAmount0,
            amount1,
            msg.sender,
            block.timestamp
        );
    }

    function removeLiquidity(uint id) public onlyProvider {
        require(liquids[id].provider == msg.sender, "Unauthorized");
    
         // extract pool id from liquid
        uint poolId = liquids[id].poolId;
        // extract pool struct
        Pool memory pool = pools[poolId];

         if (pools[poolId].token0 == priceAPI.getNativeToken()){
              payable(msg.sender).transfer(liquids[id].amount0);
              xIERC20(pool.token1).transfer(msg.sender, liquids[id].amount1);
         }else{
        // transfer tokens to providers
        xIERC20(pool.token0).transfer(msg.sender, liquids[id].amount0);
        xIERC20(pool.token1).transfer(msg.sender, liquids[id].amount1);

         }

        // delete liquid

        for (uint index = 0; index < pools[poolId].liquids.length; index++) {
            if (liquids[pools[poolId].liquids[index]].provider == msg.sender) {
                delete pools[poolId].liquids[index];
            }
        }

        for (
            uint index = 0;
            index < providers[msg.sender].liquids.length;
            index++
        ) {
            if (
                liquids[providers[msg.sender].liquids[index]].poolId == pool.id
            ) {
                delete providers[msg.sender].liquids[index];
            }
        }

        delete liquids[id];
    }

    // fetach all liquidities from a wallet
    function myLiquidities(
        address wallet
    )
        public
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        // array of provider liquidities position
        uint256[] memory providerLiquids = providers[wallet].liquids;

        uint256[] memory _pools = new uint256[](providerLiquids.length);
        uint256[] memory _amounts0 = new uint256[](providerLiquids.length);
        uint256[] memory _amounts1 = new uint256[](providerLiquids.length);

        for (uint index; index < providerLiquids.length; index++) {
            _pools[index] = liquids[providerLiquids[index]].poolId;
            _amounts0[index] = liquids[providerLiquids[index]].amount0;
            _amounts1[index] = liquids[providerLiquids[index]].amount1;
        }

        return (_pools, _amounts0, _amounts1, providerLiquids);
    }

function findPool(address token0, address token1) public view returns (uint256) {
   return _findPool(token0, token1);
}

function liquidIndex(uint256 pool_id) public view returns (uint256){
     return _liquidIndex(pool_id,msg.sender);
}
 
    function createPool(
        address token0,
        address token1
    ) public onlyOwner returns (uint) {
        return _createPool(token0, token1);
    }

    function updateProviderProfile(bool _autoStake) public onlyProvider {
        providers[msg.sender].autoStake = _autoStake;
    }

    function withDrawEarnings(uint256 amount) public onlyProvider {
        require(
            providers[msg.sender].balance >= amount,
            "Insufficient Balance"
        );

        // USDT as reward token
        xIERC20(AFRI_COIN).transfer(msg.sender, amount);

        providers[msg.sender].balance -= amount;
    }

 
 
    // === Administration === //

 





    function updateSwapFee(uint fee) public onlyOwner {
        require(fee > 0, "Platform fee cannot be zero");
        require(fee < 1000, "Platform fee cannot be a hundred");
        swapFee = fee;
    }

  
    function withDrawPlaformEarnings(
        uint256 amount,
        address receiver
    ) public onlyOwner {
        require(_platformProfit >= amount, "Insufficient Balance");

        // AFRI_COIN token as reward token
        xIERC20(AFRI_COIN).transfer(receiver, amount);
        _platformProfit -= amount;
    }

    function burnFees() public onlyOwner {
        require(getBurnableFeesBal() > 0, "Insufficient Balance");
      xIERC20(AFRI_COIN).burn(_burnableFees);
      _burnableFees-= getBurnableFeesBal();
  }

  function getBurnableFeesBal() public view onlyOwner returns (uint256){
    return _burnableFees;
  }

    // === Internal Functions === //

    function _liquidIndex(
        uint poolId,
        address provider
    ) private view returns (uint) {
        uint256[] memory providerLiquids = providers[provider].liquids;

        for (uint index = 0; index < providerLiquids.length; index++) {
            if (liquids[providerLiquids[index]].poolId == poolId) {
                return providerLiquids[index];
            }
        }

        return 0;
    }

    function _aggregateLiquids(
        uint256 amount0,
        uint256 amount1,
        uint256 poolSizeToken1,
        Pool memory pool,
        uint256 fee
    ) private {
        // equally share swap impact on all provider liquids based on their contribution
        for (uint index = 0; index < pool.liquids.length; index++) {
            uint liquidId = pool.liquids[index];


            // reward the liquid provider
            uint256 reward = ((liquids[liquidId].amount1 * fee) /
                poolSizeToken1);

            address provider = liquids[liquidId].provider;

              // calculated with ratio of this liquid compared
            // to other liquids contributing
            uint256 additionAmount = ((liquids[liquidId].amount1 * amount0) /
                poolSizeToken1);

            // step I
            liquids[liquidId].amount0 += additionAmount;

                // calculated with ratio of this liquid compared
            // to other liquids contributing
            uint256 deductionAmount = ((liquids[liquidId].amount1 * amount1) /
                poolSizeToken1);

            // step II
            liquids[liquidId].amount1 -= deductionAmount;




            providers[provider].totalEarned += reward;
            providers[provider].balance += reward;
        }
    }

    // NATIVE => ERC20
    function _transferSwappedTokens0(
        address token1,
        uint256 amount1,
        address owner
    ) private returns (uint256) {
        xIERC20 quoteToken = xIERC20(token1);

        uint256 _fee = ((amount1 / 1000) * swapFee);

        // give user their destination token minus fee
        quoteToken.transfer(owner, (amount1 - _fee));

        // convert fee to Fleep tokens
        return estimate(token1, AFRI_COIN, _fee);
    }

    // ERC20 => NATIVE
    function _transferSwappedTokens1(
        address token0,
        uint256 amount0,
        uint256 amount1,
        address owner
    ) public payable returns (uint256) {
        xIERC20 baseToken = xIERC20(token0);

        uint256 _fee = ((amount1 / 1000) * swapFee);

        baseToken.transferFrom(owner, address(this), amount0);

        // give user their destination token minus fee
        require(
            address(this).balance >= amount1,
            "Contract: Insufficient Balance"
        );
     

         (bool sent, ) = owner.call{value: amount1 - _fee}("");
        require(sent, "Failed to send Shard to the User");

        // convert fee to Fleep tokens
        return estimate(priceAPI.getNativeToken(), AFRI_COIN, _fee);
    }

    // ERC20 => ERC20
    function _transferSwappedTokens2(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        address owner
    ) private returns (uint256) {
        xIERC20 baseToken = xIERC20(token0);
        xIERC20 quoteToken = xIERC20(token1);

        uint256 _fee = ((amount1 / 1000) * swapFee);

        // tranfers the base token from user to the
        // smart contract
        baseToken.transferFrom(owner, address(this), amount0);

        // give user their destination token minus fee
        quoteToken.transfer(owner, (amount1 - _fee));

        // convert fee to Fleep tokens
        return estimate(token1, AFRI_COIN, _fee);
    }

    function _inWei(uint256 amount) private pure returns (uint256) {
        return amount * 10 ** 18;
    }

    function _findPool(
        address token0,
        address token1
    ) private view returns (uint) {
        require(
            token0 != address(0) && token1 != address(0),
            "Invalid Pool Tokens"
        );
        for (uint index = 0; index <= POOL_ID; index++) {
            // patern A
            if (
                pools[index].token0 == token0 && pools[index].token1 == token1
            ) {
                return index;
            }

            // pattern B
            if (
                pools[index].token0 == token1 && pools[index].token1 == token0
            ) {
                return index;
            }
        }
        return 0;
    }

    function _createLiquid(
        uint poolId,
        uint256 amount0,
        uint256 amount1,
        address provider
    ) private {
        LIQUID_ID++;
        // create the liquid
        liquids[LIQUID_ID] = Liquid(
            LIQUID_ID,
            poolId,
            amount0,
            amount1,
            provider
        );
        // register the liquid
        pools[poolId].liquids.push(LIQUID_ID);
        providers[provider].liquids.push(LIQUID_ID);
    }

    function _poolSize(uint id) private view returns (uint256, uint256) {
        uint256 amount0;
        uint256 amount1;
        for (uint index = 0; index < pools[id].liquids.length; index++) {
            uint liquidId = pools[id].liquids[index];
            amount0 += liquids[liquidId].amount0;
            amount1 += liquids[liquidId].amount1;
        }
        return (amount0, amount1);
    }

    function _createPool(
        address token0,
        address token1
    ) private returns (uint) {
        require(
            token0 != address(0),
            "Pair does not exists, Contact admin"
        );
        require(
            token1 != address(0),
            "Pair does not exists, Contact admin"
        );

        bool exists = _findPool(token0, token1) != 0;
        if (exists) return 0;

        POOL_ID++;
        Pool memory pool = pools[POOL_ID];

        pools[POOL_ID] = Pool(POOL_ID, token0, token1, pool.liquids);

        return POOL_ID;
    }

 

    // === Modifiers === //

    modifier onlyGuest() {
        require(providers[msg.sender].id == 0, "Only Guest");
        _;
    }

    modifier onlyProvider() {
        require(providers[msg.sender].id != 0, "Only Provider");
        _;
    }

  
}
