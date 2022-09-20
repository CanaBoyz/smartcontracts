/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("Coins upgrade")
  const { coinAddress } = meta.read()

  const Coin = await ethers.getContractFactory("Coin")
  let proxy

  if (coinAddress) {
    log("Upgrading...")
    proxy = await upgrades.upgradeProxy(coinAddress, Coin, {
      unsafeAllowRenames: true,
      // unsafeSkipStorageCheck: true,
    })
    await proxy.deployed()
    await waitTx(proxy.deployTransaction)
    log.success(`Coin upgraded: ${yl(proxy.address)}`)
  } else {
    log.error(`coinAddress not defined`)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
