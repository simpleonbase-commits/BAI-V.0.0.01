require("@nomicfoundation/hardhat-toolbox");

// Load environment variables (for deployment)
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000001";
const BASESCAN_API_KEY = process.env.BASESCAN_API_KEY || "2HCVP5PW6P3N16WH49IT2Y9JU8GSDJRS7N";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 8453  // Base chain ID for local testing
    },
    base: {
      url: "https://mainnet.base.org",
      chainId: 8453,
      accounts: [PRIVATE_KEY]
    },
    baseSepolia: {
      url: "https://sepolia.base.org",
      chainId: 84532,
      accounts: [PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: {
      base: BASESCAN_API_KEY,
      baseSepolia: BASESCAN_API_KEY
    },
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        }
      }
    ]
  }
};
