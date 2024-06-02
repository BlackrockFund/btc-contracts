// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IHF is ERC20, Ownable(msg.sender) {
    // Mapping to track cooldowns for debasing a wallet
    mapping(address => uint256) public lastDebaseTime;
    mapping(address => bool) public debaseExclusionList;

    uint256 public constant DEBASE_PERCENTAGE = 5; // 0.05% as a factor of 10000
    uint256 public constant INITIAL_DEBASE_PERCENTAGE = 1; // 0.01% as a factor of 10000
    uint256 public constant DEBASE_COOLDOWN = 30 minutes ;

    event Debased(address indexed target, uint256 amountBurned);
    event ExcludeFromDebase(address account, bool exclude);
    constructor() ERC20("IHF Smart Debase Token", "IHF") {
        _mint(msg.sender, 535000 * 10**decimals()); // Mint initial supply
    }

    // Exclude LP and CEX wallets from debase
    function excludeFromDebase(address account, bool exclude) external onlyOwner {
        debaseExclusionList[account] = exclude;
        emit ExcludeFromDebase(account, exclude);
    }

    // Debase a target wallet
    function debase(address target) external {
        require(!debaseExclusionList[target], "Target is excluded from debase");

        uint256 currentTime = block.timestamp;
        uint256 lastDebase = lastDebaseTime[target];

        uint256 debaseCooldown = DEBASE_COOLDOWN;
        uint256 debasePercentage = (lastDebase == 0) ? INITIAL_DEBASE_PERCENTAGE : DEBASE_PERCENTAGE;

        require(currentTime >= lastDebase + debaseCooldown, "Debase cooldown period has not passed");

        uint256 balance = balanceOf(target);
        uint256 debaseAmount = (balance * debasePercentage) / 10000; // Adjusted to factor of 10000

        require(debaseAmount > 0, "Debase amount must be greater than zero");

        _burn(target, debaseAmount);

        lastDebaseTime[target] = currentTime;
        emit Debased(target, debaseAmount);
    }

    // Optional: Implement UI functions to view cooldowns and debase information
    function getLastDebaseTime(address account) external view returns (uint256) {
        return lastDebaseTime[account];
    }

    function isExcludedFromDebase(address account) external view returns (bool) {
        return debaseExclusionList[account];
    }
}
