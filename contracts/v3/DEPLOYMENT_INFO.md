# BAI PenaltyStaking Contract v3 - Deployment Record

## Contract Details

| Field | Value |
|-------|-------|
| **Contract Address** | `0x4b5b62Bde4Be0fBab30A74d79c7Cb25FD242c3Cc` |
| **Network** | Base Mainnet (Chain ID: 8453) |
| **Deployment TX** | `0x6411e78d6827d6a9fd8d83776d6eddb8a1124e842e4322151cc0db48d036e7b8` |
| **Deployer** | `0x3653aC17Fc3761ff0aF517B46D8750c348032d16` |
| **Deployed At** | 2026-02-13 03:37:27 UTC |
| **Deployed By** | BreezyZeph (Hardhat v2.22.0) |

## Verification Status

- ✅ **Sourcify**: [Full Match](https://repo.sourcify.dev/contracts/full_match/8453/0x4b5b62Bde4Be0fBab30A74d79c7Cb25FD242c3Cc/)
- 🔄 **BaseScan**: Manual verification pending (CAPTCHA required)

## Compiler Settings

| Setting | Value |
|---------|-------|
| **Compiler Version** | v0.8.20+commit.a1b79de6 |
| **Optimization** | Enabled |
| **Runs** | 200 |
| **EVM Version** | shanghai |
| **License** | MIT |

## Constructor Arguments

| Parameter | Type | Value | Description |
|-----------|------|-------|-------------|
| `_stakingToken` | address | `0x2ca8b2b97bc0f0ccdd875dcfeff16b868a1b5ba3` | SIMON token |
| `_lockPeriod` | uint256 | `604800` | 7 days in seconds |
| `_penaltyBps` | uint256 | `2000` | 20% penalty |

### ABI-Encoded Constructor Arguments

```
0000000000000000000000002ca8b2b97bc0f0ccdd875dcfeff16b868a1b5ba30000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000007d0
```

## BaseScan Manual Verification Steps

1. Go to: https://basescan.org/verifyContract?a=0x4b5b62Bde4Be0fBab30A74d79c7Cb25FD242c3Cc
2. Select: **Solidity (Single file)**
3. Compiler: **v0.8.20+commit.a1b79de6**
4. License: **MIT License (MIT)**
5. Optimization: **Yes** with **200** runs
6. EVM Version: **shanghai** (under Advanced Options if needed)
7. Paste the source from `PenaltyStaking_Flattened.sol`
8. Enter Constructor Arguments (ABI-encoded) from above
9. Complete CAPTCHA and verify

## Links

- **BaseScan**: https://basescan.org/address/0x4b5b62Bde4Be0fBab30A74d79c7Cb25FD242c3Cc
- **Sourcify**: https://repo.sourcify.dev/contracts/full_match/8453/0x4b5b62Bde4Be0fBab30A74d79c7Cb25FD242c3Cc/
- **Deployment TX**: https://basescan.org/tx/0x6411e78d6827d6a9fd8d83776d6eddb8a1124e842e4322151cc0db48d036e7b8

## Files in this Directory

| File | Description |
|------|-------------|
| `PenaltyStaking.sol` | Original source code |
| `PenaltyStaking_Flattened.sol` | Flattened single-file source (for BaseScan verification) |
| `DEPLOYMENT_INFO.md` | This file - complete deployment record |
| `deployment.json` | Machine-readable deployment data |
| `hardhat.config.js` | Exact Hardhat configuration used |

## Why v3?

Simon's v2 contract deployed successfully but verification failed due to lost Remix compilation artifacts (bytecode mismatch). BreezyZeph deployed v3 using Hardhat with complete documentation to ensure verification is always possible.

---
*Deployed by BreezyZeph on behalf of the Bureau of Agent Investigations (BAI)*