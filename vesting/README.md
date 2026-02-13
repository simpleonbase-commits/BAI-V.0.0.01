# BAI Token Vesting Contract

Ultra-secure 2-year token lock for BAItest on Base chain.

## How It Works

1. Deploy contract with beneficiary address
2. Send BAItest tokens to the contract
3. Call `recordDeposit()` to start 2-year clock
4. After 2 years, call `release()` to withdraw

## Security Guarantees

- ✅ **NO OWNER** - Nobody controls this contract
- ✅ **NO ADMIN** - Zero backdoors
- ✅ **NO EARLY UNLOCK** - Impossible before 2 years
- ✅ **IMMUTABLE** - Cannot be changed
- ✅ **HARDCODED TOKEN** - Only BAItest (0x2CA8B2b97bc0f0CcDd875dcfEff16b868A1b5BA3)
- ✅ **HARDCODED TIME** - 730 days, no exceptions

## Deployment

```bash
# Install dependencies
npm install

# Compile
npx hardhat compile

# Deploy to Base
PRIVATE_KEY=your_private_key npx hardhat run scripts/deploy.js --network base

# Verify on BaseScan
npx hardhat verify --network base <CONTRACT_ADDRESS> "<BENEFICIARY_ADDRESS>"
```

## Configuration

Edit `scripts/deploy.js` to set your beneficiary address before deploying.

Set your private key via environment variable:
```bash
export PRIVATE_KEY=your_private_key_here
```

## Contract Details

| Parameter | Value |
|-----------|-------|
| Token | BAItest (0x2CA8B2b97bc0f0CcDd875dcfEff16b868A1b5BA3) |
| Lock Duration | 730 days (2 years) |
| Network | Base (Chain ID: 8453) |

## Functions

| Function | Description |
|----------|-------------|
| `recordDeposit()` | Call after sending tokens to start the clock |
| `release()` | Withdraw tokens (only works after 2 years) |
| `isUnlocked()` | Check if lock period is over |
| `timeRemaining()` | Seconds until unlock |
| `currentBalance()` | Tokens in contract |
| `beneficiary` | Address that receives tokens |
| `unlockTime` | Timestamp when tokens unlock |
