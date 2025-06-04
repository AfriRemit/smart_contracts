// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ITestPriceFeed {
    function markTokenAsTradeable(address[] memory _tokenAddresses, uint256[] memory _prices) external;
    function getTokenPrice(address _TokenAddress) external view returns (uint256);
    function getExchangeRate(address baseAddress, address quoteAddress) external view returns (int256);
    function areTokensTradeable(address[] memory _tokenDesired) external view returns (bool isTrue);
    function getTradeableTokenAddresses() external view returns (address[] memory);
    function getPrice(address tokenAddress) external view returns (uint256);
    function getNativePrice() external view returns (uint256);
    function getDecimal() external view returns (uint256);
}
