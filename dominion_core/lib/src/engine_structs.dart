part of dominion_core;

abstract class PlayerController {
  Player player;

  /// returns an ordered list of cards
  /// selected from those meeting conditions
  /// If max is < 0, there is no maximum
  Future<List<Card>> selectCardsFromHand(Card context, CardConditions conditions, int min, int max);

  /// returns a card meeting conditions or null to select no card if allowNone is true
  Future<Card> selectCardFromSupply(EventType event, CardConditions conditions, bool allowNone);

  /// returns true to complete action, false to not
  Future<bool> confirmAction(Card context, String question);

  /// returns option from options
  Future askQuestion(Card context, String question, List options);

  /// like selectCardsFromHand but for any list of cards
  Future<List<Card>> selectCardsFrom(List<Card> cards, String question, int min, int max);

  /// returns an ActionCard or null to prematurely end action phase
  Future<ActionCard> selectActionCard();

  /// returns a list of TreasureCards or an empty list to stop playing treasures
  Future<List<TreasureCard>> selectTreasureCards();

  /// player's name
  String name;

  void log(String msg) => print(msg);

  /// override this to reset state when game is reset (called after player is changed)
  reset() => null;
}

class Turn {
  int actions = 1;
  int actionsPlayed = 0;
  int buys = 1;
  int coins = 0;
  int potions = 0;
  CardBuffer played = new CardBuffer();
  Phase phase = Phase.Action;

  /// each card processor should be in form (card, oldCost) => newCost
  /// minimizing to 0 while be handled automatically
  List<Function> costProcessors = [];

  /// used by various cards to store data that should only persist for one turn
  Map misc = {};
}

enum Phase { Action, Buy, Cleanup }

enum EventType { Attack, GainCard, BuyCard, BlockCard, GuessCard, GainForOpponent }
