import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MyNFTModule = buildModule("MyNFTModule", (m) => {
  const myNFT = m.contract("MyNFT");

  return { myNFT };
});

export default MyNFTModule;