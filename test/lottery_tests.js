const nonFungible = artifacts.require("MintedHistoryContract");
const fungible = artifacts.require("HistoryToken");
const lottery = artifacts.require("LotteryStake");
const truffleAssert = require('truffle-assertions');



contract("LotteryStake", async accounts => {
    it("Ensure bonus points are accumulating for Staked NFT", async () => {
        const nonFungibleInstance = await nonFungible.deployed("", "0x59cca37DFdC09222a2a0A8634b73c5de4DAC25aB");
        const fungibleInstance = await fungible.deployed();
        const lotteryInstance = await lottery.deployed();

        await lotteryInstance.initialize(fungibleInstance.address, nonFungibleInstance.address, 320);
        await nonFungibleInstance.startPublicMint();
        await nonFungibleInstance.MintNft({ value: web3.utils.toWei(web3.utils.toBN(2))});
        await nonFungibleInstance.setTokenUri(0, "https://gateway.pinata.cloud/ipfs/QmVfY52ZzdcuHj25T5HQzYXvGyJRHgaaL7uwFQvZwj8wzT");

        await nonFungibleInstance.approve(lotteryInstance.address, 0);
        await lotteryInstance.stakingStart();
        await lotteryInstance.deposit(0);
        
        await lotteryInstance.reward([0],[],[],[],[],[],[],[]);
        const d = new Date();
        const year = d.getFullYear();
        const month = d.getMonth();
        let index = (year * 100) + month;

        let lottery = await lotteryInstance.lotteries[index];

        let result = 0;
        for (let x = 0; x < 320; x++) {
            result += lottery.stakedTokens[x].points;
        }

        assert.notEqual(0, result);
        
    });
});