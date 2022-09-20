import { ethers, upgrades, network } from "hardhat"
import { tokens, waitTx, untokens, unixTime } from "./lib/helpers"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Start MintPassCard Sale")
    const { mintPassCardSaleParams, mintPassCardParams, cardSellerAddress, mintPassCardAddress } = meta.read()

    if (!mintPassCardAddress) {
        log.error(`mintPassCardAddress not defined`)
        return
    }
    if (!mintPassCardParams) {
        log.error(`mintPassCardParams not defined`)
        return
    }
    if (!mintPassCardSaleParams) {
        log.error(`mintPassCardSaleParams not defined`)
        return
    }
    if (!cardSellerAddress) {
        log.error(`cardSellerAddress not defined`)
        return
    }

    const { levels = [] } = mintPassCardParams
    let { levelAmounts = [] } = mintPassCardSaleParams
    if (!levels.length || !levels.length == levelAmounts.length) {
        log.error(`incorrect levels`)
        return
    }
    const [deployer] = await ethers.getSigners()
    const seller = await ethers.getContractAt("CardSeller", cardSellerAddress, deployer)

    log(`Set sale...`)
    await waitTx(await seller.connect(deployer).setupSale(mintPassCardAddress, levels, levelAmounts))
    log.success("Sale set")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
