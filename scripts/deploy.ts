import { network } from "hardhat";

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const contractName = "MyToken";
  const constructorArgs: unknown[] = [1000n * 10n ** 18n];

  const { ethers } = await network.create();

  console.log(`Deploying ${contractName}...`);

  const [deployer] = await ethers.getSigners();

  console.log("Deploying with account:", deployer.address);
  console.log(
    "Balance:",
    (await ethers.provider.getBalance(deployer.address)).toString()
  );

  const ContractFactory = await ethers.getContractFactory(contractName);
  const contract = await ContractFactory.deploy(...constructorArgs);

  const tx = contract.deploymentTransaction();
  console.log("Transaction sent:", tx?.hash);

  console.log("Waiting 3 seconds before checking receipt...");
  await sleep(3000);

  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log(`${contractName} deployed to:`, address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});