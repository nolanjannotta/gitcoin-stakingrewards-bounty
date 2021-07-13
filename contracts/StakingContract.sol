/*Contract Description

[] User can Stake an ERC-20 token, thereby agreeing to lockup the staked token for X time.
[] User can unstake before the lockup period expires by paying a Y% penalty fee.
[] Of the Y% Penalty, A% is burnt, B% is sent to another address (Ecosystem Fund), and (100-A-B)% remains in the contract and added to the Reward.
[] While staking, user will earn one or more ERC-20 tokens as Reward.
[] Rewards are Z% immediately harvestable, and (100-Z)% vested linearly over D days.
[] If there is more than one reward token, they will be distributed at the same rate.

Specification
When deploying the contract, the owner should be able to declare the following parameters:

[x] Deposit token contract address
[x] Reward token contract address(es)
[] Reward amount(s)
[] Reward period start time
[] Reward period end time

When deploying the contract, the owner should be able to declare the following optional parameters:

[] Maximum limit of total staked amount
[] X: Lockup Time
[] Y: Penalty (a % of his total staked amount)
[] A: % of Penalty that is Burned
[] B: % of Penalty that is sent to Ecosystem Fund
[] Ecosystem Fund Address
[] Z: % of rewards that are immediately harvestable
[] D: no. of days that non-harvestable rewards are vested for
*/
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./StakingToken.sol";







// https://docs.synthetix.io/contracts/source/contracts/stakingrewards
contract StakingRewards is ReentrancyGuard, Pausable, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    address ecosystemFund;

    IERC20[] public rewardsTokens;
    StakingToken public stakingToken;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;

    uint256 public earlyWithdrawPercent;
    uint256 public burnPercent;
    uint256 public ecosystemPercent;
    uint256 immediateHarvestPercent; 
    uint256 lockUpTime;
    uint256 public rewardPerTokenStored;

  

    uint256 startTime;
    uint256 endTime;


    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint)) addressToRewardBalance;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address[] memory _rewardsTokens,
        StakingToken _stakingToken,
        address _ecosystemFund,

        uint _earlyWithdrawFee,
        uint _burnPercentage,
        uint _ecosystemFee,

        uint _daysUntilStart, // = number of days until start
        uint _daysUntilEnd, // number of days after start
        uint _immediateHarvestPercent,
        uint _lockUpTime // in days
    ) {

        for(uint i=0; i<_rewardsTokens.length; i++) {
            address _token = _rewardsTokens[i];
            rewardsTokens.push(IERC20(_token));
        }

        stakingToken = _stakingToken;

        ecosystemFund = _ecosystemFund;

        startTime = block.timestamp + _daysUntilStart.mul(1 days); // is this right?
        endTime = startTime + _daysUntilEnd.mul(1 days);

        earlyWithdrawPercent = _earlyWithdrawFee;
        burnPercent = _burnPercentage; 
        ecosystemPercent = _ecosystemFee; 
        immediateHarvestPercent = _immediateHarvestPercent;
        lockUpTime = _lockUpTime;



    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, endTime);
    }




    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
            );
    }

    // function earned(address account) public view returns (uint256) {
    //     return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    // }

    // function getRewardForDuration() external view returns (uint256) {
    //     return rewardRate.mul(rewardsDuration);
    // }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakingToken.transferFrom(msg.sender, address(this), amount * 1 ether);
        emit Staked(msg.sender, amount);
    }

    function _earlyWithdrawPenalty(uint _amount) internal {
        _amount = _amount * 1 ether;
        // total fee amount based on how much user trying to withdraw
        //  IN WEI!!!!!
        uint feeAmount = _amount.mul(earlyWithdrawPercent).div(100);

        // Burn 
        uint burnAmount = feeAmount.mul(burnPercent).div(100);
        stakingToken.burn(burnAmount);

        // Ecosystem fee
        uint ecosystemAmount = feeAmount.mul(ecosystemPercent).div(100);
        IERC20(stakingToken).safeTransfer(ecosystemFund, ecosystemAmount); 

        // remains in contract:
        uint remains = feeAmount.sub(ecosystemAmount.add(burnAmount));
        uint _newAmount = _amount.sub(feeAmount);
      
        _totalSupply = _totalSupply.sub((_newAmount.add(remains)).div(1 ether));

        _balances[msg.sender] = _balances[msg.sender].sub(_newAmount.div(1 ether));
        IERC20(stakingToken).safeTransfer(msg.sender, _newAmount);
        emit Withdrawn(msg.sender, _newAmount);
    


        // final amount after fees
        

    }

    function withdraw(uint256 amount) public nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        if(block.timestamp < endTime) {
            _earlyWithdrawPenalty(amount);
            

        }else {
            _totalSupply = _totalSupply.sub(amount);
            _balances[msg.sender] = _balances[msg.sender].sub(amount);
            IERC20(stakingToken).safeTransfer(msg.sender, amount.mul(1 ether)); 
            emit Withdrawn(msg.sender, amount); 
        }

        
    }

    // function getReward() public nonReentrant {
    //     uint256 reward = rewards[msg.sender];
    //     if (reward > 0) {
    //         rewards[msg.sender] = 0;
    //         rewardsToken.safeTransfer(msg.sender, reward);
    //         emit RewardPaid(msg.sender, reward);
    //     }
    // }

    // function exit() external {
    //     withdraw(_balances[msg.sender]);
    //     getReward();
    // }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // function notifyRewardAmount(uint256 reward) external onlyRewardsDistribution updateReward(address(0)) {
    //     if (block.timestamp >= periodFinish) {
    //         rewardRate = reward.div(rewardsDuration);
    //     } else {
    //         uint256 remaining = periodFinish.sub(block.timestamp);
    //         uint256 leftover = remaining.mul(rewardRate);
    //         rewardRate = reward.add(leftover).div(rewardsDuration);
    //     }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
    //     uint balance = rewardsToken.balanceOf(address(this));
    //     require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

    //     lastUpdateTime = block.timestamp;
    //     periodFinish = block.timestamp.add(rewardsDuration);
    //     emit RewardAdded(reward);
    // }

    // End rewards emission earlier
    // function updatePeriodFinish(uint timestamp) external onlyOwner {
    //     periodFinish = timestamp;
    // }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    // function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
    //     require(tokenAddress != address(stakingToken), "Cannot withdraw the staking token");
    //     IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
    //     emit Recovered(tokenAddress, tokenAmount);
    // }

    // function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
    //     require(
    //         block.timestamp > periodFinish,
    //         "Previous rewards period must be complete before changing the duration for the new period"
    //     );
    //     rewardsDuration = _rewardsDuration;
    //     emit RewardsDurationUpdated(rewardsDuration);
    // }

    /* ========== MODIFIERS ========== */

    // modifier updateReward(address account) {
    //     rewardPerTokenStored = rewardPerToken();
    //     lastUpdateTime = lastTimeRewardApplicable();
    //     if (account != address(0)) {
    //         rewards[account] = earned(account);
    //         userRewardPerTokenPaid[account] = rewardPerTokenStored;
    //     }
    //     _;
    // }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);
}