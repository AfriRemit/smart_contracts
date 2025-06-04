// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AfriRemitFaucet
 * @dev  faucet contract for the AfriRemit token
 */
contract AfriRemitFaucet is Ownable {
    IERC20 public token;
    
    // Amount to distribute per request (in wei)
    uint256 public amountAllowed = 100 * 10**18; // 100 AFRI tokens
    
    // Daily limit per user
    uint256 public dailyLimit = 100 * 10**18; // 100 AFRI tokens
    
    // Cooldown period between requests (in seconds)
    uint256 public requestCooldown = 24 hours;
    
    // Mapping to track last request time per address
    mapping(address => uint256) public lastRequestTime;
    
    // Statistics tracking
    uint256 public totalClaimed = 0;
    uint256 public totalUsers = 0;
    uint256 public claimedToday = 0;
    uint256 public totalDistributed = 0;
    
    // Events
    event TokensDispensed(address indexed recipient, uint256 amount);
    
    /**
     * @dev Constructor sets the token address
     * @param _tokenAddress Address of the AFRI token contract
     */
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Token address cannot be zero");
        token = IERC20(_tokenAddress);
    }
    
    /**
     * @dev Allows users to request tokens from the faucet
     */
    function requestTokens() external {
        address requestor = msg.sender;
        
        // Check if the faucet has enough tokens
        require(token.balanceOf(address(this)) >= amountAllowed, "Faucet does not have enough tokens");
        
        // Check if the cooldown period has passed
        require(block.timestamp >= lastRequestTime[requestor] + requestCooldown, 
                "You need to wait before requesting again");
        
        // Update request tracking
        lastRequestTime[requestor] = block.timestamp;
        
        // Update statistics
        totalClaimed++;
        claimedToday++;
        totalDistributed += amountAllowed;
        
        // Transfer tokens
        bool success = token.transfer(requestor, amountAllowed);
        require(success, "Token transfer failed");
        
        emit TokensDispensed(requestor, amountAllowed);
    }
    
    /**
     * @dev Allows the owner to fund the faucet with tokens
     * @param amount Amount of tokens to add to the faucet
     */
    function fundFaucet(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");
    }
    
    /**
     * @dev Allows the owner to withdraw tokens from the faucet
     * @param amount Amount of tokens to withdraw
     */
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(token.balanceOf(address(this)) >= amount, "Not enough tokens in the faucet");
        
        bool success = token.transfer(owner(), amount);
        require(success, "Token transfer failed");
    }
    
    /**
     * @dev Allows the owner to change the amount allowed per request
     * @param newAmount New amount to allow per request
     */
    function setAmountAllowed(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "Amount must be greater than zero");
        amountAllowed = newAmount;
    }
    
    /**
     * @dev Returns the token balance of the faucet
     */
    function getFaucetBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    /**
     * @dev Returns the time remaining before a user can request again
     * @param user Address to check
     */
    function timeUntilNextRequest(address user) external view returns (uint256) {
        uint256 lastRequest = lastRequestTime[user];
        if (lastRequest == 0) {
            return 0;
        }
        
        uint256 nextRequestTime = lastRequest + requestCooldown;
        if (block.timestamp >= nextRequestTime) {
            return 0;
        }
        
        return nextRequestTime - block.timestamp;
    }
}