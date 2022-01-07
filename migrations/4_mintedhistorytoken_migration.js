const nftContract = artifacts.require("MintedHistoryContract");

module.exports = function (deployer) {
  deployer.deploy(nftContract, "", "0x59cca37DFdC09222a2a0A8634b73c5de4DAC25aB");
};