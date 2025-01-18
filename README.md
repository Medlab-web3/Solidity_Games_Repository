# Solidity Games Repository

This repository contains various Solidity-based smart contract games. Each game is designed to showcase the functionality of Ethereum smart contracts and their integration with gameplay mechanics.

## Table of Contents

1. [Maybe Doubler](#maybe-doubler)
2. [Roulette](#roulette)
3. [Tricks](#tricks)
4. [Blackjack](#blackjack)
5. [Skate Swag](#skate-swag)
6. [Randomness and Security](#randomness-and-security)
7. [Technical Notes](#technical-notes)
8. [License](#license)

---

## Maybe Doubler

**Logic:**
- Send ETH to the contract.
- If the Unix block timestamp is **even**, you receive double your bet.
- If the Unix block timestamp is **odd**, you lose your bet.
- Assumes the contract is sufficiently funded by lost bets.



---

## Roulette

**Logic:**
- Players place bets on:
  - Color (0 for black, 1 for red).
  - Column (0 for left, 1 for middle, 2 for right).
  - Dozen (0 for first, 1 for second, 2 for third).
  - Eighteen (0 for low, 1 for high).
  - Modulus (0 for even, 1 for odd).
  - Specific numbers.
- A random number is generated when someone spins the wheel.
- Winnings are credited to the player’s account, and they can cash out anytime.


**Important Notes:**
- The randomness is derived from blockchain state (e.g., blockhash, timestamp).
- There is a balance cap of 2 ETH; excess funds are sent to the contract owner.

---

## Tricks

**Logic:**
- Allows players to set and execute simple tricks (e.g., skateboard tricks).



---

## Blackjack

**Logic:**
- Follows the regular rules of Blackjack:
  - Beat the dealer’s hand by getting as close to 21 as possible.
  - Includes special rules such as Reno Rule and modified splitting mechanics.
- Players can double down or split but not both simultaneously.



**Technical Notes:**
- Deployed using Solidity compiler version `0.8.21`.

---

## Skate Swag

**Logic:**
- Players improve their skateboarding skills by exercising and managing energy.
- Items like beer help players recover faster and improve performance.

---

## Randomness and Security

### Randomness
- True randomness isn’t feasible in the Ethereum Virtual Machine (EVM).
- Random numbers are derived from:
  - Blockhash of the previous block.
  - Current block timestamp.
  - Current block difficulty.
  - The last accepted bet.
- Vulnerabilities:
  - Miners can manipulate certain factors, making the system predictable under specific conditions.

### Security Measures
1. Randomness depends on the last bet, making direct attacks difficult.
2. Balance cap prevents excessive losses to attackers.
3. Regular balance checks ensure the contract remains operational.

---

## Technical Notes
- Solidity version compatibility:
  - Blackjack contract uses `0.8.21` due to stack limitations.
  - Other contracts are compatible with later versions.
- Gas optimization is implemented where possible, but costs may vary by network congestion.

---

## License
This repository is licensed under the MIT License. See the LICENSE file for more details.
