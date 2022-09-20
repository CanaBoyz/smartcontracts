import * as dotenv from "dotenv"

import "@nomiclabs/hardhat-etherscan"
import "@nomiclabs/hardhat-waffle"
import "@openzeppelin/hardhat-upgrades"
import "@typechain/hardhat"
import "hardhat-abi-exporter"
import "hardhat-gas-reporter"
import "solidity-coverage"
import { HardhatUserConfig, task } from "hardhat/config"

import secrets from "./secrets.json"
dotenv.config()

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners()

    for (const account of accounts) {
        console.log(account.address)
    }
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.15",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
            evmVersion: "london",
        },
    },
    networks: {
        localhost: {
            url: "http://127.0.0.1:8545",
        },
        testnet: {
            url: "https://data-seed-prebsc-2-s2.binance.org:8545/",
            chainId: 97,
            gasPrice: 10000000000,
            accounts: [secrets.testnet.privateKey],
            timeout: 120000,
        },
        mainnet: {
            url: "https://bsc-dataseed1.ninicoin.io/",
            chainId: 56,
            gasPrice: 5000000000,
            accounts: [secrets.mainnet.privateKey],
            timeout: 120000,
        },
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS !== undefined,
        currency: "USD",
    },
    etherscan: {
        // Your API key for Etherscan
        // Obtain one at https://bscscan.com/
        apiKey: {
            // binance smart chain
            bsc: secrets.etherscanApiKey,
            bscTestnet: secrets.etherscanApiKey,
        },
    },
    abiExporter: {
        path: "./abi",
        runOnCompile: true,
        clear: true,
        flat: true,
        only: [
            ":Item",
            ":Coin",
            ":Shop",
            ":Market",
            ":Card",
            ":Game",
            ":Plant",
            ":NFT",
            ":Inner",
            ":Lab",
            ":Seller",
            ":WhiteList",
            ":DepositWallet",
            ":Referrals",
            ":Hook",
        ],
        except: ["Mock", "Upgrade", "Test", "Service"],
        spacing: 2,
        pretty: false,
    },
}

export default config
