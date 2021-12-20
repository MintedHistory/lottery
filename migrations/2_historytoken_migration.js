const History = artifacts.require("HistoryToken");

module.exports = function (deployer) {
  deployer.deploy(History);
};