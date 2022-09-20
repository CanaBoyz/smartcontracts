/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("DepositWallet upgrade")
    const { depositWalletAddress } = meta.read()

    const DepositWallet = await ethers.getContractFactory("DepositWallet")
    let proxy

    if (depositWalletAddress) {
        log("Upgrading...")
        proxy = await upgrades.upgradeProxy(depositWalletAddress, DepositWallet, {
            unsafeAllowRenames: true,
            // unsafeSkipStorageCheck: true,
        })
        await proxy.deployed()
        await waitTx(proxy.deployTransaction)
        log.success(`DepositWallet upgraded: ${yl(proxy.address)}`)
    } else {
        log.error(`depositWalletAddress not defined`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
