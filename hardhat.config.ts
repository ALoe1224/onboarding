import { defineConfig } from "hardhat/config";
import hardhatEthers from "@nomicfoundation/hardhat-ethers";

export default defineConfig({
  plugins: [hardhatEthers],
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      evmVersion: "paris",
    },
  },
  networks: {
    gethLocal: {
      type: "http",
      url: "http://127.0.0.1:8545",
      chainId: 12345,
      accounts: "remote",
      timeout: 300000,
    },
  },
});

