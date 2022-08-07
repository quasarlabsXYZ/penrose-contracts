import { BigNumber, Contract, ContractFactory } from "ethers";
import { ethers, upgrades } from "hardhat";
import {
  BridgeRegistry,
  ERC721Escrow,
  StarknetMessagingMock,
} from "../../typechain";

export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export async function deployBridgeRegistry(
  l1BridgeAddress: string,
  l2BridgeAddress: BigNumber
): Promise<Contract> {
  const standardBridgePair = {
    l1BridgeAddress: l1BridgeAddress,
    l2BridgeAddress: l2BridgeAddress,
  };
  const BridgeRegistry = await ethers.getContractFactory("BridgeRegistry");
  const bridgeRegistry = await upgrades.deployProxy(
    BridgeRegistry,
    [standardBridgePair],
    { initializer: "initialize" }
  );
  return await bridgeRegistry.deployed();
}

export async function deployTestNFT(): Promise<Contract> {
  const ERC721TokenMock = await ethers.getContractFactory("ERC721TokenMock");
  const erc721TokenMock = await ERC721TokenMock.deploy();
  return await erc721TokenMock.deployed();
}

export async function deployStandardERC721Bridge(
  starknetMessagingMock: StarknetMessagingMock,
  erc721Escrow: ERC721Escrow
): Promise<Contract> {
  const StandardERC721Bridge = await ethers.getContractFactory(
    "StandardERC721Bridge"
  );
  const standardERC721Bridge = await upgrades.deployProxy(
    StandardERC721Bridge as ContractFactory,
    [starknetMessagingMock.address, erc721Escrow.address],
    { initializer: "initialize" }
  );
  return await standardERC721Bridge.deployed();
}

export async function deployTestBridge(): Promise<Contract> {
  const TokenBridgeMock = await ethers.getContractFactory("TokenBridgeMock");
  const tokenBridgeMock = await TokenBridgeMock.deploy();
  return await tokenBridgeMock.deployed();
}

export async function deployStarknetMessagingMock(): Promise<Contract> {
  const StarknetMessagingMock = await ethers.getContractFactory(
    "StarknetMessagingMock"
  );
  const starknetMessagingMock = await StarknetMessagingMock.deploy();
  return await starknetMessagingMock.deployed();
}

export async function deployERC721Escrow(): Promise<Contract> {
  const ERC721Escrow = await ethers.getContractFactory("ERC721Escrow");
  const erc721Escrow = await upgrades.deployProxy(
    ERC721Escrow as ContractFactory,
    [],
    { initializer: "initialize" }
  );
  return await erc721Escrow.deployed();
}

export const WITHDRAWER_ROLE = ethers.utils.formatBytes32String("WITHDRAWER");

export const DEPOSIT_HANDLER = BigNumber.from(
  "1285101517810983806491589552491143496277809242732141897358598292095611420389"
);

export type Uint256 = {
  low: BigNumber;
  high: BigNumber;
};

export function splitUint256(num: BigNumber): Uint256 {
  return {
    low: num.mask(128),
    high: num.shr(128),
  };
}

export function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
