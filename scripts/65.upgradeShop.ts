/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("Shops upgrade")
  const { shopAddress } = meta.read()

  const Shop = await ethers.getContractFactory("Shop")
  let proxy

  if (shopAddress) {
    log("Upgrading...")
    proxy = await upgrades.upgradeProxy(shopAddress, Shop, {
      unsafeAllowRenames: true,
      // unsafeSkipStorageCheck: true,
    })
    await proxy.deployed()
    await waitTx(proxy.deployTransaction)
    log.success(`Shop upgraded: ${yl(proxy.address)}`)
  } else {
    log.error(`shopAddress not defined`)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
