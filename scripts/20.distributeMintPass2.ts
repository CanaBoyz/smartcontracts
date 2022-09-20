import { ethers, upgrades, network } from "hardhat"
import { tokens, waitTx, untokens, unixTime } from "./lib/helpers"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Distribute MintPass 2")
    const { distribute2, mintPassCardAddress } = meta.read()

    if (!mintPassCardAddress) {
        log.error(`mintPassCardAddress not defined`)
        return
    }
    if (!distribute2 || !distribute2.length) {
        log.error(`distribute2 not defined`)
        return
    }
    const tos: string[] = []
    const levels: number[] = []
    for (const { receivers, level } of distribute2) {
        receivers.forEach((r: string) => {
            tos.push(r)
            levels.push(level)
        })
    }

    const [deployer] = await ethers.getSigners()
    const card = await ethers.getContractAt("Card", mintPassCardAddress, deployer)
    if (!tos.length) {
        log.error(`Distribute list empty`)
        return
    }
    console.log({tos, levels});

    log(`Distributing ${tos.length} mint passes...`)
    await waitTx(await card.connect(deployer).mintBatch(tos, levels))
    log.success("Distributed")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
