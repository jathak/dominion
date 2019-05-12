import "package:dominion_core/dominion_core.dart";
import "package:dominion_sets/intrigue.dart";

import "package:test/test.dart";
import "package:dominion_core/test_utils.dart";

DominionEngine engine;
Player playerA;
Player playerB;
TestController ctrlA;
TestController ctrlB;

main() {
  setUp(() {
    ctrlA = new TestController("A");
    ctrlB = new TestController("B");
    var kingdom = CardRegistry.cardsWithConditions();
    Supply supply = new Supply(kingdom, 2, false);
    engine = new DominionEngine(supply, [ctrlA, ctrlB]);
    playerA = engine.players[0];
    playerB = engine.players[1];
    playerA.turn = new Turn();
  });
  group("Simple Cards - ", nonInteractionTests);
  //group("Cards with Interaction - ", interactionTests);
  //group("Throne Room", throneRoomTests);
  //group("Attacks", attackTests);
  //group("Gardens", gardensTests);
}

nonInteractionTests() {
  test("Great Hall", () async {
    List<Card> cards = playerA.hand.asList();
    playerA.hand.receive(GreatHall.instance);
    cards.add(playerA.deck[0]);
    await playerA.playAction(GreatHall.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [GreatHall.instance]);
    expect(playerA.turn.actions, equals(1));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
    expect(GreatHall.instance.getVictoryPoints(playerA), 1);
  });
  test("Shanty Town - No Actions", () async {
    List<Card> cards = playerA.hand.asList();
    playerA.hand.receive(ShantyTown.instance);
    cards.add(playerA.deck[0]);
    cards.add(playerA.deck[1]);
    await playerA.playAction(ShantyTown.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [ShantyTown.instance]);
    expect(playerA.turn.actions, equals(2));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
  test("Shanty Town - Has Actions", () async {
    playerA.hand.receive(Courtyard.instance);
    List<Card> cards = playerA.hand.asList();
    playerA.hand.receive(ShantyTown.instance);
    await playerA.playAction(ShantyTown.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [ShantyTown.instance]);
    expect(playerA.turn.actions, equals(2));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
  test("Bridge", () async {
    List<Card> cards = playerA.hand.asList();
    playerA.hand.receive(Bridge.instance);
    await playerA.playAction(Bridge.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [Bridge.instance]);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(2));
    expect(playerA.turn.coins, equals(1));
    for (Card card in CardRegistry.cardsWithConditions()) {
      expect(card.calculateCost(playerA.turn), equals(card.cost - 1));
    }
  });
  test("Bridge - Stacked", () async {
    playerA.turn.actions = 2;
    List<Card> cards = playerA.hand.asList();
    playerA.hand.receive(Bridge.instance);
    playerA.hand.receive(Bridge.instance);
    await playerA.playAction(Bridge.instance);
    await playerA.playAction(Bridge.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [Bridge.instance, Bridge.instance]);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(3));
    expect(playerA.turn.coins, equals(2));
    for (Card card in CardRegistry.cardsWithConditions()) {
      expect(card.calculateCost(playerA.turn), equals(card.cost - 2));
    }
  });
  test("Conspirator", () async {
    List<Card> cards = playerA.hand.asList();
    playerA.hand.receive(Conspirator.instance);
    await playerA.playAction(Conspirator.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [Conspirator.instance]);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(2));
  });
  test("Conspirator - 3 times", () async {
    playerA.turn.actions = 3;
    List<Card> cards = playerA.hand.asList();
    playerA.hand.receive(Conspirator.instance);
    playerA.hand.receive(Conspirator.instance);
    playerA.hand.receive(Conspirator.instance);
    cards.add(playerA.deck[0]);
    await playerA.playAction(Conspirator.instance);
    await playerA.playAction(Conspirator.instance);
    await playerA.playAction(Conspirator.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay,
        [Conspirator.instance, Conspirator.instance, Conspirator.instance]);
    expect(playerA.turn.actions, equals(1));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(6));
  });
  test("Coppersmith", () async {
    List<Card> cards = [Coppersmith.instance, Copper.instance, Copper.instance];
    playerA.hand = makeBuffer(cards);
    await playerA.playAction(Coppersmith.instance);
    playerA.turn.phase = Phase.Buy;
    await playerA.playTreasure(Copper.instance);
    await playerA.playTreasure(Copper.instance);
    expectBufferHasCards(playerA.hand, []);
    expectBufferHasCards(playerA.inPlay, cards);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(4));
  });
  test("Coppersmith - Stacked", () async {
    playerA.turn.actions = 2;
    List<Card> cards = [
      Coppersmith.instance,
      Coppersmith.instance,
      Copper.instance,
      Copper.instance
    ];
    playerA.hand = makeBuffer(cards);
    await playerA.playAction(Coppersmith.instance);
    await playerA.playAction(Coppersmith.instance);
    playerA.turn.phase = Phase.Buy;
    await playerA.playTreasure(Copper.instance);
    await playerA.playTreasure(Copper.instance);
    expectBufferHasCards(playerA.hand, []);
    expectBufferHasCards(playerA.inPlay, cards);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(6));
  });
  test("Duke", () async {
    playerA.deck.receive(Duke.instance);
    for (int i = 0; i < 5; i++) {
      expect(Duke.instance.getVictoryPoints(playerA), equals(i));
      playerA.deck.receive(Duchy.instance);
    }
    expect(Duke.instance.getVictoryPoints(playerA), equals(5));
  });
  test("Harem", () async {
    playerA.turn.phase = Phase.Buy;
    List<Card> cards = playerA.hand.asList();
    playerA.hand.receive(Harem.instance);
    await playerA.playTreasure(Harem.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [Harem.instance]);
    expect(playerA.turn.actions, equals(1));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(2));
    expect(Harem.instance.getVictoryPoints(playerA), equals(2));
  });
}

// TODO(jathak): Test Courtyard
// TODO(jathak): Test Lurker
// TODO(jathak): Test Pawn
// TODO(jathak): Test SecretChamber
// TODO(jathak): Test Masquerade
// TODO(jathak): Test Steward
// TODO(jathak): Test Swindler
// TODO(jathak): Test WishingWell
// TODO(jathak): Test Baron
// TODO(jathak): Test Diplomat
// TODO(jathak): Test Ironworks
// TODO(jathak): Test MiningVillage
// TODO(jathak): Test SecretPassage
// TODO(jathak): Test Scout
// TODO(jathak): Test Courtier
// TODO(jathak): Test Minion
// TODO(jathak): Test Patrol
// TODO(jathak): Test Replace
// TODO(jathak): Test Saboteur
// TODO(jathak): Test Torturer
// TODO(jathak): Test TradingPost
// TODO(jathak): Test Tribute
// TODO(jathak): Test Upgrade
// TODO(jathak): Test Nobles
