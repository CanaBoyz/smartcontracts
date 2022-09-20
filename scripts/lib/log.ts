const chalk = require("chalk")

export const yl = (s: string | number) => chalk.yellow(s)
export const gr = (s: string | number) => chalk.green(s)
export const rd = (s: string | number) => chalk.red(s)
export const OK = gr("✓")
export const KO = rd("×")
export const WRN = yl("⚠")

export const log = (...args: any) => console.error(...args)

log.success = (...args: any) => {
  console.info(OK, ...args)
}
log.error = (...args: any) => {
  console.error(KO, ...args)
}
log.warn = (...args: any) => {
  console.error(WRN, ...args)
}

function logSplitter(...args: any) {
  console.error("====================")
  if (args.length) {
    console.error(...args)
  }
}

log.splitter = logSplitter

function logWideSplitter(...args: any) {
  console.error("========================================")
  if (args.length) {
    console.error(...args)
  }
}

log.wideSplitter = logWideSplitter

function logHeader(msg: string) {
  logWideSplitter(msg)
  logWideSplitter()
}

log.header = logHeader

export default log
