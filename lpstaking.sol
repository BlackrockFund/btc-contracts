

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

interface token is IERC20 {
    function mint(address recipient, uint256 _amount) external;
    function burn(uint256 _amount) external ;
    function claimtokenRebase(address _address, uint256 amount) external;
}

contract _401k2 is Ownable(msg.sender),ReentrancyGuard {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {

    
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt;
        uint256 USDCrewardDebt; // Reward debt. See explanation below.
        uint256 lastDepositTime; // Timestamp of the last deposit
        //
        // We do some fancy math here. Basically, any point in time, the amount of BTCs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accBTCPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accBTCPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 totalToken;
        uint256 allocPoint;       // How many allocation points assigned to this pool. BTCs to distribute per block.
        uint256 lastRewardTime;  // Last block time that BTCs distribution occurs.
        uint256 accBTCPerShare; // Accumulated BTCs per share, times 1e12. See below.
        uint256 accUSDCPerShare; // Accumulated BTCs per share, times 1e12. See below.
    }

    token public BTC = token(0xbD6323A83b613F668687014E8A5852079494fB68);
    token public USDC = token(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // BTC tokens created per block.
    uint256 public BTCPerSecond;
    uint256 public USDCPerSecond;

    uint256 public totalBTCdistributed = 0;
    uint256 public USDCdistributed = 0;

    // set a max BTC per second, which can never be higher than 1 per second
    uint256 public constant maUSDCPerSecond = 1e20;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block time when BTC mining starts.
    uint256 public immutable startTime;

    bool public withdrawable = false;
    uint256 public totalburn = 0;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        uint256 _BTCPerSecond,
        uint256 _USDCPerSecond,
        uint256 _startTime
    ) {

        BTCPerSecond = _BTCPerSecond;
        USDCPerSecond = _USDCPerSecond;
        startTime = _startTime;
    }

    function openWithdraw() external onlyOwner{
        withdrawable = true;
    }

    function supplyRewards(uint256 _amount) external onlyOwner {
        totalBTCdistributed = totalBTCdistributed.add(_amount);
        BTC.transferFrom(msg.sender, address(this), _amount);
    }
    
    function closeWithdraw() external onlyOwner{
        withdrawable = false;
    }

            // Update the given pool's BTC allocation point. Can only be called by the owner.
    function increaseAllocation(uint256 _pid, uint256 _allocPoint) internal {

        massUpdatePools();

        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo[_pid].allocPoint = poolInfo[_pid].allocPoint.add(_allocPoint);
    }
    
    function decreaseAllocation(uint256 _pid, uint256 _allocPoint) internal {

        massUpdatePools();

        totalAllocPoint = totalAllocPoint.sub(_allocPoint);
        poolInfo[_pid].allocPoint = poolInfo[_pid].allocPoint.sub(_allocPoint);
    }

   
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Changes BTC token reward per second, with a cap of maUSDC per second
    // Good practice to update pools without messing up the contract
    function setBTCPerSecond(uint256 _BTCPerSecond) external onlyOwner {
        require(_BTCPerSecond <= maUSDCPerSecond, "setBTCPerSecond: too many BTCs!");

        // This MUST be done or pool rewards will be calculated with new BTC per second
        // This could unfairly punish small pools that dont have frequent deposits/withdraws/harvests
        massUpdatePools(); 

        BTCPerSecond = _BTCPerSecond;
    }

    function setUSDCPerSecond(uint256 _USDCPerSecond) external onlyOwner {
        require(_USDCPerSecond <= maUSDCPerSecond, "setBTCPerSecond: too many BTCs!");

        // This MUST be done or pool rewards will be calculated with new BTC per second
        // This could unfairly punish small pools that dont have frequent deposits/withdraws/harvests
        massUpdatePools(); 

        USDCPerSecond = _USDCPerSecond;
    }


    function checkForDuplicate(IERC20 _lpToken) internal view {
        uint256 length = poolInfo.length;
        for (uint256 _pid = 0; _pid < length; _pid++) {
            require(poolInfo[_pid].lpToken != _lpToken, "add: pool already exists!!!!");
        }

    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken) external onlyOwner {

        checkForDuplicate(_lpToken); // ensure you cant add duplicate pools

        massUpdatePools();

        uint256 lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            totalToken: 0,
            allocPoint: _allocPoint,
            lastRewardTime: lastRewardTime,
            accBTCPerShare: 0,
            accUSDCPerShare: 0
        }));
    }

    // Update the given pool's BTC allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint) external onlyOwner {

        massUpdatePools();

        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }




    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        _from = _from > startTime ? _from : startTime;
        if (_to < startTime) {
            return 0;
        }
        return _to - _from;
    }

    // View function to see pending BTCs on frontend.
    function pendingBTC(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBTCPerShare = pool.accBTCPerShare;
        uint256 lpSupply = pool.totalToken;
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0 && totalAllocPoint != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 BTCReward = multiplier.mul(BTCPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            accBTCPerShare = accBTCPerShare.add(BTCReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accBTCPerShare).div(1e12).sub(user.rewardDebt);
    }

    function pendingUSDC(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accUSDCPerShare = pool.accUSDCPerShare;
        uint256 lpSupply = pool.totalToken;
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0 && totalAllocPoint != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 USDCReward = multiplier.mul(USDCPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            accUSDCPerShare = accUSDCPerShare.add(USDCReward.mul(1e12).div(lpSupply));
        }
        return (user.amount.mul(accUSDCPerShare).div(1e12).sub(user.USDCrewardDebt)).div(1e12);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.totalToken;
        if (lpSupply == 0 ||  totalAllocPoint == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        uint256 BTCReward = multiplier.mul(BTCPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
        uint256 USDCReward = multiplier.mul(USDCPerSecond).mul(pool.allocPoint).div(totalAllocPoint);

        pool.accBTCPerShare = pool.accBTCPerShare.add(BTCReward.mul(1e12).div(lpSupply));
        pool.accUSDCPerShare = pool.accUSDCPerShare.add(USDCReward.mul(1e12).div(lpSupply));
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for BTC allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accBTCPerShare).div(1e12).sub(user.rewardDebt);
        uint256 USDCpending = user.amount.mul(pool.accUSDCPerShare).div(1e12).sub(user.USDCrewardDebt);

        user.amount = user.amount.add(_amount);
        user.lastDepositTime = block.timestamp;
        pool.totalToken = pool.totalToken.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accBTCPerShare).div(1e12);
        user.USDCrewardDebt = user.amount.mul(pool.accUSDCPerShare).div(1e12);
        USDCpending = USDCpending.div(1e12);
        if(pending > 0 || USDCpending >0) {
            BTC.claimtokenRebase(msg.sender, pending);
            USDC.transfer(msg.sender, USDCpending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);

        emit Deposit(msg.sender, _pid, _amount);
    }

    function checkFeeUser(uint256 _pid) public view returns(uint256) {
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (block.timestamp < user.lastDepositTime + 2 days) {
                return 10;
        }
        else 
        return 0;
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {  
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount >= _amount, "withdraw: not good");
        require(withdrawable, "withdraw not opened");

        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accBTCPerShare).div(1e12).sub(user.rewardDebt);
        uint256 USDCpending = user.amount.mul(pool.accUSDCPerShare).div(1e12).sub(user.USDCrewardDebt);
        USDCpending = USDCpending.div(1e12);

        user.amount = user.amount.sub(_amount);
        pool.totalToken = pool.totalToken.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accBTCPerShare).div(1e12);
        user.USDCrewardDebt = user.amount.mul(pool.accUSDCPerShare).div(1e12);

        uint256 amountOut = _amount;
        uint256 fee = 0;

        if (block.timestamp < user.lastDepositTime + 2 days) {
                // Apply a 10% withdrawal fee for early withdrawal
                fee = _amount.mul(10).div(100);
                amountOut = _amount.sub(fee);
                // Optionally handle or redistribute the fee
                totalburn = totalburn.add(fee);
        }
        else {
            if(pending > 0 || USDCpending > 0) {
                BTC.claimtokenRebase(msg.sender, pending);
                USDC.transfer(msg.sender, USDCpending);
            }
        }
        token(address(pool.lpToken)).transfer(address(msg.sender), amountOut);
        
        emit Withdraw(msg.sender, _pid, amountOut);
    }

    function updateRewards(token _BTC, token _USDC) external onlyOwner {
        USDC = _USDC;
        BTC = _BTC;
    }

    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
       
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        pool.totalToken = pool.totalToken.sub(user.amount);

        user.amount = 0;
        user.rewardDebt = 0;
        user.USDCrewardDebt = 0;

        emit EmergencyWithdraw(msg.sender, _pid, user.amount);


    }
}
