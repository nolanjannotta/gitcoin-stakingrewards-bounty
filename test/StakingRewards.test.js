const { expect } = require('chai');
// const { ethers } = 'ethers';
const { BigNumber } = require('ethers')






require('chai')
  .use(require('chai-as-promised'))
  .should()

describe('StakingRewards', function () {
  let address, deployer, wallet1, wallet2, wallet3, wallet4,
    stakingTokenAddress, rewardTokenAddress1, rewardTokenAddress2, ecosystem, balance, totalsupply

  before(async () => {
    [deployer, ecosystem, wallet1, wallet2, wallet3, wallet4] = await ethers.getSigners();
    const StakingToken = await ethers.getContractFactory('StakingToken');
    stakingtoken = await StakingToken.deploy();

    const RewardToken1 = await ethers.getContractFactory('RewardToken1');
    rewardtoken1 = await RewardToken1.deploy();

    const RewardToken2 = await ethers.getContractFactory('RewardToken2');
    rewardtoken2 = await RewardToken2.deploy();
    stakingTokenAddress = stakingtoken.address;
    rewardTokenAddress1 = rewardtoken1.address;
    rewardTokenAddress2 = rewardtoken2.address;


    const StakingRewards = await ethers.getContractFactory('StakingRewards');

    stakingrewards = await StakingRewards.deploy([rewardTokenAddress1, rewardTokenAddress2],
    stakingTokenAddress, ecosystem.address, 15, 5, 5, 1, 7, 10, 7
    );

  })
  describe("Mock Tokens", async () => {

    it("deploys tokens", async () => {
      expect(stakingTokenAddress).to.be.properAddress;
      expect(rewardTokenAddress1).to.be.properAddress;
      expect(rewardTokenAddress2).to.be.properAddress;

    })

    it("transfers to wallet1", async () => {

      await stakingtoken.drip(wallet1.address, 100)
      balance = await stakingtoken.balanceOf(wallet1.address)
      console.log("wallet1 balance in wei:", balance.toString())
      
    })
    
  })

  describe('deployment', async () => {
    let a,b,c
    before(async () => {

      const StakingRewards = await ethers.getContractFactory('StakingRewards');
      stakingrewards = await StakingRewards.deploy([rewardTokenAddress1, rewardTokenAddress2],
      stakingTokenAddress, ecosystem.address, 15, 5, 5, 1, 7, 10, 7
      );

    })

    it('from should equal deployer', async () => {
      from = stakingrewards.deployTransaction.from;
      from.should.equal(deployer.address)


    })

    it('Should have proper address', async () => {

      address = stakingrewards.address;
      console.log('contract:', address)
      expect(address).to.be.properAddress;
    });

    it("tracks early withdraw fee Percent", async () => {
      a = await stakingrewards.earlyWithdrawPercent()
      b = await stakingrewards.burnPercent()
      c = await stakingrewards.ecosystemPercent()
      console.log("total fee:", a.toString())
      console.log("burn fee:", b.toString())
      console.log("ecosystem fee:", c.toString())

    })

  })

  describe("staking", async () => {

    it("stakes", async () => {
      await stakingtoken.connect(wallet1).approve(stakingrewards.address, BigNumber.from('100000000000000000000'))
      await expect(stakingrewards.connect(wallet1).stake(100))
        .to.emit(stakingrewards, 'Staked')
        .withArgs(wallet1.address, 100);
      totalsupply = await stakingrewards.totalSupply()     
      console.log("total supply:", totalsupply.toString())
      balance = await stakingtoken.balanceOf(wallet1.address)
      console.log("wallet 1 balance after stake:", balance.toString())
      
    })
    it("withdraws", async () => {
      tx = await stakingrewards.connect(wallet1).withdraw(100)

      totalsupply = await stakingtoken.balanceOf(stakingrewards.address)     
      console.log("total supply after stake", totalsupply.toString())
      balance = await stakingtoken.balanceOf(ecosystem.address)
      console.log("ecosystem", balance.toString())

      balance = await stakingtoken.balanceOf(wallet1.address)
      console.log("wallet 1 balance after stake:", balance.toString())

    })

  })
  
})