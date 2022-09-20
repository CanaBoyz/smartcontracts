/* eslint-disable prefer-const */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract } from "ethers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("Plant deploy")
  let { plantParams = {}, plantAddress } = meta.read()

  const [deployer] = await ethers.getSigners()
  let plant: Contract
  if (!plantAddress) {
    log(`Deploying Plant...`)
    const { name, symbol, baseTokenURI = "", tokenURIPre = "", tokenURIPost = "" } = plantParams
    const Plant = await ethers.getContractFactory("Plant")
    plant = await upgrades.deployProxy(Plant, [name, symbol, baseTokenURI, tokenURIPre, tokenURIPost], {
      kind: "uups",
    })
    await plant.deployed()
    await waitTx(plant.deployTransaction)
    plantAddress = plant.address
    meta.write({ plantAddress })
  } else {
    plant = await ethers.getContractAt("Plant", plantAddress, deployer)
    log(`Using existing Plant: ${yl(plantAddress)}`)
  }
  log.success(`Plant deployed: ${yl(plantAddress)}`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
