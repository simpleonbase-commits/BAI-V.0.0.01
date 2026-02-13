const hre = require("hardhat");

async function main() {
  // SET YOUR BENEFICIARY ADDRESS HERE
  const BENEFICIARY = "0x3653aC17Fc3761ff0aF517B46D8750c348032d16";
  
  console.log("Deploying BAITokenVesting...");
  console.log("Beneficiary:", BENEFICIARY);
  console.log("Lock Duration: 2 years (730 days)");
  console.log("Token: BAItest (0x2CA8B2b97bc0f0CcDd875dcfEff16b868A1b5BA3)");
  console.log("");
  
  const BAITokenVesting = await hre.ethers.getContractFactory("BAITokenVesting");
  const vesting = await BAITokenVesting.deploy(BENEFICIARY);
  await vesting.waitForDeployment();
  
  const address = await vesting.getAddress();
  
  console.log("✅ BAITokenVesting deployed to:", address);
  console.log("");
  console.log("NEXT STEPS:");
  console.log("1. Send BAItest tokens to:", address);
  console.log("2. Call recordDeposit() to start the 2-year lock");
  console.log("3. After 2 years, call release() to withdraw");
  console.log("");
  console.log("Verify on BaseScan:");
  console.log(`npx hardhat verify --network base ${address} "${BENEFICIARY}"`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
