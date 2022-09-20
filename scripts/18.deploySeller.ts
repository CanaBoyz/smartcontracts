/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract } from "ethers"
import { checkParams, tokens, waitTx } from "./lib/helpers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Seller deploy")
    const { sellerAddress, sellerParams, mintPassCardAddress, walletAddress, whitelistAddress, referralsAddress } = meta.read()
    const { sellers = [], wlOperators = [] } = sellerParams
    const [deployer] = await ethers.getSigners()
    const Seller = await ethers.getContractFactory("Seller")

    let wl: Contract

    if (
        !checkParams({
            sellerParams,
            mintPassCardAddress,
            walletAddress,
            referralsAddress,
        })
    )
        return
    if (!whitelistAddress) {
        const WhiteList = await ethers.getContractFactory("WhiteList")
        log(`Deploying Whitelist...`)
        wl = await upgrades.deployProxy(WhiteList, [], {
            kind: "uups",
        })
        await wl.deployed()
        await waitTx(wl.deployTransaction)
        meta.write({ whitelistAddress: wl.address })
        log.success(`Whitelist deployed: ${yl(wl.address)}`)
    } else {
        wl = await ethers.getContractAt("WhiteList", whitelistAddress, deployer)
        log(`WhiteList existing seller: ${yl(whitelistAddress)}`)
    }

    let seller: Contract
    if (!sellerAddress) {
        log(`Deploying seller...`)
        seller = await upgrades.deployProxy(Seller, [walletAddress, mintPassCardAddress, referralsAddress], {
            kind: "uups",
        })
        await seller.deployed()
        await waitTx(seller.deployTransaction)
        meta.write({ sellerAddress: seller.address })
        log.success(`Seller deployed: ${yl(seller.address)}`)
    } else {
        seller = await ethers.getContractAt("Seller", sellerAddress, deployer)
        log(`Using existing seller: ${yl(sellerAddress)}`)
    }

    const card = await ethers.getContractAt("Card", mintPassCardAddress, deployer)
    const referrals = await ethers.getContractAt("Referrals", referralsAddress, deployer)

    log(`Check setup...`)
    if ((await seller.getWallet()) != walletAddress) {
        log(`Update walletAddress..`)
        await waitTx(await seller.connect(deployer).setWallet(walletAddress))
    }
    if ((await seller.getReferralsContract()) != referralsAddress) {
        log(`Update referralsAddress..`)
        await waitTx(await seller.connect(deployer).setReferralsContract(referralsAddress))
    }

    log(`Check roles...`)
    const OPERATOR_ROLE = await card.OPERATOR_ROLE()
    if (!(await card.hasRole(OPERATOR_ROLE, seller.address))) {
        log(`Granting OPERATOR_ROLE to operator...`)
        await waitTx(await card.connect(deployer).grantRole(OPERATOR_ROLE, seller.address))
    }
    log.success(`OPERATOR_ROLE granted to operator: ${yl(seller.address)}`)

    if (!(await referrals.hasRole(OPERATOR_ROLE, seller.address))) {
        await waitTx(await referrals.connect(deployer).grantRole(OPERATOR_ROLE, seller.address))
    }
    log.success(`OPERATOR_ROLE granted to market at Referrals`)

    log(`Check sellers...`)
    const SELLER_ROLE = await seller.SELLER_ROLE()
    for (const m of sellers) {
        if (!(await seller.hasRole(SELLER_ROLE, m))) {
            log(`Granting SELLER_ROLE to seller...`)
            await waitTx(await seller.connect(deployer).grantRole(SELLER_ROLE, m))
        }
        log.success(`SELLER_ROLE granted to seller: ${yl(m)}`)
    }

    log(`Check Whitelist operators...`)
    // const OPERATOR_ROLE = await card.OPERATOR_ROLE()
    for (const m of wlOperators) {
        if (!(await wl.hasRole(OPERATOR_ROLE, m))) {
            log(`Granting Whitelist OPERATOR_ROLE to operator...`)
            await waitTx(await wl.connect(deployer).grantRole(OPERATOR_ROLE, m))
        }
        log.success(`Whitelist OPERATOR_ROLE granted to operator: ${yl(m)}`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
