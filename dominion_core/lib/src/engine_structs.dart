part of dominion_core;

abstract class PlayerController {
  Player player;

  /// returns true to complete action, false to not
  Future<bool> confirmAction(String prompt,
          {@required Card context, EventType event}) async =>
      (await askQuestion(prompt, ["Yes", "No"], context: context)) == "Yes";

  /// returns option from options
  Future<String> askQuestion(String prompt, List<String> options,
      {@required Card context, EventType event});

  /// Prompts the user to select some cards.
  Future<List<T>> selectCardsFrom<T extends Card>(List<T> cards, String prompt,
      {@required Card context, EventType event, int min: 0, int max});

  /// Prompts the user to select some cards from [buffer].
  Future<List<Card>> selectCardsFromBuffer(CardBuffer buffer, String prompt,
          {@required Card context,
          CardConditions conditions,
          EventType event,
          int min: 0,
          int max}) =>
      conditions == null
          ? selectCardsFrom(buffer.toList(), prompt,
              context: context, event: event, min: min, max: max)
          : selectCardsFrom(
              buffer
                  .toList()
                  .where((card) => conditions.allowsFor(card, player))
                  .toList(),
              prompt,
              context: context,
              event: event,
              min: min,
              max: max);

  /// Prompts the user to select a card from a list.
  Future<T> selectCardFrom<T extends Card>(List<T> cards, String prompt,
          {@required Card context,
          EventType event,
          bool optional: false}) async =>
      optional
          ? firstOrNone(await selectCardsFrom(cards, prompt,
              context: context, event: event, max: 1))
          : (await selectCardsFrom(cards, prompt,
                  context: context, event: event, min: 1, max: 1))
              .first;

  /// Prompts the user to select a card from a buffer.
  Future<Card> selectCardFromBuffer(CardBuffer buffer, String prompt,
          {@required Card context,
          CardConditions conditions,
          EventType event,
          bool optional: false}) async =>
      optional
          ? firstOrNone(await selectCardsFromBuffer(buffer, prompt,
              context: context, conditions: conditions, event: event, max: 1))
          : (await selectCardsFromBuffer(buffer, prompt,
                  context: context,
                  conditions: conditions,
                  event: event,
                  min: 1,
                  max: 1))
              .first;

  Future<List<Card>> selectCardsFromHand(String prompt,
          {@required Card context,
          CardConditions conditions,
          EventType event,
          int min: 0,
          int max}) =>
      selectCardsFromBuffer(player.hand, prompt,
          conditions: conditions,
          context: context,
          event: event,
          min: min,
          max: max);

  Future<Card> selectCardFromHand(String prompt,
          {@required Card context,
          CardConditions conditions,
          EventType event,
          bool optional: false}) =>
      selectCardFromBuffer(player.hand, prompt,
          context: context,
          conditions: conditions,
          event: event,
          optional: optional);

  /// Context may be null when buying a card during the buy phase.
  Future<Card> selectCardFromSupply(String prompt, EventType event,
          {@required Card context, CardConditions conditions, bool optional}) =>
      selectCardFrom(
          player.engine.supply.cardsInSupply
              .where((card) => conditions.allowsFor(card, player))
              .toList(),
          prompt,
          context: context,
          event: event,
          optional: optional);

  /// returns an ActionCard or null to prematurely end action phase
  Future<Action> selectActionCard() => selectCardFrom(
      player.hand.whereType<Action>(), "Select an Action card to play",
      context: null, optional: true);

  /// returns a list of TreasureCards or an empty list to stop playing treasures
  Future<List<Treasure>> selectTreasureCards({int min: 0, int max}) =>
      selectCardsFrom(player.hand.whereType<Treasure>(),
          "Select Treasure cards to play in order",
          context: null, min: min, max: max);

  /// player's name
  String name;

  void log(String msg) => print(msg);

  /// override this to reset state when game is reset (called after player is changed)
  reset() => null;
}

T firstOrNone<T>(List<T> list) => list.isEmpty ? null : list.first;

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
  /// For most cards, this should be null.
  ///
  /// For Durations and other cards kept in play by a Duration, this should be
  /// a function to be run at the start of the next turn that returns true if it
  /// persists for another turn and false otherwise.
  List<NextTurnAction> actions = [];

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
      actions.removeAt(index);
      target.receive(card);
      return true;
    }
    return false;
  }

  @override
  int receive(Card card, {NextTurnAction onNextTurn}) {
    super.receive(card);
    actions.add(onNextTurn);
    return actions.length - 1;
  }

  /// Cleans up all cards in play that are not being discarded.
  Future cleanup(Player player) async {
    int i = 0;
    var discarding = <Card>[];
    while (i < _cards.length) {
      if (actions[i] != null) {
        i++;
      } else {
        discarding.add(_cards.removeAt(i));
        actions.removeAt(i);
      }
    }
    while (player.hand.length > 0) {
      discarding.add(player.hand.removeTop());
    }
    for (var card in discarding) {
      player.discarded.receive(card);
      await card.onDiscard(player, cleanup: true, cleanedUp: discarding);
    }
  }

  /// Runs all of the next turn actions for persistant cards.
  Future runNextTurnActions() async {
    for (var i = 0; i < actions.length; i++) {
      if (actions[i] == null) continue;
      if (!(await actions[i]())) actions[i] = null;
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
  Contraband,
  Reaction
}

class Mat {
  final String name;
  final buffer = CardBuffer();

  Mat(this.name);
}
