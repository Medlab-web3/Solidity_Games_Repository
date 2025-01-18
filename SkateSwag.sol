// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.21;

contract SkateSwag {
    uint256 public level;

    uint256 public constant BEER_PRICE = 0.001 ether;
    uint256 public constant BEER_DRINKING_TIME = 20 minutes;
    uint256 public constant NORMAL_PRACTICE_TIME = 20 minutes;
    uint256 public constant PRACTICE_TIME_WITH_BEER = 10 minutes;

    uint256 public beerFreeTime; // Timestamp when the player will be sober
    uint256 public nextPracticeTime; // Timestamp when the player can practice again

    /**
     * @notice Allows the player to practice skating.
     * @dev Adjusts the practice time based on sobriety and increases the level accordingly.
     */
    function practice() external {
        require(block.timestamp >= nextPracticeTime, "You need to wait before practicing again.");

        if (block.timestamp >= beerFreeTime) {
            // Player is sober
            level += 2;
            nextPracticeTime = block.timestamp + NORMAL_PRACTICE_TIME;
        } else {
            // Player is under the influence of beer
            level += 1;
            nextPracticeTime = block.timestamp + PRACTICE_TIME_WITH_BEER;
        }
    }

    /**
     * @notice Returns the current level of the player.
     * @return The player's current level.
     */
    function currentLevel() external view returns (uint256) {
        return level;
    }

    /**
     * @notice Checks if the player is currently drinking beer.
     * @return True if the player is under the influence of beer, false otherwise.
     */
    function isDrinkingBeer() external view returns (bool) {
        return block.timestamp < beerFreeTime;
    }

    /**
     * @notice Allows the player to drink beer.
     * @dev The player must pay the specified price and cannot practice immediately after.
     */
    function drinkBeer() external payable {
        require(msg.value == BEER_PRICE, "Incorrect Ether amount sent for buying beer.");
        require(block.timestamp >= nextPracticeTime, "It's too early to practice again.");
        beerFreeTime = block.timestamp + BEER_DRINKING_TIME;
    }
}