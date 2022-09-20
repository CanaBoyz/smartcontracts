import { ethers, upgrades, network } from "hardhat"
import { tokens, waitTx, untokens, unixTime } from "./lib/helpers"
import { log, yl } from "./lib/log"
import metaInit from "./lib/meta"
const meta = metaInit(network.name)

async function main() {
    log.header("Start MintPassCard Sale")
    const { cardSellerAddress } = meta.read()

    if (!cardSellerAddress) {
        log.error(`cardSellerAddress not defined`)
        return
    }

    const [deployer] = await ethers.getSigners()
    const seller = await ethers.getContractAt("CardSeller", cardSellerAddress, deployer)


    const activeSale = await seller.getSale()
    console.log(activeSale)
    if (activeSale.start === 0) {
        throw new Error("Sale not started")
    }
   
    await waitTx(
        await seller
            .connect(deployer)
            .closeSale(),
    )
    log.success("Sale finished")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })

// {
//     card: '0x353ebAb8c4DC828F9b217d6d0D91dBEb95D8f4F7',
//     levels: [
//       BigNumber { value: "1" },
//       BigNumber { value: "2" },
//       BigNumber { value: "3" },
//       BigNumber { value: "4" }
//     ],
//     amounts: [
//       BigNumber { value: "6499" },
//       BigNumber { value: "3000" },
//       BigNumber { value: "480" },
//       BigNumber { value: "20" }
//     ],
//     remainAmounts: [
//       BigNumber { value: "5858" },
//       BigNumber { value: "2735" },
//       BigNumber { value: "456" },
//       BigNumber { value: "20" }
//     ],
//     totalAmount: BigNumber { value: "9999" },
//     totalRemainAmount: BigNumber { value: "9069" }
// }