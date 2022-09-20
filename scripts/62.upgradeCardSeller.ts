import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("CardSeller upgrade")
  const { cardSellerAddress } = meta.read()
  if (cardSellerAddress) {
    log("Upgrading...")
    const [owner] = await ethers.getSigners()
    const CardSeller = await ethers.getContractFactory("CardSeller", owner)
    const proxy = await upgrades.upgradeProxy(cardSellerAddress, CardSeller)
    await proxy.deployed()
    await waitTx(proxy.deployTransaction)
    log.success(`CardSeller upgraded: ${yl(proxy.address)}`)
  } else {
    log.error(`cardSellerAddress not defined`)
  }
  log.splitter()
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
