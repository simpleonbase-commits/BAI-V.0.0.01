// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// OpenZeppelin Contracts v5.0.0 (utils/ReentrancyGuard.sol)
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

// OpenZeppelin Contracts v5.0.0 (token/ERC20/IERC20.sol)
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

// OpenZeppelin Contracts v5.0.0 (token/ERC20/extensions/IERC20Permit.sol)
interface IERC20Permit {
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// OpenZeppelin Contracts v5.0.0 (utils/Address.sol)
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

// OpenZeppelin Contracts v5.0.0 (token/ERC20/utils/SafeERC20.sol)
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
 * @dev This is a TEST CONTRACT for BAI token economics experimentation
 * 
 * SECURITY FEATURES:
 * - No owner/admin functions (truly immutable)
 * - ReentrancyGuard on all external state-changing functions
 * - Solidity 0.8+ for built-in overflow protection
 * - Checks-Effects-Interactions pattern throughout
 * - SafeERC20 for token transfers
 * - Input validation on all functions
 * 
 * MECHANISM:
 * - Users stake tokens with a lock period
 * - Early unstaking (before lock expires) incurs a penalty
 * - Penalties are redistributed to all remaining stakers proportionally
 * - The more paper hands exit, the richer diamond hands become
 */
contract PenaltyStaking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ CONSTANTS ============
    
    /// @notice The token being staked (immutable, set at deployment)
    IERC20 public immutable stakingToken;
    
    /// @notice Lock period in seconds (immutable)
    uint256 public immutable lockPeriod;
    
    /// @notice Early unstake penalty percentage (basis points, 10000 = 100%)
    /// @dev 2000 = 20% penalty
    uint256 public immutable penaltyBps;
    
    /// @notice Precision for reward calculations (1e18)
    uint256 private constant PRECISION = 1e18;
    
    /// @notice Maximum penalty (50% = 5000 bps) - protect users from extreme penalties
    uint256 private constant MAX_PENALTY_BPS = 5000;

    // ============ STATE ============
    
    /// @notice Total tokens currently staked
    uint256 public totalStaked;
    
    /// @notice Accumulated penalty rewards per token (scaled by PRECISION)
    uint256 public rewardPerTokenStored;
    
    /// @notice User stake info
    struct StakeInfo {
        uint256 amount;              // Amount staked
        uint256 stakedAt;            // Timestamp of stake
        uint256 rewardPerTokenPaid;  // rewardPerTokenStored at time of last action
        uint256 pendingRewards;      // Accumulated unclaimed rewards
    }
    
    /// @notice Mapping of user address to their stake info
    mapping(address => StakeInfo) public stakes;
    
    // ============ EVENTS ============
    
    event Staked(address indexed user, uint256 amount, uint256 unlockTime);
    event Unstaked(address indexed user, uint256 amount, uint256 penalty, bool early);
    event RewardsClaimed(address indexed user, uint256 amount);
    event PenaltyDistributed(uint256 amount, uint256 totalStaked);

    // ============ ERRORS ============
    
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientStake();
    error NoRewardsToClaim();
    error InvalidPenalty();

    // ============ CONSTRUCTOR ============
    
    /**
     * @notice Deploy the staking contract
     * @param _stakingToken Address of the ERC20 token to stake
     * @param _lockPeriod Lock period in seconds (e.g., 7 days = 604800)
     * @param _penaltyBps Penalty in basis points (e.g., 2000 = 20%)
     */
    constructor(
        address _stakingToken,
        uint256 _lockPeriod,
        uint256 _penaltyBps
    ) {
        if (_stakingToken == address(0)) revert ZeroAddress();
        if (_penaltyBps > MAX_PENALTY_BPS) revert InvalidPenalty();
        
        stakingToken = IERC20(_stakingToken);
        lockPeriod = _lockPeriod;
        penaltyBps = _penaltyBps;
    }

    // ============ VIEW FUNCTIONS ============
    
    /**
     * @notice Calculate current reward per token
     * @return Current accumulated reward per token (scaled by PRECISION)
     */
    function rewardPerToken() public view returns (uint256) {
        return rewardPerTokenStored;
    }
    
    /**
     * @notice Calculate pending rewards for a user
     * @param account User address
     * @return Total pending rewards (including already accumulated)
     */
    function earned(address account) public view returns (uint256) {
        StakeInfo storage stake = stakes[account];
        return (
            (stake.amount * (rewardPerTokenStored - stake.rewardPerTokenPaid)) / PRECISION
        ) + stake.pendingRewards;
    }
    
    /**
     * @notice Check if a user's stake is unlocked
     * @param account User address
     * @return True if stake is unlocked (can withdraw without penalty)
     */
    function isUnlocked(address account) public view returns (bool) {
        StakeInfo storage stake = stakes[account];
        if (stake.amount == 0) return true;
        return block.timestamp >= stake.stakedAt + lockPeriod;
    }
    
    /**
     * @notice Get unlock timestamp for a user
     * @param account User address
     * @return Timestamp when stake unlocks
     */
    function unlockTime(address account) public view returns (uint256) {
        StakeInfo storage stake = stakes[account];
        if (stake.amount == 0) return 0;
        return stake.stakedAt + lockPeriod;
    }
    
    /**
     * @notice Calculate penalty for early unstake
     * @param amount Amount being unstaked
     * @return Penalty amount that would be charged
     */
    function calculatePenalty(uint256 amount) public view returns (uint256) {
        return (amount * penaltyBps) / 10000;
    }

    // ============ EXTERNAL FUNCTIONS ============
    
    /**
     * @notice Stake tokens
     * @param amount Amount of tokens to stake
     * @dev Lock period starts/resets with each stake
     */
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        
        // Update rewards for user before changing their stake
        _updateReward(msg.sender);
        
        // Effects: Update state before external call
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].stakedAt = block.timestamp;
        totalStaked += amount;
        
        // Interaction: Transfer tokens in
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        
        emit Staked(msg.sender, amount, block.timestamp + lockPeriod);
    }
    
    /**
     * @notice Unstake tokens
     * @param amount Amount to unstake
     * @dev If unstaking before lock period, penalty is applied and distributed
     */
    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        
        StakeInfo storage userStake = stakes[msg.sender];
        if (amount > userStake.amount) revert InsufficientStake();
        
        // Update rewards before changing stake
        _updateReward(msg.sender);
        
        bool early = block.timestamp < userStake.stakedAt + lockPeriod;
        uint256 penalty = 0;
        uint256 amountAfterPenalty = amount;
        
        if (early) {
            penalty = calculatePenalty(amount);
            amountAfterPenalty = amount - penalty;
        }
        
        // Effects: Update state before external calls
        userStake.amount -= amount;
        totalStaked -= amount;
        
        // Distribute penalty to remaining stakers
        if (penalty > 0 && totalStaked > 0) {
            // Add penalty to reward pool
            rewardPerTokenStored += (penalty * PRECISION) / totalStaked;
            emit PenaltyDistributed(penalty, totalStaked);
        }
        
        // Interaction: Transfer tokens out (minus penalty)
        stakingToken.safeTransfer(msg.sender, amountAfterPenalty);
        
        emit Unstaked(msg.sender, amount, penalty, early);
    }
    
    /**
     * @notice Claim accumulated rewards (from penalties)
     * @dev Rewards come from penalties paid by early unstakers
     */
    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        
        uint256 reward = stakes[msg.sender].pendingRewards;
        if (reward == 0) revert NoRewardsToClaim();
        
        // Effects: Clear pending rewards before transfer
        stakes[msg.sender].pendingRewards = 0;
        
        // Interaction: Transfer rewards
        stakingToken.safeTransfer(msg.sender, reward);
        
        emit RewardsClaimed(msg.sender, reward);
    }
    
    /**
     * @notice Unstake all and claim rewards in one transaction
     * @dev Convenience function - penalty still applies if early
     */
    function exit() external nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];
        uint256 stakedAmount = userStake.amount;
        
        if (stakedAmount == 0 && userStake.pendingRewards == 0) {
            revert ZeroAmount();
        }
        
        // Update rewards
        _updateReward(msg.sender);
        
        bool early = block.timestamp < userStake.stakedAt + lockPeriod;
        uint256 penalty = 0;
        uint256 amountAfterPenalty = stakedAmount;
        
        if (early && stakedAmount > 0) {
            penalty = calculatePenalty(stakedAmount);
            amountAfterPenalty = stakedAmount - penalty;
        }
        
        // Get pending rewards
        uint256 pendingReward = userStake.pendingRewards;
        
        // Effects: Clear all state
        userStake.amount = 0;
        userStake.pendingRewards = 0;
        totalStaked -= stakedAmount;
        
        // Distribute penalty to remaining stakers
        if (penalty > 0 && totalStaked > 0) {
            rewardPerTokenStored += (penalty * PRECISION) / totalStaked;
            emit PenaltyDistributed(penalty, totalStaked);
        }
        
        // Interaction: Transfer everything out
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

    // ============ INTERNAL FUNCTIONS ============
    
    /**
     * @notice Update reward accounting for a user
     * @param account User address to update
     */
    function _updateReward(address account) internal {
        if (account != address(0)) {
            stakes[account].pendingRewards = earned(account);
            stakes[account].rewardPerTokenPaid = rewardPerTokenStored;
        }
    }
}