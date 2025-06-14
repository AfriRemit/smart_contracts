// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Swap} from "../src/core/Swap.sol"; 
import {TestPriceFeed} from "../src/feeds/TestPriceFeed.sol"; 
import {TestnetToken} from "../src/tokens/TestToken.sol"; 


contract SwapConstructorTest is Test {
    Swap public swap;
    TestPriceFeed public priceFeed;
    TestnetToken public afriCoin;

    address public constant nativeToken = address(0x123); // fake native token address

    event PoolCreated(address indexed tokenA, address indexed tokenB);

    function setUp() public {
        // Deploy mocks
        priceFeed = new TestPriceFeed(nativeToken);
        afriCoin = new TestnetToken("AfriCoin", "AFC");

        swap = new Swap(address(priceFeed), address(afriCoin));

    }

    function testConstructorSetsAddresses() public {
        swap = new Swap(address(priceFeed), address(afriCoin));
        assertEq(address(swap.priceAPI()), address(priceFeed));
        assertEq(swap.AFRI_COIN(), address(afriCoin));
    }

    function testConstructorRevertsIfPriceAPIIsZero() public {
        vm.expectRevert("Swap: Price API address cannot be zero.");
        swap = new Swap(address(0), address(afriCoin));
    }

    function testConstructorRevertsIfAfriCoinIsZero() public {
        vm.expectRevert("Swap: AFRI_COIN address cannot be zero.");
        swap = new Swap(address(priceFeed), address(0));
    }

   function testInitialPoolIsCreated() public {
    swap = new Swap(address(priceFeed), address(afriCoin)); // constructor emits the event

    (address token0, address token1) = swap.getPool(1);
    assertEq(token0, nativeToken);
    assertEq(token1, address(afriCoin));
}

}
