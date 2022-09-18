// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {IERC20} from "./utils/IERC20.sol";
import {Proxiable} from "./utils/Proxible.sol";




/// @author developeruche SOME PORTION of this code base was gotten from SMART CONTRACT PROGRAMMER YOUTUBE CHANNEL
contract StakingWithReward is Proxiable {
    /*
       ================ //
       STATE VARIABLES // 
       ============== //
     */
    IERC20 public stakingToken;
    IERC20 public rewardsToken;
    address public owner;
    uint256 public duration;
    uint256 public finishAt;
    uint256 public updatedAt;
    uint256 public rewardRate; 
    uint256 public rewardPerTokenStored;
    uint256 public minStakingPeriod;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userStakingPeriod;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    bool public isInitialize;

    /*
       ================ //
       MODIFIERS // 
       ============== //
     */

    modifier MustBeInitialized() {
        require(isInitialize, "not yet initilized");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }


    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();
        if(_account != address(0)) {
            rewards[_account] = earned((_account));
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    modifier minStakePeriodNotReached() {
        require(block.timestamp < userStakingPeriod[msg.sender], "Cannot unstake now");
        _;
    }

    /// @param _stakingToken: this is the contract address of the token that is to be staked 
    /// @param _rewardToken: this is the address of the token the user would be receiving their staking rewards in 
    /// @param _minStakePeriod: this is how long a user must stake their token before they can unstake their token
    function initialize(address _stakingToken, address _rewardToken, uint256 _minStakePeriod) public {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);
        minStakingPeriod = _minStakePeriod;
    }

    /// @notice this is the first function to be called after deployment
    /// @notice this function would set the duration on how long the staking would last
    /// @param _duration: this is a uint256 value of seconds of how long the skaing would last note this must be longer that the minstaking period 
    function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(finishAt < block.timestamp && _duration > minStakingPeriod, "reward duration not finished");
        duration = _duration;
    }

    /// @notice this is the second function that would be call after deployment after this function is called the _amount of token can be transafered to this contract address
    /// @dev this function set the amount of tokens that a staker would receive and also set the finish at and using the already set duration
    /// @param _amount: this is the total amout of token the owner would be sending into this function 
    function notifyRewardAmount(uint256 _amount) external onlyOwner updateReward(address(0)) {
        if(block.timestamp > finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint256 remainingRewards = rewardRate * (finishAt - block.timestamp);
            rewardRate = (remainingRewards + _amount) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");

        require(rewardRate * duration <= rewardsToken.balanceOf(address(this)), "reward amount > balance");

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }


    /// @notice user would call this function to stake their token
    /// @dev this function would take out the token from the user account and and send it to this contract, this function would also set the time user can und=stake their tokens
    /// @param _amount: this is the amount of token the user wishes to stake
    function stake(uint256 _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
        updateCanUnstakeTime();
    }


    /// @notice this is the function the user would call to unstake their tokens
    /// @dev this function would transfer the _amount of tokens the user wishes to withdraw 
    function unstake(uint256 _amount) external updateReward(msg.sender) minStakePeriodNotReached {
        require(_amount > 0, "amount = 0");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function lastTimeRewardApplicable() public view returns (uint256 ) {
        return _min(block.timestamp, finishAt);
    }

    /// @notice this funtioc returns the reward a user would get per token 
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply;
    }
    
    /// @notice thid function would return the tokend this user has earned overtime
    function earned(address _account) public view returns(uint256 ) {
         return (balanceOf[_account] * (
            rewardPerToken() - userRewardPerTokenPaid[_account]
          )) / 1e18 + rewards[_account];
    }

    /// @notice this function would sent the reward the user has accumulate overtime 
    /// @dev this would update the user reward first then send the reward token if the if the is one 
    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];

        if(reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }


    /// @dev this function is an internal function that would update the next time the user can unstake staked tokens 
    function updateCanUnstakeTime() internal {
        userStakingPeriod[msg.sender] = block.timestamp + minStakingPeriod;
    }

    function updateCode(address newCode) public onlyOwner MustBeInitialized  {
        updateCodeAddress(newCode);
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256 ) {
        return x <= y ? x : y;
    }
}