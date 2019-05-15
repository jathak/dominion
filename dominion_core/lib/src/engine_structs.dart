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
  //CardBuffer played = new CardBuffer();

  /// The phase this turn is currently in.
  Phase phase = Phase.Action;

  /// List of cards gained on this turn (includes bought cards)
  List<Card> gained = [];

  /// List of cards bought on this turn
  List<Card> bought = [];

  CardConditions buyConditions = CardConditions()..mustBeBuyable = true;

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

class InPlayBuffer extends CardBuffer {
  List<ForNextTurn> nextTurn = [];

  @override
  bool remove(Card card) {
    throw Exception("Use cleanup to remove cards from play!");
  }

  @override
  Card removeTop() {
    throw Exception("Use cleanup to remove cards from play!");
  }

  @override
  bool moveTo(Card card, CardTarget target) {
    int count =
        _cards.map((item) => item == card ? 1 : 0).fold(0, (a, b) => a + b);
    if (count > 0) {
      int index = _cards.indexOf(card);
      _cards.removeAt(index);
      nextTurn.removeAt(index);
      target.receive(card);
      return true;
    }
    return false;
  }

  @override
  int receive(Card card, {ForNextTurn forNextTurn}) {
    super.receive(card);
    nextTurn.add(forNextTurn);
    return nextTurn.length - 1;
  }

  /// Cleans up all cards in play that are not being discarded.
  Future cleanup(Player player) async {
    int i = 0;
    var discarding = <Card>[];
    while (i < _cards.length) {
      if (nextTurn[i]?.persists ?? false) {
        i++;
      } else {
        discarding.add(_cards.removeAt(i));
        nextTurn.removeAt(i);
      }
    }
    for (var card in discarding) {
      await card.onDiscard(player, cleanup: true, cleanedUp: discarding);
    }
  }

  /// Runs all of the next turn actions for persistant cards.
  Future runNextTurnActions() async {
    for (var forNextTurn in nextTurn) {
      if (forNextTurn != null) {
        forNextTurn.persists = await forNextTurn.action();
      }
    }
  }
}

String cardWord(int count) => count == 1 ? 'card' : 'cards';

enum Phase { Action, Buy, Cleanup }

enum EventType {
  Attack,
  GainCard,
  BuyCard,
  BlockCard,
  GuessCard,
  GainForOpponent,
  TrashCard,
  Embargo,
  Contraband
}

class Mat {
  final String name;
  final buffer = CardBuffer();

  Mat(this.name);
}
