const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Prode", function () {

  let prode;
  let mockDAI;
  let conditionalTokens;
  const oracleAddress = ethers.constants.AddressZero; // TODO

  beforeEach(async function() {
    const MockDAI = await ethers.getContractFactory("MockDAI");
    mockDAI = await MockDAI.deploy();
    await mockDAI.deployed();

    const ConditionalTokens = await ethers.getContractFactory("ConditionalTokens");
    conditionalTokens = await ConditionalTokens.deploy();
    await conditionalTokens.deployed();

    const Prode = await ethers.getContractFactory("Prode");
    prode = await Prode.deploy(conditionalTokens.address, oracleAddress, mockDAI.address, ethers.utils.parseUnits('1', 18));
    await prode.deployed();
  });

  describe("addMatches", function() {
    it("Should fail if not called by owner", async function () {
      const [owner, notOwner] = await ethers.getSigners();

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
});
