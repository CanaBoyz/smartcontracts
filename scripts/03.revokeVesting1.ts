import { BigNumber, constants } from "ethers"
import { ethers, upgrades, network } from "hardhat"
import { tokens, waitTx, untokens, unixTime } from "./lib/helpers"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)
const { Zero } = constants

async function main() {
  log.header("Revoke coins")
  const { coinDistributeVested1 = [], coinAddress } = meta.read()

  if (!coinAddress) {
    log.error(`coinAddress not defined`)
    return
  }
  if (!coinDistributeVested1.filter((d: any) => d.list && d.list.length).length) {
    log.error(`no one distribute list is defined`)
    return
  }

  if (!coinDistributeVested1.filter((d: any) => d.complete && !d.revoked).length) {
    log.error(`all distributions already revoked`)
    return
  }

  const [deployer] = await ethers.getSigners()
  const coin = await ethers.getContractAt("Coin", coinAddress, deployer)

  for (const [i, d] of coinDistributeVested1.entries()) {
    const { list, revokable = true, revoked = false, complete = false } = d
    if (revoked || !complete || !revokable || !list || !list.length) {
      continue
    }
    const receivers = list.reduce((receivers: string[], [receiver]: [string, number]) => {
      receivers.push(receiver)
      return receivers
    }, [])
    log(`Revoke vested from ${receivers.length} receivers`)
    await waitTx(await coin.connect(deployer).revokeVestedAllBatch(receivers))
    coinDistributeVested1.splice(i, 1, { ...coinDistributeVested1[i], revoked: 1 })
    meta.write({ coinDistributeVested1 })
  }
  log.success("Revoked!")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
