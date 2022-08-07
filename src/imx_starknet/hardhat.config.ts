import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-web3";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-gas-reporter";
import "@shardlabs/starknet-hardhat-plugin";

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100000000, // num assets we expect to be deposited over the lifetime of the contract
      },
    },
  },
  starknet: {
    venv: "active",
    network: "devnet", // alpha for goerli testnet, or any other network defined in networks
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./immutablex/ethereum",
    tests: "./tests/functional",
    starknetSources: "./immutablex/starknet",
    starknetArtifacts: "./starknet-artifacts",
  },

  networks: {
    goerli: {
      url: process.env.GOERLI_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    devnet: {
      url: "http://localhost:5050",
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    coinmarketcap: process.env.CMC_KEY,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
