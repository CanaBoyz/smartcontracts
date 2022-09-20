/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Referrals upgrade")
    const { referralsAddress } = meta.read()

    const Referrals = await ethers.getContractFactory("Referrals")
    let proxy

    if (referralsAddress) {
        log("Upgrading...")
        proxy = await upgrades.upgradeProxy(referralsAddress, Referrals, {
            unsafeAllowRenames: true,
            // unsafeSkipStorageCheck: true,
        })
        await proxy.deployed()
        await waitTx(proxy.deployTransaction)
        log.success(`Referrals upgraded: ${yl(proxy.address)}`)
    } else {
        log.error(`referralsAddress not defined`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
