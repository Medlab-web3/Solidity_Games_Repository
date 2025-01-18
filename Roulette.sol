// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.21;

contract Roulette {
    uint256 public constant BET_AMOUNT = 0.01 ether;
    uint256 public constant MAX_BANK_BALANCE = 2 ether;

    uint256 public necessaryBalance;
    uint256 public nextRoundTimestamp;

    address payable public creator;

    mapping(address => uint256) public winnings;

    uint8[] public payouts = [2, 3, 3, 2, 2, 36];
    uint8[] public numberRange = [1, 2, 2, 1, 1, 36];

    struct Bet {
        address player;
        uint8 betType;
        uint8 number;
    }

    Bet[] public bets;

    event BetPlaced(address indexed player, uint8 betType, uint8 number);
    event RandomNumber(uint256 number);
    event WinningsWithdrawn(address indexed player, uint256 amount);

    modifier onlyCreator() {
        require(msg.sender == creator, "Only the creator can perform this action");
        _;
    }

    constructor() {
        creator = payable(msg.sender);
        nextRoundTimestamp = block.timestamp;
    }

    receive() external payable {}

    function getStatus() external view returns (
        uint256 activeBets,
        uint256 totalBetValue,
        uint256 nextSpinTime,
        uint256 bankBalance,
        uint256 playerWinnings
    ) {
        return (
            bets.length,
            bets.length * BET_AMOUNT,
            nextRoundTimestamp,
            address(this).balance,
            winnings[msg.sender]
        );
    }

    function placeBet(uint8 number, uint8 betType) external payable {
        require(msg.value == BET_AMOUNT, "Incorrect bet amount");
        require(betType <= 5, "Invalid bet type");
        require(number <= numberRange[betType], "Invalid number for bet type");

        uint256 payoutForThisBet = payouts[betType] * BET_AMOUNT;
        uint256 newBalance = necessaryBalance + payoutForThisBet;
        require(newBalance <= address(this).balance, "Insufficient bank balance");

        necessaryBalance = newBalance;
        bets.push(Bet(msg.sender, betType, number));

        emit BetPlaced(msg.sender, betType, number);
    }

    function spinWheel() external onlyCreator {
        require(bets.length > 0, "No bets placed");
        require(block.timestamp >= nextRoundTimestamp, "Cannot spin yet");

        unchecked {
            nextRoundTimestamp = block.timestamp + 1 minutes;
        }

        uint256 randomNumber = generateRandomNumber();

        for (uint256 i = 0; i < bets.length; i++) {
            Bet memory bet = bets[i];
            if (isWinningBet(bet, randomNumber)) {
                winnings[bet.player] += BET_AMOUNT * payouts[bet.betType];
            }
        }

        delete bets;
        necessaryBalance = 0;

        if (address(this).balance > MAX_BANK_BALANCE) {
            distributeProfits();
        }

        emit RandomNumber(randomNumber);
    }

    function generateRandomNumber() internal view returns (uint256) {
        uint256 random = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    blockhash(block.number - 1),
                    bets[bets.length - 1].player
                )
            )
        );
        return random % 37;
    }

    function isWinningBet(Bet memory bet, uint256 randomNumber) internal pure returns (bool) {
        if (randomNumber == 0) {
            return bet.betType == 5 && bet.number == 0;
        }

        if (bet.betType == 5) return bet.number == randomNumber;
        if (bet.betType == 4) return (bet.number == 0 ? randomNumber % 2 == 0 : randomNumber % 2 == 1);
        if (bet.betType == 3) return (bet.number == 0 ? randomNumber <= 18 : randomNumber >= 19);
        if (bet.betType == 2) return (bet.number == 0 ? randomNumber <= 12 : (bet.number == 1 ? randomNumber <= 24 : randomNumber > 24));
        if (bet.betType == 1) return (bet.number == 0 ? randomNumber % 3 == 1 : (bet.number == 1 ? randomNumber % 3 == 2 : randomNumber % 3 == 0));

        // Bet on color
        if (bet.betType == 0) {
            bool isBlack = (randomNumber <= 10 || (randomNumber >= 20 && randomNumber <= 28)) ? randomNumber % 2 == 0 : randomNumber % 2 == 1;
            return bet.number == 0 ? isBlack : !isBlack;
        }

        return false;
    }

    function cashOut() external {
        uint256 amount = winnings[msg.sender];
        require(amount > 0, "No winnings to withdraw");
        require(amount <= address(this).balance, "Insufficient contract balance");

        winnings[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit WinningsWithdrawn(msg.sender, amount);
    }

    function distributeProfits() internal {
        uint256 excessAmount = address(this).balance - MAX_BANK_BALANCE;
        if (excessAmount > 0) {
            creator.transfer(excessAmount);
        }
    }

    function terminateContract() external onlyCreator {
        selfdestruct(creator);
    }
}