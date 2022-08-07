/* 
  To run integration tests -> 
  create .env file in root directory of the form:
  ```
  GOERLI_URL=https://eth-goerli.alchemyapi.io/v2/xxxxxxxxxxxxxxxx
  PRIVATE_KEY=xxxxxxxxxxxxxxxx
  ```
  Where PRIVATE_KEY is the ethereum private key. 
  STARKNET_OWNER_ADDRESS and STARKNET_OWNER_PKEY must be set with an account on goerli with preloaded ETH.
  Modify starknet.network to "alpha" in hardhat config. Ensure you are in an environment
  with cairo installed, then run
  `npx hardhat test tests/integration/bridge.test.ts --network goerli`
*/
import { ethers, upgrades, starknet } from "hardhat";
import dotenv from "dotenv";
import { Account } from "@shardlabs/starknet-hardhat-plugin/dist/src/account";
import {
  deployBridge,
  BridgeDeploymentResult,
} from "../../scripts/deployBridge";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ERC721TokenMock } from "../../typechain";
import { BigNumber } from "ethers";
import { deployERC721 } from "../utils/starknetDeploys";
import {
  FeeEstimation,
  StarknetContract,
} from "@shardlabs/starknet-hardhat-plugin/dist/src/types";
import { expect } from "chai";
import { sleep } from "../utils/ethereumUtils";
import {
  fromUint256WithFelts,
  toUint256WithFelts,
} from "../utils/starknetUtils";
import config from "../../config.json";

dotenv.config();

describe("Bridge Test", function () {
  this.timeout(3_600_000); // 1hr
  let starknetOwner: Account;
  let ethereumOwner: SignerWithAddress;
  let bridgeDeployment: BridgeDeploymentResult;

  before(async function () {
    if (
      process.env.STARKNET_OWNER_ADDRESS == null ||
      process.env.STARKNET_OWNER_PKEY == null
    ) {
      console.log(
        "STARKNET_OWNER_ADDRESS and STARKNET_OWNER_PKEY must be set with an account on goerli with preloaded ETH"
      );
      process.exit(1);
    }
    starknetOwner = await starknet.getAccountFromAddress(
      process.env.STARKNET_OWNER_ADDRESS,
      process.env.STARKNET_OWNER_PKEY,
      "OpenZeppelin"
    );
    console.log(
      "Using owner address: ",
      starknetOwner.starknetContract.address
    );
    [ethereumOwner] = await ethers.getSigners();
    bridgeDeployment = await deployBridge(
      starknetOwner,
      config.STARKNET_CORE_GOERLI
    );
  });

  describe("NFT Deposit & Withdraw", function () {
    let ethNFT: ERC721TokenMock;
    let starknetNFT: StarknetContract;
    let fee: FeeEstimation;

    before(async function () {
      // deploy testNFT on L1
      const ERC721TokenMock = await ethers.getContractFactory(
        "ERC721TokenMock"
      );
      console.log("Executing L1 ERC721 deploy");
      const erc721TokenMock = await ERC721TokenMock.deploy();
      console.log("Waiting for L1 ERC721 to be deployed");
      ethNFT = (await erc721TokenMock.deployed()) as ERC721TokenMock;
      // mint 10 NFTs to the owner
      console.log("Minting NFTs");
      await ethNFT.mintBatch(ethereumOwner.address, 10);
      console.log("Minted NFTs");

      // deploy testNFT on L2
      starknetNFT = await deployERC721(
        BigInt(starknetOwner.starknetContract.address),
        "ERC721_Full"
      );
      console.log(`deployed l2 NFT at address ${starknetNFT.address}`);

      // give mint permission to the L2 bridge
      const grantMinterRoleArgs = [
        starknetNFT,
        "grantRole",
        {
          role: starknet.shortStringToBigInt("MINTER_ROLE"),
          account: BigInt(bridgeDeployment.bridgeL2.address),
        },
      ] as const;
      fee = await starknetOwner.estimateFee(...grantMinterRoleArgs);
      await starknetOwner.invoke(...grantMinterRoleArgs, {
        maxFee: fee.amount,
      });

      console.log(
        `minter role granted to ${bridgeDeployment.bridgeL2.address}`
      );

      // give burn permission to the L2 bridge
      const grantBurnerRoleArgs = [
        starknetNFT,
        "grantRole",
        {
          role: starknet.shortStringToBigInt("BURNER_ROLE"),
          account: BigInt(bridgeDeployment.bridgeL2.address),
        },
      ] as const;
      fee = await starknetOwner.estimateFee(...grantBurnerRoleArgs);
      await starknetOwner.invoke(...grantBurnerRoleArgs, {
        maxFee: fee.amount,
      });
      console.log(
        `burner role granted to ${bridgeDeployment.bridgeL2.address}`
      );

      // register token on registry
      const registerTx = await bridgeDeployment.registry.registerToken(
        ethNFT.address,
        BigNumber.from(starknetNFT.address)
      );
      console.log(`Waiting for txHash: ${registerTx.hash}`);
      await registerTx.wait(1); // wait to prevent replacement error
      console.log("Registered with Bridge Registry");
    });

    it("Can deposit NFTs", async function () {
      console.log("Depositing NFT");
      // the balance of owner on L1 should be 10
      expect(await ethNFT.balanceOf(ethereumOwner.address)).to.deep.equal(
        BigNumber.from(10)
      );

      const approveTx = await ethNFT.setApprovalForAll(
        bridgeDeployment.bridgeL1.address,
        true
      );
      console.log(`Waiting for txHash: ${approveTx.hash}`);
      await approveTx.wait(1);
      const depositTx = await bridgeDeployment.bridgeL1.deposit(
        ethNFT.address,
        [1, 2],
        BigNumber.from(starknetOwner.starknetContract.address),
        {
          gasLimit: 1000000,
        }
      );

      console.log(
        `Waiting for ${config.DEPOSIT_WAIT_BLOCK_COUNT} blocks, current block is ${ethers.provider.blockNumber}`
      );
      console.log(`Waiting for txHash: ${depositTx.hash}`);
      await depositTx.wait(config.DEPOSIT_WAIT_BLOCK_COUNT);
      console.log(
        `Finished waiting for ${config.DEPOSIT_WAIT_BLOCK_COUNT} blocks`
      );

      // the balance of owner on L1 should be 8
      expect(await ethNFT.balanceOf(ethereumOwner.address)).to.deep.equal(
        BigNumber.from(8)
      );

      // the balance of owner on L2 should be 2
      const ownerBalance = (
        await starknetNFT.call("balanceOf", {
          owner: BigInt(starknetOwner.starknetContract.address),
        })
      ).balance;
      console.log(
        `Balance of ${
          starknetOwner.starknetContract.address
        } is ${fromUint256WithFelts(ownerBalance).toString()}`
      );
      expect(ownerBalance.low).to.deep.equal(2n);
      expect(ownerBalance.high).to.deep.equal(0n);
    });

    it("Can withdraw NFTs", async function () {
      // execute withdraw on L2
      console.log("Executing initiate_withdraw");
      const initiateWithdrawArgs = [
        bridgeDeployment.bridgeL2,
        "initiate_withdraw",
        {
          l2_token_address: starknetNFT.address,
          l2_token_ids: [toUint256WithFelts(2)],
          l1_claimant: BigInt(ethereumOwner.address),
        },
      ] as const;
      fee = await starknetOwner.estimateFee(...initiateWithdrawArgs);
      const initiateWithdrawResult = await starknetOwner.invoke(
        ...initiateWithdrawArgs,
        { maxFee: fee.amount }
      );
      console.log(initiateWithdrawResult);

      // the balance of owner on L2 should be 1
      const ownerBalance = (
        await starknetNFT.call("balanceOf", {
          owner: BigInt(starknetOwner.starknetContract.address),
        })
      ).balance;
      console.log(
        `Balance of ${
          starknetOwner.starknetContract.address
        } is ${fromUint256WithFelts(ownerBalance).toString()}`
      );
      expect(ownerBalance.low).to.deep.equal(1n);
      expect(ownerBalance.high).to.deep.equal(0n);

      // wait for 50 blocks to be committed
      let startBlockNumber = await ethers.provider.getBlockNumber();
      let endBlockNumber = startBlockNumber + config.WITHDRAW_WAIT_BLOCK_COUNT;
      console.log(`Waiting till block ${endBlockNumber}`);
      while ((await ethers.provider.getBlockNumber()) <= endBlockNumber) {
        await sleep(100_000);
        console.log(
          `Current block is ${await ethers.provider.getBlockNumber()}`
        );
      }
      console.log(`Finished waiting`);
      const isWithdrawableResult =
        await bridgeDeployment.bridgeL1.isWithdrawable(
          ethNFT.address,
          [BigNumber.from(2)],
          ethereumOwner.address
        );
      console.log(`isWithdrawable result: ${isWithdrawableResult}`);
      console.log(`Executing withdraw`);
      const withdrawTx = await bridgeDeployment.bridgeL1.withdraw(
        ethNFT.address,
        [BigNumber.from(2)],
        ethereumOwner.address
      );
      console.log(`Waiting for txHash: ${withdrawTx.hash}`);
      await withdrawTx.wait(1);

      // the balance of owner on L1 should be 9
      expect(await ethNFT.balanceOf(ethereumOwner.address)).to.deep.equal(
        BigNumber.from(9)
      );
    });
  });
});
