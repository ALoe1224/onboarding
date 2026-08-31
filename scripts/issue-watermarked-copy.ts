import { network } from "hardhat";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { createReadStream } from "node:fs";
import {
  access,
  mkdir,
  readFile,
  rename,
  writeFile,
} from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";

import { createWatermarkId } from "./create-watermark-id.js";

const execFileAsync = promisify(execFile);

type IssueConfig = {
  inputFile: string;
  recipient: string;
  keyFile: string;
  watermarkedDirectory: string;
  resultsDirectory: string;
  strength: number;
};

type DetectionMatch = {
  key?: string;
  pos?: string;
  bits?: string;
  quality?: number;
  error?: number;
  rating?: number;
  type?: string;
  speed?: number;
};

type DetectionResult = {
  length?: string;
  matches?: DetectionMatch[];
};

async function calculateSha256(filePath: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const hash = createHash("sha256");
    const input = createReadStream(filePath);

    input.on("data", (chunk) => {
      hash.update(chunk);
    });

    input.on("error", reject);

    input.on("end", () => {
      resolve(`0x${hash.digest("hex")}`);
    });
  });
}

async function waitForSuccessfulTransaction(
  tx: any,
  operationName: string
) {
  const receipt = await tx.wait();

  if (!receipt) {
    throw new Error(`${operationName}: receiptを取得できませんでした`);
  }

  if (receipt.status !== 1) {
    throw new Error(`${operationName}: transactionが失敗しました`);
  }

  return receipt;
}

async function main() {
  /*
   * Hardhatネットワークへ接続
   */
  const { ethers, networkName } = await network.create();

  console.log("Network:", networkName);

  /*
   * 設定ファイルを読み込む
   */
  const configPath = path.resolve("config/issue.json");

  const config = JSON.parse(
    await readFile(configPath, "utf8")
  ) as IssueConfig;

  const inputFile = path.resolve(config.inputFile);
  const keyFile = path.resolve(config.keyFile);
  const watermarkedDirectory = path.resolve(
    config.watermarkedDirectory
  );
  const resultsDirectory = path.resolve(
    config.resultsDirectory
  );

  await access(inputFile);
  await access(keyFile);

  if (!ethers.isAddress(config.recipient)) {
    throw new Error(
      `recipientが不正です: ${config.recipient}`
    );
  }

  const recipient = ethers.getAddress(config.recipient);

  /*
   * deployments/gethLocal.jsonからShareRegistryのアドレスを取得
   */
  const deploymentPath = path.resolve(
    "deployments",
    `${networkName}.json`
  );

  const deployment = JSON.parse(
    await readFile(deploymentPath, "utf8")
  );

  const contractAddress =
    deployment.contractAddress || deployment.address;

  if (!contractAddress) {
    throw new Error(
      `${deploymentPath}にcontractAddressがありません`
    );
  }

  if (!ethers.isAddress(contractAddress)) {
    throw new Error(
      `コントラクトアドレスが不正です: ${contractAddress}`
    );
  }

  const contractCode =
    await ethers.provider.getCode(contractAddress);

  if (contractCode === "0x") {
    throw new Error(
      `コントラクトが存在しません: ${contractAddress}`
    );
  }

  /*
   * 元音源のSHA-256を自動計算
   */
  const workHash = await calculateSha256(inputFile);

  console.log("Input file:", inputFile);
  console.log("workHash:", workHash);

  if (!ethers.isHexString(workHash, 32)) {
    throw new Error("workHashがbytes32ではありません");
  }

  /*
   * 共有ごとに32バイトの乱数を生成
   */
  const shareSalt = ethers.hexlify(
    ethers.randomBytes(32)
  );

  console.log("shareSalt:", shareSalt);

  /*
   * 128ビットwatermarkIdを生成
   */
  const parentTokenIdText = process.env.PARENT_TOKEN_ID ?? "0";
  if (!/^\d+$/.test(parentTokenIdText)) {
    throw new Error(`PARENT_TOKEN_IDが不正です: ${parentTokenIdText}`);
  }
  const parentTokenId = BigInt(parentTokenIdText);

  const watermarkId = createWatermarkId(
    workHash,
    recipient,
    shareSalt,
    parentTokenId
  );

  if (!ethers.isHexString(watermarkId, 16)) {
    throw new Error(
      "watermarkIdが16バイトではありません"
    );
  }

  // watermarkCommitment を生成 (keccak256(watermarkId))
  const watermarkCommitment = ethers.keccak256(watermarkId);

  const audiowmarkMessage = watermarkId
    .slice(2)
    .toLowerCase();

  console.log("watermarkId:", watermarkId);
  console.log("watermarkCommitment:", watermarkCommitment);
  console.log("parentTokenId:", parentTokenId);
  console.log(
    "Audiowmark message:",
    audiowmarkMessage
  );

  /*
   * 出力ファイル名を生成
   */
  await mkdir(watermarkedDirectory, {
    recursive: true,
  });

  await mkdir(resultsDirectory, {
    recursive: true,
  });

  const inputName = path.parse(inputFile).name;

  const temporaryAudioFile = path.join(
    watermarkedDirectory,
    `.${inputName}_${audiowmarkMessage}.tmp.wav`
  );

  const finalAudioFile = path.join(
    watermarkedDirectory,
    `${inputName}_${audiowmarkMessage}.wav`
  );

  const detectionResultFile = path.join(
    resultsDirectory,
    `${inputName}_${audiowmarkMessage}_detect.json`
  );

  const issuanceResultFile = path.join(
    resultsDirectory,
    `${inputName}_${audiowmarkMessage}_issuance.json`
  );

  /*
   * Audiowmarkで一時ファイルへ埋め込み
   */
  console.log("Embedding watermark...");

  await execFileAsync(
    "audiowmark",
    [
      "add",
      "--key",
      keyFile,
      "--strength",
      String(config.strength),
      inputFile,
      temporaryAudioFile,
      audiowmarkMessage,
    ],
    {
      maxBuffer: 20 * 1024 * 1024,
    }
  );

  await access(temporaryAudioFile);

  console.log(
    "Temporary audio:",
    temporaryAudioFile
  );

  /*
   * 同じ鍵で自己検出
   */
  console.log("Detecting watermark...");

  await execFileAsync(
    "audiowmark",
    [
      "get",
      "--key",
      keyFile,
      "--json",
      detectionResultFile,
      temporaryAudioFile,
    ],
    {
      maxBuffer: 20 * 1024 * 1024,
    }
  );

  const detectionResult = JSON.parse(
    await readFile(detectionResultFile, "utf8")
  ) as DetectionResult;

  const matches = Array.isArray(
    detectionResult.matches
  )
    ? detectionResult.matches
    : [];

  /*
   * 先頭候補やスコアではなく、32桁全体が完全一致した候補を探す
   */
  const exactMatches = matches.filter(
    (match) =>
      typeof match.bits === "string" &&
      match.bits.toLowerCase() ===
        audiowmarkMessage
  );

  if (exactMatches.length === 0) {
    throw new Error(
      "自己検出に失敗しました。ShareRegistryには登録しません"
    );
  }

  console.log(
    "Exact matches:",
    exactMatches.length
  );

  /*
   * ShareRegistryへ接続
   */
  const [issuer] = await ethers.getSigners();

  const registry = await ethers.getContractAt(
    "ShareRegistry",
    contractAddress
  );

  console.log("Issuer:", issuer.address);
  console.log("Recipient:", recipient);
  console.log("Contract:", contractAddress);

  /*
   * 作品が未登録ならregisterWork
   */
  const currentOwner =
    await registry.workOwners(workHash);

  let registerWorkResult:
    | Record<string, unknown>
    | null = null;

  if (
    currentOwner.toLowerCase() ===
    ethers.ZeroAddress.toLowerCase()
  ) {
    console.log("Work is not registered.");

    const registerWorkTx =
      await registry.registerWork(workHash);

    const registerWorkReceipt =
      await waitForSuccessfulTransaction(
        registerWorkTx,
        "registerWork"
      );

    registerWorkResult = {
      skipped: false,
      transactionHash: registerWorkTx.hash,
      blockNumber:
        registerWorkReceipt.blockNumber,
      gasUsed:
        registerWorkReceipt.gasUsed.toString(),
    };

    console.log(
      "Work registered:",
      registerWorkTx.hash
    );
  } else {
    if (
      ethers.getAddress(currentOwner) !==
      ethers.getAddress(issuer.address)
    ) {
      throw new Error(
        `作品は別の所有者によって登録済みです: ${currentOwner}`
      );
    }

    registerWorkResult = {
      skipped: true,
      reason: "already registered",
      owner: currentOwner,
    };

    console.log(
      "Work is already registered:",
      currentOwner
    );
  }

  /*
   * 自己検出成功後にregisterShare
   */
  console.log("Registering share...");

  const registerShareTx =
    await registry.registerShare(
      watermarkId,
      workHash,
      recipient,
      shareSalt,
      watermarkCommitment,
      parentTokenId
    );

  const registerShareReceipt =
    await waitForSuccessfulTransaction(
      registerShareTx,
      "registerShare"
    );

  console.log(
    "Share registered:",
    registerShareTx.hash
  );

  /*
   * チェーン上の登録内容を再取得
   */
  const savedShare =
    await registry.getShare(watermarkId);
  const tokenId =
    await registry.tokenIdByWatermarkId(watermarkId);

  if (tokenId === 0n) {
    throw new Error("発行したtokenIdを取得できませんでした");
  }

  if (
    savedShare.workHash.toLowerCase() !==
    workHash.toLowerCase()
  ) {
    throw new Error(
      "チェーン上のworkHashが一致しません"
    );
  }

  if (
    ethers.getAddress(savedShare.recipient) !==
    recipient
  ) {
    throw new Error(
      "チェーン上のrecipientが一致しません"
    );
  }

  if (savedShare.active !== true) {
    throw new Error(
      "登録直後のactiveがtrueではありません"
    );
  }

  /*
   * チェーン登録成功後に正式ファイル名へ変更
   */
  await rename(
    temporaryAudioFile,
    finalAudioFile
  );

  /*
   * 発行結果JSONを保存
   */
  const issuanceResult = {
    idVersion: "WM_SHARE_V1",
    network: networkName,
    contractAddress,
    issuer: issuer.address,
    recipient,

    inputFile,
    outputFile: finalAudioFile,

    workHash,
    shareSalt,
    watermarkId,
    audiowmarkMessage,
    strength: config.strength,

    detection: {
      resultFile: detectionResultFile,
      candidateCount: matches.length,
      exactMatchCount: exactMatches.length,
      exactMatches,
    },

    blockchain: {
      registerWork: registerWorkResult,
      registerShare: {
        tokenId: tokenId.toString(),
        parentTokenId: parentTokenId.toString(),
        transactionHash: registerShareTx.hash,
        blockNumber:
          registerShareReceipt.blockNumber,
        gasUsed:
          registerShareReceipt.gasUsed.toString(),
      },
      shareRecord: {
        tokenId: tokenId.toString(),
        workHash: savedShare.workHash,
        issuer: savedShare.issuer,
        recipient: savedShare.recipient,
        shareSalt: savedShare.shareSalt,
        watermarkCommitment: savedShare.watermarkCommitment,
        parentTokenId: savedShare.parentTokenId.toString(),
        issuedAt:
          savedShare.issuedAt.toString(),
        active: savedShare.active,
      },
    },

    createdAt: new Date().toISOString(),
  };

  await writeFile(
    issuanceResultFile,
    JSON.stringify(issuanceResult, null, 2) +
      "\n",
    "utf8"
  );

  console.log("");
  console.log(
    "Watermarked copy issued successfully"
  );
  console.log("Output:", finalAudioFile);
  console.log("Result:", issuanceResultFile);
}

main().catch((error) => {
  console.error("");
  console.error(
    "Watermarked copy issuance failed"
  );
  console.error(error);
  process.exitCode = 1;
});
