// SPDX-License-Identifier: MIT
// SupraOracles 
pragma solidity ^0.8.13;


interface ISupraSValueFeed {
    function getSvalue(uint64 _pairIndex) external view returns (bytes32, bool);
    function getSvalues(uint64[] memory _pairIndexes) external view returns (bytes32[] memory, bool[] memory);
   
    function checkPrice(string memory marketPair) external view returns (int256 price, uint256 timestamp);


}