/* eslint-disable prefer-const */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract } from "ethers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("InnerCoin deploy")
    let { innerCoinParams, innerCoinAddress } = meta.read()
    const [deployer] = await ethers.getSigners()
    let coin: Contract
    if (!innerCoinAddress) {
        log(`Deploying InnerCoin...`)
        const { name, symbol, feeFromForced, feeToForced, feeDefault } = innerCoinParams
        const InnerCoin = await ethers.getContractFactory("InnerCoin")
        coin = await upgrades.deployProxy(InnerCoin, [name, symbol, feeFromForced, feeToForced, feeDefault], {
            kind: "uups",
        })
        await coin.deployed()
        await waitTx(coin.deployTransaction)
        innerCoinAddress = coin.address
        meta.write({ innerCoinAddress })
    } else {
        coin = await ethers.getContractAt("InnerCoin", innerCoinAddress, deployer)
        log(`Using existing InnerCoin: ${yl(innerCoinAddress)}`)
    }
    log.success(`Coin deployed: ${yl(innerCoinAddress)}`)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
