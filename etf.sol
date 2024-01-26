// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

interface IBTC {
     function claimtokenRebase(address _address, uint256 amount) external;
}

interface Itoken is IERC20 {
    function decimals() external view returns(uint256);
}

contract ETF is ERC20("ETF", "ETF"), Ownable(msg.sender) , ReentrancyGuard{ 
    
    
    struct UserInfo  {
        uint256 totalbonded;
        uint256 finalInteractionBlock;
        uint256 VestTime;
    }

    Itoken public BondToken;
    IBTC BTC;
    constructor(address _BTC, address _Bondtoken) {
        _mint(msg.sender, 0 * 10 ** decimals());
        _setceil(0e18);
        BTC = IBTC(_BTC);
        BondToken = Itoken(_Bondtoken);
    }
    mapping(address => UserInfo) public userInfo;
    using SafeERC20 for Itoken;
    using SafeMath for uint256;



    uint256 public bondPrice = 1000;
    uint256 public bondCap = 0;
    uint256 public maxperTX = 300e18;
    uint256 public vestingTime = 5 days;
    bool public bondOpen = false;
   


    function burn(uint256 _amount) external  {
        _burn(msg.sender, _amount);
    }

    function setceil(uint256 _bondCap) external onlyOwner {
        bondCap = _bondCap;
    }

    function _setceil(uint256 _bondCap) internal {
        bondCap = _bondCap;
    }

    
    function setbondPrice(uint256 _bondPrice) external onlyOwner {
       
        bondPrice = _bondPrice;
    }

    function setvestingTime(uint256 _period) external onlyOwner {
        require(_period >= 0 days &&_period <=30 days);
        vestingTime = _period;
    }

    function canclaimTokens(address _address) external view returns(uint256) {
        uint256 durationPass = block.timestamp.sub(userInfo[_address].finalInteractionBlock);
        uint256 canclaim;
        if (durationPass >= userInfo[_address].VestTime){
            canclaim = userInfo[_address].totalbonded;
        }
        else {
            canclaim = userInfo[_address].totalbonded.mul(durationPass).div(userInfo[_address].VestTime);
        }
        return canclaim;
    }


    function setOpenbond(bool _bondOpen) external onlyOwner {
        bondOpen = _bondOpen;
    }

    function setMAXtx(uint256 _max) external onlyOwner {
        maxperTX = _max;
    }

    function recoverTreasuryTokens() external onlyOwner {
        BondToken.safeTransfer(owner(), BondToken.balanceOf(address(this)));
    }


    function bond(uint256 _amount) external nonReentrant {

        require(_amount <= maxperTX, "max");
        require(bondOpen, "bnot opened");
        require(BondToken.balanceOf(msg.sender) >= _amount, "BondToken b too low");
        uint256 _amountin = _amount.mul(10**18).div(10**BondToken.decimals());
        uint256 amountOut = _amountin.mul(1000).div(bondPrice);
        
        require(this.totalSupply().add(amountOut) <= bondCap, "over bond cap");
        userInfo[msg.sender].totalbonded = userInfo[msg.sender].totalbonded.add(amountOut);
        userInfo[msg.sender].finalInteractionBlock = block.timestamp;
        userInfo[msg.sender].VestTime = vestingTime;

        _mint(address(this), amountOut);
        BondToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    function claim() external nonReentrant {

        require(userInfo[msg.sender].totalbonded > 0, "no bond");
        uint256 durationPass = block.timestamp.sub(userInfo[msg.sender].finalInteractionBlock);
        uint256 canclaim;
        if (durationPass >= userInfo[msg.sender].VestTime){
            canclaim = userInfo[msg.sender].totalbonded;
            userInfo[msg.sender].VestTime = 0;
        }
        else {
            canclaim = userInfo[msg.sender].totalbonded.mul(durationPass).div(userInfo[msg.sender].VestTime);
            userInfo[msg.sender].VestTime = userInfo[msg.sender].VestTime.sub(durationPass);
            
        }
        userInfo[msg.sender].totalbonded = userInfo[msg.sender].totalbonded.sub(canclaim);
        userInfo[msg.sender].finalInteractionBlock = block.timestamp;

        this.burn(canclaim);
        BTC.claimtokenRebase(msg.sender, canclaim);
    }

    function remainingbondableTokens() external view returns(uint256){
        
        return bondCap.sub(this.totalSupply());
    }

    function remainingVestedTime(address _address) external view returns(uint256){
        uint256 durationPass = block.timestamp.sub(userInfo[_address].finalInteractionBlock);
        if (durationPass >= userInfo[_address].VestTime){
            return 0;
        }
        else {
            return userInfo[_address].VestTime.sub(durationPass);
        }
        
    }

}