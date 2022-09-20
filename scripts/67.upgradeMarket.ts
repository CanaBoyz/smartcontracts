/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Markets upgrade")
    const { marketAddress } = meta.read()

    const Market = await ethers.getContractFactory("Market")
    let proxy

    if (marketAddress) {
        log("Upgrading...")
        proxy = await upgrades.upgradeProxy(marketAddress, Market, {
            unsafeAllowRenames: true,
            // unsafeSkipStorageCheck: true,
        })
        await proxy.deployed()
        await waitTx(proxy.deployTransaction)
        log.success(`Market upgraded: ${yl(proxy.address)}`)
    } else {
        log.error(`marketAddress not defined`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
