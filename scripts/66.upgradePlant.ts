/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("Plants upgrade")
  const { plantAddress } = meta.read()

  const Plant = await ethers.getContractFactory("Plant")
  let proxy

  if (plantAddress) {
    log("Upgrading...")
    proxy = await upgrades.upgradeProxy(plantAddress, Plant, {
      unsafeAllowRenames: true,
      // unsafeSkipStorageCheck: true,
    })
    await proxy.deployed()
    await waitTx(proxy.deployTransaction)
    log.success(`Plant upgraded: ${yl(proxy.address)}`)
  } else {
    log.error(`plantAddress not defined`)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
