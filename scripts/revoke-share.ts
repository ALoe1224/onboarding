import { network } from "hardhat";

export async function revokeShare({
  contractAddress,
  watermarkId,
}: {
  contractAddress: string;
  watermarkId: string;
}) {
  const { ethers } = await network.create();
  const registry = await ethers.getContractAt("ShareRegistry", contractAddress);

  console.log("Revoking share for watermarkId:", watermarkId);
  const tx = await registry.revokeShare(watermarkId);
  await tx.wait();

  console.log("Share revoked successfully");
  console.log("Contract:", contractAddress);
  console.log("WatermarkId:", watermarkId);
  console.log("Transaction:", tx.hash);

  return { contractAddress, watermarkId, txHash: tx.hash };
}

async function main() {
  const contractAddress = process.env.CONTRACT_ADDRESS || process.env.SHARE_REGISTRY_ADDR;
  const watermarkId = process.env.WATERMARK_ID;

  if (!contractAddress || !watermarkId) {
    throw new Error("Missing required environment variables: CONTRACT_ADDRESS or SHARE_REGISTRY_ADDR, and WATERMARK_ID");
  }

  await revokeShare({ contractAddress, watermarkId });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
