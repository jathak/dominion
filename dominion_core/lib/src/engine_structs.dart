part of dominion_core;

abstract class PlayerController {
  Player player;

  /// returns an ordered list of cards
  /// selected from those meeting conditions
  /// If max is < 0, there is no maximum
  Future<List<Card>> selectCardsFromHand(
      Card context, CardConditions conditions, int min, int max);

  /// returns a card meeting conditions or null to select no card if allowNone is true
  Future<Card> selectCardFromSupply(
      EventType event, CardConditions conditions, bool allowNone);

  /// returns true to complete action, false to not
  Future<bool> confirmAction(Card context, String question);

  /// returns option from options
  Future askQuestion(Card context, String question, List options);

  /// like selectCardsFromHand but for any list of cards
  Future<List<Card>> selectCardsFrom(
      List<Card> cards, String question, int min, int max);

  /// returns an ActionCard or null to prematurely end action phase
  Future<Action> selectActionCard();

  /// returns a list of TreasureCards or an empty list to stop playing treasures
  Future<List<Treasure>> selectTreasureCards();

  /// player's name
  String name;

  void log(String msg) => print(msg);

  /// override this to reset state when game is reset (called after player is changed)
  reset() => null;
}

class Turn {
  /// The number of actions remaining for this turn.
  int actions = 1;

  /// The number of buys remaining for this turn.
  int buys = 1;

  /// The number of coins to spend this turn.
  int coins = 0;

  /// The number of potions to spend this turn.
  int potions = 0;

  /// The buffer containing the cards played this turn.
  CardBuffer played = new CardBuffer();

  /// The phase this turn is currently in.
  Phase phase = Phase.Action;

  /// The number of times any given type of card has been played this turn.
  Map<Card, int> playCounts = {};
  int playCount(Card card) => playCounts[card] ?? 0;
  int totalPlayCount(bool condition(Card card)) => playCounts.keys
      .where(condition)
      .fold(0, (count, card) => count + playCounts[card]);

  List<PlayListener> playListeners = [];

  List<CostProcessor> costProcessors = [];

  /// Used by various cards to store data that should only persist for one turn
  Map misc = {};
}

typedef Future PlayListener(Card card);

typedef int CostProcessor(Card card, int oldCost);

String cardWord(int count) => count == 1 ? 'card' : 'cards';

enum Phase { Action, Buy, Cleanup }

enum EventType {
  Attack,
  GainCard,
  BuyCard,
  BlockCard,
  GuessCard,
  GainForOpponent
}
