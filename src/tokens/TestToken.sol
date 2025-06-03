// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract TestnetToken is ERC20Burnable {
    uint256 private MAX_ALLOCATION = inWei(100);

    // user address => minted amount
    mapping(address => uint256) public allocations;

//    [LINK,  DAI, NEAR , COMP, TRX , AAVE]
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, inWei(500));
        _mint(address(this), inWei(500));
    }

    // faucet minting for testing purposes
    function faucet(uint256 _amount) public {
        uint256 amount = inWei(_amount);
        require(amount > 0, "Amount cannot be zero");
        require(
            allocations[msg.sender] + amount < MAX_ALLOCATION,
            "Cant Mint More Tokens"
        );
        allocations[msg.sender] += amount;
        _approve(address(this), msg.sender, amount);
        transferFrom(address(this), msg.sender, amount);
    }

function approve(address spender, uint256 amount) public override returns (bool) {
    // Your custom logic here
    return super.approve(spender, amount); // Call the parent contract's approve function
}






    
     function burn(uint256 _amount) public override{
        uint256 balances = balanceOf(msg.sender);
        
        require(_amount > 0);
        require (balances >= _amount); 
        super.burn(_amount);
    }
    
    function getUserTokenAllocation() public view  returns(uint256){
         return allocations[msg.sender];
    }
    
    function inWei(uint256 amount) public view returns (uint256) {
        return amount * 10 ** decimals();
    }



 



   
}
