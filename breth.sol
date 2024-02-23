// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';


interface ILido {
    function submit(address _referral) external payable returns (uint256);
}

interface IstETH is IERC20 {
    // Add any specific functions you might need for stETH, if any, besides what's in IERC20
}


contract brETHVault is ERC20, Ownable(msg.sender), ReentrancyGuard {
    ILido public lido;
    IstETH public stETH; // Add a state variable for the stETH token contract
    address public buybackWallet;
    uint256 public mintFeePercent = 30; // Basis points
    uint256 public redeemFeePercent = 70; // Basis points
    uint256 public totalFee;

    constructor(address _lidoAddress, address _stETHAddress, address _buybackWallet) ERC20("brETH Token", "brETH") {
        lido = ILido(_lidoAddress);
        stETH = IstETH(_stETHAddress); // Initialize the stETH token contract
        buybackWallet = _buybackWallet;
    }

    function mint() external payable nonReentrant{
        require(msg.value > 0, "Must send ETH to mint brETH");
        uint256 fee = calculateFee(msg.value, mintFeePercent);
        uint256 amountAfterFee = msg.value - fee;

        totalFee += fee;

        lido.submit{value: msg.value}(owner());
        stETH.transfer(buybackWallet, fee);
        _mint(msg.sender, amountAfterFee);
        
    }

    function redeem(uint256 brETHAmount) external nonReentrant {
        require(balanceOf(msg.sender) >= brETHAmount, "Insufficient brETH balance");
        uint256 fee = calculateFee(brETHAmount, redeemFeePercent);
        uint256 amountAfterFee = brETHAmount - fee;
        totalFee += fee;
        _burn(msg.sender, brETHAmount);
        require(stETH.transfer(msg.sender, amountAfterFee), "stETH transfer failed");
        if (fee > 0) {
            stETH.transfer(buybackWallet, fee); // Consider how you handle the fee in stETH context
        }
    }

    function checkProtocolProfits() public view returns (uint256) {
        uint256 totalStETH = stETH.balanceOf(address(this)); // This should be the balance of stETH instead
        uint256 totalBrETHSupply = totalSupply();
        if (totalStETH > totalBrETHSupply) {
            return totalStETH - totalBrETHSupply;
        }
        return 0;
    }

    function claimProtocolProfits() external onlyOwner {
        uint256 profits = checkProtocolProfits();
        require(profits > 0, "No profits to claim");
        totalFee += profits;
        stETH.transfer(msg.sender, profits); 
    }

    function calculateFee(uint256 amount, uint256 feePercent) private pure returns (uint256) {
        return amount * feePercent / 10000; // Adjust calculation for basis points
    }

    function setMintFeePercent(uint256 _mintFeePercent) external onlyOwner {
        require(_mintFeePercent >= 0 && _mintFeePercent <= 1000, "Fee must be between 0% and 10%");
        mintFeePercent = _mintFeePercent;
    }

    function setRedeemFeePercent(uint256 _redeemFeePercent) external onlyOwner {
        require(_redeemFeePercent >= 0 && _redeemFeePercent <= 1000, "Fee must be between 0% and 10%");
        redeemFeePercent = _redeemFeePercent;
    }

    function setBuybackWallet(address _buybackWallet) external onlyOwner {
        buybackWallet = _buybackWallet;
    }

    // Fallback function to accept ETH
    receive() external payable {
        revert("Send ETH through mint function");
    }
}
