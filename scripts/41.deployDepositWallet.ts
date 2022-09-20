/* eslint-disable prefer-const */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract, constants } from "ethers"
import { checkParams, tokens, waitTx } from "./lib/helpers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

const { AddressZero } = constants

async function main() {
    log.header("Nft yield deploy")
    let { depositWalletAddress, coinAddress, walletAddress, marketAddress, depositWalletParams } = meta.read()
    const { withdrawFee } = depositWalletParams
    const [deployer] = await ethers.getSigners()

    if (
        !checkParams({
            coinAddress,
            walletAddress,
            marketAddress,
            depositWalletParams,
            withdrawFee,
        })
    )
        return

    let depositWallet: Contract
    if (!depositWalletAddress) {
        log(`Deploying DepositWallet...`)
        const DepositWallet = await ethers.getContractFactory("DepositWallet")
        depositWallet = await upgrades.deployProxy(DepositWallet, [coinAddress, walletAddress, marketAddress, withdrawFee], {
            kind: "uups",
        })
        await depositWallet.deployed()
        await waitTx(depositWallet.deployTransaction)
        depositWalletAddress = depositWallet.address
        meta.write({ depositWalletAddress })
    } else {
        depositWallet = await ethers.getContractAt("DepositWallet", depositWalletAddress, deployer)
        log(`Using existing DepositWallet: ${yl(depositWalletAddress)}`)
    }
    log.success(`DepositWallet deployed: ${yl(depositWalletAddress)}`)

    const coin = await ethers.getContractAt("Coin", coinAddress, deployer)
    const market = await ethers.getContractAt("Market", marketAddress, deployer)

    log(`Check setup...`)
    if ((await depositWallet.getWallet()) != walletAddress) {
        log(`Update marketAddress..`)
        await waitTx(await depositWallet.connect(deployer).setWallet(walletAddress))
    }
    if ((await depositWallet.getMerketContract()) != marketAddress) {
        log(`Update marketAddress..`)
        await waitTx(await depositWallet.connect(deployer).setMarketContract(marketAddress))
    }
    if ((await depositWallet.getWithdrawFee()) != withdrawFee) {
        log(`Update withdrawFee..`)
        await waitTx(await depositWallet.connect(deployer).setWithdrawFee(withdrawFee))
    }

    log(`Check roles...`)
    const OPERATOR_ROLE = await coin.OPERATOR_ROLE()
    if (!(await coin.hasRole(OPERATOR_ROLE, depositWallet.address))) {
        log(`Granting OPERATOR_ROLE to operator...`)
        await waitTx(await coin.connect(deployer).grantRole(OPERATOR_ROLE, depositWallet.address))
    }
    log.success(`OPERATOR_ROLE granted on Coin`)

    // if (!(await market.hasRole(OPERATOR_ROLE, depositWallet.address))) {
    //     log(`Granting OPERATOR_ROLE to operator...`)
    //     await waitTx(await market.connect(deployer).grantRole(OPERATOR_ROLE, depositWallet.address))
    // }
    // log.success(`OPERATOR_ROLE granted on Market`)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
