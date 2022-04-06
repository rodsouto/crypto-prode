pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ConditionalTokens.sol";

contract Prode is Ownable, ERC1155Holder {

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
     * @dev mapping to track if a player already placed a bet in a specific round
     */
    mapping(uint256 => mapping(address => bool)) roundBets;

    /**
     * @dev number of rounds created
     */
    uint256 totalRounds;

    event MatchAdded(uint256 round, uint256 matchIndex, bytes32 questionId, bytes32 conditionId);
    event BetPlaced(uint256 round, bytes32 conditionId, uint256 matchIndex, address player, uint8 bet);

    constructor(ConditionalTokens _conditionalTokens, address _oracle, IERC20 _collateral, uint256 _amount) {
        conditionalTokens = _conditionalTokens;
        oracle = _oracle;
        collateral = _collateral;
        amount = _amount;

        collateral.approve(address(conditionalTokens), type(uint256).max);
    }

    /**
     * @param matches each item of the array is the questionId
     */
    function addMatches(bytes32[] calldata matches) external onlyOwner {
        uint256 len = matches.length;

        for(uint256 i = 0; i < len; i++) {
            bytes32 conditionId = conditionalTokens.getConditionId(oracle, matches[i]);
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
     * If the bet has three outcomes, the values must be 1/2/3 for team1/team2/draw. 
     * If the bet has two outcomes, the value must be 1/2 for team1/team2.
     */
    function placeBets(uint8[] calldata bets, uint256 roundNumber) public {
        require(bets.length == rounds[roundNumber].length, "Invalid bets");
        require(!roundBets[roundNumber][msg.sender], "Already placed bets in this round");

        uint256 len = bets.length;

        roundBets[roundNumber][msg.sender] = true;

        for(uint256 i = 0; i < len; i++) {
            conditionalTokens.setPosition(
                msg.sender,
                collateral,
                rounds[roundNumber][i].conditionId,
                bets[i],
                amount
            );

            emit BetPlaced(totalRounds, rounds[roundNumber][i].conditionId, i, msg.sender, bets[i]);
        }
    }

}