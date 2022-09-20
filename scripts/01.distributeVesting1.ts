import { BigNumber, constants } from "ethers"
import { ethers, upgrades, network } from "hardhat"
import { tokens, waitTx, untokens, unixTime } from "./lib/helpers"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)
const { Zero } = constants

async function main() {
  log.header("Distribute vesting")
  const { coinDistributeVested1 = [], coinAddress } = meta.read()

  if (!coinAddress) {
    log.error(`coinAddress not defined`)
    return
  }
  if (!coinDistributeVested1.filter((d: any) => d.list && d.list.length).length) {
    log.error(`no one distribute list is defined`)
    return
  }

  if (!coinDistributeVested1.filter((d: any) => !d.complete).length) {
    log.error(`all distributions already completed`)
    return
  }

  const [deployer] = await ethers.getSigners()
  const coin = await ethers.getContractAt("Coin", coinAddress, deployer)

  for (const [i, d] of coinDistributeVested1.entries()) {
    const { list, revokable = true, complete = false, start, cliff, end } = d
    if (complete || !list || !list.length) {
      continue
    }
    // const { list, start, cliff, end, revokable = true } = d
    const { receivers, amounts } = list.reduce(
      (dl: { receivers: string[]; amounts: BigNumber[] }, [receiver, amount]: [string, number]) => {
        dl.receivers.push(receiver)
        dl.amounts.push(tokens(amount))
        return dl
      },
      { receivers: [], amounts: [] }
    )
    log(
      `Distributing ${untokens(amounts.reduce((n: BigNumber, a: BigNumber) => n.add(a), Zero))} Coins to ${
        receivers.length
      } receivers with:` +
        `\n> start ${new Date(start * 1000).toLocaleDateString()}, ` +
        `\n> cliff ${new Date(cliff * 1000).toLocaleDateString()}, ` +
        `\n> end ${new Date(end * 1000).toLocaleDateString()}, `,
      `\n> revokable: ${revokable}...`
    )
    await waitTx(await coin.connect(deployer).distributeVested(receivers, amounts, start, cliff, end, revokable))
    coinDistributeVested1.splice(i, 1, { ...coinDistributeVested1[i], complete: 1 })
    meta.write({ coinDistributeVested1 })
  }
  log.success("Distributed")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
