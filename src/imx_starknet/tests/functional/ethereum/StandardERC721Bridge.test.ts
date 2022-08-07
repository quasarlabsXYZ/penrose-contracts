import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import {
  ERC721AttackerMock,
  ERC721Escrow,
  ERC721TokenMock,
  StandardERC721Bridge,
  StarknetMessagingMock,
  IERC721Bridge,
  BridgeRegistry,
} from "../../../typechain";
import {
  deployStandardERC721Bridge,
  deployTestNFT,
  deployStarknetMessagingMock,
  deployERC721Escrow,
  WITHDRAWER_ROLE,
  DEPOSIT_HANDLER,
  deployBridgeRegistry,
  splitUint256,
} from "../../utils/ethereumUtils";

describe("Bridge Test", function () {
  let starknetMessagingMock: StarknetMessagingMock;
  let bridge: StandardERC721Bridge;
  let testNFT: ERC721TokenMock;
  let erc721Escrow: ERC721Escrow;
  let bridgeRegistry: BridgeRegistry;

  let owner: SignerWithAddress;
  const ownerL2Address: BigNumber = BigNumber.from("343243534643534");
  const l2BridgeAddress: BigNumber = BigNumber.from("123456781234567");
  const testNFTl2Address: BigNumber = BigNumber.from(
    "352040181584456735608515580760888541466059565068553383579463728554843487000"
  );

  let user1: SignerWithAddress;
  let users: SignerWithAddress[];

  beforeEach(async function () {
    [owner, user1, ...users] = await ethers.getSigners();
    // deploy starknet messaging mock
    starknetMessagingMock =
      (await deployStarknetMessagingMock()) as StarknetMessagingMock;
    // deploy ERC721Escrow
    erc721Escrow = (await deployERC721Escrow()) as ERC721Escrow;
    // deploy standard ERC721 bridge
    bridge = (await deployStandardERC721Bridge(
      starknetMessagingMock,
      erc721Escrow
    )) as StandardERC721Bridge;
    // add the bridge as a withdrawer for the escrow contract
    await erc721Escrow.grantRole(WITHDRAWER_ROLE, bridge.address);

    // deploy the bridge registry
    bridgeRegistry = (await deployBridgeRegistry(
      bridge.address,
      l2BridgeAddress
    )) as BridgeRegistry;

    // initialize the standard erc721 bridge with the bridge registry
    await bridge.setBridgeRegistry(bridgeRegistry.address);

    // deploy testNFT
    testNFT = (await deployTestNFT()) as ERC721TokenMock;
    expect(await testNFT.owner()).to.equal(owner.address);
    // mint 15 NFTs to the owner
    await testNFT.mintBatch(owner.address, 15);

    await bridgeRegistry.registerToken(testNFT.address, testNFTl2Address);
  });

  describe("Initialization", function () {
    it("bridge registry cannot be reinitialized", async function () {
      await expect(
        bridge.setBridgeRegistry(testNFT.address)
      ).to.be.revertedWith("bridge registry already set");
    });
  });

  describe("L1 to L2 Flow", function () {
    describe("deposit", function () {
      it("token holder can deposit an NFT", async function () {
        const depositTokenId = 1;
        expect(await testNFT.ownerOf(depositTokenId)).to.deep.equal(
          owner.address
        );
        await testNFT.setApprovalForAll(bridge.address, true);
        await bridge.deposit(testNFT.address, [depositTokenId], ownerL2Address);
        expect(await testNFT.ownerOf(depositTokenId)).to.deep.equal(
          erc721Escrow.address
        );

        // the starknet core contract should consume the correct output
        const tokenId = splitUint256(BigNumber.from(depositTokenId));
        await starknetMessagingMock.mockConsumeMessageToL2(
          BigNumber.from(bridge.address),
          l2BridgeAddress,
          DEPOSIT_HANDLER,
          [
            testNFTl2Address,
            ownerL2Address,
            BigNumber.from(testNFT.address),
            BigNumber.from("2"), // len of deposited token Ids (num tokens * 2)
            tokenId.low,
            tokenId.high,
          ],
          BigNumber.from("0") // nonce of the messaging contract, increments with every message sent, starts at 0
        );
      });

      it("token holder cannot deposit the same NFT twice", async function () {
        const depositTokenId = 1;
        expect(await testNFT.ownerOf(depositTokenId)).to.deep.equal(
          owner.address
        );
        await testNFT.setApprovalForAll(bridge.address, true);
        await bridge.deposit(testNFT.address, [depositTokenId], ownerL2Address);
        expect(await testNFT.ownerOf(depositTokenId)).to.deep.equal(
          erc721Escrow.address
        );

        await expect(
          bridge.deposit(testNFT.address, [depositTokenId], ownerL2Address)
        ).to.be.revertedWith(
          "ERC721: transfer caller is not owner nor approved"
        );
      });

      it("token holder cannot execute deposit with empty NFT list", async function () {
        await testNFT.setApprovalForAll(bridge.address, true);
        await expect(
          bridge.deposit(testNFT.address, [], ownerL2Address)
        ).to.be.revertedWith("_tokenIds must not be empty");
      });

      it("token holder can deposit multiple NFTs", async function () {
        expect(await testNFT.ownerOf(1)).to.deep.equal(owner.address);
        await testNFT.setApprovalForAll(bridge.address, true);
        const depositTokenIds = Array.from({ length: 10 }, (_, i) => i + 1);

        // correct events should be emitted
        await expect(
          bridge.deposit(testNFT.address, depositTokenIds, ownerL2Address)
        )
          .to.emit(bridge, "Deposit")
          .withArgs(
            owner.address,
            testNFT.address,
            depositTokenIds,
            ownerL2Address,
            0
          );

        // owner of the deposited tokens should change
        for (const tokenId of depositTokenIds) {
          expect(await testNFT.ownerOf(tokenId)).to.deep.equal(
            erc721Escrow.address
          );
        }

        // starknet core contract should consume the correct output
        const tokenIdsBN = depositTokenIds.map((ti) => BigNumber.from(ti));
        let expectedPayload = [
          testNFTl2Address,
          ownerL2Address,
          BigNumber.from(testNFT.address),
          BigNumber.from(tokenIdsBN.length * 2),
        ];

        for (const tokenId of tokenIdsBN) {
          const splitTokenId = splitUint256(BigNumber.from(tokenId));
          expectedPayload.push(splitTokenId.low);
          expectedPayload.push(splitTokenId.high);
        }

        await starknetMessagingMock.mockConsumeMessageToL2(
          BigNumber.from(bridge.address),
          l2BridgeAddress,
          DEPOSIT_HANDLER,
          expectedPayload,
          BigNumber.from("0") // nonce of the messaging contract, increments with every message sent, starts at 0
        );
      });

      it("token holder cannot safe transfer directly to the bridge", async function () {
        const depositTokenId = 1;
        expect(await testNFT.ownerOf(depositTokenId)).to.deep.equal(
          owner.address
        );
        await expect(
          testNFT["safeTransferFrom(address,address,uint256)"](
            owner.address,
            bridge.address,
            BigNumber.from(depositTokenId)
          )
        ).to.be.revertedWith(
          "ERC721: transfer to non ERC721Receiver implementer"
        );
      });

      it("token holder cannot safe transfer directly to the erc721 escrow", async function () {
        const depositTokenId = 1;
        expect(await testNFT.ownerOf(depositTokenId)).to.deep.equal(
          owner.address
        );
        await expect(
          testNFT["safeTransferFrom(address,address,uint256)"](
            owner.address,
            erc721Escrow.address,
            BigNumber.from(depositTokenId)
          )
        ).to.be.revertedWith(
          "ERC721: transfer to non ERC721Receiver implementer"
        );
      });

      it("token holder can normal transfer directly to the bridge (not recommended as holder will lose nft)", async function () {
        const depositTokenId = 1;
        expect(await testNFT.ownerOf(depositTokenId)).to.deep.equal(
          owner.address
        );
        await testNFT.transferFrom(
          owner.address,
          bridge.address,
          BigNumber.from("1")
        );
        expect(await testNFT.ownerOf(depositTokenId)).to.deep.equal(
          bridge.address
        );
      });
    });

    describe("deposit cancellation", function () {
      let depositTokenIds: Array<number> = [];
      let tokenIdsBN: Array<BigNumber>;

      beforeEach(async function () {
        // before each deposit cancellation test case, deposit 10 NFTs with tokenIds 1 -> 10
        await testNFT.setApprovalForAll(bridge.address, true);
        depositTokenIds = Array.from({ length: 10 }, (_, i) => i + 1);
        tokenIdsBN = depositTokenIds.map((x) => BigNumber.from(x));

        await bridge.deposit(testNFT.address, depositTokenIds, ownerL2Address);

        for (const tokenId of depositTokenIds) {
          expect(await testNFT.ownerOf(BigNumber.from(tokenId))).to.deep.equal(
            erc721Escrow.address
          );
        }
      });
      describe("initiateCancelDeposit", function () {
        it("depositor can cancel their deposit with correct params", async function () {
          await expect(
            bridge.initiateCancelDeposit(
              testNFT.address,
              depositTokenIds,
              ownerL2Address,
              0
            )
          )
            .to.emit(bridge, "DepositCancelInitiated")
            .withArgs(
              owner.address,
              testNFT.address,
              depositTokenIds,
              ownerL2Address,
              0
            );
        });

        it("depositor can initiate the deposit cancellation multiple times", async function () {
          // initiating the deposit cancellation multiple times will simply
          // reset the time required before they can call completeCancelDeposit
          await bridge.initiateCancelDeposit(
            testNFT.address,
            depositTokenIds,
            ownerL2Address,
            0
          );

          await bridge.initiateCancelDeposit(
            testNFT.address,
            depositTokenIds,
            ownerL2Address,
            0
          );
        });

        it("sender cannot cancel someone elses deposit", async function () {
          await expect(
            bridge
              .connect(user1)
              .initiateCancelDeposit(
                testNFT.address,
                depositTokenIds,
                ownerL2Address,
                0
              )
          ).to.be.revertedWith("tokens were not deposited by sender");
        });
        it("depositor cannot cancel their deposit with incorrect nonce", async function () {
          await expect(
            bridge.initiateCancelDeposit(
              testNFT.address,
              depositTokenIds,
              ownerL2Address,
              1
            )
          ).to.be.revertedWith("tokens were not deposited by sender");
        });
        it("depositor cannot cancel their deposit with incorrect tokenIds", async function () {
          await expect(
            bridge.initiateCancelDeposit(
              testNFT.address,
              depositTokenIds.concat(12),
              ownerL2Address,
              0
            )
          ).to.be.revertedWith("tokens were not deposited by sender");
        });
        it("depositor cannot cancel their deposit with incorrect token address", async function () {
          const newNFT: ERC721TokenMock =
            (await deployTestNFT()) as ERC721TokenMock;
          await newNFT.mintBatch(erc721Escrow.address, BigNumber.from("20"));
          await bridgeRegistry.registerToken(newNFT.address, testNFTl2Address);
          await expect(
            bridge.initiateCancelDeposit(
              newNFT.address,
              depositTokenIds,
              ownerL2Address,
              0
            )
          ).to.be.revertedWith("tokens were not deposited by sender");
        });

        it("successfully consume a deposit from L2 before cancellation", async function () {
          let payload = [
            testNFTl2Address,
            ownerL2Address,
            BigNumber.from(testNFT.address),
            BigNumber.from(tokenIdsBN.length * 2),
          ];

          for (const tokenId of tokenIdsBN) {
            const splitTokenId = splitUint256(BigNumber.from(tokenId));
            payload.push(splitTokenId.low);
            payload.push(splitTokenId.high);
          }

          await starknetMessagingMock.mockConsumeMessageToL2(
            bridge.address,
            l2BridgeAddress,
            DEPOSIT_HANDLER,
            payload,
            0
          );
        });

        it("succesfully consume a deposit from L2 after initiating cancellation", async function () {
          await bridge.initiateCancelDeposit(
            testNFT.address,
            depositTokenIds,
            ownerL2Address,
            0
          );

          let payload = [
            testNFTl2Address,
            ownerL2Address,
            BigNumber.from(testNFT.address),
            BigNumber.from(tokenIdsBN.length * 2),
          ];

          for (const tokenId of tokenIdsBN) {
            const splitTokenId = splitUint256(BigNumber.from(tokenId));
            payload.push(splitTokenId.low);
            payload.push(splitTokenId.high);
          }

          await starknetMessagingMock.mockConsumeMessageToL2(
            bridge.address,
            l2BridgeAddress,
            DEPOSIT_HANDLER,
            payload,
            0
          );
        });

        it("cannot initiate cancel deposit after it has been consumed from L2", async function () {
          let payload = [
            testNFTl2Address,
            ownerL2Address,
            BigNumber.from(testNFT.address),
            BigNumber.from(tokenIdsBN.length * 2),
          ];

          for (const tokenId of tokenIdsBN) {
            const splitTokenId = splitUint256(BigNumber.from(tokenId));
            payload.push(splitTokenId.low);
            payload.push(splitTokenId.high);
          }

          await starknetMessagingMock.mockConsumeMessageToL2(
            bridge.address,
            l2BridgeAddress,
            DEPOSIT_HANDLER,
            payload,
            0
          );

          await expect(
            bridge.initiateCancelDeposit(
              testNFT.address,
              depositTokenIds,
              ownerL2Address,
              0
            )
          ).to.be.revertedWith("NO_MESSAGE_TO_CANCEL");
        });
      });

      describe("completeCancelDeposit", function () {
        beforeEach(async function () {
          await bridge.initiateCancelDeposit(
            testNFT.address,
            depositTokenIds,
            ownerL2Address,
            0
          );
        });

        it("can execute if message has not been consumed on L2", async function () {
          await expect(
            bridge.completeCancelDeposit(
              testNFT.address,
              depositTokenIds,
              ownerL2Address,
              0,
              owner.address
            )
          )
            .to.emit(bridge, "DepositCancelled")
            .withArgs(
              owner.address,
              testNFT.address,
              depositTokenIds,
              ownerL2Address,
              0
            );
        });

        it("cannot cancel someone elses deposit", async function () {
          await expect(
            bridge
              .connect(user1)
              .completeCancelDeposit(
                testNFT.address,
                depositTokenIds,
                ownerL2Address,
                0,
                owner.address
              )
          ).to.be.revertedWith("tokens were not deposited by sender");
        });

        it("cannot execute with incorrect nonce", async function () {
          await expect(
            bridge.completeCancelDeposit(
              testNFT.address,
              depositTokenIds,
              ownerL2Address,
              1,
              owner.address
            )
          ).to.be.revertedWith("tokens were not deposited by sender");
        });

        it("cannot execute with incorrect token address", async function () {
          const newNFT: ERC721TokenMock =
            (await deployTestNFT()) as ERC721TokenMock;
          await newNFT.mintBatch(erc721Escrow.address, BigNumber.from("20"));
          await bridgeRegistry.registerToken(newNFT.address, testNFTl2Address);
          await expect(
            bridge.completeCancelDeposit(
              newNFT.address,
              depositTokenIds,
              ownerL2Address,
              0,
              owner.address
            )
          ).to.be.revertedWith("tokens were not deposited by sender");
        });

        it("cannot execute with incorrect token ids", async function () {
          await expect(
            bridge.completeCancelDeposit(
              testNFT.address,
              depositTokenIds.splice(0, 3),
              ownerL2Address,
              0,
              owner.address
            )
          ).to.be.revertedWith("tokens were not deposited by sender");
        });

        it("cannot execute with incorrect ownerL2Address", async function () {
          await expect(
            bridge.completeCancelDeposit(
              testNFT.address,
              depositTokenIds,
              BigNumber.from("2132132131232"),
              0,
              owner.address
            )
          ).to.be.revertedWith("tokens were not deposited by sender");
        });

        it("cannot consume on L2 after cancellation", async function () {
          await bridge.completeCancelDeposit(
            testNFT.address,
            depositTokenIds,
            ownerL2Address,
            0,
            owner.address
          );

          let payload = [
            testNFTl2Address,
            ownerL2Address,
            BigNumber.from(testNFT.address),
            BigNumber.from(tokenIdsBN.length * 2),
          ];

          for (const tokenId of tokenIdsBN) {
            const splitTokenId = splitUint256(BigNumber.from(tokenId));
            payload.push(splitTokenId.low);
            payload.push(splitTokenId.high);
          }

          await expect(
            starknetMessagingMock.mockConsumeMessageToL2(
              bridge.address,
              l2BridgeAddress,
              DEPOSIT_HANDLER,
              payload,
              0
            )
          ).to.be.revertedWith("INVALID_MESSAGE_TO_CONSUME");
        });
      });
    });
  });

  describe("L2 to L1 Flow", function () {
    let depositTokenIds: Array<number> = [];
    let withdrawnTokenIds: Array<number> = [];

    beforeEach(async function () {
      // before each withdraw test case, deposit 10 NFTs with tokenIds 1 -> 10
      await testNFT.setApprovalForAll(bridge.address, true);
      depositTokenIds = Array.from({ length: 10 }, (_, i) => i + 1);
      await bridge.deposit(testNFT.address, depositTokenIds, ownerL2Address);

      for (const tokenId of depositTokenIds) {
        expect(await testNFT.ownerOf(BigNumber.from(tokenId))).to.deep.equal(
          erc721Escrow.address
        );
      }
    });

    afterEach(async function () {
      // Expect that only the withdrawn token has changed owner
      for (const tokenId of depositTokenIds) {
        if (withdrawnTokenIds.indexOf(tokenId) > -1) {
          expect(await testNFT.ownerOf(BigNumber.from(tokenId))).to.deep.equal(
            owner.address
          );
        } else {
          expect(await testNFT.ownerOf(BigNumber.from(tokenId))).to.deep.equal(
            erc721Escrow.address
          );
        }
      }
    });
    describe("withdraw", function () {
      it("rightful claimant can withdraw a single token", async function () {
        withdrawnTokenIds = [depositTokenIds[0]];

        const tokenIdsBN = withdrawnTokenIds.map((x) => BigNumber.from(x));

        let payload = [
          testNFTl2Address,
          BigNumber.from(owner.address),
          BigNumber.from(testNFT.address),
          BigNumber.from(withdrawnTokenIds.length * 2), // number of deposited tokens
        ];

        for (const tokenId of withdrawnTokenIds) {
          const splitTokenId = splitUint256(BigNumber.from(tokenId));
          payload.push(splitTokenId.low);
          payload.push(splitTokenId.high);
        }

        await starknetMessagingMock.mockSendMessageFromL2(
          l2BridgeAddress,
          BigNumber.from(bridge.address),
          payload
        );

        await expect(
          bridge.withdraw(testNFT.address, tokenIdsBN, owner.address)
        )
          .to.emit(bridge, "Withdraw")
          .withArgs(owner.address, testNFT.address, tokenIdsBN);
      });

      it("rightful claimant can withdraw many tokens", async function () {
        withdrawnTokenIds = [
          depositTokenIds[0],
          depositTokenIds[1],
          depositTokenIds[2],
        ];

        let payload = [
          testNFTl2Address,
          BigNumber.from(owner.address),
          BigNumber.from(testNFT.address),
          BigNumber.from(withdrawnTokenIds.length * 2), // number of deposited tokens
        ];

        for (const tokenId of withdrawnTokenIds) {
          const splitTokenId = splitUint256(BigNumber.from(tokenId));
          payload.push(splitTokenId.low);
          payload.push(splitTokenId.high);
        }

        await starknetMessagingMock.mockSendMessageFromL2(
          l2BridgeAddress,
          BigNumber.from(bridge.address),
          payload
        );

        const tokenIdsBN = withdrawnTokenIds.map((x) => BigNumber.from(x));
        await expect(
          bridge.withdraw(testNFT.address, tokenIdsBN, owner.address)
        )
          .to.emit(bridge, "Withdraw")
          .withArgs(owner.address, testNFT.address, tokenIdsBN);
      });

      it("false claimmant cannot withdraw any tokens", async function () {
        withdrawnTokenIds = [depositTokenIds[0]];
        const splitTokenId = splitUint256(BigNumber.from(depositTokenIds[0]));

        await starknetMessagingMock.mockSendMessageFromL2(
          l2BridgeAddress,
          BigNumber.from(bridge.address),
          [
            l2BridgeAddress,
            BigNumber.from(owner.address),
            BigNumber.from(testNFT.address),
            BigNumber.from(withdrawnTokenIds.length * 2), // number of deposited tokens
            BigNumber.from(splitTokenId.low),
            BigNumber.from(splitTokenId.high),
          ]
        );

        // attempt to execute withdraw as user1
        await expect(
          bridge
            .connect(user1)
            .withdraw(testNFT.address, withdrawnTokenIds, user1.address)
        ).to.be.revertedWith("INVALID_MESSAGE_TO_CONSUME");

        // we expect no tokens to be withdraw successfully
        withdrawnTokenIds = [];
      });

      it("rightful claimant cannot withdraw more tokens than allocated", async function () {
        withdrawnTokenIds = [
          depositTokenIds[0],
          depositTokenIds[1],
          depositTokenIds[2],
        ];

        let payload = [
          testNFTl2Address,
          BigNumber.from(owner.address),
          BigNumber.from(testNFT.address),
          BigNumber.from(withdrawnTokenIds.length * 2), // number of deposited tokens
        ];

        for (const tokenId of withdrawnTokenIds) {
          const splitTokenId = splitUint256(BigNumber.from(tokenId));
          payload.push(splitTokenId.low);
          payload.push(splitTokenId.high);
        }

        await starknetMessagingMock.mockSendMessageFromL2(
          l2BridgeAddress,
          BigNumber.from(bridge.address),
          payload
        );

        // attempt to withdraw more than the tokenIds
        const tokenIdsBN = withdrawnTokenIds.map((x) => BigNumber.from(x));
        await expect(
          bridge.withdraw(
            testNFT.address,
            tokenIdsBN.concat(BigNumber.from("5")),
            owner.address
          )
        ).to.be.revertedWith("INVALID_MESSAGE_TO_CONSUME");

        // we expect no tokenIds to be withdrawn successfully
        withdrawnTokenIds = [];
      });

      it("attempting to withdraw an empty list of tokenIds fails", async function () {
        // we expect no tokens to be withdrawn successfully
        withdrawnTokenIds = [];
        // attempt to execute withdraw as user1
        await expect(
          bridge.connect(user1).withdraw(testNFT.address, [], owner.address)
        ).to.be.revertedWith("_tokenIds must not be empty");
      });

      it("attempt to withdraw a token which has not been deposited fails", async function () {
        const newNFT: ERC721TokenMock =
          (await deployTestNFT()) as ERC721TokenMock;
        await newNFT.mintBatch(newNFT.address, BigNumber.from("10"));
        await bridgeRegistry.registerToken(newNFT.address, testNFTl2Address);

        const tokenIdsBN = [BigNumber.from("1")];
        const splitTokenId = splitUint256(BigNumber.from("1"));

        let payload = [
          testNFTl2Address,
          BigNumber.from(owner.address),
          BigNumber.from(newNFT.address),
          BigNumber.from("2"), // number of deposited tokens * 2
          BigNumber.from(splitTokenId.low),
          BigNumber.from(splitTokenId.high),
        ];

        await starknetMessagingMock.mockSendMessageFromL2(
          l2BridgeAddress,
          BigNumber.from(bridge.address),
          payload
        );

        await expect(
          bridge.withdraw(newNFT.address, tokenIdsBN, owner.address)
        ).to.be.revertedWith(
          "ERC721: approve caller is not owner nor approved for all"
        );
      });
    });

    describe("isWithdrawable", function () {
      let tokenIdsBN: BigNumber[];

      beforeEach(async function () {
        // before each test case, we send a message from L2 -> L1 with a valid withdrawal
        withdrawnTokenIds = [
          depositTokenIds[0],
          depositTokenIds[1],
          depositTokenIds[2],
        ];

        tokenIdsBN = withdrawnTokenIds.map((x) => BigNumber.from(x));

        let payload = [
          testNFTl2Address,
          BigNumber.from(owner.address),
          BigNumber.from(testNFT.address),
          BigNumber.from(withdrawnTokenIds.length * 2), // number of deposited tokens
        ];

        for (const tokenId of withdrawnTokenIds) {
          const splitTokenId = splitUint256(BigNumber.from(tokenId));
          payload.push(splitTokenId.low);
          payload.push(splitTokenId.high);
        }

        await starknetMessagingMock.mockSendMessageFromL2(
          l2BridgeAddress,
          BigNumber.from(bridge.address),
          payload
        );
        withdrawnTokenIds = [];
      });

      it("returns true when withdraw is available", async function () {
        expect(
          await bridge.isWithdrawable(
            testNFT.address,
            tokenIdsBN,
            owner.address
          )
        ).to.be.true;
      });

      it("returns false when withdraw has incorrect withdrawer", async function () {
        expect(
          await bridge.isWithdrawable(
            testNFT.address,
            tokenIdsBN,
            user1.address
          )
        ).to.be.false;
      });

      it("return false when withdraw token has not been deposited", async function () {
        const newNFT: ERC721TokenMock =
          (await deployTestNFT()) as ERC721TokenMock;
        await newNFT.mintBatch(erc721Escrow.address, BigNumber.from("20"));
        await bridgeRegistry.registerToken(newNFT.address, testNFTl2Address);
        expect(
          await bridge.isWithdrawable(newNFT.address, tokenIdsBN, owner.address)
        ).to.be.false;
      });

      it("return false when withdraw tokens does not match L2 to L1 message", async function () {
        expect(
          await bridge.isWithdrawable(
            testNFT.address,
            tokenIdsBN.concat(BigNumber.from(5)),
            owner.address
          )
        ).to.be.false;
      });
    });
  });
});
