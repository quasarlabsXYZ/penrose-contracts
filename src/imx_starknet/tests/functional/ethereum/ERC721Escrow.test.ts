import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, utils } from "ethers";
import { ethers } from "hardhat";
import { ERC721Escrow, ERC721TokenMock } from "../../../typechain";
import {
  deployTestNFT,
  deployERC721Escrow,
  ZERO_ADDRESS,
  WITHDRAWER_ROLE,
} from "../../utils/ethereumUtils";

describe("ERC721 Escrow Test", function () {
  let testNFT: ERC721TokenMock;
  let erc721Escrow: ERC721Escrow;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let users: SignerWithAddress[];

  beforeEach(async function () {
    [owner, user1, user2, ...users] = await ethers.getSigners();
    // deploy ERC721Escrow
    erc721Escrow = (await deployERC721Escrow()) as ERC721Escrow;
    // deploy testNFT
    testNFT = (await deployTestNFT()) as ERC721TokenMock;
    expect(await testNFT.owner()).to.equal(owner.address);
    // mint 20 NFTs to user1 (tokIds 21 -> 41)
    await testNFT.mintBatch(user1.address, 20);
  });

  it("escrow owner can grant role to a withdrawer", async function () {
    await erc721Escrow.grantRole(WITHDRAWER_ROLE, user1.address);
  });

  it("user1 cannot safeTransfer to escrow as they do not have the withdrawer role", async function () {
    await expect(
      testNFT
        .connect(user1)
        ["safeTransferFrom(address,address,uint256)"](
          user1.address,
          erc721Escrow.address,
          BigNumber.from(10)
        )
    ).to.be.revertedWith("ERC721: transfer to non ERC721Receiver implementer");
  });

  it("user1 can safeTransfer to escrow once they have the withdrawer role", async function () {
    await erc721Escrow.grantRole(WITHDRAWER_ROLE, user1.address);
    await testNFT
      .connect(user1)
      ["safeTransferFrom(address,address,uint256)"](
        user1.address,
        erc721Escrow.address,
        BigNumber.from(10)
      );
  });

  it("user1 can call approveForWithdraw as they have the withdrawer role", async function () {
    const tokenId = BigNumber.from("10");
    // owner allows user1.address to become a withdrawer
    await erc721Escrow.grantRole(WITHDRAWER_ROLE, user1.address);
    await testNFT
      .connect(user1)
      ["safeTransferFrom(address,address,uint256)"](
        user1.address,
        erc721Escrow.address,
        tokenId
      );

    expect(await testNFT.getApproved(tokenId)).to.deep.equal(ZERO_ADDRESS);

    // as user1 is has the withdrawer role, they can request they be approved to move a token
    await erc721Escrow
      .connect(user1)
      .approveForWithdraw(testNFT.address, tokenId);

    expect(await testNFT.getApproved(tokenId)).to.deep.equal(user1.address);
  });

  it("user1 cannot transfer away from escrow as they are not approved", async function () {
    await expect(
      testNFT
        .connect(user1)
        .transferFrom(erc721Escrow.address, user2.address, BigNumber.from("10"))
    ).to.be.revertedWith("ERC721: transfer from incorrect owner");
  });

  it("user1 cannot call approveForWithdraw as they do not have the withdrawer role", async function () {
    await expect(
      erc721Escrow.connect(user1).approveForWithdraw(testNFT.address, [1])
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role 0x5749544844524157455200000000000000000000000000000000000000000000`
    );
  });

  it("owner can remove a withdrawer", async function () {
    const tokenId = BigNumber.from(10);
    // transfer token 10 to the escrow
    await erc721Escrow.grantRole(WITHDRAWER_ROLE, user1.address);
    await testNFT
      .connect(user1)
      ["safeTransferFrom(address,address,uint256)"](
        user1.address,
        erc721Escrow.address,
        tokenId
      );

    // grante withdrawer role to user2 which will later be revoked
    await erc721Escrow.grantRole(WITHDRAWER_ROLE, user2.address);
    await erc721Escrow
      .connect(user2)
      .approveForWithdraw(testNFT.address, tokenId);

    await erc721Escrow.revokeRole(WITHDRAWER_ROLE, user2.address);

    // as withdrawer role has been revoked, they can no longer invoke approveForWithdraw
    await expect(
      erc721Escrow.connect(user2).approveForWithdraw(testNFT.address, tokenId)
    ).to.be.revertedWith(
      `AccessControl: account ${user2.address.toLocaleLowerCase()} is missing role 0x5749544844524157455200000000000000000000000000000000000000000000`
    );
  });
});
