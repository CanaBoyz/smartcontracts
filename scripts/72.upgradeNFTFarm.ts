/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("NFTFarm upgrade")
    const { nftFarmAddress } = meta.read()

    const NFTFarm = await ethers.getContractFactory("NFTFarm")
    let proxy

    if (nftFarmAddress) {
        log("Upgrading...")
        proxy = await upgrades.upgradeProxy(nftFarmAddress, NFTFarm, {
            unsafeAllowRenames: true,
            // unsafeSkipStorageCheck: true,
        })
        await proxy.deployed()
        await waitTx(proxy.deployTransaction)
        log.success(`NFTFarm upgraded: ${yl(proxy.address)}`)
    } else {
        log.error(`nftFarmAddress not defined`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
