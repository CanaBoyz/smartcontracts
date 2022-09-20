/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract } from "ethers"
import { checkParams, tokens, waitTx } from "./lib/helpers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Market deploy")
    const {
        marketParams,
        marketAddress,
        itemAddress,
        shopAddress,
        priceFeedAddress,
        walletAddress,
        routerAddress,
        busdAddress,
        coinAddress,
        innerCoinAddress,
        referralsAddress,
    } = meta.read()
    const { minters = [], itemPrices } = marketParams
    const [deployer] = await ethers.getSigners()
    let market: Contract

    if (
        !checkParams({
            marketParams,
            itemAddress,
            shopAddress,
            priceFeedAddress,
            walletAddress,
            routerAddress,
            busdAddress,
            coinAddress,
            innerCoinAddress,
            referralsAddress,
            itemPrices,
        })
    )
        return

    if (!marketAddress) {
        log(`Deploying Market...`)
        const Market = await ethers.getContractFactory("Market")
        market = await upgrades.deployProxy(
            Market,
            [walletAddress, itemAddress, shopAddress, coinAddress, innerCoinAddress, busdAddress, routerAddress, referralsAddress],
            {
                kind: "uups",
            }
        )
        await market.deployed()
        await waitTx(market.deployTransaction)
        meta.write({ marketAddress: market.address })
        log.success(`Market deployed: ${yl(market.address)}`)
    } else {
        market = await ethers.getContractAt("Market", marketAddress, deployer)
        log(`Using existing Market: ${yl(marketAddress)}`)
    }

    const shop = await ethers.getContractAt("Shop", shopAddress, deployer)
    const item = await ethers.getContractAt("Item", itemAddress, deployer)
    const coin = await ethers.getContractAt("Coin", coinAddress, deployer)
    const innerCoin = await ethers.getContractAt("InnerCoin", innerCoinAddress, deployer)
    const referrals = await ethers.getContractAt("Referrals", referralsAddress, deployer)

    log(`Check setup...`)
    if ((await market.getWallet()) != walletAddress) {
        log(`Update walletAddress..`)
        await waitTx(await market.connect(deployer).setWallet(walletAddress))
    }
    if ((await market.getReferralsContract()) != referralsAddress) {
        log(`Update referralsAddress..`)
        await waitTx(await market.connect(deployer).setReferralsContract(referralsAddress))
    }

    log(`Setup roles...`)
    const MINTER_ROLE = await item.MINTER_ROLE()
    const OPERATOR_ROLE = await item.OPERATOR_ROLE()

    if (!(await item.hasRole(MINTER_ROLE, market.address))) {
        await waitTx(await item.connect(deployer).grantRole(MINTER_ROLE, market.address))
    }
    log.success(`MINTER_ROLE granted to market at Item`)

    if (!(await item.hasRole(OPERATOR_ROLE, market.address))) {
        await waitTx(await item.connect(deployer).grantRole(OPERATOR_ROLE, market.address))
    }
    log.success(`OPERATOR_ROLE granted to market at Item`)

    if (!(await shop.hasRole(MINTER_ROLE, market.address))) {
        await waitTx(await shop.connect(deployer).grantRole(MINTER_ROLE, market.address))
    }
    log.success(`MINTER_ROLE granted to market at Shop`)

    if (!(await shop.hasRole(OPERATOR_ROLE, market.address))) {
        await waitTx(await shop.connect(deployer).grantRole(OPERATOR_ROLE, market.address))
    }
    log.success(`OPERATOR_ROLE granted to market at Shop`)

    if (!(await coin.hasRole(OPERATOR_ROLE, market.address))) {
        await waitTx(await coin.connect(deployer).grantRole(OPERATOR_ROLE, market.address))
    }
    log.success(`OPERATOR_ROLE granted to market at Coin`)

    if (!(await innerCoin.hasRole(OPERATOR_ROLE, market.address))) {
        await waitTx(await innerCoin.connect(deployer).grantRole(OPERATOR_ROLE, market.address))
    }

    if (!(await referrals.hasRole(OPERATOR_ROLE, market.address))) {
        await waitTx(await referrals.connect(deployer).grantRole(OPERATOR_ROLE, market.address))
    }
    log.success(`OPERATOR_ROLE granted to market at Referrals`)

    log.success(`Check item prices...`)

    const ids = Object.keys(itemPrices).map(Number)
    const prices = Object.values(itemPrices).map((x: any) => [tokens(x[0]), tokens(x[1])])
    const p = await market.getItemsPrices(ids)

    // console.log(p)
    let sync = false
    for (let i = 0; i < ids.length; ++i) {
        // console.log(p[i]);
        const { buyPriceUSD, sellPriceUSD } = p[i]
        if (!buyPriceUSD.eq(prices[i][0]) || !sellPriceUSD.eq(prices[i][1])) {
            sync = true
            break
        }
    }
    if (sync) {
        log.success(`Syncing...`)
        await waitTx(await market.setItemsPrices(ids, prices))
    }
    log.success(`Item prices set`)

    log(`Check minters...`)

    for (const m of minters) {
        if (!(await market.hasRole(MINTER_ROLE, m))) {
            log(`Granting MINTER_ROLE to minter...`)
            await waitTx(await market.connect(deployer).grantRole(MINTER_ROLE, m))
        }
        log.success(`MINTER_ROLE granted to minter: ${yl(m)}`)
    }

    // const { kindProps } = marketParams
    // const params = await market.getKindProps()
    // for (const p of params) {
    // }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
