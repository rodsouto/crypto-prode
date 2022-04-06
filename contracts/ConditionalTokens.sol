pragma solidity ^0.8.13;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "hardhat/console.sol";

contract ConditionalTokens is ERC1155Supply {

    event ConditionResolution(
        bytes32 indexed conditionId,
        address indexed oracle,
        bytes32 indexed questionId,
        uint payout
    );

    event PositionSet(
        address indexed stakeholder,
        IERC20 collateralToken,
        bytes32 indexed conditionId,
        uint outcome,
        uint amount
    );
    event PayoutRedemption(
        address indexed redeemer,
        IERC20 indexed collateralToken,
        bytes32 conditionId,
        uint outcome,
        uint payout
    );

    // Collateral balance for each condition ID
    mapping(bytes32 => uint) balance;

    /// Mapping key is a condition ID. Value=N is the oracle setting outcome N as valid.
    mapping(bytes32 => uint) public payouts;

    constructor() ERC1155("") {

    }

    /// @dev Called by the oracle for reporting results of conditions. Will set the payout for the condition with the ID ``keccak256(abi.encodePacked(oracle, questionId))``, where oracle is the message sender and questionId is one of the parameters of this function.
    /// @param questionId The question ID the oracle is answering for
    /// @param payout The oracle's answer
    function reportPayouts(bytes32 questionId, uint payout) external {
        // IMPORTANT, the oracle is enforced to be the sender because it's part of the hash.
        bytes32 conditionId = getConditionId(msg.sender, questionId);
        require(payouts[conditionId] == 0, "payout already set");

        payouts[conditionId] = payout;
        emit ConditionResolution(conditionId, msg.sender, questionId, payout);
    }

    /// @dev This contract will attempt to transfer `amount` collateral from stakeholder to itself. If successful, `amount` stake will be minted in the `outcome` target position. If any of the transfers, mints, or burns fail, the transaction will revert.
    /// @param stakeholder The user that is creating the position.
    /// @param collateralToken The address of the positions' backing collateral token.
    /// @param conditionId The ID of the condition to split on.
    /// @param outcome Outcome selected by the user.
    /// @param amount The amount of collateral
    function setPosition(
        address stakeholder,
        IERC20 collateralToken,
        bytes32 conditionId,
        uint outcome,
        uint amount
    ) external {
        require(outcome > 0, "invalid outcome");
        require(collateralToken.transferFrom(stakeholder, address(this), amount), "could not receive collateral tokens");

        balance[conditionId] += amount;

        _mint(
            stakeholder,
            // position ID is the ERC 1155 token ID
            getPositionId(collateralToken, getCollectionId(conditionId, outcome)),
            amount,
            ""
        );

        emit PositionSet(stakeholder, collateralToken, conditionId, outcome, amount);
    }

    function redeemPositions(IERC20 collateralToken, bytes32[] calldata conditionsIds) public {
        uint256 len = conditionsIds.length;

        for(uint256 i = 0; i < len; i++) {
            bytes32 conditionId = conditionsIds[i];

            require(payouts[conditionId] > 0, "result for condition not received yet");

            // using payouts[conditionId] we are ensuring that the user has the token that represents the valid outcome
            uint positionId = getPositionId(collateralToken, getCollectionId(conditionId, payouts[conditionId]));

            uint payoutStake = balanceOf(msg.sender, positionId);

            if (payoutStake > 0) {
                uint totalPayout = payoutStake * balance[conditionId] / totalSupply(positionId);

                balance[conditionId] -= totalPayout;

                _burn(msg.sender, positionId, payoutStake);

                require(collateralToken.transfer(msg.sender, totalPayout), "could not transfer payout to message sender");

                emit PayoutRedemption(msg.sender, collateralToken, conditionId, payouts[conditionId], totalPayout);
            }
        }
    }

    /// @dev Constructs a condition ID from an oracle, a question ID, and the outcome slot count for the question.
    /// @param oracle The account assigned to report the result for the prepared condition.
    /// @param questionId An identifier for the question to be answered by the oracle.
    function getConditionId(address oracle, bytes32 questionId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(oracle, questionId));
    }

    /// @dev Constructs an outcome collection ID from a condition ID and an outcome.
    /// @param conditionId Condition ID of the outcome collection.
    /// @param outcome Collection outcome.
    function getCollectionId(bytes32 conditionId, uint outcome) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(conditionId, outcome));
    }

    /// @dev Constructs a position ID from a collateral token and an outcome collection. These IDs are used as the ERC-1155 ID for this contract.
    /// @param collateralToken Collateral token which backs the position.
    /// @param collectionId ID of the outcome collection associated with this position.
    function getPositionId(IERC20 collateralToken, bytes32 collectionId) internal pure returns (uint) {
        return uint(keccak256(abi.encodePacked(collateralToken, collectionId)));
    }
}