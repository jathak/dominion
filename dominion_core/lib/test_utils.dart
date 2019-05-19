library test_utils;

import 'package:dominion_core/dominion_core.dart';

import 'package:meta/meta.dart';
import 'package:test/test.dart';

import 'dart:async';

expectBufferHasCards(CardBuffer buffer, List<Card> cards) {
  expect(buffer.toList(), equals(cards));
}

CardBuffer makeBuffer(List<Card> cards) {
  var buffer = CardBuffer();
  for (var c in cards) buffer.receive(c);
  return buffer;
}

Deck makeDeck(List<Card> cards) {
  var deck = Deck();
  for (var c in cards) deck.receive(c);
  return deck;
}

abstract class GameplayTester {
  DominionEngine engine;
  Player playerA;
  Player playerB;
  Player playerC;
  Player playerD;
  TestController ctrlA;
  TestController ctrlB;
  TestController ctrlC;
  TestController ctrlD;

  int numPlayers;

  GameplayTester(
      {Iterable<Card> kingdom,
      this.numPlayers = 2,
      bool expensiveBasics = false}) {
    if (numPlayers > 4) throw Exception("Maximum of four players supported!");
    if (numPlayers < 2) throw Exception("Minimum of two players required!");
    setUp(() {
      var supply = Supply(kingdom ?? CardRegistry.cardsWithConditions(),
          numPlayers, expensiveBasics);
      ctrlA = TestController("A");
      ctrlB = TestController("B");
      var controllers = [ctrlA, ctrlB];
      if (numPlayers > 2) {
        ctrlC = TestController("C");
        controllers.add(ctrlC);
      }
      if (numPlayers > 3) {
        ctrlD = TestController("D");
        controllers.add(ctrlD);
      }
      engine = DominionEngine(supply, controllers);
      playerA = engine.players[0];
      playerB = engine.players[1];
      if (numPlayers > 2) playerC = engine.players[2];
      if (numPlayers > 3) playerD = engine.players[3];
      for (var player in engine.players) {
        player.deck = makeDeck(startingDeck);
        player.hand = makeBuffer(startingHand);
      }
      playerA.turn = Turn();
    });
  }

  main();

  /// Queue of game actions and checks within a test.
  List<GameplayStep> _steps;

  GameplayStep get _step => _steps.last;

  testGameplay(description, void body()) {
    test(description, () async {
      _steps = [GameplayStep()];
      body();
      for (var step in _steps) {
        await step.run(engine);
      }
    });
  }

  testPlayAction(Action card,
      {void before(),
      void after(),
      @required int actions,
      @required int buys,
      @required int coins,
      int drewCards: 0,
      List<Card> trashPile: const [],
      List<Card> discarded: const []}) {
    testGameplay(card.toString(), () {
      (before ?? () => null)();
      var hand = playerA.hand.toList();
      var deck = playerB.deck.toList();
      for (var i = 0; i < drewCards; i++) {
        hand.add(deck.removeAt(0));
      }
      putCardInHand(card);
      playAction(card);
      (after ?? () => null)();
      playerShouldHave(
          actions: actions,
          buys: buys,
          coins: coins,
          hand: hand,
          deck: deck,
          inPlay: [card],
          discarded: discarded);
    });
  }

  void _addPlayerTask(Player player, Function(Player) task) {
    _addTask(() => task(player ?? playerA));
  }

  void _addTask(Function() task) {
    if (_step.expectedGameState != null || _step.expectedQueries != null) {
      _steps.add(GameplayStep());
    }
    _step.engineTasks.add(task);
  }

  void playAction(Action card, {Player player}) {
    _addPlayerTask(player, (player) async {
      await player.playAction(card);
    });
  }

  void moveCard(Card card, CardSource from, CardTarget to) {
    _addTask(() => from.moveTo(card, to));
  }

  void receiveCard(Card card, CardTarget target) {
    _addTask(() => target.receive(card));
  }

  void putCardInHand(Card card, {Player player}) {
    _addPlayerTask(player, (player) => player.hand.receive(card));
  }

  void putCardOnDeck(Card card, {Player player}) {
    _addPlayerTask(player, (player) => player.deck.top.receive(card));
  }

  void shouldAskQuestion(
      {Player player,
      String withPrompt,
      Card withContext,
      EventType withEvent,
      @required String response(List<String> options)}) {
    player ??= playerA;
    _step.expectedQueries.add(() {
      (player.controller as TestController).expectQuestion(
          withPrompt: withPrompt,
          withContext: withContext,
          withEvent: withEvent,
          response: response);
    });
  }

  void shouldConfirmAction(
      {Player player,
      String withPrompt,
      Card withContext,
      EventType withEvent,
      @required bool response()}) {
    player ??= playerA;
    _step.expectedQueries.add(() {
      (player.controller as TestController).expectConfirm(
          withPrompt: withPrompt,
          withContext: withContext,
          withEvent: withEvent,
          response: response);
    });
  }

  void shouldSelectCardsFrom(
      {Player player,
      Type ofType,
      String withPrompt,
      Card withContext,
      EventType withEvent,
      int withMin,
      int withMax,
      @required List<Card> response(List<Card> cards)}) {
    player ??= playerA;
    _step.expectedQueries.add(() {
      (player.controller as TestController).expectSelectCards(
          withPrompt: withPrompt,
          withContext: withContext,
          withEvent: withEvent,
          withMin: withMin,
          withMax: withMax,
          response: response);
    });
  }

  List<Card> get startingHand => List.generate(5, (_) => Copper.instance);
  List<Card> get startingDeck => [
        Estate.instance,
        Estate.instance,
        Estate.instance,
        Copper.instance,
        Copper.instance
      ];

  void playerShouldHave(
      {Player player,
      int actions,
      int buys,
      int coins,
      List<Card> deck,
      List<Card> hand,
      List<Card> inPlay,
      List<Card> discarded}) {
    player ??= playerA;
    _step.expectedGameState ??= GameStateCheck()..engine = engine;
    _step.expectedGameState.playerStates
        .putIfAbsent(player, () => PlayerStateCheck()..player = player);
    var state = _step.expectedGameState.playerStates[player];
    if ((actions != null && state.actions != null) &&
        (buys != null && state.buys != null) &&
        (coins != null && state.coins != null) &&
        (deck != null && state.deck != null) &&
        (hand != null && state.hand != null) &&
        (inPlay != null && state.inPlay != null) &&
        (discarded != null && state.discarded != null)) {
      _steps.add(GameplayStep());
      playerShouldHave(
          player: player,
          actions: actions,
          buys: buys,
          coins: coins,
          deck: deck,
          hand: hand,
          inPlay: inPlay,
          discarded: discarded);
      return;
    }
    state.actions = actions;
    state.buys = buys;
    state.coins = coins;
    state.deck = deck;
    state.hand = hand;
    state.inPlay = inPlay;
    state.discarded = discarded;
  }

  void trashPileShouldHave(List<Card> cards) {
    _step.expectedGameState ??= GameStateCheck()..engine = engine;
    if (_step.expectedGameState.trashPile != null) {
      _steps.add(GameplayStep());
      trashPileShouldHave(cards);
      return;
    }
    _step.expectedGameState.trashPile = cards;
  }
}

class GameplayStep {
  final engineTasks = <Function()>[];
  final expectedQueries = <Function()>[];

  GameStateCheck expectedGameState;

  run(DominionEngine engine) async {
    for (var query in expectedQueries) {
      query();
    }
    for (var task in engineTasks) {
      await task();
    }
    var mismatches = <String>[];
    expectedGameState?.findMismatches(mismatches);
    if (mismatches.isNotEmpty) {
      fail(mismatches.join('\n'));
    }
    for (var player in engine.players) {
      var ctrl = player.controller as TestController;
      if (ctrl.answerers.isNotEmpty) fail("answerQuestion not called!");
      if (ctrl.confirmers.isNotEmpty) fail("confirmAction not called!");
      if (ctrl.selectors.isNotEmpty) fail("selectCardsFrom not called!");
    }
  }
}

class GameStateCheck {
  DominionEngine engine;
  final playerStates = <Player, PlayerStateCheck>{};
  List<Card> trashPile;

  void findMismatches(List<String> mismatches) {
    for (var checks in playerStates.values) {
      var mm = <String>[];
      checks.findMismatches(mm);
      if (mm.isNotEmpty) {
        mismatches.add("Player ${checks.player.name}");
        mismatches.addAll(mm);
      }
    }
    _checkBuffer("Trash", engine.trashPile, trashPile, mismatches, indent: '');
    // TODO(jathak): Check supply piles
    if (mismatches.isNotEmpty) {
      mismatches.insert(0, "Incorrect game state!");
    }
  }
}

class PlayerStateCheck {
  Player player;
  int actions;
  int buys;
  int coins;
  List<Card> deck;
  List<Card> hand;
  List<Card> inPlay;
  List<Card> discarded;

  void findMismatches(List<String> mismatches) {
    _checkBuffer("Deck", player.deck, deck, mismatches);
    _checkBuffer("Hand", player.hand, hand, mismatches);
    _checkBuffer("In Play", player.inPlay, inPlay, mismatches);
    _checkBuffer("Discard Pile", player.discarded, discarded, mismatches);
    var realActions = player.turn?.actions;
    var realBuys = player.turn?.buys;
    var realCoins = player.turn?.coins;
    if (actions != null && actions != realActions) {
      mismatches.add("  Expected $actions actions, actually $realActions");
    }
    if (buys != null && buys != realBuys) {
      mismatches.add("  Expected $buys buys, actually $realBuys");
    }
    if (coins != null && coins != realCoins) {
      mismatches.add("  Expected $coins coins, actually $realCoins");
    }
  }
}

void _checkBuffer(String description, CardBuffer buffer, List<Card> expected,
    List<String> mismatches,
    {String indent = '  '}) {
  if (expected == null) return;
  var actual = buffer.toList();
  var equal = actual.length == expected.length;
  if (equal) {
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) {
        equal = false;
        break;
      }
    }
  }
  if (!equal) {
    mismatches.add("${indent}$description");
    mismatches.add("${indent}  Expected: $expected");
    mismatches.add("${indent}    Actual: $actual");
    mismatches.add("${indent}");
  }
}

class TestController extends PlayerController {
  TestController(this.name);

  List<String> messages = [];

  void log(String msg) => messages.add(msg);

  String name;

  Player player;

  final answerers =
      <bool Function(String, Card, EventType), String Function(List<String>)>{};
  final confirmers =
      <bool Function(String, Card, EventType), bool Function()>{};
  final selectors = <
      bool Function(Type, String, Card, EventType, int min, int max),
      List<Card> Function(List<Card>)>{};

  void expectQuestion(
      {String withPrompt,
      Card withContext,
      EventType withEvent,
      @required String response(List<String> options)}) {
    answerers[(prompt, context, event) {
      return (withPrompt == null || withPrompt == prompt) &&
          (withContext == null || withContext == context) &&
          (withEvent == null || withEvent == event);
    }] = response;
  }

  void expectConfirm(
      {String withPrompt,
      Card withContext,
      EventType withEvent,
      @required bool response()}) {
    confirmers[(prompt, context, event) {
      return (withPrompt == null || withPrompt == prompt) &&
          (withContext == null || withContext == context) &&
          (withEvent == null || withEvent == event);
    }] = response;
  }

  void expectSelectCards(
      {Type ofType,
      String withPrompt,
      Card withContext,
      EventType withEvent,
      int withMin,
      int withMax,
      @required List<Card> response(List<Card> cards)}) {
    selectors[(type, prompt, context, event, min, max) {
      return (ofType == null || ofType == type) &&
          (withPrompt == null || withPrompt == prompt) &&
          (withContext == null || withContext == context) &&
          (withEvent == null || withEvent == event) &&
          (withMin == null || withMin == min) &&
          (withMax == null || withMax == max);
    }] = response;
  }

  @override
  Future<String> askQuestion(String prompt, List<String> options,
      {Card context, EventType event}) async {
    if (answerers.isNotEmpty) {
      var check = answerers.keys.first;
      if (check(prompt, context, event)) {
        return answerers.remove(check)(options);
      }
    }
    return fail("Unexpected controller call: "
            "askQuestion($prompt, $options, context: $context" +
        (event == null ? '' : ', event: $event') +
        ")");
  }

  @override
  Future<bool> confirmAction(String prompt,
      {Card context, EventType event}) async {
    for (var check in confirmers.keys.toList()) {
      if (check(prompt, context, event)) {
        return confirmers.remove(check)();
      }
    }
    return fail("Unexpected controller call: "
            "confirmAction($prompt, context: $context" +
        (event == null ? '' : ', event: $event') +
        ")");
  }

  @override
  Future<List<T>> selectCardsFrom<T extends Card>(List<T> cards, String prompt,
      {Card context, EventType event, int min = 0, int max}) async {
    for (var check in selectors.keys.toList()) {
      if (check(T, prompt, context, event, min, max)) {
        return selectors.remove(check)(cards);
      }
    }
    return fail("Unexpected controller call: "
            "selectCardsFrom($cards, $prompt, context: $context" +
        (event == null ? '' : ', event: $event') +
        (min == null ? '' : ', min: $min') +
        (max == null ? '' : ', max: $max') +
        ")");
  }
}
