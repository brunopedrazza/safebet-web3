const SafeBet = artifacts.require("SafeBet")
const ZaoTokenAddress = "0x82884B8377BB6487ff018a0385D0D7a579bb8000"

module.exports = async function (deployer, network, accounts) {
  // Deploy SafeBet
  await deployer.deploy(SafeBet, ZaoTokenAddress)
  const safeBet = await SafeBet.deployed()
}