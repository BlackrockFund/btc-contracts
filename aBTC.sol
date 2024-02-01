// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IBTC is IERC20{
    function burn(uint256 amount) external;
    function mint(address to, uint256 amount) external;
}

contract aBTCVault is ERC20, Ownable(msg.sender) {
    IBTC public btcToken;
    address public buybackWallet;
    uint256 public mintFeePercent = 1;  // Initial mint fee percentage
    uint256 public redeemFeePercent = 2; // Initial redeem fee percentage

    constructor(address _btcTokenAddress, address _buybackWallet) ERC20("aBTC Token", "aBTC") {
        btcToken = IBTC(_btcTokenAddress);
        buybackWallet = _buybackWallet;
    }

    function mint(uint256 btcAmount) external {
        uint256 fee = calculateFee(btcAmount, mintFeePercent);
        uint256 amountAfterFee = btcAmount - fee;
        btcToken.transferFrom(address(msg.sender), address(this), btcAmount);
        btcToken.burn(btcAmount);
        _mint(msg.sender, amountAfterFee);
        _mint(buybackWallet, fee);
    }

    function redeem(uint256 abtcAmount) external {
        uint256 fee = calculateFee(abtcAmount, redeemFeePercent);
        uint256 amountAfterFee = abtcAmount - fee;

        _burn(msg.sender, abtcAmount);
        btcToken.mint(msg.sender, amountAfterFee);
        _mint(buybackWallet, fee);
    }

    function calculateFee(uint256 amount, uint256 feePercent) private pure returns (uint256) {
        return amount * feePercent / 100;
    }

    function setMintFeePercent(uint256 _mintFeePercent) external onlyOwner {
        require(_mintFeePercent >= 0 && _mintFeePercent <= 10, "Fee must be between 0% and 10%");
        mintFeePercent = _mintFeePercent;
    }

    function setRedeemFeePercent(uint256 _redeemFeePercent) external onlyOwner {
        require(_redeemFeePercent >= 0 && _redeemFeePercent <= 10, "Fee must be between 0% and 10%");
        redeemFeePercent = _redeemFeePercent;
    }

    function setBuybackWallet(address _buybackWallet) external onlyOwner {
        buybackWallet = _buybackWallet;
    }

    // Additional functions and safety checks can be added here.
}
