// SPDX-License-Identifier: MIT
// Flattened contract for BaseScan verification
// Deployed to Base: 0xa3769D111e493289e6d98D7791E286d847b4d294

pragma solidity ^0.8.20;

// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)
abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;
    error ReentrancyGuardReentrantCall();
    constructor() { _status = NOT_ENTERED; }
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }
    function _nonReentrantBefore() private {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
    }
    function _nonReentrantAfter() private { _status = NOT_ENTERED; }
    function _reentrancyGuardEntered() internal view returns (bool) { return _status == ENTERED; }
}

// OpenZeppelin IERC20
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

// OpenZeppelin SafeERC20
library Address {
    error AddressInsufficientBalance(address account);
    error AddressEmptyCode(address target);
    error FailedInnerCall();
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) revert AddressInsufficientBalance(address(this));
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert FailedInnerCall();
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) revert AddressInsufficientBalance(address(this));
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }
    function verifyCallResultFromTarget(address target, bool success, bytes memory returndata) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            if (returndata.length == 0 && target.code.length == 0) revert AddressEmptyCode(target);
            return returndata;
        }
    }
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) _revert(returndata);
        return returndata;
    }
    function _revert(bytes memory returndata) private pure {
        if (returndata.length > 0) {
            assembly { let returndata_size := mload(returndata) revert(add(32, returndata), returndata_size) }
        } else {
            revert FailedInnerCall();
        }
    }
}

library SafeERC20 {
    using Address for address;
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));
        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));
        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) revert SafeERC20FailedOperation(address(token));
    }
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

/**
 * @title PenaltyStaking
 * @notice Immutable staking contract with penalty redistribution
 * @dev Paper hands pay 20% penalty -> Diamond hands earn rewards
 * 
 * SECURITY FEATURES:
 * - ReentrancyGuard on all state-changing functions
 * - SafeERC20 for all token transfers
 * - No owner/admin functions (truly immutable)
 * - Solidity 0.8+ overflow protection
 * 
 * Deployed to Base: 0xa3769D111e493289e6d98D7791E286d847b4d294
 */
contract PenaltyStaking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Immutable parameters (set once at deployment)
    IERC20 public immutable stakingToken;
    uint256 public immutable lockPeriod;
    uint256 public immutable penaltyBps; // basis points (2000 = 20%)

    // Staker info
    struct StakeInfo {
        uint256 amount;
        uint256 stakeTime;
        uint256 rewardDebt; // For reward calculation
    }

    mapping(address => StakeInfo) public stakes;
    
    // Global state
    uint256 public totalStaked;
    uint256 public accRewardPerShare; // Accumulated rewards per share (scaled by 1e18)
    uint256 private constant PRECISION = 1e18;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 penalty, bool early);
    event RewardsClaimed(address indexed user, uint256 amount);
    event PenaltyDistributed(uint256 amount);

    constructor(address _stakingToken, uint256 _lockPeriod, uint256 _penaltyBps) {
        require(_stakingToken != address(0), "Invalid token");
        require(_penaltyBps <= 5000, "Penalty too high"); // Max 50%
        
        stakingToken = IERC20(_stakingToken);
        lockPeriod = _lockPeriod;
        penaltyBps = _penaltyBps;
    }

    /**
     * @notice Stake tokens
     * @param amount Amount to stake
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        
        // Claim any pending rewards first
        _claimRewards(msg.sender);
        
        // Transfer tokens from user
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update stake info
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].stakeTime = block.timestamp;
        stakes[msg.sender].rewardDebt = (stakes[msg.sender].amount * accRewardPerShare) / PRECISION;
        
        totalStaked += amount;
        
        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake tokens (penalty if early)
     */
    function unstake() external nonReentrant {
        StakeInfo storage info = stakes[msg.sender];
        require(info.amount > 0, "Nothing staked");
        
        // Claim any pending rewards first
        _claimRewards(msg.sender);
        
        uint256 amount = info.amount;
        uint256 penalty = 0;
        bool early = block.timestamp < info.stakeTime + lockPeriod;
        
        if (early) {
            // Calculate penalty
            penalty = (amount * penaltyBps) / 10000;
            
            // Distribute penalty to remaining stakers
            if (totalStaked > amount && penalty > 0) {
                accRewardPerShare += (penalty * PRECISION) / (totalStaked - amount);
                emit PenaltyDistributed(penalty);
            }
        }
        
        // Update state before transfer
        totalStaked -= amount;
        info.amount = 0;
        info.stakeTime = 0;
        info.rewardDebt = 0;
        
        // Transfer tokens back (minus penalty)
        stakingToken.safeTransfer(msg.sender, amount - penalty);
        
        emit Unstaked(msg.sender, amount, penalty, early);
    }

    /**
     * @notice Claim accumulated rewards without unstaking
     */
    function claimRewards() external nonReentrant {
        _claimRewards(msg.sender);
    }

    /**
     * @notice Internal reward claim logic
     */
    function _claimRewards(address user) internal {
        StakeInfo storage info = stakes[user];
        if (info.amount == 0) return;
        
        uint256 pending = (info.amount * accRewardPerShare) / PRECISION - info.rewardDebt;
        
        if (pending > 0) {
            info.rewardDebt = (info.amount * accRewardPerShare) / PRECISION;
            stakingToken.safeTransfer(user, pending);
            emit RewardsClaimed(user, pending);
        }
    }

    // View functions
    function pendingRewards(address user) external view returns (uint256) {
        StakeInfo storage info = stakes[user];
        if (info.amount == 0) return 0;
        return (info.amount * accRewardPerShare) / PRECISION - info.rewardDebt;
    }

    function timeUntilUnlock(address user) external view returns (uint256) {
        StakeInfo storage info = stakes[user];
        if (info.amount == 0) return 0;
        uint256 unlockTime = info.stakeTime + lockPeriod;
        if (block.timestamp >= unlockTime) return 0;
        return unlockTime - block.timestamp;
    }

    function isLocked(address user) external view returns (bool) {
        StakeInfo storage info = stakes[user];
        if (info.amount == 0) return false;
        return block.timestamp < info.stakeTime + lockPeriod;
    }
}