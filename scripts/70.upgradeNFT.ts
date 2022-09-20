/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("NFT upgrade")
    const { nftAddress } = meta.read()

    const NFT = await ethers.getContractFactory("NFT")
    let proxy

    if (nftAddress) {
        log("Upgrading...")
        proxy = await upgrades.upgradeProxy(nftAddress, NFT, {
            unsafeAllowRenames: true,
            // unsafeSkipStorageCheck: true,
        })
        await proxy.deployed()
        await waitTx(proxy.deployTransaction)
        log.success(`NFT upgraded: ${yl(proxy.address)}`)
    } else {
        log.error(`nftAddress not defined`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
