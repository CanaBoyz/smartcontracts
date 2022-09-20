/* eslint-disable @typescript-eslint/no-unsafe-argument */
import { Contract, constants } from "ethers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, unixTime, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const { AddressZero } = constants
const meta = metaInit(network.name)

async function main() {
  log.header("Seller deploy")
  const { sellerAddress, sellerParams, whitelistAddress } = meta.read()
  const [deployer] = await ethers.getSigners()
  const Seller = await ethers.getContractFactory("Seller")

  if (!sellerAddress) {
    log.error(`sellerAddress not defined`)
    return
  }
  if (!whitelistAddress) {
    log.error(`whitelistAddress not defined`)
    return
  }

  const wl = await ethers.getContractAt("WhiteList", whitelistAddress, deployer)
  log(`WhiteList WhiteList seller: ${yl(whitelistAddress)}`)

  const seller = await ethers.getContractAt("Seller", sellerAddress, deployer)
  log(`Using existing seller: ${yl(sellerAddress)}`)

  const { whiteList = [], sales = [], currentSaleId = 0 } = sellerParams

  if (whiteList.length > 0) {
    log(`add whitelist...`)

    const chunkSize = 500
    for (let i = 0; i < whiteList.length; i += chunkSize) {
      log(`Add chunk ${i / chunkSize}...`)
      const chunk = whiteList.slice(i, i + chunkSize)
      await waitTx(await wl.addToList(chunk))
      log.success(`Chunk ${i / chunkSize} added`)
    }
  }

  if (!sales.length) {
    log.error(`sales not defined`)
    return
  }
  // for (const { price, start = unixTime(), duration = 0, amount = 0, id = 0, isUSD = false, isWL = false } of sales) {
  //   const sale = await seller.getSale(id)
  //   if (start && sale.start.toNumber() === start) {
  //     log.warn(`Sale ${id} already started`)
  //     continue
  //   }
  //   const wlAddress = isWL ? whitelistAddress : AddressZero
  //   log(`Seting sale...`)
  //   await waitTx(await seller.connect(deployer).setSale(id, start, duration, amount, wlAddress, isUSD, tokens(price)))
  //   log.success(`Sale ${id} set`)
  // }

  // if (currentSaleId) {
  //   log(`Seting currentSaleId...`)
  //   await waitTx(await seller.connect(deployer).setCurrentSaleId(currentSaleId))
  //   log.success(`currentSaleId set to ${currentSaleId}`)
  // }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
