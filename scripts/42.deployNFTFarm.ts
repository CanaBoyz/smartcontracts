/* eslint-disable prefer-const */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract, constants } from "ethers"
import { checkParams, tokens, waitTx } from "./lib/helpers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const { AddressZero } = constants
const meta = metaInit(network.name)

async function main() {
    log.header("Nft yield deploy")
    let { nftFarmAddress, nftFarmParams, nftAddress, coinAddress, depositWalletAddress } = meta.read()
    const [deployer] = await ethers.getSigners()

    if (
        !checkParams({
            nftAddress,
            coinAddress,
            depositWalletAddress,
            nftFarmParams,
        })
    )
        return

    let nftFarm: Contract
    if (!nftFarmAddress) {
        log(`Deploying NFTFarm...`)
        const { yieldPerPeriod = 5000, farmPeriod = 86400, stopDate = 0 } = nftFarmParams
        const NFTFarm = await ethers.getContractFactory("NFTFarm")
        nftFarm = await upgrades.deployProxy(NFTFarm, [coinAddress, nftAddress, depositWalletAddress, tokens(yieldPerPeriod), farmPeriod, stopDate], {
            kind: "uups",
        })
        await nftFarm.deployed()
        await waitTx(nftFarm.deployTransaction)
        nftFarmAddress = nftFarm.address
        meta.write({ nftFarmAddress })
    } else {
        nftFarm = await ethers.getContractAt("NFTFarm", nftFarmAddress, deployer)
        log(`Using existing NFTFarm: ${yl(nftFarmAddress)}`)
    }
    log.success(`NFTFarm deployed: ${yl(nftFarmAddress)}`)

    const coin = await ethers.getContractAt("Coin", coinAddress, deployer)
    const nft = await ethers.getContractAt("NFT", nftAddress, deployer)
    log(`Check roles...`)
    const OPERATOR_ROLE = await coin.OPERATOR_ROLE()
    if (!(await coin.hasRole(OPERATOR_ROLE, nftFarm.address))) {
        log(`Granting OPERATOR_ROLE on Coin...`)
        await waitTx(await coin.connect(deployer).grantRole(OPERATOR_ROLE, nftFarm.address))
    }
    log.success(`OPERATOR_ROLE granted to: ${yl(nftFarm.address)}`)

    if (!(await nft.hasRole(OPERATOR_ROLE, nftFarm.address))) {
        log(`Granting OPERATOR_ROLE on NFT...`)
        await waitTx(await nft.connect(deployer).grantRole(OPERATOR_ROLE, nftFarm.address))
    }
    log.success(`OPERATOR_ROLE granted to: ${yl(nftFarm.address)}`)

    log(`Check operators...`)
    const { operators = [] } = nftFarmParams
    // const OPERATOR_ROLE = await nftFarm.OPERATOR_ROLE()
    for (const m of operators) {
        if (!(await nftFarm.hasRole(OPERATOR_ROLE, m))) {
            log(`Granting OPERATOR_ROLE to ${yl(m)}...`)
            await waitTx(await nftFarm.connect(deployer).grantRole(OPERATOR_ROLE, m))
        }
        log.success(`OPERATOR_ROLE granted to ${yl(m)}`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
