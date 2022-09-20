import { Contract } from "ethers"
import { ethers, upgrades, network } from "hardhat"
import { tokens, waitTx } from "./lib/helpers"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("Cards deploy")
  let { mintPassCardAddress, mintPassCardParams, nftAddress } = meta.read()
  const [deployer] = await ethers.getSigners()
  const Card = await ethers.getContractFactory("Card")
  let card: Contract
  if (!mintPassCardAddress) {
    // if (mintPassCardParams) {
    log(`Deploying mintPassCard...`)
    const { name, symbol, baseURI, maxOwnsCount, maxUsesCount, levels = [], levelURIs = [] } = mintPassCardParams
    card = await upgrades.deployProxy(Card, [name, symbol, baseURI, maxOwnsCount, maxUsesCount], {
      kind: "uups",
    })
    await card.deployed()
    await waitTx(card.deployTransaction)
    meta.write({ mintPassCardAddress: card.address })
    log.success(`mintPassCard deployed: ${yl(card.address)}`)

    if (levels.length && levels.length == levelURIs.length) {
      log(`Set level uris...`)
      //set level uris
      await waitTx(await card.setLevelURIs(levels, levelURIs))
      log.success(`level URIs set`)
    }
    // } else {
    //   log(`Skip mintPassCard deploy: no mintPassCardParams`)
    // }
  } else {
    card = await ethers.getContractAt("Card", mintPassCardAddress, deployer)
    log(`Using existing mintPassCard: ${yl(mintPassCardAddress)}`)
  }
  log(`Check minters...`)
  const { minters = [], operators = [], enableClaim } = mintPassCardParams
  const MINTER_ROLE = await card.MINTER_ROLE()
  for (let m of minters) {
    if (!(await card.hasRole(MINTER_ROLE, m))) {
      log(`Granting MINTER_ROLE to minter...`)
      await waitTx(await card.connect(deployer).grantRole(MINTER_ROLE, m))
    }
    log.success(`MINTER_ROLE granted to minter: ${yl(m)}`)
  }

  log(`Check operators...`)
  const OPERATOR_ROLE = await card.OPERATOR_ROLE()
  for (let m of operators) {
    if (!(await card.hasRole(OPERATOR_ROLE, m))) {
      log(`Granting OPERATOR_ROLE to operator...`)
      await waitTx(await card.connect(deployer).grantRole(OPERATOR_ROLE, m))
    }
    log.success(`OPERATOR_ROLE granted to operator: ${yl(m)}`)
  }

  if (enableClaim && nftAddress) {
    if (!(await card.claimEnabled())) {
      log(`Enabling claim...`)
      await waitTx(await card.connect(deployer).initClaim(nftAddress))
    }
    log.success(`Claim enabled`)
  } else {
    log.warn(`Claim not enabled`)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
