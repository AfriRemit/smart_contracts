// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import {Events} from "../libraries/Events.sol";
import {xIERC20} from "../interfaces/xIERC20.sol";
import {TestPriceFeed} from "../feeds/TestPriceFeed.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/**
 * @title AfriCoin Swap Contract
 * @dev Decentralized exchange contract for token swapping and liquidity provision on LISK network
 * @notice This contract allows users to swap tokens, provide liquidity, and earn rewards using ETH as native token
 * @author AfriCoin Team
 */
contract Swap is OwnerIsCreator, ReentrancyGuard {
    using SafeERC20 for xIERC20;
    

    // ============ RECEIVE FUNCTION ============
    
    /**
     * @dev Allows contract to receive native ETH tokens
     * @notice Automatically called when ETH is sent to the contract
     */
    receive() external payable {
        emit Events.Received(msg.sender, msg.value);
    }
    
    // ============ STATE VARIABLES ============
    
    /// @dev Price feed oracle contract for token price calculations
    TestPriceFeed public priceAPI;
    
    /// @dev Platform accumulated profits in AfriCoin tokens
    uint256 private _platformProfit;
    
    /// @dev Accumulated fees designated for burning
    uint256 private _burnableFees;

    /// @dev Swap fee percentage (0.20% = 20 basis points)
    uint private swapFee = 20;

    /// @dev Unique identifier counter for pools
    uint256 private POOL_ID;
    
    /// @dev Unique identifier counter for liquidity positions
    uint256 private LIQUID_ID;
    
    /// @dev Unique identifier counter for providers
    uint256 private PROVIDER_ID;

    /// @dev Address of the AfriCoin token contract
    address public AFRI_COIN;
 
    // ============ MAPPINGS ============
    
    /// @dev Maps pool ID to Pool struct
    mapping(uint => Pool) public pools;
    
    /// @dev Maps provider address to Provider struct
    mapping(address => Provider) public providers;
    
    /// @dev Maps liquid ID to Liquid struct
    mapping(uint => Liquid) public liquids;

    // ============ STRUCTS ============

    /**
     * @dev Represents a liquidity pool containing two tokens
     * @param id Unique identifier for the pool
     * @param token0 Address of the first token in the pair
     * @param token1 Address of the second token in the pair
     * @param liquids Array of liquid IDs belonging to this pool
     */
    struct Pool {
        uint id;
        address token0;
        address token1;
        uint[] liquids;
    }

    /**
     * @dev Represents a liquidity position provided by a user
     * @param id Unique identifier for the liquid position
     * @param poolId ID of the pool this liquid belongs to
     * @param amount0 Amount of token0 in the position
     * @param amount1 Amount of token1 in the position
     * @param provider Address of the liquidity provider
     */
    struct Liquid {
        uint id;
        uint poolId;
        uint256 amount0;
        uint256 amount1;
        address provider;
    }

    /**
     * @dev Represents a liquidity provider's profile
     * @param id Unique identifier for the provider
     * @param totalEarned Total rewards earned by the provider
     * @param balance Current available balance for withdrawal
     * @param autoStake Whether to automatically stake rewards
     * @param liquids Array of liquid IDs owned by this provider
     */
    struct Provider {
        uint id;
        uint256 totalEarned;
        uint256 balance;
        bool autoStake;
        uint[] liquids;
    }


    // ============ CONSTRUCTOR ============

    /**
     * @dev Initializes the swap contract with price feed and AfriCoin token
     * @param _priceAPI Address of the price feed oracle contract
     * @param _AFRI_COIN Address of the AfriCoin token contract
     */
    constructor(address _priceAPI, address _AFRI_COIN) {
        // Input validation: Ensure _priceAPI and _AFRI_COIN addresses are not zero.
        require(_priceAPI != address(0), "Swap: Price API address cannot be zero.");
        require(_AFRI_COIN != address(0), "Swap: AFRI_COIN address cannot be zero.");
        
        // Initialize the price feed oracle
        priceAPI = TestPriceFeed(_priceAPI);
        
        // Set the AfriCoin token address
        AFRI_COIN = _AFRI_COIN;


        // Create initial pool for ETH/AfriCoin pair
        _createPool(priceAPI.getNativeToken(), _AFRI_COIN);
        


    }

    // ============ GETTER FUNCTIONS ============ 

    function getPool(uint id) public view returns (address token0, address token1) {
        Pool memory pool = pools[id];
        return (pool.token0, pool.token1);
    }

    


    // ============ PUBLIC VIEW FUNCTIONS ============

    /**
     * @dev Returns the total liquidity size for a token pair
     * @param token0 Address of the first token
     * @param token1 Address of the second token
     * @return amount0 Total amount of token0 in the pool
     * @return amount1 Total amount of token1 in the pool
     */
    function getPoolSize(
        address token0,
        address token1
    ) public view returns (uint256, uint256) {
        // Input validation: Ensure token addresses are not zero.
        require(token0 != address(0), "Swap: token0 address cannot be zero.");
        require(token1 != address(0), "Swap: token1 address cannot be zero.");
        uint poolId = _findPool(token0, token1);
        return _poolSize(poolId);
    }

    /**
     * @dev Estimates the output amount for a token swap
     * @param token0 Address of the input token
     * @param token1 Address of the output token
     * @param amount0 Amount of input token in wei
     * @return Estimated amount of output token
     */
    function estimate(
        address token0,
        address token1,
        uint256 amount0
    ) public view returns (uint256) {
        // Input validation: Ensure token addresses are not zero and amount0 is positive.
        require(token0 != address(0), "Swap: token0 address cannot be zero.");
        require(token1 != address(0), "Swap: token1 address cannot be zero.");
        require(amount0 > 0, "Swap: Input amount must be positive.");
        uint256 _rate = priceAPI.estimate(token0, token1, amount0);
        return _rate;
    }

    /**
     * @dev Returns the address of this contract
     * @return Address of the swap contract
     */
    function getContractAddress() public view returns (address) {
        return address(this);
    }

    /**
     * @dev Finds a pool ID for a given token pair
     * @param token0 Address of the first token
     * @param token1 Address of the second token
     * @return Pool ID if found, 0 if not found
     */
    function findPool(address token0, address token1) public view returns (uint256) {
        // Input validation: Ensure token addresses are not zero.
        require(token0 != address(0), "Swap: token0 address cannot be zero.");
        require(token1 != address(0), "Swap: token1 address cannot be zero.");
        return _findPool(token0, token1);
    }

    /**
     * @dev Gets the liquid ID for a provider in a specific pool
     * @param pool_id ID of the pool to check
     * @return Liquid ID if found, 0 if not found
     */
    function liquidIndex(uint256 pool_id) public view returns (uint256) {
        // Input validation: Ensure pool_id is valid (e.g., greater than 0 if 0 is invalid ID)
        // require(pool_id > 0, "Swap: Invalid pool ID."); // Uncomment if pool ID 0 is strictly invalid
        return _liquidIndex(pool_id, msg.sender);
    }

    /**
     * @dev Returns the current burnable fees balance (owner only)
     * @return Amount of fees available for burning
     */
    function getBurnableFeesBal() public view onlyOwner returns (uint256) {
        return _burnableFees;
    }

    /**
     * @dev Returns the address of the price feed oracle.
     * @return Address of the price feed oracle.
     */
    function getPriceFeed() public view returns (address) {
        return address(priceAPI);
    }

    /**
     * @dev Returns the current swap fee percentage.
     * @return The swap fee in basis points.
     */
    function getSwapFee() public view returns (uint) {
        return swapFee;
    }

    // ============ PROVIDER FUNCTIONS ============

    /**
     * @dev Registers a new liquidity provider account
     * @notice Can only be called by addresses that are not already providers
     */
    function unlockedProviderAccount() public onlyGuest {
        // Denial of Service: Ensure that the 'liquids' array in the Provider struct does not grow unboundedly
        // The current implementation uses 'providers[msg.sender].liquids' directly, implying it's an array for a single provider.
        // If this array is meant to store all liquids for a provider, ensure operations on it are gas-efficient and bounded.
        // Consider alternative data structures or pagination if many liquids are expected per provider.

        // Create new unique provider ID
        PROVIDER_ID++;

        // Initialize provider with default values
        // Optimize to minimize state writes for gas efficiency.
        // Changed to explicit initialization for new providers as 'onlyGuest' ensures it's a new entry.
        // This avoids unnecessary reads of default zero values from storage for new accounts.
        providers[msg.sender] = Provider(
            PROVIDER_ID,
            0, // totalEarned starts at 0 for new provider.
            0, // balance starts at 0 for new provider.
            false,
            new uint[](0) // liquids array starts empty for new provider.
        );
    }

    /**
     * @dev Updates provider's auto-staking preference
     * @param _autoStake Whether to automatically stake rewards
     */
    function updateProviderProfile(bool _autoStake) public onlyProvider {
        // Access Control: Consider implementing a timelock for critical updates or if this function
        // could lead to significant changes in user behavior or fund flow.
        providers[msg.sender].autoStake = _autoStake;
        // Emit event for provider profile update for transparency.
        emit Events.ProviderProfileUpdated(msg.sender, _autoStake, block.timestamp);
    }

    /**
     * @dev Allows provider to withdraw their earned rewards
     * @param amount Amount of AfriCoin tokens to withdraw
     */
    function withDrawEarnings(uint256 amount) public onlyProvider nonReentrant {
        // Input validation: Ensure the amount is positive.
        require(amount > 0, "Swap: Withdrawal amount must be positive.");
        require(
            providers[msg.sender].balance >= amount,
            "Insufficient Balance"
        );

        // Checks-Effects-Interactions Pattern: State update before external call.
        // Update provider balance before transferring tokens to prevent reentrancy.
        providers[msg.sender].balance -= amount; 

        // Transfer AfriCoin rewards to provider
        // Use OpenZeppelin's SafeERC20 for secure token transfers to prevent common ERC20 issues.
        xIERC20(AFRI_COIN).safeTransfer(msg.sender, amount);
    }

    // ============ SWAPPING FUNCTIONS ============

    /**
     * @dev Swaps tokens for the caller
     * @param token0 Address of the input token
     * @param token1 Address of the output token
     * @param amount0 Amount of input token to swap
     * @return Amount of output token received
     */
    function swap(
        address token0,
        address token1,
        uint256 amount0
    ) public payable returns (uint256) {
        // Input validation: Ensure token addresses are not zero and amount0 is positive.
        require(token0 != address(0), "Swap: Input token0 address cannot be zero.");
        require(token1 != address(0), "Swap: Input token1 address cannot be zero.");
        require(amount0 > 0, "Swap: Input amount must be positive.");
        // The swap function handles ETH transfers, so it must be payable.
        // Consider adding slippage control (e.g., minAmountOut) to protect users from front-running.
        return doSwap(token0, token1, amount0, msg.sender);
    }

    /**
     * @dev Performs token swap with detailed validation and fee handling
     * @param token0 Address of the input token
     * @param token1 Address of the output token
     * @param amount0 Amount of input token to swap
     * @param user Address receiving the swapped tokens
     * @return amount1 Amount of output token received
     */
    function doSwap(
        address token0,
        address token1,
        uint256 amount0,
        address user
    ) public payable nonReentrant returns (uint256) {
        // Input validation: Ensure token addresses are not zero, user address is not zero, and amount0 is valid.
        require(token0 != address(0), "Swap: doSwap token0 address cannot be zero.");
        require(token1 != address(0), "Swap: doSwap token1 address cannot be zero.");
        require(user != address(0), "Swap: doSwap user address cannot be zero.");
        require(amount0 >= 100, "Amount to swap cannot be lesser than 100 WEI");

        uint256 amount1;
        uint256 _safeAmount0 = amount0;

        // Find the pool for this token pair
        uint poolId = _findPool(token0, token1);
        require(pools[poolId].id > 0, "Pool does not exists");

        // Handle ETH => ERC20 swaps
        if (token0 == priceAPI.getNativeToken()) {
            require(msg.value >= 100, "Native Currency cannot be lesser than 100 WEI");
            // Input validation: Ensure msg.value matches amount0 for ETH swaps if expected to be exact.
            require(msg.value == amount0, "Swap: ETH amount sent must match input amount.");
            
            _safeAmount0 = msg.value;
            amount1 = estimate(token0, token1, _safeAmount0);

            // Verify sufficient pool liquidity
            (, uint256 poolSizeToken1) = _poolSize(poolId);
            require(poolSizeToken1 >= amount1, "Insufficient Pool Size");

            // Process swap and calculate fees
            uint256 fee = _transferSwappedTokens0(
                pools[poolId].token1,
                amount1,
                user
            );

            // Distribute fees: 80% to providers, 3% for burning, 17% platform profit
            // Arithmetic operations: Ensure safe calculations. Solidity 0.8+ provides default checked arithmetic.
            uint256 providersReward = (fee * 80) / 100; // Use fixed-point arithmetic if higher precision required for fee calculation.
            uint256 burnFee = (fee * 3) / 100;
            _burnableFees += burnFee;
            uint256 contractProfit = fee - providersReward - burnFee;
            _platformProfit += contractProfit;

            // Update liquidity positions
            _aggregateLiquids(
                _safeAmount0,
                amount1,
                poolSizeToken1,
                pools[poolId],
                providersReward
            );
        }
        // Handle ERC20 => ETH swaps
        else if (token1 == priceAPI.getNativeToken()) {
            amount1 = estimate(token0, token1, _safeAmount0);

            // Verify sufficient pool liquidity
            (uint256 poolSizeToken1, ) = _poolSize(poolId);
            require(poolSizeToken1 >= amount1, "Insufficient Pool Size");
            
            // Transfer input token from user to contract first (Checks-Effects-Interactions).
            // Use OpenZeppelin's SafeERC20 for secure token transfers.
            xIERC20(token0).safeTransferFrom(msg.sender, address(this), _safeAmount0);

            // Process swap and calculate fees
            uint256 fee = _transferSwappedTokens1(
                pools[poolId].token0,
                _safeAmount0,
                amount1,
                user
            );

            // Distribute fees
            uint256 providersReward = (fee * 80) / 100;
            uint256 burnFee = (fee * 3) / 100;
            _burnableFees += burnFee;
            uint256 contractProfit = fee - providersReward - burnFee;
            _platformProfit += contractProfit;

            // Update liquidity positions
            _aggregateLiquids(
                _safeAmount0,
                amount1,
                poolSizeToken1,
                pools[poolId],
                providersReward
            );
        }
        // Handle ERC20 => ERC20 swaps
        else {
            amount1 = estimate(token0, token1, _safeAmount0);
            
            // Transfer input token from user to contract first (Checks-Effects-Interactions).
            // Use OpenZeppelin's SafeERC20 for secure token transfers.
            xIERC20(token0).safeTransferFrom(msg.sender, address(this), _safeAmount0);

            // Determine correct pool size based on token position
            uint256 poolSizeToken1;
            if (pools[poolId].token0 == token1) {
                (uint256 _poolSizeToken1, ) = _poolSize(poolId);
                poolSizeToken1 = _poolSizeToken1;
            } else if (pools[poolId].token1 == token1) {
                (, uint256 _poolSizeToken1) = _poolSize(poolId);
                poolSizeToken1 = _poolSizeToken1;
            }

            require(poolSizeToken1 >= amount1, "Insufficient Pool Size");

            // Process swap and calculate fees
            uint256 fee = _transferSwappedTokens2(
                token0,
                token1,
                _safeAmount0,
                amount1,
                user
            );

            // Distribute fees
            uint256 providersReward = (fee * 80) / 100;
            uint256 burnFee = (fee * 3) / 100;
            _burnableFees += burnFee;
            uint256 contractProfit = fee - providersReward - burnFee;
            _platformProfit += contractProfit;

            // Update liquidity positions
            _aggregateLiquids(
                _safeAmount0,
                amount1,
                poolSizeToken1,
                pools[poolId],
                providersReward
            );
        }

        // Emit swap event for on-chain tracking
        emit Events.FleepSwaped(
            amount0,
            amount1,
            token0,
            token1,
            block.timestamp
        );

        return amount1;
    }

    // ============ LIQUIDITY PROVIDER FUNCTIONS ============

    /**
     * @dev Provides liquidity to a specified pool
     * @param poolId ID of the pool to provide liquidity to
     * @param amount0 Amount of token0 to provide
     */
    function provideLiquidity(
        uint poolId,
        uint256 amount0
    ) public payable nonReentrant {
        // Input validation: Ensure poolId is valid, amount0 is positive, and token addresses are not zero.
        require(poolId > 0, "Swap: Invalid pool ID.");
        require(amount0 > 0, "Swap: Liquidity amount must be positive.");
        require(pools[poolId].id > 0, "Swap: Pool does not exist.");

        uint256 amount1;
        uint256 _safeAmount0 = amount0;

        // Auto-register as provider if not already registered
        if (providers[msg.sender].id == 0) {
            unlockedProviderAccount();
        }

        // Handle ETH token provision
        if (pools[poolId].token0 == priceAPI.getNativeToken()) {
            require(msg.value > 0, "ETH cannot be zero for native token provision."); // Changed from 100 to 0 for stricter validation.
            require(msg.value == amount0, "Swap: ETH amount sent must match input amount.");
            
            _safeAmount0 = msg.value;
            // Calculate required amount of paired token
            amount1 = estimate(
                pools[poolId].token0,
                pools[poolId].token1,
                _safeAmount0
            );
            // Input validation: Ensure the estimated amount is positive.
            require(amount1 > 0, "Swap: Estimated amount1 must be positive.");

            // Transfer paired token from provider to contract
            // Use OpenZeppelin's SafeERC20 for secure token transfers to prevent common ERC20 issues.
            xIERC20(pools[poolId].token1).safeTransferFrom(
                msg.sender,
                address(this),
                amount1
            );
        } else {
            // Calculate required amount of paired token
            amount1 = estimate(
                pools[poolId].token0,
                pools[poolId].token1,
                _safeAmount0
            );
            // Input validation: Ensure the estimated amount is positive.
            require(amount1 > 0, "Swap: Estimated amount1 must be positive.");
            
            // Transfer both tokens from provider to contract
            // Use OpenZeppelin's SafeERC20 for secure token transfers.
            xIERC20(pools[poolId].token0).safeTransferFrom(
                msg.sender,
                address(this),
                _safeAmount0
            );
            xIERC20(pools[poolId].token1).safeTransferFrom(
                msg.sender,
                address(this),
                amount1
            );
        }

        // Check if provider already has liquidity in this pool
        uint liquidId = _liquidIndex(poolId, msg.sender);

        if (liquidId > 0) {
            // Update existing liquidity position
            liquids[liquidId].amount0 += _safeAmount0;
            liquids[liquidId].amount1 += amount1;
        } else {
            // Create new liquidity position
            _createLiquid(poolId, _safeAmount0, amount1, msg.sender);
        }

        // Emit liquidity provision event
        emit Events.LiquidProvided(
            pools[poolId].token0,
            pools[poolId].token1,
            _safeAmount0,
            amount1,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Removes liquidity from a pool and returns tokens to provider
     * @param id ID of the liquidity position to remove
     */
    function removeLiquidity(uint id) public onlyProvider nonReentrant {
        require(liquids[id].provider == msg.sender, "Unauthorized");
    
        // Get pool information
        uint poolId = liquids[id].poolId;
        Pool storage pool = pools[poolId]; // Use storage for direct modification

        // Find and remove liquid ID from pool's liquids array using swap-and-pop
        for (uint i = 0; i < pool.liquids.length; i++) {
            if (pool.liquids[i] == id) {
                pool.liquids[i] = pool.liquids[pool.liquids.length - 1];
                pool.liquids.pop();
                break;
            }
        }

        // Find and remove liquid ID from provider's liquids array using swap-and-pop
        Provider storage provider = providers[msg.sender]; // Use storage
        for (uint i = 0; i < provider.liquids.length; i++) {
            if (provider.liquids[i] == id) {
                provider.liquids[i] = provider.liquids[provider.liquids.length - 1];
                provider.liquids.pop();
                break;
            }
        }

        // Return tokens to provider based on pool type
        if (pools[poolId].token0 == priceAPI.getNativeToken()) {
            // Return ETH and ERC20 token
            payable(msg.sender).transfer(liquids[id].amount0);
            xIERC20(pool.token1).transfer(msg.sender, liquids[id].amount1);
        } else {
            // Return both ERC20 tokens
            xIERC20(pool.token0).transfer(msg.sender, liquids[id].amount0);
            xIERC20(pool.token1).transfer(msg.sender, liquids[id].amount1);
        }

        // Delete the liquidity position from mapping
        delete liquids[id];

        // Emit event for liquidity removal
        emit Events.LiquidRemoved(
            pool.token0,
            pool.token1,
            liquids[id].amount0, // Note: liquids[id] will be zero after delete, capture before
            liquids[id].amount1, // This also implies capturing amounts before delete
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Returns all liquidity positions for a given wallet
     * @param wallet Address of the wallet to query
     * @return _pools Array of pool IDs
     * @return _amounts0 Array of token0 amounts
     * @return _amounts1 Array of token1 amounts
     * @return providerLiquids Array of liquid IDs
     */
    function myLiquidities(
        address wallet
    ) public view returns (uint256[] memory, uint256[] memory, uint256[] memory, uint256[] memory) {
        // Input Validation: Ensure wallet address is not zero.
        require(wallet != address(0), "Swap: Wallet address cannot be zero.");
        // Denial of Service: This function iterates over a dynamic array (`providers[wallet].liquids`).
        // If a provider has a very large number of liquidity positions, this function call
        // could become very expensive and potentially revert due to gas limits.
        // Consider implementing pagination or off-chain indexing for large datasets.
        uint256[] memory providerLiquids = providers[wallet].liquids;

        uint256[] memory _pools = new uint256[](providerLiquids.length);
        uint256[] memory _amounts0 = new uint256[](providerLiquids.length);
        uint256[] memory _amounts1 = new uint256[](providerLiquids.length);

        for (uint index = 0; index < providerLiquids.length; index++) {
            // Gas Efficiency: Minimize state reads within the loop if possible.
            // Current reads are necessary for data retrieval.
            _pools[index] = liquids[providerLiquids[index]].poolId;
            _amounts0[index] = liquids[providerLiquids[index]].amount0;
            _amounts1[index] = liquids[providerLiquids[index]].amount1;
        }

        return (_pools, _amounts0, _amounts1, providerLiquids);
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @dev Creates a new trading pool for a token pair (owner only)
     * @param token0 Address of the first token
     * @param token1 Address of the second token
     * @return Pool ID of the created pool
     */
    function createPool(
        address token0,
        address token1
    ) public onlyOwner returns (uint) {
        // Input validation: Ensure token addresses are not zero.
        require(token0 != address(0), "Swap: createPool token0 address cannot be zero.");
        require(token1 != address(0), "Swap: createPool token1 address cannot be zero.");
        // Access Control: This function is onlyOwner. Consider a timelock for production deployments if creating new pools is a critical operation.
        return _createPool(token0, token1);
    }

    /**
     * @dev Updates the swap fee percentage (owner only)
     * @param fee New fee in basis points (20 = 0.20%)
     */
    function updateSwapFee(uint fee) public onlyOwner {
        // Input Validation: Ensure fee is within a reasonable range.
        require(fee > 0, "Platform fee cannot be zero");
        require(fee < 1000, "Platform fee cannot be a hundred"); // Assuming max fee is 9.99%
        swapFee = fee;
        // Emit event for swap fee update for transparency.
        emit Events.SwapFeeUpdated(fee, msg.sender, block.timestamp);
    }

    /**
     * @dev Withdraws platform earnings to specified address (owner only)
     * @param amount Amount of AfriCoin tokens to withdraw
     * @param receiver Address to receive the tokens
     */
    function withDrawPlaformEarnings(
        uint256 amount,
        address receiver
    ) public onlyOwner nonReentrant {
        // Input Validation: Ensure receiver address is not zero and amount is positive.
        require(receiver != address(0), "Swap: Receiver address cannot be zero.");
        require(amount > 0, "Swap: Withdrawal amount must be positive.");
        require(_platformProfit >= amount, "Insufficient Balance");

        // Checks-Effects-Interactions Pattern: State update before external call.
        // Update platform profit balance before transferring tokens to prevent reentrancy.
        _platformProfit -= amount;

        // Transfer AfriCoin tokens to receiver
        // Use OpenZeppelin's SafeERC20 for secure token transfers.
        xIERC20(AFRI_COIN).safeTransfer(receiver, amount);
        // Emit event for fee collection/withdrawal for transparency.
        emit Events.FeeCollected(amount, AFRI_COIN, block.timestamp);
    }

    /**
     * @dev Burns accumulated fees by destroying AfriCoin tokens (owner only)
     */
    function burnFees() public onlyOwner nonReentrant {
        // Input Validation: Ensure there are burnable fees.
        require(getBurnableFeesBal() > 0, "Insufficient Balance");
        
        uint256 amountToBurn = _burnableFees; // Store amount to burn before modification.

        // Burn the accumulated fees
        // Use OpenZeppelin's SafeERC20 for secure token burning.
        xIERC20(AFRI_COIN).burn(amountToBurn);
        // Checks-Effects-Interactions Pattern: State update after external call, in case of revert.
        _burnableFees = 0; // Reset burnable fees to zero after burning.
        // Emit event for fee burning for transparency.
        emit Events.FeeBurned(amountToBurn, AFRI_COIN, block.timestamp);
    }

    // ============ INTERNAL FUNCTIONS ============

    /**
     * @dev Finds the liquid ID for a provider in a specific pool
     * @param poolId ID of the pool
     * @param provider Address of the provider
     * @return Liquid ID if found, 0 if not found
     */
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

    /**
     * @dev Distributes swap impact and rewards across all liquidity providers
     * @param amount0 Amount of token0 being swapped
     * @param amount1 Amount of token1 being swapped
     * @param poolSizeToken1 Total size of token1 in the pool
     * @param pool Pool struct containing liquidity information
     * @param fee Total fee to distribute to providers
     */
    function _aggregateLiquids(
        uint256 amount0,
        uint256 amount1,
        uint256 poolSizeToken1,
        Pool memory pool,
        uint256 fee
    ) private {
        // Denial of Service: Ensure this loop does not iterate over an unbounded array of liquidity providers.
        // If the number of liquids in a pool grows very large, this function could become too expensive to execute.
        // Consider alternative mechanisms for distributing rewards or capping the number of liquidity providers per pool.
        // Optimize to minimize state writes for gas efficiency within the loop.
        for (uint index = 0; index < pool.liquids.length; index++) {
            uint liquidId = pool.liquids[index];

            // Calculate provider's share of rewards based on their contribution
            // Use SafeMath for all arithmetic operations to prevent overflow/underflow, though Solidity 0.8+ has default checked arithmetic.
            uint256 reward = (liquids[liquidId].amount1 * fee) / poolSizeToken1;

            address provider = liquids[liquidId].provider;

            // Calculate proportional addition to token0
            uint256 additionAmount = (liquids[liquidId].amount1 * amount0) / poolSizeToken1;
            liquids[liquidId].amount0 += additionAmount;

            // Calculate proportional deduction from token1
            uint256 deductionAmount = (liquids[liquidId].amount1 * amount1) / poolSizeToken1;
            liquids[liquidId].amount1 -= deductionAmount;

            // Update provider rewards
            // Minimize state updates to save gas costs.
            // These are individual state updates, which are generally efficient.
            providers[provider].totalEarned += reward;
            providers[provider].balance += reward;
        }
    }

    /**
     * @dev Handles ETH => ERC20 token transfers and fee calculation
     * @param token1 Address of the output ERC20 token
     * @param amount1 Amount of output token to transfer
     * @param owner Address receiving the tokens
     * @return Fee amount in AfriCoin tokens
     */
    function _transferSwappedTokens0(
        address token1,
        uint256 amount1,
        address owner
    ) private returns (uint256) {
        xIERC20 quoteToken = xIERC20(token1);

        // Calculate swap fee (corrected for precision: multiply before divide)
        uint256 _fee = (amount1 * swapFee) / 10000; // Assuming swapFee is in basis points (e.g., 20 for 0.2%)

        // Transfer tokens minus fee to user
        quoteToken.transfer(owner, (amount1 - _fee));

        // Convert fee to AfriCoin equivalent
        return estimate(token1, AFRI_COIN, _fee);
    }

    /**
     * @dev Handles ERC20 => ETH token transfers and fee calculation
     * @param token0 Address of the input ERC20 token
     * @param amount0 Amount of input token
     * @param amount1 Amount of ETH to transfer
     * @param owner Address receiving the ETH
     * @return Fee amount in AfriCoin tokens
     */
    function _transferSwappedTokens1(
        address token0,
        uint256 amount0,
        uint256 amount1,
        address owner
    ) private returns (uint256) { // Changed visibility from public to private as it's an internal helper function.
        xIERC20 baseToken = xIERC20(token0);

        // Calculate swap fee (corrected for precision: multiply before divide)
        uint256 _fee = (amount1 * swapFee) / 10000; // Assuming swapFee is in basis points

        // Transfer input token from user to contract
        // Use OpenZeppelin's SafeERC20 for secure token transfers.
        baseToken.safeTransferFrom(owner, address(this), amount0);

        // Verify contract has sufficient ETH balance
        require(
            address(this).balance >= amount1,
            "Contract: Insufficient Balance"
        );

        // Transfer ETH minus fee to user
        // Consider using 'call' with proper checks for security and gas efficiency.
        (bool sent, ) = owner.call{value: amount1 - _fee}("");
        require(sent, "Failed to send ETH to the User");

        // Convert fee to AfriCoin equivalent
        return estimate(priceAPI.getNativeToken(), AFRI_COIN, _fee);
    }

    /**
     * @dev Handles ERC20 => ERC20 token transfers and fee calculation
     * @param token0 Address of the input token
     * @param token1 Address of the output token
     * @param amount0 Amount of input token
     * @param amount1 Amount of output token
     * @param owner Address receiving the output tokens
     * @return Fee amount in AfriCoin tokens
     */
    function _transferSwappedTokens2(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        address owner
    ) private returns (uint256) {
        xIERC20 baseToken = xIERC20(token0);
        xIERC20 quoteToken = xIERC20(token1);

        // Calculate swap fee (corrected for precision: multiply before divide)
        uint256 _fee = (amount1 * swapFee) / 10000; // Assuming swapFee is in basis points

        // Transfer input token from user to contract
        // Use OpenZeppelin's SafeERC20 for secure token transfers.
        baseToken.safeTransferFrom(owner, address(this), amount0);

        // Transfer output token minus fee to user
        quoteToken.safeTransfer(owner, (amount1 - _fee));

        // Convert fee to AfriCoin equivalent
        return estimate(token1, AFRI_COIN, _fee);
    }

    /**
     * @dev Finds a pool ID for a given token pair
     * @param token0 Address of the first token
     * @param token1 Address of the second token
     * @return Pool ID if found, 0 if not found
     */
    function _findPool(
        address token0,
        address token1
    ) private view returns (uint) {
        require(
            token0 != address(0) && token1 != address(0),
            "Invalid Pool Tokens"
        );
        
        for (uint index = 0; index <= POOL_ID; index++) {
            // Check both token arrangements (A/B and B/A)
            if (
                (pools[index].token0 == token0 && pools[index].token1 == token1) ||
                (pools[index].token0 == token1 && pools[index].token1 == token0)
            ) {
                return index;
            }
        }
        return 0;
    }

    /**
     * @dev Creates a new liquidity position
     * @param poolId ID of the pool
     * @param amount0 Amount of token0
     * @param amount1 Amount of token1
     * @param provider Address of the liquidity provider
     */
    function _createLiquid(
        uint poolId,
        uint256 amount0,
        uint256 amount1,
        address provider
    ) private {
        LIQUID_ID++;
        
        // Create the liquidity position
        liquids[LIQUID_ID] = Liquid(
            LIQUID_ID,
            poolId,
            amount0,
            amount1,
            provider
        );
        
        // Register the liquid in pool and provider records
        pools[poolId].liquids.push(LIQUID_ID);
        providers[provider].liquids.push(LIQUID_ID);
    }

    /**
     * @dev Calculates the total size of a liquidity pool
     * @param id Pool ID
     * @return amount0 Total amount of token0 in the pool
     * @return amount1 Total amount of token1 in the pool
     */
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

    /**
     * @dev Creates a new liquidity pool for a token pair
     * @param token0 Address of the first token
     * @param token1 Address of the second token
     * @return Pool ID of the created pool
     */
    function _createPool(
        address token0,
        address token1
    ) private returns (uint) {
        // Input validation: Ensure token addresses are not zero.
        require(
            token0 != address(0),
            "Pair does not exists, Contact admin"
        );
        require(
            token1 != address(0),
            "Pair does not exists, Contact admin"
        );

        // Check if pool already exists
        bool exists = _findPool(token0, token1) != 0;
        if (exists) return 0;

        POOL_ID++;
        // Create new pool with empty liquids array
        pools[POOL_ID] = Pool(POOL_ID, token0, token1, new uint[](0)); // Explicitly initialize liquids as an empty array.

        // Emit event for pool creation for transparency.
        emit Events.PoolCreated(POOL_ID, token0, token1, msg.sender, block.timestamp);

        return POOL_ID;
    }

    // ============ MODIFIERS ============

    /**
     * @dev Restricts access to addresses that are not registered as providers
     */
    modifier onlyGuest() {
        require(providers[msg.sender].id == 0, "Only Guest");
        _;
    }

    /**
     * @dev Restricts access to registered liquidity providers only
     */
    modifier onlyProvider() {
        require(providers[msg.sender].id != 0, "Only Provider");
        _;
    }
}