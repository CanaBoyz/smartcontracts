/* eslint-disable prefer-const */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract } from "ethers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Shop deploy")
    let { shopParams = {}, shopAddress } = meta.read()
    const [deployer] = await ethers.getSigners()
    let shop: Contract
    if (!shopAddress) {
        log(`Deploying Shop...`)
        const { name, symbol, baseTokenURI = "", tokenURIPre = "", tokenURIPost = "" } = shopParams
        const Shop = await ethers.getContractFactory("Shop")
        shop = await upgrades.deployProxy(Shop, [name, symbol, baseTokenURI, tokenURIPre, tokenURIPost], {
            kind: "uups",
        })
        await shop.deployed()
        await waitTx(shop.deployTransaction)
        shopAddress = shop.address
        meta.write({ shopAddress })
    } else {
        shop = await ethers.getContractAt("Shop", shopAddress, deployer)
        log(`Using existing Shop: ${yl(shopAddress)}`)
    }
    log.success(`Shop deployed: ${yl(shopAddress)}`)

    log(`Check minters...`)
    const { minters = [] } = shopParams
    const MINTER_ROLE = await shop.MINTER_ROLE()
    for (const m of minters) {
        if (!(await shop.hasRole(MINTER_ROLE, m))) {
            log(`Granting MINTER_ROLE to minter...`)
            await waitTx(await shop.connect(deployer).grantRole(MINTER_ROLE, m))
        }
        log.success(`MINTER_ROLE granted to minter: ${yl(m)}`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
