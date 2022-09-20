/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("Coins upgrade")
  const { innerCoinAddress } = meta.read()

  const Coin = await ethers.getContractFactory("InnerCoin")
  let proxy

  if (innerCoinAddress) {
    log("Upgrading...")
    proxy = await upgrades.upgradeProxy(innerCoinAddress, Coin)
    await proxy.deployed()
    await waitTx(proxy.deployTransaction)
    log.success(`Coin upgraded: ${yl(proxy.address)}`)
  } else {
    log.error(`innerCoinAddress not defined`)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
