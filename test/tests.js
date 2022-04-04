const { expect } = require("chai");
const { ethers } = require("hardhat");

const NEW_PLAYER_POSITION_EVENT = "event NewPlayerPosition(address player, address collateral, bytes32 conditionId, uint256 playerSet, uint256 amount);";

function getEvents(receipt, eventAbi) {
  let iface = new ethers.utils.Interface([eventAbi]);
  return receipt.logs.map((log) => {
    try {
      return iface.parseLog(log);
    } catch (e) {
      return null;
    }
  }).filter(Boolean);
}
function getConditions(txReceipt) {
  const result = {conditionsIds: [], indexSets: []};

  getEvents(txReceipt, NEW_PLAYER_POSITION_EVENT).forEach(event => {
    result.conditionsIds.push(event.args.conditionId);
    result.indexSets.push([event.args.playerSet.toString()]);
  });

  return result;
}

describe("Prode", function () {

  let prode;
  let mockDAI;
  let conditionalTokens;

  beforeEach(async function() {
    const [owner, oracle] = await ethers.getSigners();

    const MockDAI = await ethers.getContractFactory("MockDAI");
    mockDAI = await MockDAI.deploy();
    await mockDAI.deployed();

    const ConditionalTokens = await ethers.getContractFactory("ConditionalTokens");
    conditionalTokens = await ConditionalTokens.deploy();
    await conditionalTokens.deployed();

    const Prode = await ethers.getContractFactory("Prode");
    prode = await Prode.deploy(conditionalTokens.address, oracle.address, mockDAI.address, ethers.utils.parseUnits('1', 18));
    await prode.deployed();
  });

  describe("addMatches", function() {
    it("Should fail if not called by owner", async function () {
      const [owner, oracle, notOwner] = await ethers.getSigners();

      await expect(
        prode.connect(notOwner).addMatches(['0x0000000000000000000000000000000000000000000000000000000000000001'], 2)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should fail if outcomeSlotCount is invalid", async function () {
      await expect(
        prode.addMatches(['0x0000000000000000000000000000000000000000000000000000000000000001'], 4)
      ).to.be.revertedWith("Invalid outcomeSlotCount");
    });

    it("Should emit MatchAdded event", async function () {
      await expect(prode.addMatches(['0x0000000000000000000000000000000000000000000000000000000000000001'], 2)).to.emit(prode, "MatchAdded");
    });
  });

  describe("placeBets", function() {
    it("Should fail if arrays have different length", async function () {
      // TODO
    });

    it("Should fail if already bet in this round", async function () {
      // TODO
    });

    it("Should emit BetPlaced event", async function () {
      // TODO
    });

    it("Should split position", async function () {
      // TODO
    });
  });

  describe("Demo", function() {

    it("Demo", async function () {
      const [_, oracle, rodri, koki, fede] = await ethers.getSigners();

      const matches = [
        '0x0000000000000000000000000000000000000000000000000000000000000001', // argentina-saudi arabia
        '0x0000000000000000000000000000000000000000000000000000000000000002', // mexico-poland
      ];

      const twoDAI = ethers.utils.parseUnits('2', 18); // 1 DAI for each match

      await mockDAI.mint(rodri.address, twoDAI);
      await mockDAI.mint(fede.address, twoDAI);
      await mockDAI.mint(koki.address, twoDAI);

      await mockDAI.connect(rodri).approve(prode.address, twoDAI);
      await mockDAI.connect(koki).approve(prode.address, twoDAI);
      await mockDAI.connect(fede).approve(prode.address, twoDAI);

      // create match
      await prode.addMatches(matches, 3);

      // place bets
      const tx1 = await prode.connect(rodri).placeBets([0, 0], 0); // argentina, mexico
      const tx2 = await prode.connect(koki).placeBets([0, 1], 0); // argentina, poland
      const tx3 = await prode.connect(fede).placeBets([2, 2], 0); // draw, draw

      // report results
      await conditionalTokens.connect(oracle).reportPayouts(matches[0], [1, 0, 0]); // argentina wins
      await conditionalTokens.connect(oracle).reportPayouts(matches[1], [1, 0, 0]); // mexico wins

      // distribute positions
      await prode.connect(rodri).distributePositions(0);
      await prode.connect(koki).distributePositions(0);
      await prode.connect(fede).distributePositions(0);

      // redeem tokens
      const tx1Conditions = getConditions(await tx1.wait());
      const tx2Conditions = getConditions(await tx2.wait());
      const tx3Conditions = getConditions(await tx3.wait());

      await conditionalTokens.connect(rodri).redeemMultiPositions(mockDAI.address, ethers.constants.HashZero, tx1Conditions.conditionsIds, tx1Conditions.indexSets);
      await conditionalTokens.connect(koki).redeemMultiPositions(mockDAI.address, ethers.constants.HashZero, tx2Conditions.conditionsIds, tx2Conditions.indexSets);
      await conditionalTokens.connect(fede).redeemMultiPositions(mockDAI.address, ethers.constants.HashZero, tx3Conditions.conditionsIds, tx3Conditions.indexSets);

      expect((await mockDAI.balanceOf(rodri.address)).toString()).to.equal('4500000000000000000');
      expect((await mockDAI.balanceOf(koki.address)).toString()).to.equal('1500000000000000000');
      expect((await mockDAI.balanceOf(fede.address)).toString()).to.equal('0');
    });
  });

});
