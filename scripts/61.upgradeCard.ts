import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("Cards upgrade")
  const { mintPassCardAddress, discountCardAddress, giftCardAddress, whiteListCardAddress } = meta.read()

  const Card = await ethers.getContractFactory("Card")
  let proxy

  if (mintPassCardAddress) {
    log("Upgrading...")
    proxy = await upgrades.upgradeProxy(mintPassCardAddress, Card)
    await proxy.deployed()
    await waitTx(proxy.deployTransaction)
    log.success(`mintPassCard upgraded: ${yl(proxy.address)}`)
  } else {
    log.error(`mintPassCardAddress not defined`)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
