import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Account } from "@shardlabs/starknet-hardhat-plugin/dist/src/account";
import {
  FeeEstimation,
  StarknetContract,
} from "@shardlabs/starknet-hardhat-plugin/dist/src/types";
import { BigNumber, ContractFactory } from "ethers";
import { ethers, upgrades } from "hardhat";
import {
  BridgeRegistry,
  ERC721Escrow,
  StandardERC721Bridge,
} from "../typechain";
import {
  deployBridgeRegistry,
  deployERC721Escrow,
  WITHDRAWER_ROLE,
} from "../tests/utils/ethereumUtils";
import { deployStandardERC721Bridge } from "../tests/utils/starknetDeploys";

export type BridgeDeploymentResult = {
  bridgeL1: StandardERC721Bridge;
  bridgeL2: StarknetContract;
  registry: BridgeRegistry;
  escrow: ERC721Escrow;
};

export async function deployBridge(
  starknetDeployer: Account,
  starknetCoreAddress: string
): Promise<BridgeDeploymentResult> {
  // Deploy Bridge on L2
  console.log(
    "Using owner address: ",
    starknetDeployer.starknetContract.address
  );
  let starknetBridge: StarknetContract;
  let fee: FeeEstimation;

  starknetBridge = await deployStandardERC721Bridge(
    BigInt(starknetDeployer.starknetContract.address)
  );
  console.log(`L2 bridge deployed to ${starknetBridge.address}`);

  // Deploy Escrow contract on L1
  const erc721Escrow = (await deployERC721Escrow()) as ERC721Escrow;
  console.log(`Escrow deployed to address ${erc721Escrow.address}`);

  // Deploy Bridge on L1
  const StandardERC721Bridge = await ethers.getContractFactory(
    "StandardERC721Bridge"
  );
  const standardERC721Bridge = await upgrades.deployProxy(
    StandardERC721Bridge as ContractFactory,
    [starknetCoreAddress, erc721Escrow.address],
    { initializer: "initialize" }
  );
  const bridge =
    (await standardERC721Bridge.deployed()) as StandardERC721Bridge;
  console.log(`L1 Bridge deployed to address ${bridge.address}`);

  // Grant Bridge Withdrawer role on L1
  let tx = await erc721Escrow.grantRole(WITHDRAWER_ROLE, bridge.address);
  console.log(`Waiting for txHash: ${tx.hash}`);
  await tx.wait(1);
  console.log("L1 Bridge granted withdrawer role");

  // Deploy Bridge Registy on L1
  const bridgeRegistry = (await deployBridgeRegistry(
    bridge.address,
    BigNumber.from(starknetBridge.address)
  )) as BridgeRegistry;
  console.log(`Bridge Registry deployed to address ${bridgeRegistry.address}`);

  // Set bridge registry on bridge on L1
  tx = await bridge.setBridgeRegistry(bridgeRegistry.address, {
    gasLimit: 1000000,
  });
  console.log(`Waiting for txHash: ${tx.hash}`);
  await tx.wait(1);
  console.log("BridgeRegistry address set on the L1 Bridge");

  // Set L1 Bridge address on Bridge on L2
  const setL1BridgeArgs = [
    starknetBridge,
    "set_l1_bridge",
    {
      l1_bridge_address: BigInt(bridge.address),
    },
  ] as const;
  fee = await starknetDeployer.estimateFee(...setL1BridgeArgs);
  console.log(fee);
  await starknetDeployer.invoke(...setL1BridgeArgs, {
    maxFee: fee.amount,
  });
  console.log("L1 Bridge address set on L2 Bridge");

  const returnResult: BridgeDeploymentResult = {
    bridgeL1: bridge,
    bridgeL2: starknetBridge,
    registry: bridgeRegistry,
    escrow: erc721Escrow,
  };
  return returnResult;
}
