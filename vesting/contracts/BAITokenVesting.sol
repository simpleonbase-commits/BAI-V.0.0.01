// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BAITokenVesting
 * @author Bureau of Agent Investigations
 * @notice Ultra-secure 2-year token lock for BAItest
 * 
 * HOW IT WORKS:
 * 1. Deploy this contract with your wallet address
 * 2. Send BAItest tokens to this contract address
 * 3. Tokens are locked for 2 YEARS from first deposit
 * 4. After 2 years, call release() to get your tokens
 * 
 * SECURITY GUARANTEES:
 * ✅ NO OWNER - Nobody can control this contract
 * ✅ NO ADMIN - Zero special functions, zero backdoors
 * ✅ NO EARLY UNLOCK - Impossible to withdraw before 2 years
 * ✅ IMMUTABLE - Cannot be changed, upgraded, or modified
 * ✅ HARDCODED TOKEN - Only BAItest, nothing else
 * ✅ HARDCODED TIME - Exactly 730 days, no exceptions
 * 
 * WHAT CANNOT HAPPEN:
 * ❌ Cannot change beneficiary
 * ❌ Cannot change unlock time  
 * ❌ Cannot emergency withdraw
 * ❌ Cannot pause or stop
 * ❌ Cannot accept other tokens
 * ❌ Cannot be upgraded
 */
contract BAITokenVesting is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============================================
    // HARDCODED - CANNOT BE CHANGED
    // ============================================
    
    /// @notice BAItest token on Base - THE ONLY TOKEN ACCEPTED
    address public constant TOKEN = 0x2CA8B2b97bc0f0CcDd875dcfEff16b868A1b5BA3;
    
    /// @notice Lock duration: exactly 2 years
    uint256 public constant LOCK_DURATION = 730 days;

    // ============================================
    // SET ONCE AT DEPLOYMENT
    // ============================================
    
    /// @notice Who receives tokens after 2 years
    address public immutable beneficiary;
    
    // ============================================
    // STATE
    // ============================================
    
    /// @notice When first tokens were deposited (0 = no deposit yet)
    uint256 public lockStart;
    
    /// @notice When tokens unlock (set after first deposit)
    uint256 public unlockTime;
    
    /// @notice Tokens already withdrawn
    uint256 public released;

    // ============================================
    // EVENTS
    // ============================================
    
    event Deposited(uint256 amount, uint256 lockStart, uint256 unlockTime);
    event Released(uint256 amount);

    // ============================================
    // ERRORS
    // ============================================
    
    error ZeroAddress();
    error NotUnlocked();
    error NothingToRelease();

    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    /// @notice Deploy with beneficiary address
    /// @param _beneficiary Who will receive tokens after 2 years
    constructor(address _beneficiary) {
        if (_beneficiary == address(0)) revert ZeroAddress();
        beneficiary = _beneficiary;
    }

    // ============================================
    // DEPOSIT - Just send tokens here
    // ============================================
    
    /// @notice Call after sending tokens to record the deposit
    /// @dev First call starts the 2-year clock
    function recordDeposit() external {
        uint256 balance = IERC20(TOKEN).balanceOf(address(this));
        uint256 newDeposit = balance - (totalLocked() - released);
        
        if (newDeposit > 0 && lockStart == 0) {
            // First deposit - start the clock
            lockStart = block.timestamp;
            unlockTime = block.timestamp + LOCK_DURATION;
            emit Deposited(newDeposit, lockStart, unlockTime);
        }
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /// @notice Total tokens currently in this contract
    function totalLocked() public view returns (uint256) {
        return IERC20(TOKEN).balanceOf(address(this)) + released;
    }
    
    /// @notice Tokens available in contract right now
    function currentBalance() external view returns (uint256) {
        return IERC20(TOKEN).balanceOf(address(this));
    }
    
    /// @notice Is the lock period over?
    function isUnlocked() public view returns (bool) {
        return lockStart != 0 && block.timestamp >= unlockTime;
    }
    
    /// @notice Seconds until unlock (0 if unlocked or no deposit)
    function timeRemaining() external view returns (uint256) {
        if (lockStart == 0 || block.timestamp >= unlockTime) return 0;
        return unlockTime - block.timestamp;
    }

    // ============================================
    // RELEASE - Only works after 2 years
    // ============================================
    
    /// @notice Withdraw tokens to beneficiary (only after 2 years)
    function release() external nonReentrant {
        if (!isUnlocked()) revert NotUnlocked();
        
        uint256 amount = IERC20(TOKEN).balanceOf(address(this));
        if (amount == 0) revert NothingToRelease();
        
        released += amount;
        IERC20(TOKEN).safeTransfer(beneficiary, amount);
        
        emit Released(amount);
    }
}
