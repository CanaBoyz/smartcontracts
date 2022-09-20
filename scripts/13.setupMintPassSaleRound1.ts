import { ethers, upgrades, network } from "hardhat"
import { tokens, waitTx, untokens, unixTime } from "./lib/helpers"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Start MintPassCard Sale Round 1")
    const { mintPassCardSaleRoundParams1, cardSellerAddress } = meta.read()

    if (!mintPassCardSaleRoundParams1) {
        log.error(`mintPassCardSaleRoundParams1 not defined`)
        return
    }
    if (!cardSellerAddress) {
        log.error(`cardSellerAddress not defined`)
        return
    }

    let {
        price,
        start = unixTime(), //now
        duration = 0,
        amount = 0,
        roundId = 0,
    } = mintPassCardSaleRoundParams1

    if (!roundId) {
        log.error(`roundId not set`)
        return
    }

    const [deployer] = await ethers.getSigners()
    const seller = await ethers.getContractAt("CardSeller", cardSellerAddress, deployer)

    let [round, id] = await seller.getSaleRound()
    console.log(round, id);
    if (start && round.start.toNumber() === start) {
        throw new Error("Sale already started")
    }
    log(`Starting sale round...`)
    if (!start) {
        start = unixTime() //now
    }
    await waitTx(await seller.connect(deployer).setupSaleRound(start, duration, tokens(price), amount, roundId))
    log.success("Sale round set")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
