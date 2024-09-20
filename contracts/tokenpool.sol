// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./erc20.sol";

contract StakingPool {
    LToken public stakingToken;
    uint public rewardRate = 100;  // Reward tokens per block for simplicity
    uint public totalStaked;
    address public owner;

    struct Staker {
        uint amountStaked;
        uint rewardDebt;
        uint lastRewardBlock;
    }

    mapping(address => Staker) public stakers;

    event Staked(address indexed user, uint amount);
    event Unstaked(address indexed user, uint amount);
    event RewardPaid(address indexed user, uint reward);

    constructor(LToken _stakingToken) {
        stakingToken = _stakingToken;
        owner = msg.sender;
    }

    // Function to allow users to stake tokens
    function stake(uint _amount) external payable  {
        require(_amount > 0, "Cannot stake 0 tokens");
        
        Staker storage staker = stakers[msg.sender];

        // Update reward debt and staked amount for the user
        if (staker.amountStaked > 0) {
            uint pendingReward = calculatePendingReward(msg.sender);
            staker.rewardDebt += pendingReward;
        }

        stakingToken.transferFrom(msg.sender, address(this), _amount);

        staker.amountStaked += _amount;
        staker.lastRewardBlock = block.number;

        totalStaked += _amount;

        emit Staked(msg.sender, _amount);
    }

    // Function to calculate pending rewards for the user
    function calculatePendingReward(address _user) public view returns (uint) {
        Staker memory staker = stakers[_user];
        uint stakedDuration = block.number - staker.lastRewardBlock;
        uint pendingReward = (staker.amountStaked * stakedDuration * rewardRate) / 1e18;
        return pendingReward;
    }

    // Function to unstake tokens and claim rewards
    function unstake(uint _amount) external {
        Staker storage staker = stakers[msg.sender];
        require(staker.amountStaked >= _amount, "Cannot unstake more than staked");

        // Calculate rewards and transfer to the user
        uint pendingReward = calculatePendingReward(msg.sender) + staker.rewardDebt;
        staker.rewardDebt = 0;
        stakingToken.transfer(msg.sender, pendingReward);

        // Reduce staked amount and update total staked
        staker.amountStaked -= _amount;
        staker.lastRewardBlock = block.number;
        totalStaked -= _amount;

        // Transfer staked tokens back to the user
        stakingToken.transfer(msg.sender, _amount);

        emit Unstaked(msg.sender, _amount);
        emit RewardPaid(msg.sender, pendingReward);
    }

    // Function to check the pending reward of a staker
    function pendingReward(address _user) external view returns (uint) {
        return calculatePendingReward(_user) + stakers[_user].rewardDebt;
    }

    // Function to withdraw the reward without unstaking
    function claimReward() external {
        Staker storage staker = stakers[msg.sender];
        uint pendingReward = calculatePendingReward(msg.sender) + staker.rewardDebt;
        require(pendingReward > 0, "No reward to claim");

        // Reset reward debt and transfer reward to user
        staker.rewardDebt = 0;
        staker.lastRewardBlock = block.number;
        stakingToken.transfer(msg.sender, pendingReward);

        emit RewardPaid(msg.sender, pendingReward);
    }

    // Function to allow the owner to set the reward rate
    function setRewardRate(uint _rewardRate) external {
        require(msg.sender == owner, "Only the owner can set the reward rate");
        rewardRate = _rewardRate;
    }
}