/* eslint-disable prefer-const */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract, constants } from "ethers"
import { checkParams, tokens, waitTx } from "./lib/helpers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("CardSeller deploy")
  let { cardSellerAddress, priceFeedAddress, walletAddress, busdAddress, mintPassCardAddress } = meta.read()

  if (
    !checkParams({
      mintPassCardAddress,
      priceFeedAddress,
      walletAddress,
      busdAddress,
    })
  )
    return

  let seller: Contract
  const [deployer] = await ethers.getSigners()

  if (!cardSellerAddress) {
    log(`Deploying CardSeller...`)
    const CardSeller = await ethers.getContractFactory("CardSeller")
    seller = await upgrades.deployProxy(CardSeller, [walletAddress, busdAddress, priceFeedAddress], {
      kind: "uups",
    })
    await seller.deployed()
    await waitTx(seller.deployTransaction)
    cardSellerAddress = seller.address
    meta.write({ cardSellerAddress })
  } else {
    seller = await ethers.getContractAt("CardSeller", cardSellerAddress, deployer)
    log(`Using existing cardSellerAddress: ${yl(cardSellerAddress)}`)
  }
  log.success(`CardSeller deployed: ${yl(cardSellerAddress)}`)

  const proxyMintPassCard = await ethers.getContractAt("Card", mintPassCardAddress, deployer)
  log(`Granting MINTER_ROLE...`)
  const MINTER_ROLE = await proxyMintPassCard.MINTER_ROLE()
  if (!(await proxyMintPassCard.hasRole(MINTER_ROLE, cardSellerAddress))) {
    await waitTx(await proxyMintPassCard.connect(deployer).grantRole(MINTER_ROLE, cardSellerAddress))
    log.success(`MintPassCard MINTER_ROLE granted to: ${yl(cardSellerAddress)}`)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
