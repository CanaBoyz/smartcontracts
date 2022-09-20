/* eslint-disable prefer-const */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract } from "ethers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Item deploy")
    let { itemParams = {}, itemAddress } = meta.read()
    const [deployer] = await ethers.getSigners()
    let item: Contract
    if (!itemAddress) {
        log(`Deploying Item...`)
        const { name, symbol, baseTokenURI = "", tokenURIPre = "", tokenURIPost = "" } = itemParams
        const Item = await ethers.getContractFactory("Item")
        item = await upgrades.deployProxy(Item, [name, symbol, baseTokenURI, tokenURIPre, tokenURIPost], {
            kind: "uups",
        })
        await item.deployed()
        await waitTx(item.deployTransaction)
        itemAddress = item.address
        meta.write({ itemAddress })
    } else {
        item = await ethers.getContractAt("Item", itemAddress, deployer)
        log(`Using existing Item: ${yl(itemAddress)}`)
    }
    log.success(`Item deployed: ${yl(itemAddress)}`)

    log(`Check minters...`)
    const { minters = [], kindProps = {} } = itemParams
    const MINTER_ROLE = await item.MINTER_ROLE()
    for (const m of minters) {
        if (!(await item.hasRole(MINTER_ROLE, m))) {
            log(`Granting MINTER_ROLE to minter...`)
            await waitTx(await item.connect(deployer).grantRole(MINTER_ROLE, m))
        }
        log.success(`MINTER_ROLE granted to minter: ${yl(m)}`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
