// Sources flattened with hardhat v2.22.0 https://hardhat.org

// SPDX-License-Identifier: MIT

// File contracts/PenaltyStaking.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.20;

// OpenZeppelin Contracts v5.0.0 - ReentrancyGuard (inlined)
abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }
}

// OpenZeppelin v5.0.0 - IERC20 (inlined)
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// OpenZeppelin v5.0.0 - IERC20Permit (inlined)
interface IERC20Permit {
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// OpenZeppelin v5.0.0 - Address library (inlined)
library Address {
    error AddressInsufficientBalance(address account);
    error AddressEmptyCode(address target);
    error FailedInnerCall();

    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    function verifyCallResultFromTarget(address target, bool success, bytes memory returndata) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    function _revert(bytes memory returndata) private pure {
        if (returndata.length > 0) {
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// OpenZeppelin v5.0.0 - SafeERC20 (inlined)
library SafeERC20 {
    using Address for address;

    error SafeERC20FailedOperation(address token);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

/**
 * @title PenaltyStaking - Paper Hands Pay, Diamond Hands Gain
 * @author Bureau of Agent Investigations (BAI)
 * @notice Immutable staking contract where early unstakers pay penalties to remaining stakers
 */
contract PenaltyStaking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakingToken;
    uint256 public immutable lockPeriod;
    uint256 public immutable penaltyBps;
    
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MAX_PENALTY_BPS = 5000;
    
    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;
    
    struct StakeInfo {
        uint256 amount;
        uint256 stakedAt;
        uint256 rewardPerTokenPaid;
        uint256 pendingRewards;
    }
    
    mapping(address => StakeInfo) public stakes;
    
    event Staked(address indexed user, uint256 amount, uint256 unlockTime);
    event Unstaked(address indexed user, uint256 amount, uint256 penalty, bool early);
    event RewardsClaimed(address indexed user, uint256 amount);
    event PenaltyDistributed(uint256 amount, uint256 totalStaked);

    error ZeroAmount();
    error ZeroAddress();
    error InsufficientStake();
    error NoRewardsToClaim();
    error InvalidPenalty();

    constructor(address _stakingToken, uint256 _lockPeriod, uint256 _penaltyBps) {
        if (_stakingToken == address(0)) revert ZeroAddress();
        if (_penaltyBps > MAX_PENALTY_BPS) revert InvalidPenalty();
        stakingToken = IERC20(_stakingToken);
        lockPeriod = _lockPeriod;
        penaltyBps = _penaltyBps;
    }

    function earned(address account) public view returns (uint256) {
        StakeInfo storage stake = stakes[account];
        return ((stake.amount * (rewardPerTokenStored - stake.rewardPerTokenPaid)) / PRECISION) + stake.pendingRewards;
    }
    
    function isUnlocked(address account) public view returns (bool) {
        StakeInfo storage stake = stakes[account];
        if (stake.amount == 0) return true;
        return block.timestamp >= stake.stakedAt + lockPeriod;
    }
    
    function unlockTime(address account) public view returns (uint256) {
        StakeInfo storage stake = stakes[account];
        if (stake.amount == 0) return 0;
        return stake.stakedAt + lockPeriod;
    }
    
    function calculatePenalty(uint256 amount) public view returns (uint256) {
        return (amount * penaltyBps) / 10000;
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateReward(msg.sender);
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].stakedAt = block.timestamp;
        totalStaked += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount, block.timestamp + lockPeriod);
    }
    
    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        StakeInfo storage userStake = stakes[msg.sender];
        if (amount > userStake.amount) revert InsufficientStake();
        _updateReward(msg.sender);
        bool early = block.timestamp < userStake.stakedAt + lockPeriod;
        uint256 penalty = 0;
        uint256 amountAfterPenalty = amount;
        if (early) {
            penalty = calculatePenalty(amount);
            amountAfterPenalty = amount - penalty;
        }
        userStake.amount -= amount;
        totalStaked -= amount;
        if (penalty > 0 && totalStaked > 0) {
            rewardPerTokenStored += (penalty * PRECISION) / totalStaked;
            emit PenaltyDistributed(penalty, totalStaked);
        }
        stakingToken.safeTransfer(msg.sender, amountAfterPenalty);
        emit Unstaked(msg.sender, amount, penalty, early);
    }
    
    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 reward = stakes[msg.sender].pendingRewards;
        if (reward == 0) revert NoRewardsToClaim();
        stakes[msg.sender].pendingRewards = 0;
        stakingToken.safeTransfer(msg.sender, reward);
        emit RewardsClaimed(msg.sender, reward);
    }
    
    function exit() external nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];
        uint256 stakedAmount = userStake.amount;
        if (stakedAmount == 0 && userStake.pendingRewards == 0) {
            revert ZeroAmount();
        }
        _updateReward(msg.sender);
        bool early = block.timestamp < userStake.stakedAt + lockPeriod;
        uint256 penalty = 0;
        uint256 amountAfterPenalty = stakedAmount;
        if (early && stakedAmount > 0) {
            penalty = calculatePenalty(stakedAmount);
            amountAfterPenalty = stakedAmount - penalty;
        }
        uint256 pendingReward = userStake.pendingRewards;
        userStake.amount = 0;
        userStake.pendingRewards = 0;
        totalStaked -= stakedAmount;
        if (penalty > 0 && totalStaked > 0) {
            rewardPerTokenStored += (penalty * PRECISION) / totalStaked;
            emit PenaltyDistributed(penalty, totalStaked);
        }
        uint256 totalOut = amountAfterPenalty + pendingReward;
        if (totalOut > 0) {
            stakingToken.safeTransfer(msg.sender, totalOut);
        }
        if (stakedAmount > 0) {
            emit Unstaked(msg.sender, stakedAmount, penalty, early);
        }
        if (pendingReward > 0) {
            emit RewardsClaimed(msg.sender, pendingReward);
        }
    }

    function _updateReward(address account) internal {
        if (account != address(0)) {
            stakes[account].pendingRewards = earned(account);
            stakes[account].rewardPerTokenPaid = rewardPerTokenStored;
        }
    }
}