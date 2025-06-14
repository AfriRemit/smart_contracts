// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Swap} from "../src/core/Swap.sol"; 
import {TestPriceFeed} from "../src/feeds/TestPriceFeed.sol"; 
import {TestnetToken} from "../src/tokens/TestToken.sol"; 

 contract GetPoolSizeTest is Test {
    Swap public swap;
    
    // Test tokens
    TestnetToken public token0;
    TestnetToken public token1;
    TestnetToken public token2;
    TestnetToken public token3;
    
    address zeroAddress = address(0);
    address provider = address(0x999);
    uint256 poolWithLiquidityId;
    uint256 emptyPoolId;

    // Price API mock address - replace with your actual price oracle address
    address priceAPI = address(0x123);
    // Native token address - typically WETH or similar
    address nativeToken = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function setUp() public {
        // Deploy test tokens
        token0 = new TestnetToken("Token0", "TKN0");
        token1 = new TestnetToken("Token1", "TKN1");
        token2 = new TestnetToken("Token2", "TKN2");
        token3 = new TestnetToken("Token3", "TKN3");
        
        // Deploy swap contract with required constructor parameters
        swap = new Swap(priceAPI, nativeToken);
        
        // Setup provider account
        vm.deal(provider, 100 ether);
        vm.startPrank(provider);
        
        // Get tokens from faucet
        token0.faucet(100); // 100 TKN0
        token1.faucet(200); // 200 TKN1
        token2.faucet(100); // 100 TKN2
        token3.faucet(100); // 100 TKN3
        
        // Approve swap contract to spend tokens
        token0.approve(address(swap), type(uint256).max);
        token1.approve(address(swap), type(uint256).max);
        token2.approve(address(swap), type(uint256).max);
        token3.approve(address(swap), type(uint256).max);
        
        // Setup a pool with liquidity (100 token0, 200 token1)
        poolWithLiquidityId = swap.createPool(address(token0), address(token1));
        
        // Mock estimate to return 200 when input is 100 (2:1 ratio)
        vm.mockCall(
            address(swap),
            abi.encodeWithSelector(Swap.estimate.selector, address(token0), address(token1), 100 ether),
            abi.encode(200 ether)
        );
        
        // Provide liquidity (100 token0 will require 200 token1 based on our mock)
        swap.provideLiquidity(poolWithLiquidityId, 100 ether);
        
        // Setup an empty pool (no liquidity)
        emptyPoolId = swap.createPool(address(token2), address(token3));
        
        vm.stopPrank();
    }

    /// @dev Test 1: Verify accurate amounts for pool with liquidity
    function test_ReturnsAccurateAmountsForPoolWithLiquidity() public {
        (uint256 amount0, uint256 amount1) = swap.getPoolSize(address(token0), address(token1));
        
        assertEq(amount0, 100 ether, "Incorrect token0 amount");
        assertEq(amount1, 200 ether, "Incorrect token1 amount");
    }

    /// @dev Test 2: Verify (0, 0) returned for empty pool
    function test_ReturnsZeroForEmptyPool() public {
        (uint256 amount0, uint256 amount1) = swap.getPoolSize(address(token2), address(token3));
        
        assertEq(amount0, 0, "Token0 amount should be 0");
        assertEq(amount1, 0, "Token1 amount should be 0");
    }

    /// @dev Test 3: Verify revert when token0 is zero address
    function test_RevertWhenToken0IsZeroAddress() public {
        vm.expectRevert("Swap: token0 address cannot be zero.");
        swap.getPoolSize(zeroAddress, address(token1));
    }

    /// @dev Test 4: Verify revert when token1 is zero address
    function test_RevertWhenToken1IsZeroAddress() public {
        vm.expectRevert("Swap: token1 address cannot be zero.");
        swap.getPoolSize(address(token0), zeroAddress);
    }

    /// @dev Test 5: Verify (0, 0) returned for non-existent pool
    function test_ReturnsZeroForNonExistentPool() public {
        TestnetToken nonExistentTokenA = new TestnetToken("NonExistentA", "NEA");
        TestnetToken nonExistentTokenB = new TestnetToken("NonExistentB", "NEB");
        
        (uint256 amount0, uint256 amount1) = swap.getPoolSize(address(nonExistentTokenA), address(nonExistentTokenB));
        
        assertEq(amount0, 0, "Should return 0 for token0 in non-existent pool");
        assertEq(amount1, 0, "Should return 0 for token1 in non-existent pool");
    }
}