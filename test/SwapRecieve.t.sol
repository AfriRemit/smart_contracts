// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Swap} from "../src/core/Swap.sol";
import {TestnetToken} from"../src/tokens/TestToken.sol";
import {TestPriceFeed} from "../src/feeds/TestPriceFeed.sol";
import {Events} from "../src/libraries/Events.sol";

contract SwapReceiveTest is Test {
    Swap public swap;
    TestnetToken public afriCoin;
    TestPriceFeed public priceFeed;

    address nativeToken = address(0x123);

    address user = address(0xBEEF);
    uint256 sendAmount = 1 ether;

    function setUp() public {
        afriCoin = new TestnetToken("AfriCoin", "AFC");
        priceFeed = new TestPriceFeed(nativeToken);
        swap = new Swap(address(priceFeed), address(afriCoin));

        vm.deal(user, 10 ether); // fund the user with ETH
    }

    function testReceiveEmitsEventAndIncreasesBalance() public {
        // Check initial balance
        assertEq(address(swap).balance, 0);

        // Expect event
        vm.prank(user);
        vm.expectEmit(true, true, false, true); // indexed sender, non-indexed value
        emit Events.Received(user, sendAmount);

        // Send ETH to contract (triggers receive())
        (bool success, ) = address(swap).call{value: sendAmount}("");
        assertTrue(success, "ETH transfer failed");

        // Check new balance
        assertEq(address(swap).balance, sendAmount);
    }
}
