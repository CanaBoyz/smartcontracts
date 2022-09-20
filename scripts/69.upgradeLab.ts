/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("Labs upgrade")
  const { labAddress } = meta.read()

  const Lab = await ethers.getContractFactory("Lab")
  let proxy

  if (labAddress) {
    log("Upgrading...")
    proxy = await upgrades.upgradeProxy(labAddress, Lab)
    await proxy.deployed()
    await waitTx(proxy.deployTransaction)
    log.success(`Lab upgraded: ${yl(proxy.address)}`)
  } else {
    log.error(`labAddress not defined`)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
