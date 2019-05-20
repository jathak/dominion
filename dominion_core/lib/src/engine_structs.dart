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
              context: context, event: event, max: 1)) as T
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
          {@required Card context,
          CardConditions conditions,
          bool optional: false}) =>
      selectCardFrom(
          player.engine.supply.cardsInSupply
              .where((card) => conditions?.allowsFor(card, player) ?? true)
              .toList(),
          prompt,
          context: context,
          event: event,
          optional: optional);

  /// returns an ActionCard or null to prematurely end action phase
  Future<Action> selectActionCard({Card context, EventType event}) async {
    var actions = player.hand.whereType<Action>();
    if (actions.isEmpty) return null;
    return selectCardFrom<Action>(actions, "Select an Action card to play",
        context: context, event: event, optional: true);
  }

  /// returns a list of TreasureCards or an empty list to stop playing treasures
  Future<List<Treasure>> selectTreasureCards(
          {Card context, EventType event, int min: 0, int max}) =>
      selectCardsFrom(player.hand.whereType<Treasure>(),
          "Select Treasure cards to play in order",
          context: context, event: event, min: min, max: max);

  /// player's name
  String name;

  void log(String msg) => print(msg);

  /// override this to reset state when game is reset (called after player is changed)
  reset() => null;
}

Card firstOrNone(List<Card> list) => list.isEmpty ? null : list.first;

/// Parts of the turn that are serializable (for storing last turn)
class TurnStub {
  /// The number of actions remaining for this turn.
  int actions = 1;

  /// The number of buys remaining for this turn.
  int buys = 1;

  /// The number of coins to spend this turn.
  int coins = 0;

  /// The number of potions to spend this turn.
  int potions = 0;

  /// List of cards gained on this turn (includes bought cards)
  List<Card> gained = [];

  /// List of cards bought on this turn
  List<Card> bought = [];

  /// The number of times any given type of card has been played this turn.
  Map<Card, int> playCounts = {};
  int playCount(Card card) => playCounts[card] ?? 0;
  int totalPlayCount(bool condition(Card card)) => playCounts.keys
      .where(condition)
      .fold(0, (count, card) => count + playCounts[card]);

  Map<String, dynamic> serialize() => {
        'type': 'TurnStub',
        'actions': actions,
        'buys': buys,
        'coins': coins,
        'potions': potions,
        'gained': [for (var card in gained) card.name],
        'bought': [for (var card in bought) card.name],
        'playCounts': {
          for (var card in playCounts.keys) card.name: playCounts[card]
        }
      };

  static TurnStub deserialize(data) => TurnStub()
    ..actions = data['actions']
    ..buys = data['buys']
    ..coins = data['coins']
    ..potions = data['potions']
    ..gained = CardRegistry.findAll(data['gained'])
    ..bought = CardRegistry.findAll(data['bought'])
    ..playCounts = {
      for (var name in data['playCounts'].keys)
        CardRegistry.find(name): data['playCounts'][name]
    };
}

class Turn extends TurnStub {
  /// The phase this turn is currently in.
  Phase phase = Phase.Action;

  CardConditions buyConditions = CardConditions()
    ..mustBeBuyable = true
    ..mustBeAvailable = true;

  List<PlayListener> playListeners = [];

  List<CostProcessor> costProcessors = [];
}

typedef Future PlayListener(Card card);

typedef int CostProcessor(Card card, int oldCost);

class InPlayBuffer extends CardBuffer {
  /// For most cards, this should be null.
  ///
  /// For Durations and other cards kept in play by a Duration, this should be
  /// a function to be run at the start of the next turn that returns true if it
  /// persists for another turn and false otherwise.
  List<NextTurn> actions = [];

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
  int receive(Card card, {NextTurn onNextTurn}) {
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
      if (!(await actions[i].run())) actions[i] = null;
    }
  }

  Map<String, dynamic> serialize() => {
        'type': 'InPlayBuffer',
        'cards': _cards.map((card) => card.serialize()).toList(),
        'actions': actions.map((action) => action.serialize()).toList()
      };

  static InPlayBuffer deserialize(data, Player player) => InPlayBuffer()
    .._cards = Card.deserializeList(data['cards'])
    ..actions = [
      for (var action in data['actions'])
        action == null ? null : NextTurn.deserialize(action, player)
    ];
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
  Reaction,
  ActionPhase,
  BuyPhase
}

class Mat {
  final String name;
  var buffer = CardBuffer();
  final bool public;

  Mat(this.name, this.public);

  Map<String, dynamic> serialize() => {
        'type': 'Mat',
        'name': name,
        'buffer': buffer.serialize(),
        'public': public
      };

  static Mat deserialize(data) =>
      Mat(data['name'], data['public'])..buffer = data['buffer'];

  bool operator ==(other) =>
      other is Mat &&
      name == other.name &&
      public == other.public &&
      buffer.length == other.buffer.length &&
      [for (var i = 0; i < buffer.length; i++) buffer[i] == other.buffer[i]]
          .where((x) => !x)
          .isEmpty;
}

/// Represents a set of tasks to run at the start of the next turn.
/// Used for Durations
class NextTurn {
  final List<NextTurnTask> tasks;
  final NextTurn blockedOn;

  NextTurn(this.tasks, {this.blockedOn});

  Future<bool> run() async {
    for (var task in tasks.toList()) {
      await task.task();
      task.turns--;
      if (task.turns == 0) tasks.remove(task);
    }
    return !complete;
  }

  bool get complete => tasks.isEmpty && (blockedOn?.complete ?? true);

  Map<String, dynamic> serialize() => {
        'type': 'NextTurn',
        'tasks': [for (var task in tasks) task.serialize()],
        'blockedOn': blockedOn?.serialize()
      };

  static NextTurn deserialize(data, Player player) => NextTurn([
        for (var task in data['tasks'])
          if (task['type'] == 'NextTurnTask')
            NextTurnTask.deserialize(task, player)
          else
            if (task['type'] == 'StorageNextTurnTask')
              StorageNextTurnTask.deserialize(task, player)
      ],
          blockedOn: data['blockedOn'] == null
              ? null
              : NextTurn.deserialize(data['blockedOn'], player));

  static NextTurn combine(Iterable<NextTurn> nextTurns) {
    var nts = nextTurns.toList()..removeWhere((nt) => nt == null);
    if (nts.isEmpty) return null;
    if (nts.length == 1) return nts.first;
    var tasks = <NextTurnTask>[];
    for (var nt in nts) {
      tasks.addAll(nt.tasks);
    }
    return NextTurn(tasks);
  }
}

class NextTurnTask {
  final String name;
  final Future Function() task;

  /// The number of turns this task should run for. Normally 1.
  /// If this task runs for the rest of the game, set to -1.
  int turns;
  final int count;
  NextTurnTask._(this.name, this.task, {this.turns: 1, this.count: 1});

  static NextTurnTask drawCard(Player player, {int turns: 1, int count: 1}) =>
      NextTurnTask._('drawCard', () async {
        player.draw(count);
      }, turns: turns, count: count);

  static NextTurnTask extraAction(Player player,
          {int turns: 1, int count: 1}) =>
      NextTurnTask._('extraAction', () async {
        player.turn.actions += count;
      }, turns: turns, count: count);

  static NextTurnTask extraBuy(Player player, {int turns: 1, int count: 1}) =>
      NextTurnTask._('extraBuy', () async {
        player.turn.buys += count;
      }, turns: turns, count: count);

  static NextTurnTask extraCoin(Player player, {int turns: 1, int count: 1}) =>
      NextTurnTask._('extraCoin', () async {
        player.turn.coins += count;
      }, turns: turns, count: count);

  Map<String, dynamic> serialize() =>
      {'type': 'NextTurnTask', 'name': name, 'turns': turns, 'count': count};

  static NextTurnTask deserialize(data, Player player) {
    var count = data['count'] ?? 1;
    var turns = data['turns'] ?? 1;
    switch (data['name']) {
      case 'drawCard':
        return drawCard(player, turns: turns, count: count);
      case 'extraAction':
        return extraAction(player, turns: turns, count: count);
      case 'extraBuy':
        return extraBuy(player, turns: turns, count: count);
      case 'extraCoin':
        return extraCoin(player, turns: turns, count: count);
    }
    return null;
  }
}

class StorageNextTurnTask extends NextTurnTask {
  final CardBuffer buffer;
  final Card context;
  final int returnPerTurn;
  final bool public;

  StorageNextTurnTask(Player player, this.buffer,
      {@required this.context,
      this.returnPerTurn,
      this.public: false,
      int turns: 1})
      : super._('storage', () async {
          if (buffer.length == 0) return;
          if (returnPerTurn == null || buffer.length <= returnPerTurn) {
            var cards = buffer.length == 1 ? buffer[0] : buffer;
            player.notifyAnnounce(
                "You take $cards from $context into your",
                public
                    ? "takes $cards from $context into their"
                    : "takes ${buffer.length} ${cardWord(buffer.length)} "
                        "into their",
                "hand");
            buffer.dumpTo(player.hand);
          } else {
            throw Exception("returnPerTurn not yet implemented!");
          }
        }, turns: turns);

  Map<String, dynamic> serialize() => {
        'type': 'StorageNextTurnTask',
        'buffer': buffer.serialize(),
        'context': context.name,
        'returnPerTurn': returnPerTurn,
        'public': public,
        'turns': turns,
      };

  static StorageNextTurnTask deserialize(data, Player player) =>
      StorageNextTurnTask(player, CardBuffer.deserialize(data['buffer']),
          context: CardRegistry.find(data['context']),
          returnPerTurn: data['returnPerTurn'],
          public: data['public'] ?? false,
          turns: data['turns'] ?? 1);
}
