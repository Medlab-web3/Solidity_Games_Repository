// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.21;

/*
Split under 21 rule:
If either of the player's hand in a split beats dealer, the player wins bet on both hands automatically.
But if the player busts on either deck, the dealer wins bet on both decks. If the player's first hand has a standoff with 
dealer, the player's other hand must beat dealer, otherwise the dealer wins.
If the player's second hand stands off with dealer, the player gets original bet back.
The player can either double down or split; the player cannot split then double down and vice versa.
*/

contract BlackJack {
    address private player;

    bool private roundInProgress;
    bool private displayUpdate;
    bool private dDown;
    bool private insurance;
    bool private insured;
    bool private split;
    bool private splitting;

    uint256 private constant ETH_LIMIT = 100000000000000 wei;
    uint256 private safeBalance;
    uint256 private origBalance;
    uint256 private splitCount;
    uint256 private rngCounter;
    uint256 private randNum;
    uint256 private playerBet;
    uint256 private playerCard1;
    uint256 private playerCard2;
    uint256 private playerNewCard;
    uint256 private playerCardTotal;
    uint256 private playerSplitTotal;
    uint256 private dealerCard1;
    uint256 private dealerCard2;
    uint256[2] private dealerNewCard;
    uint256 private dealerCardTotal;
    uint256 public gamesPlayed;

    string private dealerMsg;

    // Events
    event PlayerDeposit(address indexed contractAddress, address indexed player, uint256 amount);
    event PlayerWithdrawal(address indexed contractAddress, address indexed player, uint256 amount);

    // Modifiers
    modifier isValidAddr() {
        require(msg.sender != address(0), "Invalid Address.");
        _;
    }

    modifier isPlayer() {
        require(msg.sender == player, "Only Player can use this function.");
        _;
    }

    modifier playerTurn() {
        require(roundInProgress, "This function can only be used while round is in progress.");
        _;
    }

    modifier newRound() {
        require(!roundInProgress, "This function cannot be used while round is in progress.");
        _;
    }

    constructor() {
        roundInProgress = false;
        rngCounter = 1;
        gamesPlayed = 0;
        dealerMsg = " --> Bet Limits: 1 wei - 1000 wei. Waiting for Player Bet.";
    }

    function payContract() external payable isValidAddr newRound returns (string memory) {
        require(safeBalance + msg.value <= ETH_LIMIT, "Too much Ether!");

        if (safeBalance > 0) {
            require(player == msg.sender, "Only Player can pay this contract.");
        }

        safeBalance += msg.value;
        origBalance += msg.value;
        player = msg.sender;

        emit PlayerDeposit(address(this), msg.sender, msg.value);
        dealerMsg = "Contract Paid.";

        return dealerMsg;
    }

    function RNG() internal returns (uint256 randomNumber) {
        uint256 seed = block.timestamp - rngCounter;
        rngCounter *= 2;
        randNum = (uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), seed))) % 13) + 1;

        if (randNum > 10) {
            randNum = 10;
        }

        if (rngCounter > 420000000) {
            rngCounter = randNum;
        }

        return randNum;
    }

    function placeBet(uint256 bet) external isValidAddr isPlayer newRound returns (string memory) {
        require(bet >= 1 wei && bet <= 1000 wei, "Bet Limits are 1 wei - 1000 wei.");
        require(bet <= safeBalance, "Insufficient funds to place this bet.");

        if (!dDown && !split && !insurance) {
            playerBet = 0;
        }

        safeBalance -= bet;
        if (!insurance) {
            playerBet += bet;
        }

        roundInProgress = true;
        gamesPlayed += 1;

        if (!dDown && !split && !insurance) {
            return deal();
        } else {
            if (insurance) {
                insurance = false;
            }
            dealerMsg = "Bet Placed.";
            return dealerMsg;
        }
    }

    function cashOut() external isValidAddr isPlayer newRound returns (string memory) {
        uint256 tempBalance = origBalance;
        if (safeBalance <= origBalance) {
            dealerMsg = "You would have lost Ether! Good thing I'm a generous smart contract. Original bet returned.";
        } else {
            dealerMsg = "You are a worthy adversary! Original bet returned.";
        }

        emit PlayerWithdrawal(address(this), msg.sender, origBalance);
        safeBalance = 0;
        origBalance = 0;

        payable(msg.sender).transfer(tempBalance);
        return dealerMsg;
    }

    function deal() internal returns (string memory) {
        playerCard1 = RNG();
        if (playerCard1 == 1) {
            playerCard1 = 11;
        }

        dealerCard1 = RNG();
        playerCard2 = RNG();
        if (playerCard2 == 1 && playerCard1 < 11) {
            playerCard2 = 11;
        }

        playerCardTotal = playerCard1 + playerCard2;

        if (dealerCard1 == 1) {
            dealerMsg = " --> Want Insurance?";
            dealerCard1 = 11;
            insurance = true;
        }

        dealerCardTotal = dealerCard1 + dealerCard2;

        if (playerCardTotal == 21) {
            dealerCard2 = RNG();
            if (dealerCard2 == 1) {
                dealerCard2 = 11;
            }

            dealerCardTotal = dealerCard1 + dealerCard2;

            if (dealerCardTotal == playerCardTotal) {
                dealerMsg = " --> StandOff!";
                safeBalance += playerBet;
                roundInProgress = false;
            } else {
                dealerMsg = " --> BlackJack! Player Wins.";
                safeBalance += (playerBet * 2) + (playerBet / 2);
                roundInProgress = false;
            }
        } else {
            dealerMsg = " --> Player's Turn.";
        }

        if (playerCard1 == playerCard2) {
            split = true;
            if (insurance) {
                dealerMsg = " --> Player's Turn. Want Insurance? Player can Split.";
            } else {
                dealerMsg = " --> Player's Turn. Player can Split.";
            }
        }

        if (playerCardTotal == 9 || playerCardTotal == 10 || playerCardTotal == 11) {
            dDown = true;
            if (insurance) {
                dealerMsg = " --> Player's Turn. Want Insurance? Player can Double Down.";
                if (split) {
                    dealerMsg = " --> Player's Turn. Want Insurance? Player can Split or Double Down.";
                }
            } else {
                dealerMsg = " --> Player's Turn. Player can Double Down.";
                if (split) {
                    dealerMsg = " --> Player's Turn. Player can Split or Double Down.";
                }
            }
        }

        return dealerMsg;
    }
    
    // Hit
    function hit() isValidAddr isPlayer playerTurn public returns (string memory) {
        
        // Handle double down, insurance and splitting
        dDownInsSplit();
        
        _pNewCard = RNG();
        // Ace is 1 unless Player has a total less than 11
        if(_pNewCard == 1 && _pCardTotal < 11) {
            // Ace = 11
            _pNewCard = 11;
        }
            
        // Choose for 1st round winner during split
        if(_splitting == true) {
            _pSplitTotal += _pNewCard;
            
            // Handle hit Win
            hitWin(_pSplitTotal);
            
        } else {
            // Choose winner for normal play or second round during split
            _pCardTotal += _pNewCard;
            
            // Handle hit win
            hitWin(_pCardTotal);
        }
        return _dMsg;
        
    }
    
    //Stand
    function stand() isValidAddr isPlayer playerTurn public returns (string memory) {
        
        // Handle double down, insurance and splitting
        dDownInsSplit();
        
        // Dealer's turn
        if(_splitCount < 2) {
            // Show Dealer Card 2
            _dCard2 = RNG();
            // Ace
            if(_dCard2 == 1 && _dCard1 < 11) {
                // Ace = 11
                _dCard2 = 11;
            }
         
            // Update Dealer's card Total
            _dCardTotal = _dCard1 + _dCard2;
        
            uint256 _dCardIndex = 0;        
            // Dealer must Hit to 16 and Stand on all 17's
            while(_dCardTotal < 17) {
                _dNewCard[_dCardIndex] = RNG();
                // Ace
                if(_dNewCard[_dCardIndex] == 1 && _dCardTotal < 11) {
                    // Ace = 11
                    _dNewCard[_dCardIndex] = 11;
                }
                
                _dCardTotal += _dNewCard[_dCardIndex];
                _dCardIndex += 1;
                if(_dCardIndex > 1)
                    _dCardIndex = 0;
            }
        }
        
        // Choose winner
        if(_dCardTotal == 21) {
            // For double down play 
            if(_pCardTotal == 21 || _pSplitTotal == 21) {
                _dMsg = " --> StandOff!";
                // Update balance
                _safeBalance += _pBet;
            } else {
                if(_splitting == true) {
                    _splitCount += 1;
                    _dMsg = " --> Player's Turn.";
                }
                else {
                    _dMsg = " --> BlackJack! Dealer Wins.";
                    _roundInProgress = false;
                    if(_insured == true) {
                        _insured = false;
                        // Bet has doubled so insurance is 1/2 * bet
                        _safeBalance += (_pBet/2);
                    }
                }
            }
            
        } else if(_dCardTotal > 21) {
            if(_splitting == true) {
                _splitCount += 1;
                _dMsg = " --> Player's Turn.";
                // Update balance
                _safeBalance += (_pBet * 2);
            }
            else {
                _dMsg = " --> Dealer Bust. Player Wins.";
                // Update balance: bet * 2
                _safeBalance += (_pBet * 2);
                _roundInProgress = false;
            }
            
        } else {
            if(_pCardTotal <= 21) {
                // If dealer wins
                if((21 - _dCardTotal) < (21 - _pCardTotal)) {
                    if(_splitting == true) {
                        _splitCount += 1;
                        _dMsg = " --> Player's Turn.";
                    }
                    else {
                        _dMsg = " --> Dealer Wins.";
                        _roundInProgress = false;
                    }
                // If player wins
                } else if((21 - _dCardTotal) > (21 - _pCardTotal)) {
                    if(_splitting == true) {
                        _splitCount += 1;
                        _dMsg = " --> Player's Turn.";
                        // Update balance
                        _safeBalance += (_pBet * 2);
                    }
                    else {
                        _dMsg = " --> Player Wins.";
                        // Update balance: bet * 2
                        _safeBalance += (_pBet * 2);
                        _roundInProgress = false;
                    }
                // If its a standoff
                } else {
                    if(_splitting == true) {
                        _splitCount += 1;
                        _dMsg = " --> Player's Turn.";
                        // Update balance
                        _safeBalance += _pBet;
                    }
                    else {
                        _dMsg = " --> StandOff!";
                        // End round
                        _roundInProgress = false;
                        // Update balance: bet
                        _safeBalance += _pBet;
                    }
                }
            // Player card can only be greater than 21 on double down hand
            } else {
                _dMsg = " --> Player Bust! Dealer Wins.";
            }
        }
        
        return _dMsg;
    }
    
    
    // Double down
    function doubleDown() isValidAddr isPlayer playerTurn 
        public returns (string memory) {
        // Make sure player can double down
        require(_dDown == true, "Player cannot Double Down right now.");
        
        // If player has a chance to split but doubles down
        if(_split == true) {
            // Remove chance to split
            _split = false;
        }
        // If player has a chance to get insurance but doesn't
        if(_insurance == true) {
            // Remove chance to get insurance
            _insurance = false;
        }
        
        // Place same amount as original Bet
        uint256 bet = _pBet; 
        
        // Pause game to place Bet
        _roundInProgress = false;
        
        // Place Bet and resume game
        placeBet(bet);
        
        // Deal extra card
        _pNewCard = RNG();
        // Ace is 1 unless Player has a total less than 11
        if(_pNewCard == 1 && _pCardTotal < 11) {
            // Ace = 11
            _pNewCard = 11;
        }
        
        // Update player's card total
        _pCardTotal += _pNewCard;
        
        // Let dealer finish his hand and end round
        return stand();
    }
    
    // Split
    function split() isValidAddr isPlayer playerTurn public returns (string memory) {
        // Make sure player can double down
        require(_split == true, "Player cannot Split right now.");
        
        // If player has a chance to double down but splits
        if(_dDown == true) {
            // Remove chance to double down
            _dDown = false;
        }
        // If player has a chance to get insurance but doesn't
        if(_insurance == true) {
            // Remove chance to get insurance
            _insurance = false;
        }
        
        // Update balances
        if(_pCard1 == 11) {
            _pCardTotal = 11;
            _pSplitTotal = 11;
        }
        else {
            _pCardTotal = _pCardTotal/2;
            _pSplitTotal = _pCardTotal;
        }
        
        // Place same amount as original Bet
        uint256 bet = _pBet;
        
        // Pause game to place Bet
        _roundInProgress = false;
        
        // Place bet and resume game
        placeBet(bet);
        
        // Turn splitting on
        _splitting = true;
        
        // Turn chance to split again off
        _split = false;
        
        // If player's cards are both Aces
        if(_pCard1 == 11) {
            // Deal only one more card for card 1
            _pNewCard = RNG();
            // Ace is always 1 in this case 
            
            // Update split card total
            _pSplitTotal += _pNewCard;
            
            // Then stand
            stand();
            
            // Turn splitting off
            _splitting = false;
            // Make sure dealer doesn't draw again
            _splitCount = 2;
            
            // Deal only one more card for card 2
            _pNewCard = RNG();
            // Ace is always 1 in this case 
            
            // Update player split total
            _pCardTotal += _pNewCard;
            
            // Then stand
            stand();
        }
    }
    
    // Insurance
    function insurance() isValidAddr isPlayer playerTurn 
        public returns (string memory) {
        // Make sure player can have insurance
        require(_insurance == true, "Player cannot have insurance right now.");
        
        // Place half amount as original Bet
        uint256 bet = _pBet/2; 
        
        // Insure
        _insured = true;
        
        // Pause game to place Bet
        _roundInProgress = false;
        
        // Place Bet and resume game
        placeBet(bet);
        
    }
    
    function dDownInsSplit() internal {
        // If player has a chance to double down but hits
        if(_dDown == true) {
            // Remove chance to double down
            _dDown = false;
        }
        
        // If player has a chance to split 
        if(_split == true || _splitting == true) {
            if(_splitCount >= 2) {
                // Remove chance to split after splitting
                _splitting = false;
                _split = false;
            }
            else if(_splitting == true) {
                // Start split counter if player is splitting
                _splitCount = 1;
            } else {
            
                // If not splitting, remove chance to split
                _split = false;
            }
        }
        
        // If player has a chance to get insurance but hits
        if(_insurance == true) {
            // Remove chance to get insurance
            _insurance = false;
        }
    }
    
    function hitWin(uint256 _cTotal) internal {
        
        // BlackJack or bust
        if(_cTotal == 21) {
            // If there might be a standoff
            if(_dCard1 >= 10) {
                // Show dealer's second card
                _dCard2 = RNG();
                // Update dealer card total
                _dCardTotal = _dCard1 + _dCard2;
            }
            
            // Choose winner
            if(_dCardTotal == _cTotal) {
                _dMsg = " --> StandOff!";
                // Update balance
                if(_insured == true) {
                    _insured = false;
                    _safeBalance += (_pBet/2);
                }
                _safeBalance += _pBet;
                _roundInProgress = false;
            }
            else {
                _dMsg = " --> BlackJack! Player Wins.";
                // Update balance: bet * 2
                _safeBalance += (_pBet * 2);
                _roundInProgress = false;
            }
        } else if(_cTotal > 21) {
            _dMsg = " --> Player Bust! Dealer Wins.";
            
            // If player was insured
            if(_insured == true) {
                _insured = false;
                // Show dealer's second card
                _dCard2 = RNG();
                // Update dealer card total
                _dCardTotal = _dCard1 + _dCard2;
                // Update balance
                if(_dCardTotal == 21)
                    _safeBalance += _pBet;
            }
            _roundInProgress = false; 
        }
        else
            _dMsg = " --> Player's Turn.";
        
    }
    
    function displayTable() 
        public 
        view 
        returns (string memory Message, uint256 PlayerBet, uint256 PlayerCard1, uint256 PlayerCard2, 
                    uint256 PlayerNewCard, uint256 PlayerCardTotal, uint256 PlayerSplitTotal, 
                    uint256 DealerCard1, uint256 DealerCard2, uint256 DealerNewCard1, 
                    uint256 DealerNewCard2, uint256 DealerCardTotal, uint256 Pot) {
                        
            
        return (_dMsg, _pBet, _pCard1, _pCard2, _pNewCard, _pCardTotal, _pSplitTotal, 
            _dCard1, _dCard2, _dNewCard[0], _dNewCard[1], _dCardTotal, _safeBalance);
    }
    
}
