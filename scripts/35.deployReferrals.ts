/* eslint-disable prefer-const */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract } from "ethers"
import { checkParams, tokens, waitTx } from "./lib/helpers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Referrals deploy")
    let { referralsParams, referralsAddress, walletAddress } = meta.read()
    const { levelRewardPercents } = referralsParams
    const [deployer] = await ethers.getSigners()
    let referrals: Contract

    if (
        !checkParams({
            walletAddress,
            referralsParams,
            levelRewardPercents,
        })
    )
        return

    if (!referralsAddress) {
        log(`Deploying Referrals...`)
        const Referrals = await ethers.getContractFactory("Referrals")
        referrals = await upgrades.deployProxy(Referrals, [walletAddress, levelRewardPercents.map((v: number) => Math.floor(v * 100))], {
            kind: "uups",
        })
        await referrals.deployed()
        await waitTx(referrals.deployTransaction)
        referralsAddress = referrals.address
        meta.write({ referralsAddress })
    } else {
        referrals = await ethers.getContractAt("Referrals", referralsAddress, deployer)
        log(`Using existing Referrals: ${yl(referralsAddress)}`)
    }
    log.success(`Referrals deployed: ${yl(referralsAddress)}`)

    log.success(`Check level rewards...`)

    const rewards = await referrals.getRefLevelRewardPercents()
    if (rewards.length !== levelRewardPercents.length || rewards.every((v: number, i: number) => v === levelRewardPercents[i])) {
        log(`Updating level rewards...`)
        await waitTx(await referrals.connect(deployer).setRefLevelRewardPercents(levelRewardPercents))
    }
    log.success(`Level rewards set`)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
