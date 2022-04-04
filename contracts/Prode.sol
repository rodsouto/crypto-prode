pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ConditionalTokens.sol";

contract Prode is Ownable {

    struct Match {
        bytes32 questionId;
        bytes32 conditionId;
    }

    ConditionalTokens immutable public conditionalTokens;
    address immutable public oracle;
    IERC20 immutable public collateral;
    uint256 immutable public amount;

    /**
     * @dev existing rounds. Each round is a set of matches to bet on.
     */
    mapping(uint256 => Match[]) rounds;

    /**
     * @dev roundOutcome must be 2 o 3
     */
    mapping(uint256 => uint8) roundsOutcomes;

    /**
     * @dev mapping to track if a player already placed a bet in a specific round
     */
    mapping(uint256 => mapping(address => bool)) roundBets;

    /**
     * @dev number of rounds created
     */
    uint256 totalRounds;

    event MatchAdded(uint256 round, uint256 matchIndex, bytes32 questionId, bytes32 conditionId);
    event BetPlaced(uint256 round, uint256 matchIndex, address player, uint8 bet);

    constructor(ConditionalTokens _conditionalTokens, address _oracle, IERC20 _collateral, uint256 _amount) {
        conditionalTokens = _conditionalTokens;
        oracle = _oracle;
        collateral = _collateral;
        amount = _amount;
    }

    /**
     * @param matches each item of the array is the questionId
     * @param outcomeSlotCount 2 o 3 depending on whether a draw is a valid result or not
     */
    function addMatches(bytes32[] calldata matches, uint8 outcomeSlotCount) external onlyOwner {
        require(outcomeSlotCount == 2 || outcomeSlotCount == 3, "Invalid outcomeSlotCount");

        roundsOutcomes[totalRounds] = outcomeSlotCount;

        uint256 len = matches.length;

        for(uint256 i = 0; i < len; i++) {
            bytes32 conditionId = conditionalTokens.getConditionId(oracle, matches[i], outcomeSlotCount);
            conditionalTokens.prepareCondition(oracle, matches[i], outcomeSlotCount);
            rounds[totalRounds].push(
                Match({
                    questionId: matches[i], 
                    conditionId: conditionId
                })
            );

            emit MatchAdded(totalRounds, i, matches[i], conditionId);
        }

        totalRounds++;
    }

    /**
     * @param bets array with a bet for each match. 
     * If the bet has three outcomes, the values must be 0/1/2 for team1/team2/draw. 
     * If the bet has two outcomes, the value must be 0/1 for team1/team2.
     */
    function placeBets(uint8[] calldata bets, uint256 roundNumber) public {
        require(bets.length == rounds[roundNumber].length, "Invalid bets");
        require(!roundBets[roundNumber][msg.sender], "Already placed bets in this round");

        // TODO: deduce fee?
        collateral.transferFrom(msg.sender, address(this), bets.length * amount);

        uint256 len = bets.length;

        roundBets[roundNumber][msg.sender] = true;

        uint256[] memory allIndexSets = getAllIndexSets(roundsOutcomes[roundNumber]);

        for(uint256 i = 0; i < len; i++) {
            require(bets[i] < roundsOutcomes[roundNumber], "Invalid bet value");

            splitPosition(
                rounds[roundNumber][i].conditionId, 
                getPlayerSet(bets[i], roundsOutcomes[roundNumber]), 
                allIndexSets
            );

            emit BetPlaced(totalRounds, i, msg.sender, bets[i]);
        }
    }

    /**
     * @dev The player receives the conditional tokens representing his bet and we keep the tokens representing the other outcomes.
     */
    function splitPosition(bytes32 conditionId, uint256 playerSet, uint256[] memory allIndexSets) internal {
        conditionalTokens.splitPosition(
            collateral,
            0,
            conditionId,
            allIndexSets,
            amount
        );

        conditionalTokens.safeTransferFrom(
            address(this),
            msg.sender,
            conditionalTokens.getPositionId(
                collateral, 
                conditionalTokens.getCollectionId(
                    0, 
                    conditionId, 
                    playerSet
                )
            ),
            amount,
            bytes("")
        );
    }

    /**
     * @dev distributes to the user the proportional share of the pool for this round. 
     * If this function returns true, then is needed to call conditionalTokens.redeemMultiPositions().
     */
    function distributePositions(uint256 roundNumber) external returns (bool hasPositions) {
        require(roundNumber <= totalRounds, "Invalid round");

        uint256 len = rounds[roundNumber].length;

        uint256[] memory allIndexSets = getAllIndexSets(roundsOutcomes[roundNumber]);

        for(uint256 i = 0; i < len; i++) {
            require(conditionalTokens.payoutDenominator(rounds[roundNumber][i].conditionId) > 0, "Result for condition not received yet");

            if (distributePosition(allIndexSets, rounds[roundNumber][i].conditionId)) {
                hasPositions = true;
            }
        }
    }

    /**
     * @dev distributes to the user the proportional share of the pool
     */
    function distributePosition(uint256[] memory allIndexSets, bytes32 conditionId) internal returns (bool hasPositions) {
        uint256 len = allIndexSets.length;

        for(uint256 i = 0; i < len; i++) {
            uint positionId = conditionalTokens.getPositionId(
                collateral,
                conditionalTokens.getCollectionId(bytes32(0), conditionId, allIndexSets[i])
            );

            uint256 senderBalance = conditionalTokens.balanceOf(msg.sender, positionId);

            if (senderBalance == 0) {
                continue;
            }

            hasPositions = true;

            uint256 totalSupply = conditionalTokens.totalSupply(positionId);
            uint256 prodeBalance = conditionalTokens.balanceOf(address(this), positionId);
            uint256 nonProdeBalance = totalSupply - prodeBalance;

            conditionalTokens.safeTransferFrom(
                address(this),
                msg.sender,
                positionId,
                prodeBalance * (senderBalance / nonProdeBalance),
                bytes("")
            );
        }
    }

    function getPlayerSet(uint8 value, uint8 outcomeSlots) internal pure returns (uint256) {
        if (outcomeSlots == 2) {
            /**
            * Outcomes = 2
            *
            * value=0 if team 1 win, value=1 if team 2 win
            *
            * Win 1 | Win 2
            * 1        0       = 0b01 = 1
            * 0        1       = 0b10 = 2
            */

            return value == 0 ? 1 : 2;
        }

        /**
        * Outcomes = 3
        *
        * value=0 if team 1 win, value=1 if team 2 win, value=2 if draw
        *
        * Win 1 | Win 2 | Draw
        * 1        0       0     = 0b001 = 1
        * 0        1       0     = 0b010 = 2        *
        * 0        0       1     = 0b100 = 4
        */
        return value == 0 ? 1 : (value == 1 ? 2: 4);
    }

    function getAllIndexSets(uint8 outcomeSlots) internal pure returns (uint256[] memory indexSets) {
        indexSets[0] = 1;
        indexSets[1] = 2;

        if (outcomeSlots == 2) {
            return indexSets;
        }

        indexSets[2] = 4;

        return indexSets;
    }

}