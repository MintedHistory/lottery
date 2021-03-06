const nonFungible = artifacts.require("MintedHistoryContract");
const fungible = artifacts.require("HistoryToken");
const lottery = artifacts.require("LotteryStake");
const truffleAssert = require('truffle-assertions');



contract("LotteryStake", async accounts => {
    it("Ensure bonus points are accumulating for Staked NFT", async () => {
        const nonFungibleInstance = await nonFungible.deployed("", "0x59cca37DFdC09222a2a0A8634b73c5de4DAC25aB");
        const fungibleInstance = await fungible.deployed();
        const lotteryInstance = await lottery.deployed();

        await lotteryInstance.initialize(fungibleInstance.address, nonFungibleInstance.address, 320, 0);
        await nonFungibleInstance.startPublicMint();
        await nonFungibleInstance.MintNft({ value: web3.utils.toWei(web3.utils.toBN(2))});
        await nonFungibleInstance.setTokenUri(0, "https://gateway.pinata.cloud/ipfs/QmVfY52ZzdcuHj25T5HQzYXvGyJRHgaaL7uwFQvZwj8wzT");

        await nonFungibleInstance.approve(lotteryInstance.address, 0);
        await lotteryInstance.stakingStart();
        await lotteryInstance.deposit(0);

        await fungibleInstance.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", lotteryInstance.address);
        
        await lotteryInstance.reward([0],[],[],[],[],[],[],[]);
        
        console.log(await lotteryInstance.stakedTokens());

        var value = await lotteryInstance.getLotteryPoints(2022, 1);

        assert.equal(value[0].points, 16);
        
    });
    it("Test randomness of function, 10 requests produce 10 different results", async () => {
        const lotteryInstance = await lottery.deployed();
        const size = 320;
        var selections = [];
        for (var x = 0; x < 10; x++) {
            var item = await lotteryInstance.random(size);
            selections.push(item);
        }
        
        assert.equal(new Set(selections).size, selections.length);
    });
});