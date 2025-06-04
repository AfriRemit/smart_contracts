// SPDX-License-Identifier: MIT
// SupraOracles 
pragma solidity ^0.8.13;
interface IPriceFeedUtils {

    function unpack(bytes32 data) external pure returns(uint256[4] memory);

    function bytesToUint256(bytes memory _bs) external pure returns (uint256 value);

}