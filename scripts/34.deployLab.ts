/* eslint-disable prefer-const */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract } from "ethers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("Lab deploy")
  let { labParams = {}, labAddress, itemAddress, plantAddress, innerCoinAddress } = meta.read()
  const [deployer] = await ethers.getSigners()
  let lab: Contract
  const { interval = 86400 } = labParams
  if (!labAddress) {
    log(`Deploying Lab...`)
    const Lab = await ethers.getContractFactory("Lab")
    lab = await upgrades.deployProxy(Lab, [itemAddress, plantAddress, innerCoinAddress, interval], {
      kind: "uups",
    })
    await lab.deployed()
    await waitTx(lab.deployTransaction)
    labAddress = lab.address
    meta.write({ labAddress })
  } else {
    lab = await ethers.getContractAt("Lab", labAddress, deployer)
    log(`Using existing Lab: ${yl(labAddress)}`)
  }
  log.success(`Lab deployed: ${yl(labAddress)}`)

  const plant = await ethers.getContractAt("Plant", plantAddress, deployer)
  const item = await ethers.getContractAt("Item", itemAddress, deployer)
  const innerCoin = await ethers.getContractAt("InnerCoin", innerCoinAddress, deployer)

  log(`Check interval...`)
  if ((await lab.baseInterval()).toNumber() !== interval) {
    await waitTx(await lab.connect(deployer).setBaseInterval(interval))
  }

  log(`Setup roles...`)
  const MINTER_ROLE = await item.MINTER_ROLE()
  const OPERATOR_ROLE = await item.OPERATOR_ROLE()

  if (!(await item.hasRole(MINTER_ROLE, labAddress))) {
    await waitTx(await item.connect(deployer).grantRole(MINTER_ROLE, labAddress))
  }
  log.success(`MINTER_ROLE granted to lab at Item`)

  if (!(await item.hasRole(OPERATOR_ROLE, labAddress))) {
    await waitTx(await item.connect(deployer).grantRole(OPERATOR_ROLE, labAddress))
  }
  log.success(`OPERATOR_ROLE granted to lab at Item`)

  if (!(await plant.hasRole(MINTER_ROLE, labAddress))) {
    await waitTx(await plant.connect(deployer).grantRole(MINTER_ROLE, labAddress))
  }
  log.success(`MINTER_ROLE granted to lab at plant`)

  if (!(await plant.hasRole(OPERATOR_ROLE, labAddress))) {
    await waitTx(await plant.connect(deployer).grantRole(OPERATOR_ROLE, labAddress))
  }
  log.success(`OPERATOR_ROLE granted to lab at plant`)

  if (!(await innerCoin.hasRole(MINTER_ROLE, labAddress))) {
    await waitTx(await innerCoin.connect(deployer).grantRole(MINTER_ROLE, labAddress))
  }
  log.success(`MINTER_ROLE granted to lab at InnerCoin`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
