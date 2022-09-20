import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("Items upgrade")
  const { itemAddress } = meta.read()

  const Item = await ethers.getContractFactory("Item")
  let proxy

  if (itemAddress) {
    log("Upgrading...")
    proxy = await upgrades.upgradeProxy(itemAddress, Item, {
      unsafeAllowRenames: true,
      // unsafeSkipStorageCheck: true,
    })
    await proxy.deployed()
    await waitTx(proxy.deployTransaction)
    log.success(`Item upgraded: ${yl(proxy.address)}`)
  } else {
    log.error(`itemAddress not defined`)
  }
}
  
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
