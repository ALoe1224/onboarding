import { network } from "hardhat";

async function main() {
  const { ethers } = await network.create();

  const contractAddress = process.env.CONTRACT_ADDRESS;

  if (!contractAddress) {
    throw new Error("CONTRACT_ADDRESSを指定してください");
  }

  const registry = await ethers.getContractAt(
    "ShareRegistry",
    contractAddress
  );

  const expectedOwners = [
    {
      tokenId: 1n,
      expected: "0x1000000000000000000000000000000000000002",
    },
    {
      tokenId: 2n,
      expected: "0x1000000000000000000000000000000000000003",
    },
  ];

  console.log("Contract:", contractAddress);
  console.log("");

  /*
   * 1. NFT所有者の確認
   */
  for (const { tokenId, expected } of expectedOwners) {
    const actualOwner = await registry.ownerOf(tokenId);

    console.log(`token ${tokenId} owner:`, actualOwner);

    if (
      ethers.getAddress(actualOwner) !==
      ethers.getAddress(expected)
    ) {
      throw new Error(
        `token ${tokenId}の所有者が一致しません`
      );
    }
  }

  console.log("NFT ownership check: OK");
  console.log("");

  /*
   * 2. 失効後もNFTが残っているか確認
   */
  const token2Record =
    await registry.getShareByTokenId(2n);

  console.log("token 2 active:", token2Record.active);
  console.log("token 2 recipient:", token2Record.recipient);

  if (token2Record.active !== false) {
    throw new Error("token 2が失効状態ではありません");
  }

  console.log("Revoked NFT remains recorded: OK");
  console.log("");

  /*
   * 3. NFT転送禁止の確認
   */
  const token2Owner = await registry.ownerOf(2n);
  const transferDestination =
    "0x1000000000000000000000000000000000000004";

  try {
    const tx = await registry.transferFrom(
      token2Owner,
      transferDestination,
      2n
    );

    await tx.wait();

    throw new Error(
      "転送が成功してしまいました"
    );
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : String(error);

    if (
      !message.includes(
        "ShareNFT transfers are not allowed"
      )
    ) {
      throw error;
    }

    console.log(
      "NFT transfer was correctly blocked"
    );
    console.log(
      "Reason: ShareNFT transfers are not allowed"
    );
  }

  console.log("");
  console.log("ERC-721 checks completed successfully");
}

main().catch((error) => {
  console.error("");
  console.error("ERC-721 check failed");
  console.error(error);
  process.exitCode = 1;
});