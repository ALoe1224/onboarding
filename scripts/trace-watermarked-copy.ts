import { network } from "hardhat";
import { execFile } from "node:child_process";
import {
  access,
  mkdir,
  readFile,
  writeFile,
} from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

type TraceConfig = {
  inputFile: string;
  keyFile: string;
  resultsDirectory: string;
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

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }

  if (typeof error === "object" && error !== null) {
    const value = error as {
      message?: unknown;
      shortMessage?: unknown;
      reason?: unknown;
    };

    return [
      value.message,
      value.shortMessage,
      value.reason,
    ]
      .filter((item) => typeof item === "string")
      .join(" ");
  }

  return String(error);
}

async function main() {
  /*
   * HardhatからGethへ接続
   */
  const { ethers, networkName } =
    await network.create();

  console.log("Network:", networkName);

  /*
   * trace.jsonを読み込む
   */
  const configPath = path.resolve(
    "config/trace.json"
  );

  const config = JSON.parse(
    await readFile(configPath, "utf8")
  ) as TraceConfig;

  const inputFile = path.resolve(
    config.inputFile
  );

  const keyFile = path.resolve(
    config.keyFile
  );

  const resultsDirectory = path.resolve(
    config.resultsDirectory
  );

  await access(inputFile);
  await access(keyFile);

  await mkdir(resultsDirectory, {
    recursive: true,
  });

  console.log("Input file:", inputFile);

  /*
   * デプロイ済みコントラクトのアドレスを取得
   */
  const deploymentPath = path.resolve(
    "deployments",
    `${networkName}.json`
  );

  const deployment = JSON.parse(
    await readFile(deploymentPath, "utf8")
  );

  const contractAddress =
    deployment.contractAddress ||
    deployment.address;

  if (
    !contractAddress ||
    !ethers.isAddress(contractAddress)
  ) {
    throw new Error(
      "コントラクトアドレスが不正です"
    );
  }

  const contractCode =
    await ethers.provider.getCode(
      contractAddress
    );

  if (contractCode === "0x") {
    throw new Error(
      `コントラクトが存在しません: ${contractAddress}`
    );
  }

  console.log("Contract:", contractAddress);

  /*
   * Audiowmarkの出力先を決める
   */
  const inputName =
    path.parse(inputFile).name;

  const detectionResultFile = path.join(
    resultsDirectory,
    `${inputName}_trace-detect.json`
  );

  const traceResultFile = path.join(
    resultsDirectory,
    `${inputName}_trace.json`
  );

  /*
   * 調査対象音源からID候補を検出
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
      inputFile,
    ],
    {
      maxBuffer: 20 * 1024 * 1024,
    }
  );

  const detectionResult = JSON.parse(
    await readFile(
      detectionResultFile,
      "utf8"
    )
  ) as DetectionResult;

  const matches = Array.isArray(
    detectionResult.matches
  )
    ? detectionResult.matches
    : [];

  console.log(
    "Detection matches:",
    matches.length
  );

  /*
   * 6. 32桁のID候補だけを取り出し、
   *    同じIDを1つにまとめる
   */
  const candidates =
    new Map<string, DetectionMatch[]>();

  for (const match of matches) {
    if (
      typeof match.bits !== "string" ||
      !/^[0-9a-fA-F]{32}$/.test(
        match.bits
      )
    ) {
      continue;
    }

    const bits =
      match.bits.toLowerCase();

    const evidence =
      candidates.get(bits) || [];

    evidence.push(match);
    candidates.set(bits, evidence);
  }

  console.log(
    "Unique candidates:",
    candidates.size
  );

  /*
   * ShareRegistryへ接続
   */
  const registry =
    await ethers.getContractAt(
      "ShareRegistry",
      contractAddress
    );

  const registeredShares:
    Array<Record<string, unknown>> = [];

  /*
   * 各候補をブロックチェーンで検索
   */
  for (
    const [bits, evidence]
    of candidates.entries()
  ) {
    const watermarkId = `0x${bits}`;
    const watermarkCommitment = ethers.keccak256(watermarkId);

    console.log(
      "Checking:",
      watermarkId
    );
    console.log(
      "Commitment:",
      watermarkCommitment
    );

    try {
      // watermarkCommitment からtokenIdを取得
      const tokenId = await registry.getTokenIdByCommitment(watermarkCommitment);

      if (tokenId === 0n) {
        console.log(
          "Not registered in blockchain"
        );
        continue;
      }

      // tokenId から詳細情報を取得
      const share = await registry.getShareByTokenId(tokenId);
      const sharePath = await registry.getSharePath(tokenId);

      const pathRecords = [];
      for (const pathTokenId of [...sharePath].reverse()) {
        const pathShare = await registry.getShareByTokenId(pathTokenId);
        pathRecords.push({
          tokenId: pathTokenId.toString(),
          issuer: pathShare.issuer,
          recipient: pathShare.recipient,
          parentTokenId: pathShare.parentTokenId.toString(),
          issuedAt: pathShare.issuedAt.toString(),
          issuedAtIso: new Date(Number(pathShare.issuedAt) * 1000).toISOString(),
          active: pathShare.active,
        });
      }

      const issuedAt =
        share.issuedAt.toString();

      const issuedAtIso =
        new Date(
          Number(share.issuedAt) * 1000
        ).toISOString();

      // 親情報を取得
      const parentTokenId = share.parentTokenId;
      let parentRecipient = null;
      if (parentTokenId !== 0n) {
        const parentShare = await registry.getShareByTokenId(parentTokenId);
        parentRecipient = parentShare.recipient;
      }

      registeredShares.push({
        watermarkId,
        tokenId: tokenId.toString(),

        detection: {
          occurrenceCount:
            evidence.length,
          matches: evidence,
        },

        shareRecord: {
          workHash:
            share.workHash,
          issuer:
            share.issuer,
          recipient:
            share.recipient,
          shareSalt:
            share.shareSalt,
          watermarkCommitment:
            share.watermarkCommitment,
          parentTokenId:
            parentTokenId.toString(),
          parentRecipient,
          issuedAt,
          issuedAtIso,
          active:
            share.active,
        },

        sharePath: sharePath.map((id: bigint) => id.toString()),
        pathRecords,
      });

      console.log(
        "Registered share found"
      );
      console.log(
        "  watermarkId:",
        watermarkId
      );
      console.log(
        "  tokenId:",
        tokenId
      );
      console.log(
        "  recipient:",
        share.recipient
      );
      console.log(
        "  parentTokenId:",
        parentTokenId
      );
      console.log(
        "  sharePath:",
        sharePath.map((id: bigint) => id.toString()).join(" ← ")
      );
      console.log("  recipientPath:");
      for (const pathRecord of pathRecords) {
        console.log(
          `    token ${pathRecord.tokenId}: ${pathRecord.recipient} (${pathRecord.active ? "VALID" : "REVOKED"})`
        );
      }

      console.log(
        "  workHash:",
        share.workHash
      );
      console.log(
        "  issuedAt:",
        issuedAtIso
      );
      console.log(
        "  active:",
        share.active
      );
    } catch (error) {
      const message =
        getErrorMessage(error);

      /*
       * 未登録候補は正常に除外する。
       * 通信障害など、別のエラーは停止する。
       */
      if (
        message.includes(
          "share not found"
        )
      ) {
        console.log(
          "  Not registered"
        );
        continue;
      }

      throw error;
    }
  }

  /*
   * 追跡結果をJSONへ保存
   */
  const traceResult = {
    status:
      registeredShares.length > 0
        ? "found"
        : "not_found",

    network: networkName,
    contractAddress,
    inputFile,

    detection: {
      resultFile:
        detectionResultFile,
      rawMatchCount:
        matches.length,
      uniqueCandidateCount:
        candidates.size,
    },

    registeredShareCount:
      registeredShares.length,

    registeredShares,

    tracedAt:
      new Date().toISOString(),
  };

  await writeFile(
    traceResultFile,
    JSON.stringify(
      traceResult,
      null,
      2
    ) + "\n",
    "utf8"
  );

  console.log("");

  if (
    registeredShares.length === 0
  ) {
    console.log(
      "No registered share was found"
    );
  } else {
    console.log(
      "Trace completed successfully"
    );
    console.log(
      "Registered shares:",
      registeredShares.length
    );
  }

  console.log(
    "Result:",
    traceResultFile
  );
}

main().catch((error) => {
  console.error("");
  console.error(
    "Watermarked copy trace failed"
  );
  console.error(error);
  process.exitCode = 1;
});
