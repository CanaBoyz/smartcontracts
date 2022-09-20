import { BigNumber, constants } from "ethers"
import { ethers, upgrades, network } from "hardhat"
import { tokens, waitTx, untokens, unixTime } from "./lib/helpers"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)
const { Zero } = constants

async function main() {
    log.header("Distribute coin 1")
    const { coinDistribute1 = [], coinAddress } = meta.read()

    if (!coinAddress) {
        log.error(`coinAddress not defined`)
        return
    }
    if (!coinDistribute1.filter((d: any) => d.list && d.list.length).length) {
        log.error(`no one distribute list is defined`)
        return
    }

    if (!coinDistribute1.filter((d: any) => !d.complete).length) {
        log.error(`all distributions already completed`)
        return
    }

    const [deployer] = await ethers.getSigners()
    const coin = await ethers.getContractAt("Coin", coinAddress, deployer)

    for (const [i, d] of coinDistribute1.entries()) {
        if (d.complete || !d.list || !d.list.length) {
            continue
        }
        const { list } = d
        const { receivers, amounts } = list.reduce(
            (dl: { receivers: string[]; amounts: BigNumber[] }, [receiver, amount]: [string, number]) => {
                dl.receivers.push(receiver)
                dl.amounts.push(tokens(amount))
                return dl
            },
            { receivers: [], amounts: [] },
        )
        log(
            `Distributing ${untokens(amounts.reduce((n: BigNumber, a: BigNumber) => n.add(a), Zero))} Coins to ${
                receivers.length
            } receivers`
        )
        await waitTx(await coin.connect(deployer).distribute(receivers, amounts))
        coinDistribute1.splice(i, 1, { ...coinDistribute1[i], complete: 1 })
        meta.write({ coinDistribute1 })
    }
    log.success("Distributed")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
