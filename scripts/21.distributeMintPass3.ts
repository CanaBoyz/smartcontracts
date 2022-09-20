import { ethers, upgrades, network } from "hardhat"
import { tokens, waitTx, untokens, unixTime } from "./lib/helpers"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Distribute MintPass 3")
    const { distribute3, mintPassCardAddress } = meta.read()

    if (!mintPassCardAddress) {
        log.error(`mintPassCardAddress not defined`)
        return
    }
    if (!distribute3 || !distribute3.length) {
        log.error(`distribute3 not defined`)
        return
    }
    const tos: string[] = []
    const levels: number[] = []
    for (const { receivers, level } of distribute3) {
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
