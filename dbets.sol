pragma solidity ^0.4.11;

/**
 * Math operations with safety checks
 */
library SafeMath {
  function mul(uint a, uint b) internal returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint a, uint b) internal returns (uint) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint a, uint b) internal returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function add(uint a, uint b) internal returns (uint) {
    uint c = a + b;
    assert(c >= a);
    return c;
  }

  function max64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a >= b ? a : b;
  }

  function min64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a < b ? a : b;
  }

  function max256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a >= b ? a : b;
  }

  function min256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a < b ? a : b;
  }

}

contract dbets {
    using SafeMath for uint;
    uint public numGames;
    uint public numBets;
    
    //NOT TO BE USED.  FOR TESTING ONLY
    address public betWinner;

    function dbets () {
        //address owner = msg.sender;
        numGames = 0;
        numBets = 0;
    }

    //Game and Bet states
    enum GameState {upcoming,open,inprogress,finished}
    enum BetState {Open,Taken,Live,Closed}

    struct Game {

        GameState gameState;

        //Basic Game variables
        uint gameTime;
        int8 awayScore;
        int8 homeScore;
        string awayTeam;
        string homeTeam;
        string league;

    }

    struct GameLine {

        //Game lines
        int8 awayML;
        int8 homeML;
        int8 awaySpread;
        int8 homeSpread;
        int8 total;
        int8 awayTotalLine;
        int8 homeTotalLine;
        bool betOpen;
    }

    struct Bet {

        /*
            Selections and BetTypes will be properties based on integers.
            BetType
                1 - Spread
                2 - Money Line
                3 - Total (over/under)

            Selection
                1 - Home Team
                2 - Away Team
                3 - Under
                4 - Over
        */

        BetState betState;

        address player;
        address house;
        uint gameIndex;
        uint betAmount;
        uint takeAmount;
        uint pick;
        uint betType;
        int8 line;

    }

    struct Player {

        uint [] betIDs;
        uint membership;

    }

    mapping (address => Player) players;
    
    //Have to set fixed Array Lengths for now.  This really needs to be dynamic
    Game [20] public games;
    GameLine [20] public gamesLines;
    Bet [100] public bets;

    //Game functions

    function addGame (string _awayTeam, string _homeTeam,string _league, uint _gameTime) {

        games[numGames].gameState = GameState.upcoming;
        games[numGames].awayTeam = _awayTeam;
        games[numGames].homeTeam = _homeTeam;
        games[numGames].gameTime = _gameTime;
        games[numGames].league = _league;
        games[numGames].awayScore = 0;
        games[numGames].homeScore = 0;

        numGames = SafeMath.add(numGames, 1);

    }

    function setLines (uint _gameIndex, int8 _awayML, int8 _homeML, int8 _awaySpread, int8 _homeSpread, int8 _total, int8 _awayTotalLine, int8 _homeTotalLine)
    {
        gamesLines[_gameIndex].awayML = _awayML;
        gamesLines[_gameIndex].homeML = _homeML;
        gamesLines[_gameIndex].awaySpread = _awaySpread;
        gamesLines[_gameIndex].homeSpread = _homeSpread;
        gamesLines[_gameIndex].total = _total;
        gamesLines[_gameIndex].awayTotalLine = _awayTotalLine;
        gamesLines[_gameIndex].homeTotalLine = _homeTotalLine;
        gamesLines[_gameIndex].betOpen = true;
    }

    function updateScore (uint _gameIndex, int8 _awayScore, int8 _homeScore)
    {
        games[_gameIndex].awayScore = _awayScore;
        games[_gameIndex].homeScore = _homeScore;
    }

    function setFinalScore (uint _gameIndex, int8 _awayScore, int8 _homeScore) returns (bool)
    {
        //Call the update score with the final values
        updateScore (_gameIndex, _awayScore, _homeScore);

        //Change the game state to finished
        games[_gameIndex].gameState = GameState.finished;
    }

    //Bets Functions
    function createBet (uint _betType, uint _betAmount, uint _takeAmount, uint _pick, uint _gameIndex, int8 _line) {

        require(gamesLines[_gameIndex].betOpen);

        bets[numBets].player = msg.sender;
        bets[numBets].betAmount = _betAmount;
        bets[numBets].takeAmount = _takeAmount;
        bets[numBets].betType = _betType;
        bets[numBets].pick = _pick;
        bets[numBets].gameIndex = _gameIndex;
        bets[numBets].line = _line;
        bets[numBets].betState = BetState.Open;

        players[msg.sender].betIDs.push(numBets);

        numBets = SafeMath.add(numBets,1);
    }

    function takeBet (uint _betIndex) payable {
        require(msg.value >= bets[_betIndex].takeAmount);
        require(bets[_betIndex].betState == BetState.Open);
        require(bets[_betIndex].player != msg.sender);

        bets[_betIndex].house = msg.sender;
        bets[_betIndex].betState = BetState.Taken;

        players[msg.sender].betIDs.push(_betIndex);
    }

    function collectWinnings (uint _betIndex) payable {
    

        require(bets[_betIndex].betState == BetState.Taken);

        uint gameID = bets[_betIndex].gameIndex;

        require(games[gameID].gameState == GameState.finished);

        betWinner = determineWinner(_betIndex, gameID);
    }

    function determineWinner (uint _betIndex, uint _gameIndex) internal returns (address) {

        Bet memory completeBet = bets[_betIndex];
        Game memory completeGame = games[_gameIndex];

        uint betType = completeBet.betType;
        uint pick = completeBet.pick;
        address winner;
        bool isPush;

        //If the wager is a Spread
        if (betType == 1){
            //Determine if player selected the Away Team
            if(pick == 1){
                if((completeGame.awayScore + completeBet.line > completeGame.homeScore)){
                    winner = completeBet.player;
                }else if((completeGame.awayScore + completeBet.line) < completeGame.homeScore){
                    winner = completeBet.house;
                }else{
                    winner = completeBet.player;
                    isPush = true;
                }
            //Determine if player selected the Home Team
            }else if(pick == 2){
                if((completeGame.homeScore + completeBet.line > completeGame.awayScore)){
                    winner = completeBet.player;
                }else if((completeGame.homeScore + completeBet.line < completeGame.awayScore)){
                    winner = completeBet.house;
                }else{
                    winner = completeBet.player;
                    isPush = true;
                }
            }
        //If wager is the Money Line
        }else if (betType == 2){
            //If the player took the Away Team
            if(pick == 1){
                if(completeGame.awayScore > completeGame.homeScore){
                    winner = completeBet.player;
                }else{
                    winner = completeBet.house;
                }
            //If the player took the Home Team
            }else if(pick == 2){
                if(completeGame.homeScore > completeGame.awayScore){
                    winner = completeBet.player;
                }else if(completeGame.homeScore < completeGame.awayScore){
                    winner = completeBet.house;
                }else{
                    winner = completeBet.player;
                    isPush = true;
                }
            }
        //If wager is the Over/Under
        }else if (betType == 3){

            if(pick == 3){
                if((completeGame.awayScore + completeGame.homeScore) > completeBet.line)
                {
                    winner = completeBet.player;
                }else if ((completeGame.awayScore + completeGame.homeScore) < completeBet.line)
                {
                    winner = completeBet.house;
                }else
                {
                    winner = completeBet.player;
                    isPush = true;
                }
            }else if(pick == 4){
                if((completeGame.awayScore + completeGame.homeScore) < completeBet.line){
                    winner = completeBet.player;
                }else if((completeGame.awayScore + completeGame.homeScore) > completeBet.line)
                {
                    winner = completeBet.house;
                }else
                {
                    winner = completeBet.player;
                    isPush = true;
                }
            }
        }
        return winner;
    }
}
