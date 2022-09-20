import { BigNumber, Contract, utils } from "ethers"
import { TransactionReceipt, TransactionResponse } from "@ethersproject/abstract-provider"

import log from "./log"

export function unixTime(time: number | null = null) {
    const curTime = time ? new Date(time) : new Date()
    return Math.floor(curTime.getTime() / 1000)
}

export function tokens(amount: string | number) {
    return utils.parseEther(amount.toString())
}

export function untokens(amount: BigNumber) {
    return utils.formatEther(amount)
}

export async function waitTx(tx: any): Promise<TransactionReceipt> {
    log(`Wait for tx: ${tx.hash}`)
    return await tx.wait()
}

export function calcVesting({ vestingStart = 0, vestingCliff = 0, vestingFinish = 108 }) {
    if (isNaN(vestingStart)) {
        vestingStart = unixTime(vestingStart)
    }
    if (isNaN(vestingCliff)) {
        vestingCliff = unixTime(vestingCliff)
    }
    if (isNaN(vestingFinish)) {
        vestingFinish = unixTime(vestingCliff)
    } else {
        vestingFinish = vestingStart + vestingFinish * 24 * 60 * 60
    }
    return { vestingStart, vestingCliff, vestingFinish }
}

export function checkParams(params = {}) {
    let result = true
    for (const [name, value] of Object.entries(params)) {
        if (!value) {
            log.error(`${name} not defined`)
            result = false
        }
    }
    return result
}

// let tx = await router.connect(bob).swapExactTokensForETHSupportingFeeOnTransferTokens(
//     amountIn,
//     0, // ignore min amount
//     [token.address, weth.address],
//     bob.address,
//     "999999999999999999999999999999",
// )
// let logs = (await tx.wait()).logs
// console.log(logs);
// await parseLogs(logs, { router, pair, token })

export function parseLogs(logs: Array<any>, contracts: { [name: string]: Contract }) {
    for (const name of Object.keys(contracts)) {
        console.log(">>>", name, contracts[name].address)
    }
    for (const l of logs) {
        const c = Object.entries(contracts).find(([name, contract]) => contract.address === l.address)
        if (c) {
            console.log(">>>", l.logIndex, c[0], l.address)
            try {
                // eslint-disable-next-line @typescript-eslint/no-unsafe-argument
                const { name, signature, args } = c[1].interface.parseLog(l)
                const a = Object.entries(args).reduce((r: any, [k, v]) => {
                    if (BigNumber.isBigNumber(v)) {
                        r[k] = untokens(v) // v.toHexString()
                    } else {
                        r[k] = v
                    }
                    return r
                }, {})
                console.log({ name, signature, args: a })
            } catch (e) {
                //
            }
        }
    }
}
