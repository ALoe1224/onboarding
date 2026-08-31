import { AbiCoder, getBytes, hexlify } from "ethers";
import { blake2s } from "@noble/hashes/blake2.js";

const abiCoder = AbiCoder.defaultAbiCoder();

export function createWatermarkId(
  workHash: string,
  recipient: string,
  shareSalt: string,
  parentTokenId: number | bigint = 0
): string {
  const encoded = abiCoder.encode(
    ["string", "bytes32", "address", "uint256", "bytes32"],
    [
      "WM_SHARE_V1",
      workHash,
      recipient,
      parentTokenId,
      shareSalt,
    ]
  );

  // 最初から16バイト＝128ビットのBLAKE2sを計算
  const watermarkIdBytes = blake2s(getBytes(encoded), {
    dkLen: 16,
  });

  return hexlify(watermarkIdBytes);
}
