import { network } from "hardhat";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

async function main() {
  // --networkで指定されたネットワークへ接続
  const { ethers, networkName } = await network.create();

  const contractName = "ShareRegistry";

  console.log(`Deploying ${contractName} to ${networkName}...`);

  // デプロイに使用するアカウント
  const [deployer] = await ethers.getSigners();

  console.log("Deploying with account:", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");

  // コントラクトをデプロイ
  const contract = await ethers.deployContract(contractName);

  console.log("Waiting for deployment...");

  await contract.waitForDeployment();

  const contractAddress = await contract.getAddress();
  const deploymentTx = contract.deploymentTransaction();

  console.log(`${contractName} deployed successfully`);
  console.log("Network:", networkName);
  console.log("Contract address:", contractAddress);

  if (deploymentTx !== null) {
    console.log("Transaction hash:", deploymentTx.hash);
  }

  // デプロイ情報をJSONファイルへ保存
  const deploymentDirectory = path.resolve("deployments");
  const deploymentFile = path.join(
    deploymentDirectory,
    `${networkName}.json`
  );

  await mkdir(deploymentDirectory, { recursive: true });

  const deploymentData = {
    network: networkName,
    contractName,
    contractAddress,
    deployer: deployer.address,
    transactionHash: deploymentTx?.hash ?? null,
    deployedAt: new Date().toISOString(),
  };

  await writeFile(
    deploymentFile,
    JSON.stringify(deploymentData, null, 2) + "\n",
    "utf8"
  );

  console.log("Deployment information saved to:", deploymentFile);
}

main().catch((error) => {
  console.error("Deployment failed:");
  console.error(error);
  process.exitCode = 1;
});