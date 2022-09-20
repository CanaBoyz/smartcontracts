import { Contract } from "ethers"
import { ethers, network, upgrades } from "hardhat"
import { log, yl } from "./lib/log"
import { tokens, waitTx } from "./lib/helpers"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
  log.header("Nft deploy")
  let { nftParams = {}, nftAddress, mintPassCardAddress } = meta.read()
  const [deployer] = await ethers.getSigners()
  let nft: Contract
  const { baseTokenURI} = nftParams
  if (!nftAddress) {
    log(`Deploying NFT...`)
    const { name, symbol, tokenURIPre, tokenURIPost } = nftParams
    const NFT = await ethers.getContractFactory("NFT")
    nft = await upgrades.deployProxy(NFT, [name, symbol, baseTokenURI, tokenURIPre, tokenURIPost ], {
      kind: "uups",
    })
    await nft.deployed()
    await waitTx(nft.deployTransaction)
    nftAddress = nft.address
    meta.write({ nftAddress })
  } else {
    nft = await ethers.getContractAt("NFT", nftAddress, deployer)
    log(`Using existing Nft: ${yl(nftAddress)}`)
  }
  log.success(`Nft deployed: ${yl(nftAddress)}`)

  log(`Check baseURI...`)
  if ((await nft.baseURI()) !== baseTokenURI) {
    log(`Set new baseURI...`)
    await waitTx(await nft.connect(deployer).setBaseURI(baseTokenURI))
  }

  log(`Check minters...`)
  const { minters = [] } = nftParams
  const MINTER_ROLE = await nft.MINTER_ROLE()
  if (!(await nft.hasRole(MINTER_ROLE, mintPassCardAddress))) {
    log(`Granting MINTER_ROLE to MintPass contract for claim...`)
    await waitTx(await nft.connect(deployer).grantRole(MINTER_ROLE, mintPassCardAddress))
  }
  log.success(`MINTER_ROLE granted to minter: ${yl(mintPassCardAddress)}`)

  for (let m of minters) {
    if (!(await nft.hasRole(MINTER_ROLE, m))) {
      log(`Granting MINTER_ROLE to minter...`)
      await waitTx(await nft.connect(deployer).grantRole(MINTER_ROLE, m))
    }
    log.success(`MINTER_ROLE granted to minter: ${yl(m)}`)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
