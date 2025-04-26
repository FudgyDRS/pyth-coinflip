// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import { IEntropy } from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";

contract Coinflip is IEntropyConsumer {
    uint256 public numHeads;
    uint256 public numTails;
    uint256 public payoutHeads;
    uint256 public payoutTails;
    uint256 public gameNumber;
    address public owner;
    IEntropy entropy;
    uint256 public minGameBuyIn;
    uint256 public gameIndex;
    uint256 public vaultBalance;
    uint256 public gameFeePercent;


    enum Status {
        PENDING, COMPLETE, PAID
    }

    struct Game {
        uint256 pot;
        uint256 anti;
        address player1;
        address player2;
        address winner;
        Status status;
    }

    struct Player {
        uint256 totalBet;
        uint256 wins;
        uint256 losses;
        uint256 amountWon;
        uint256 amountLost;
        uint256[] games;
    }

    mapping(uint256 => Game) gameById;
    mapping(address => Player) playerByAddress;
    mapping(uint64 => uint256) gameSequenceNumber;

    event GameCreated(address player, uint256 anti, uint256 gameId);
    event GamePlayed(address player1, address player2, uint256 pot, uint256 gameId);
    event GamePaid(uint256 gameId, address winner, uint256 payout);

    error GameError(uint256 gameId, string gameError);

    modifier incrementGameIndex() {
        _;
        gameIndex++;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address entropy_) {
        owner = msg.sender;
        entropy = IEntropy(entropy_);
        // minGameBuyIn = 5 * 10**18;
        minGameBuyIn = 0.5 * 10**18; // testing
    }

    function startGame() public payable incrementGameIndex {
        require(msg.value >= minGameBuyIn, "minumum buy-in not reached");

        gameById[gameIndex] = Game(msg.value, msg.value, msg.sender, address(0), address(0), Status.PENDING);
        vaultBalance += msg.value;
        
        Player storage player = playerByAddress[msg.sender];
        player.totalBet += msg.value;
        player.games.push(gameIndex);

        vaultBalance += msg.value;
        emit GameCreated(msg.sender, msg.value, gameIndex);
    }

    function joinGame(uint256 gameId) public payable {
        Game storage game = gameById[gameId];
        require(msg.value == game.anti);
        require(game.status == Status.PENDING);
        require(game.player1 != msg.sender);
        game.player2 = msg.sender;
        game.status = Status.COMPLETE;

        Player storage player = playerByAddress[msg.sender];
        player.totalBet += msg.value;
        player.games.push(gameIndex);

        address entropyProvider = entropy.getDefaultProvider();
        uint256 fee = entropy.getFee(entropyProvider);
        game.pot += msg.value - fee;

        bytes32 userRandomNumber = keccak256(abi.encode(gameId, game.player1, game.player2, block.timestamp));
        uint64 sequenceNumber = entropy.requestWithCallback{ value: fee }(
            entropyProvider,
            userRandomNumber
        );
        gameSequenceNumber[sequenceNumber] = gameId;

        vaultBalance += msg.value - fee;
        emit GamePlayed(game.player1, msg.sender, game.pot, gameId);
    }

    function entropyCallback(
        uint64 sequenceNumber,
        address provider,
        bytes32 randomNumber
    ) internal override {
        bool success;
        uint256 gameId = gameSequenceNumber[sequenceNumber];
        Game storage game = gameById[gameId];
        Player storage player1 = playerByAddress[game.player1];
        Player storage player2 = playerByAddress[game.player2];

        // fee calculation
        uint256 fee = game.pot * gameFeePercent / 100;
        (success,) = owner.call{value: fee}("");
        require(success, "fee to owner failed");
        uint256 payout = game.pot - fee;

        // result
        uint256 result = uint256(randomNumber) %2;
        if(result > 0) {
            game.winner = game.player1; 
            player1.wins++;
            player1.amountWon += payout;
            player2.losses++;
            player2.amountLost += payout;
        } else {
            game.winner = game.player2; 
            player2.wins++;
            player2.amountWon += payout;
            player1.losses++;
            player1.amountLost += payout;
        }

        (success,) = game.winner.call{value: payout}("");
        require(success, "fee to winner failed");

        vaultBalance -= fee + payout;
        emit GamePaid(gameId, game.winner, payout);
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    function siphonMisplacedFunds(address token, address to, uint256 amount) public onlyOwner {
        if(token == address(0)) {
            uint256 balance = vaultBalance - address(this).balance;
            (bool success,) = to.call{value: balance}("");
            require(success, "eth transfer failed");
        } else {
            bytes memory message = abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), to, amount);
            (bool success,) = token.call(message);
            require(success, "token transfer failed");
        }
    }

    receive() external payable {}
}
