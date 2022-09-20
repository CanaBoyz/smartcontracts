import { ethers, upgrades, network } from "hardhat"
import { tokens, waitTx, untokens, unixTime } from "./lib/helpers"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("DistributeMulti1 MintPass")
  const { distributeMulti1, mintPassCardAddress } = meta.read()

  if (!mintPassCardAddress) {
    log.error(`mintPassCardAddress not defined`)
    return
  }
  if (!distributeMulti1 || !distributeMulti1.length) {
    log.error(`distributeMulti1 not defined`)
    return
  }
  const [deployer] = await ethers.getSigners()
  const card = await ethers.getContractAt("Card", mintPassCardAddress, deployer)

  const tos: string[] = []
  const levels: number[] = []
  const amounts: number[] = []
  let nonce = await deployer.getTransactionCount()
  for (const [i, d] of distributeMulti1.entries()) {
    // for (const { receivers, level, complete = null } of distributeMulti1) {
    if (d.complete || !d.list || !d.list.length) {
      continue
    }
    const { list, level } = d
    const { receivers, levels, amounts } = list.reduce(
      (dl: { receivers: string[]; amounts: number[]; levels: number[] }, [receiver, amount = 1]: [string, number]) => {
        dl.receivers.push(receiver)
        dl.amounts.push(amount)
        dl.levels.push(level)
        return dl
      },
      { receivers: [], amounts: [], levels: [] }
    )
    console.log({ receivers, levels, amounts })
    // d.receivers.forEach((r: string) => {
    //     tos.push(r)
    //     levels.push(d.level)
    //     amounts.push(1)
    // })

    log(`Distributing mintpass (level ${level}) to ${receivers.length} receivers...`)
    await waitTx(await card.connect(deployer).mintMultiBatch(receivers, levels, amounts, { nonce }))
    distributeMulti1.splice(i, 1, { ...distributeMulti1[i], complete: 1 })
    meta.write({ distributeMulti1 })
    nonce++
  }

  // if (!tos.length) {
  //     log.error(`Distribute list empty`)
  //     return
  // }

  log.success("Distributed")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
