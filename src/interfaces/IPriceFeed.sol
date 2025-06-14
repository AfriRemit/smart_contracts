// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPriceFeed {
    function getLatestPrice(address _tokenAddress) external view returns (uint256);
    function estimate(address _token0, address _token1, uint256 _amount0) external view returns (uint256);
    function getNativeToken() external view returns (address);
    function getAggregator(address _tokenAddress) external view returns (address);
}
