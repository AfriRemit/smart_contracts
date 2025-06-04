// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title AfriCoin
 * @dev ERC20 token specifically designed for the AfriRemit platform
 * Features:
 * - Mintable by authorized contracts only
 * - Burnable for deflationary mechanics
 * - Pausable for emergency situations
 * - Role-based access control
 * - Permit functionality for gasless approvals
 */
contract AfriCoin is ERC20, ERC20Burnable, AccessControl, Pausable, ERC20Permit {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 100 million tokens
    
    // Platform fee structure
    uint256 public transferFeeRate = 0; // 0% by default, can be set for platform revenue
    address public feeRecipient;
    
    mapping(address => bool) public isExemptFromFees;
    
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event FeeExemptionUpdated(address account, bool exempt);
    
    constructor(
        address _initialOwner,
        address _feeRecipient
    ) ERC20("AfriCoin", "AFRC") ERC20Permit("AfriCoin") {
        require(_initialOwner != address(0), "Invalid initial owner");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(MINTER_ROLE, _initialOwner);
        _grantRole(PAUSER_ROLE, _initialOwner);
        
        feeRecipient = _feeRecipient;
        
        // Mint initial supply to the owner
        _mint(_initialOwner, INITIAL_SUPPLY);
        
        // Exempt important addresses from fees
        isExemptFromFees[_initialOwner] = true;
        isExemptFromFees[address(this)] = true;
        isExemptFromFees[_feeRecipient] = true;
    }
    
    /**
     * @dev Mint new tokens - only callable by contracts with MINTER_ROLE
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(to, amount);
    }
    
    /**
     * @dev Batch mint to multiple addresses
     */
    function batchMint(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        require(totalSupply() + totalAmount <= MAX_SUPPLY, "Exceeds maximum supply");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }
    
    /**
     * @dev Pause all token transfers
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause token transfers
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Set transfer fee rate (in basis points, e.g., 100 = 1%)
     */
    function setTransferFeeRate(uint256 _feeRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeRate <= 1000, "Fee rate too high"); // Max 10%
        
        uint256 oldRate = transferFeeRate;
        transferFeeRate = _feeRate;
        
        emit FeeRateUpdated(oldRate, _feeRate);
    }
    
    /**
     * @dev Set fee recipient address
     */
    function setFeeRecipient(address _feeRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        
        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;
        
        emit FeeRecipientUpdated(oldRecipient, _feeRecipient);
    }
    
    /**
     * @dev Set fee exemption for an address
     */
    function setFeeExemption(address account, bool exempt) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isExemptFromFees[account] = exempt;
        emit FeeExemptionUpdated(account, exempt);
    }
    
    /**
     * @dev Override transfer to implement fees
     */
    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        
        if (transferFeeRate > 0 && !isExemptFromFees[from] && !isExemptFromFees[to]) {
            uint256 feeAmount = (amount * transferFeeRate) / 10000;
            uint256 transferAmount = amount - feeAmount;
            
            super._transfer(from, feeRecipient, feeAmount);
            super._transfer(from, to, transferAmount);
        } else {
            super._transfer(from, to, amount);
        }
    }
    
    /**
     * @dev Override required by Solidity
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
    
    /**
     * @dev Get platform statistics
     */
    function getPlatformStats() external view returns (
        uint256 totalSupply_,
        uint256 maxSupply_,
        uint256 circulatingSupply_,
        uint256 currentFeeRate_,
        address feeRecipient_
    ) {
        totalSupply_ = totalSupply();
        maxSupply_ = MAX_SUPPLY;
        circulatingSupply_ = totalSupply_ - balanceOf(address(this));
        currentFeeRate_ = transferFeeRate;
        feeRecipient_ = feeRecipient;
    }
}