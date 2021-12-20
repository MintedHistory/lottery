const Lottery = artifacts.require("LotteryStake");

module.exports = function (deployer) {
  deployer.deploy(Lottery);
};