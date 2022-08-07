import { Account } from "@shardlabs/starknet-hardhat-plugin/dist/src/account";
import { starknet } from "hardhat";

async function deployLogAccount() {
  const starknetAccount: Account = await starknet.deployAccount("OpenZeppelin");
  console.log(`ADDRESS=${starknetAccount.address}`);
  console.log(`PKEY=${starknetAccount.privateKey}`);
  process.exit(0);
}

deployLogAccount().then(() => console.log("Finished deploying account"));
