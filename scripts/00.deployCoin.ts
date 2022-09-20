import { Contract } from "ethers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Coin deploy")
    let { coinParams, coinAddress, hookAddresses = {} } = meta.read()
    const [deployer] = await ethers.getSigners()
    let coin: Contract
    if (!coinAddress) {
        log(`Deploying Coin...`)
        const { name, symbol, initialSupply, initialHolder, feeFromForced, feeToForced, feeDefault } = coinParams
        const Coin = await ethers.getContractFactory("Coin")
        coin = await upgrades.deployProxy(Coin, [name, symbol, tokens(initialSupply), initialHolder, feeFromForced, feeToForced, feeDefault], {
            kind: "uups",
        })
        await coin.deployed()
        await waitTx(coin.deployTransaction)
        coinAddress = coin.address
        meta.write({ coinAddress })
    } else {
        coin = await ethers.getContractAt("Coin", coinAddress, deployer)
        log(`Using existing Coin: ${yl(coinAddress)}`)
    }
    log.success(`Coin deployed: ${yl(coinAddress)}`)

    if (coinParams && coinParams.hooks && coinParams.hooks.length) {
        for (const { artifact, params = [] } of coinParams.hooks) {
            let hookAddress = hookAddresses[`${artifact}Address`]
            let hook
            if (!hookAddress) {
                log(`Deploying ${artifact}...`)
                const Hook = await ethers.getContractFactory(artifact)
                hook = await upgrades.deployProxy(Hook, params, {
                    kind: "uups",
                })
                await hook.deployed()
                await waitTx(hook.deployTransaction)
                hookAddress = hook.address
                hookAddresses[`${artifact}Address`] = hookAddress
                console.log(hookAddresses)
                meta.write({ hookAddresses })
            }
            log.success(`${artifact} deployed: ${yl(hookAddress)}`)
            //set hook url
            if (!(await coin.hookExists(hookAddress))) {
                log(`Adding ${artifact} to coin...`)
                await waitTx(await coin.addHook(hookAddress))
            }
            log.success(`${artifact} added to coin`)
        }
        if (!(await coin.hooksEnabled())) {
            log(`Enabling hooks...`)
            await waitTx(await coin.enableHooks(true))
        }
        log.success(`Hooks enabled`)
    } else {
        log(`Skip hooks deploy`)
        if (await coin.hooksEnabled()) {
            log(`Disabling hooks...`)
            await waitTx(await coin.enableHooks(false))
        }
        log.success(`Hooks disabled`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
