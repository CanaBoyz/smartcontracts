/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Seller upgrade")
    const { sellerAddress } = meta.read()

    const Seller = await ethers.getContractFactory("Seller")
    let proxy

    if (sellerAddress) {
        log("Upgrading...")
        proxy = await upgrades.upgradeProxy(sellerAddress, Seller, {
            unsafeAllowRenames: true,
            // unsafeSkipStorageCheck: true,
        })
        await proxy.deployed()
        await waitTx(proxy.deployTransaction)
        log.success(`Seller upgraded: ${yl(proxy.address)}`)
    } else {
        log.error(`sellerAddress not defined`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
