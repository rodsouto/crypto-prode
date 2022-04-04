const { expect } = require("chai");
const { ethers } = require("hardhat");

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
      await prode.connect(rodri).placeBets([0, 0], 0); // argentina, mexico
      await prode.connect(koki).placeBets([0, 1], 0); // argentina, poland
      await prode.connect(fede).placeBets([2, 2], 0); // draw, draw

      // report results
      await conditionalTokens.connect(oracle).reportPayouts(matches[0], [1, 0, 0]); // argentina wins
      await conditionalTokens.connect(oracle).reportPayouts(matches[1], [1, 0, 0]); // mexico wins

      // distribute positions
      await prode.connect(rodri).distributePositions(0);
      await prode.connect(koki).distributePositions(0);
      await prode.connect(fede).distributePositions(0);

      // redeem tokens
      // TODO: we need to have conditionsIds and indexSets to redeem the positions
      /*await conditionalTokens.connect(rodri).redeemMultiPositions(mockDAI.address, bytes32 parentCollectionId, bytes32[] calldata conditionsIds, uint[] calldata indexSets);
      await conditionalTokens.connect(koki).redeemMultiPositions(mockDAI.address, bytes32 parentCollectionId, bytes32[] calldata conditionsIds, uint[] calldata indexSets);
      await conditionalTokens.connect(fede).redeemMultiPositions(mockDAI.address, bytes32 parentCollectionId, bytes32[] calldata conditionsIds, uint[] calldata indexSets);*/

      // TODO: check results (rodri 1.5+3 DAI , koki 1.5 DAI, fede 0 DAI)
    });
  });

});
