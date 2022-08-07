import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, upgrades } from "hardhat";
import {
  BridgeRegistry,
  ERC721TokenMock,
  TokenBridgeMock,
} from "../../../typechain";
import {
  deployBridgeRegistry,
  deployTestNFT,
  deployTestBridge,
  ZERO_ADDRESS,
} from "../../utils/ethereumUtils";

describe("Bridge Registry Test", function () {
  const standardL1BridgeAddress = ethers.utils.getAddress(
    "0x3c7e870ce51a3429a3d2dfc4454282a8676f2029"
  );
  const standardL2BridgeAddress = BigNumber.from(
    "12089237316195423570985008687907853269984665640564039457584007913129639934"
  );

  const sampleL2TokenAddress = BigNumber.from(
    "12089237316195423570985008687907853269984665640564039457584007913129639000"
  );

  let sampleCustomBridgePair: any;

  let bridgeRegistry: BridgeRegistry;
  let testNFT: ERC721TokenMock;
  let testBridge: TokenBridgeMock;

  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let users: SignerWithAddress[];

  beforeEach(async function () {
    [owner, user1, ...users] = await ethers.getSigners();
    bridgeRegistry = (await deployBridgeRegistry(
      standardL1BridgeAddress,
      standardL2BridgeAddress
    )) as BridgeRegistry;
    testNFT = (await deployTestNFT()) as ERC721TokenMock;
    expect(await testNFT.owner()).to.equal(owner.address);

    testBridge = (await deployTestBridge()) as TokenBridgeMock;
    sampleCustomBridgePair = {
      l1BridgeAddress: testBridge.address,
      l2BridgeAddress: BigNumber.from("342343233432"),
    };
  });

  it("get the standard token bridge", async function () {
    expect(await bridgeRegistry.getStandardTokenBridge()).to.deep.equal([
      standardL1BridgeAddress,
      standardL2BridgeAddress,
    ]);
  });

  it("not contract owner cannot register a token", async function () {
    await expect(
      bridgeRegistry
        .connect(user1)
        .registerToken(testNFT.address, sampleL2TokenAddress)
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("contract owner can register a token", async function () {
    // event should be emitted on invoke
    await expect(
      bridgeRegistry
        .connect(owner)
        .registerToken(testNFT.address, sampleL2TokenAddress)
    ).to.emit(bridgeRegistry, "RegisterToken");

    // test get bridge by token address
    expect(await bridgeRegistry.getL2Token(testNFT.address)).to.deep.equal(
      sampleL2TokenAddress
    );
  });

  it("attempt to register token without owner an no fallback should pass", async function () {
    const ERC721TokenMockNotOwnable = await ethers.getContractFactory(
      "ERC721TokenMockNotOwnable"
    );
    const erc721TokenMockNotOwnable = await ERC721TokenMockNotOwnable.deploy();
    const erc721TokenContract = await erc721TokenMockNotOwnable.deployed();

    await bridgeRegistry.registerToken(
      erc721TokenContract.address,
      sampleL2TokenAddress
    );
  });

  it("attempt to register token with a fallback and without an owner should pass", async function () {
    /*
     * If the owner() function is not present, the fallback
     * function will be invoked by the token registry
     * when setting custom token bridge
     * The fallback function could have arbitrary code but
     * since it cannot return anything,
     * the owner() check will still fail which is expected
     * Note: This test is useful when the registry is fully decentralized
     */
    const ERC721TokenMockNotOwnable = await ethers.getContractFactory(
      "ERC721TokenMockFallback"
    );
    const erc721TokenMockNotOwnable = await ERC721TokenMockNotOwnable.deploy();
    const erc721TokenContract = await erc721TokenMockNotOwnable.deployed();

    await bridgeRegistry.registerToken(
      erc721TokenContract.address,
      sampleL2TokenAddress
    );
  });

  it("get custom bridge by address for unset token should return zero addresses", async function () {
    const result = await bridgeRegistry.getL2Token(testNFT.address);
    expect(result).to.deep.equal(BigNumber.from("0"));
  });

  it("set custom bridge for the same token multiple times should fail", async function () {
    await bridgeRegistry
      .connect(owner)
      .registerToken(testNFT.address, sampleL2TokenAddress);

    // test get bridge by token address
    expect(await bridgeRegistry.getL2Token(testNFT.address)).to.deep.equal(
      sampleL2TokenAddress
    );

    await expect(
      bridgeRegistry
        .connect(owner)
        .registerToken(testNFT.address, sampleL2TokenAddress)
    ).to.be.revertedWith("token already registered");
    // test get bridge by token address
  });

  it("bridge registry can be upgraded", async function () {
    // upgrade the contract which adds the new function
    const BridgeRegistryV2Mock = await ethers.getContractFactory(
      "BridgeRegistryV2Mock"
    );
    const upgradedBridgeRegistry = await upgrades.upgradeProxy(
      bridgeRegistry.address,
      BridgeRegistryV2Mock
    );
    // The old bridge address should be the same as the new bridge address
    expect(bridgeRegistry.address).to.deep.equal(
      upgradedBridgeRegistry.address
    );
    await upgradedBridgeRegistry.setNewVariable(BigNumber.from("316195423570"));
    expect(await upgradedBridgeRegistry.getNewVariable()).to.deep.equal(
      "316195423570"
    );
  });
});
