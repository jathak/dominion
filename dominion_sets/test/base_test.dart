import "package:dominion_core/dominion_core.dart";
import "package:dominion_sets/base_set.dart";

import "package:test/test.dart";
import "package:dominion_core/test_utils.dart";

main() {
  BaseSetTester().main();
}

class BaseSetTester extends GameplayTester {
  main() {
    group("Simple Cards - ", nonInteractionTests);
    group("Cards with Interaction - ", interactionTests);
    group("Throne Room", throneRoomTests);
    group("Attacks - ", attackTests);
    group("Gardens - ", gardensTests);
  }

  nonInteractionTests() {
    testPlayAction(Moat.instance, actions: 0, buys: 1, coins: 0, drewCards: 2);
    test("Merchant", () async {
      playerA.hand.receive(Silver.instance);
      playerA.hand.receive(Silver.instance);
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Merchant.instance);
      cards.add(playerA.deck[0]);
      await playerA.playAction(Merchant.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [Merchant.instance]);
      expect(playerA.turn.actions, equals(1));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(0));
      playerA.turn.phase = Phase.Buy;
      await playerA.playTreasure(Silver.instance);
      expect(playerA.turn.coins, equals(3));
      await playerA.playTreasure(Silver.instance);
      expect(playerA.turn.coins, equals(5));
    });
    test("Vassal - With Gold", () async {
      var hand = playerA.hand.toList();
      playerA.hand.receive(Vassal.instance);
      playerA.deck.top.receive(Gold.instance);
      await playerA.playAction(Vassal.instance);
      expectBufferHasCards(playerA.hand, hand);
      expectBufferHasCards(playerA.inPlay, [Vassal.instance]);
      expectBufferHasCards(playerA.discarded, [Gold.instance]);
      expect(playerA.turn.actions, equals(0));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(2));
    });
    testPlayAction(Village.instance,
        actions: 2, buys: 1, coins: 0, drewCards: 1);
    testPlayAction(Woodcutter.instance, actions: 0, buys: 2, coins: 2);
    test("Moneylender", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Moneylender.instance);
      await playerA.playAction(Moneylender.instance);
      cards.remove(Copper.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [Moneylender.instance]);
      expectBufferHasCards(engine.trashPile, [Copper.instance]);
      expect(playerA.turn.actions, equals(0));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(3));
    });
    testPlayAction(Poacher.instance,
        actions: 1, buys: 1, coins: 1, drewCards: 1);
    testPlayAction(Smithy.instance,
        actions: 0, buys: 1, coins: 0, drewCards: 3);
    testPlayAction(CouncilRoom.instance,
        actions: 0, buys: 2, coins: 0, drewCards: 4, after: () {
      var deck = startingDeck;
      var hand = startingHand + [deck.removeAt(0)];
      playerShouldHave(player: playerB, deck: deck, hand: hand);
    });
    testPlayAction(Festival.instance, actions: 2, buys: 2, coins: 2);
    testPlayAction(Laboratory.instance,
        actions: 1, buys: 1, coins: 0, drewCards: 2);
    testPlayAction(Market.instance,
        actions: 1, buys: 2, coins: 1, drewCards: 1);
    test("Adventurer", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Adventurer.instance);
      playerA.deck = makeDeck(
          [Silver.instance, Duchy.instance, Gold.instance, Province.instance]);
      await playerA.playAction(Adventurer.instance);
      cards.add(Silver.instance);
      cards.add(Gold.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [Adventurer.instance]);
      expectBufferHasCards(playerA.deck, [Province.instance]);
      expectBufferHasCards(playerA.discarded, [Duchy.instance]);
      expect(playerA.turn.actions, equals(0));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(0));
    });
  }

  throneRoomTests() {
    testGameplay("with Market", () {
      var deck = startingDeck;
      var hand = startingHand + [deck.removeAt(0), deck.removeAt(0)];

      putCardInHand(Market.instance);
      putCardInHand(ThroneRoom.instance);
      playAction(ThroneRoom.instance);
      shouldSelectCardsFrom(
          withContext: ThroneRoom.instance,
          withMin: 0,
          withMax: 1,
          response: (cards) => [cards.last]);
      playerShouldHave(
          actions: 2,
          buys: 3,
          coins: 2,
          hand: hand,
          deck: deck,
          inPlay: [ThroneRoom.instance, Market.instance],
          discarded: []);
    });
    testGameplay("with Witch", () {
      var deck = startingDeck;
      var hand = startingHand + deck.sublist(0, 4);
      deck.removeRange(0, 4);

      putCardInHand(Witch.instance);
      putCardInHand(ThroneRoom.instance);
      playAction(ThroneRoom.instance);
      shouldSelectCardsFrom(
          withContext: ThroneRoom.instance,
          withMin: 0,
          withMax: 1,
          response: (cards) => [cards.last]);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 0,
          hand: hand,
          deck: deck,
          inPlay: [ThroneRoom.instance, Witch.instance],
          discarded: []);
      playerShouldHave(
          player: playerB,
          hand: startingHand,
          deck: startingDeck,
          inPlay: [],
          discarded: [Curse.instance, Curse.instance]);
    });
    test("with Nothing", () {
      putCardInHand(ThroneRoom.instance);
      playAction(ThroneRoom.instance);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 0,
          hand: startingHand,
          deck: startingDeck,
          inPlay: [ThroneRoom.instance],
          discarded: []);
    });
  }

  interactionTests() {
    testGameplay("Cellar", () {
      var hand = startingHand;
      var discarded = [hand.removeAt(0), hand.removeAt(2)];
      var deck = startingDeck;
      hand.add(deck.removeAt(0));
      hand.add(deck.removeAt(0));

      putCardInHand(Cellar.instance);
      playAction(Cellar.instance);
      shouldSelectCardsFrom(
          withContext: Cellar.instance,
          withMin: 0,
          response: (cards) => [cards[0], cards[3]]);
      playerShouldHave(
          actions: 1,
          buys: 1,
          coins: 0,
          hand: hand,
          inPlay: [Cellar.instance],
          discarded: discarded,
          deck: deck);
    });
    testGameplay("Chapel", () {
      var hand = startingHand;
      var trashed = [hand.removeAt(0), hand.removeAt(2)];

      putCardInHand(Chapel.instance);
      playAction(Chapel.instance);
      shouldSelectCardsFrom(
          withContext: Chapel.instance,
          withMin: 0,
          withMax: 4,
          response: (cards) => [cards[0], cards[3]]);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 0,
          hand: hand,
          inPlay: [Chapel.instance],
          discarded: [],
          deck: startingDeck);
      trashPileShouldHave(trashed);
    });
    testGameplay("Chancellor - Don't Discard", () {
      putCardInHand(Chancellor.instance);
      playAction(Chancellor.instance);
      shouldConfirmAction(
          withContext: Chancellor.instance, response: () => false);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 2,
          hand: startingHand,
          inPlay: [Chancellor.instance],
          discarded: [],
          deck: startingDeck);
    });
    testGameplay("Chancellor - Don't Discard", () {
      putCardInHand(Chancellor.instance);
      playAction(Chancellor.instance);
      shouldConfirmAction(
          withContext: Chancellor.instance, response: () => true);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 2,
          hand: startingHand,
          inPlay: [Chancellor.instance],
          discarded: startingDeck,
          deck: []);
    });
    testGameplay("Harbinger", () {
      var deck = startingDeck;
      var hand = startingHand + [deck.removeAt(0)];

      putCardInHand(Harbinger.instance);
      receiveCard(Gold.instance, playerA.discarded);
      playAction(Harbinger.instance);
      shouldSelectCardsFrom(
          withContext: Harbinger.instance,
          withMin: 0,
          response: (cards) => [cards.first]);
      playerShouldHave(
          actions: 1,
          buys: 1,
          coins: 0,
          hand: hand,
          inPlay: [Harbinger.instance],
          deck: <Card>[Gold.instance] + deck,
          discarded: []);
    });
    testGameplay("Vassal - With Village", () {
      var deck = startingDeck;
      var hand = startingHand + [deck.removeAt(0)];

      putCardInHand(Vassal.instance);
      putCardOnDeck(Village.instance);
      playAction(Vassal.instance);
      shouldConfirmAction(withContext: Vassal.instance, response: () => true);
      playerShouldHave(
          actions: 2,
          buys: 1,
          coins: 2,
          hand: hand,
          inPlay: [Vassal.instance, Village.instance],
          deck: deck,
          discarded: []);
    });
    testGameplay("Workshop", () {
      putCardInHand(Workshop.instance);
      playAction(Workshop.instance);
      shouldSelectCardsFrom(
          withContext: Workshop.instance,
          withEvent: EventType.GainCard,
          withMin: 1,
          withMax: 1,
          response: (cards) => [Silver.instance]);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 0,
          hand: startingHand,
          deck: startingDeck,
          inPlay: [Workshop.instance],
          discarded: [Silver.instance]);
    });
    testGameplay("Feast", () {
      putCardInHand(Feast.instance);
      playAction(Feast.instance);
      shouldSelectCardsFrom(
          withContext: Feast.instance,
          withEvent: EventType.GainCard,
          withMin: 1,
          withMax: 1,
          response: (cards) => [Duchy.instance]);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 0,
          hand: startingHand,
          deck: startingDeck,
          inPlay: [],
          discarded: [Duchy.instance]);
      trashPileShouldHave([Feast.instance]);
    });
    testGameplay("Poacher - two empty supplies", () {
      // Empty two supplies
      var emptied = CardBuffer();
      engine.supply.supplyOf(Smithy.instance).dumpTo(emptied);
      engine.supply.supplyOf(Village.instance).dumpTo(emptied);

      var deck = startingDeck;
      var hand = startingHand + [deck.removeAt(0)];
      var discarded = [hand.removeAt(0), hand.removeAt(0)];

      putCardInHand(Poacher.instance);
      playAction(Poacher.instance);
      shouldSelectCardsFrom(
          withContext: Poacher.instance,
          withMin: 2,
          withMax: 2,
          response: (cards) => cards.sublist(0, 2));
      playerShouldHave(
          actions: 1,
          buys: 1,
          coins: 1,
          hand: hand,
          deck: deck,
          inPlay: [Poacher.instance],
          discarded: discarded);
    });
    testGameplay("Remodel", () {
      putCardInHand(Artisan.instance);
      putCardInHand(Remodel.instance);
      playAction(Remodel.instance);
      shouldSelectCardsFrom(
          withContext: Remodel.instance,
          withEvent: EventType.TrashCard,
          withMin: 1,
          withMax: 1,
          response: (cards) => [cards.last]);
      shouldSelectCardsFrom(
          withContext: Remodel.instance,
          withEvent: EventType.GainCard,
          withMin: 1,
          withMax: 1,
          response: (cards) => [Province.instance]);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 0,
          hand: startingHand,
          deck: startingDeck,
          inPlay: [Remodel.instance],
          discarded: [Province.instance]);
      trashPileShouldHave([Artisan.instance]);
    });
    testGameplay("Library - Keep Actions", () {
      putCardInHand(Library.instance);
      putCardOnDeck(Gold.instance);
      putCardOnDeck(Smithy.instance);
      putCardOnDeck(Silver.instance);
      putCardOnDeck(Village.instance);
      playAction(Library.instance);
      shouldConfirmAction(withContext: Library.instance, response: () => false);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 0,
          hand: startingHand + [Village.instance, Silver.instance],
          deck: [Smithy.instance, Gold.instance] + startingDeck,
          inPlay: [Library.instance],
          discarded: []);
    });
    testGameplay("Library - Discard Actions", () {
      putCardInHand(Library.instance);
      putCardOnDeck(Gold.instance);
      putCardOnDeck(Smithy.instance);
      putCardOnDeck(Silver.instance);
      putCardOnDeck(Village.instance);
      playAction(Library.instance);
      shouldConfirmAction(withContext: Library.instance, response: () => true);
      shouldConfirmAction(withContext: Library.instance, response: () => true);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 0,
          hand: startingHand + [Silver.instance, Gold.instance],
          deck: startingDeck,
          inPlay: [Library.instance],
          discarded: [Village.instance, Smithy.instance]);
    });
    testGameplay("Mine", () {
      putCardInHand(Silver.instance);
      putCardInHand(Mine.instance);
      playAction(Mine.instance);
      shouldSelectCardsFrom(
          withContext: Mine.instance,
          withEvent: EventType.TrashCard,
          withMin: 0,
          withMax: 1,
          response: (cards) => [cards.last]);
      shouldSelectCardsFrom(
          withContext: Mine.instance,
          withEvent: EventType.GainCard,
          withMin: 1,
          withMax: 1,
          response: (cards) => [Gold.instance]);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 0,
          hand: startingHand + [Gold.instance],
          deck: startingDeck,
          inPlay: [Mine.instance],
          discarded: []);
      trashPileShouldHave([Silver.instance]);
    });
    // TODO(jathak): Test Sentry
    // TODO(jathak): Test Artisan
  }

  attackTests() {
    testGameplay("Bureaucrat - No Victory", () {
      putCardInHand(Bureaucrat.instance);
      playAction(Bureaucrat.instance);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 0,
          hand: startingHand,
          deck: <Card>[Silver.instance] + startingDeck,
          inPlay: [Bureaucrat.instance],
          discarded: []);
      playerShouldHave(player: playerB, hand: startingHand, deck: startingDeck);
    });
    testGameplay("Bureaucrat - One Victory", () {
      putCardInHand(Bureaucrat.instance);
      putCardInHand(Duchy.instance, player: playerB);
      playAction(Bureaucrat.instance);
      playerShouldHave(
          actions: 0,
          buys: 1,
          coins: 0,
          hand: startingHand,
          deck: <Card>[Silver.instance] + startingDeck,
          inPlay: [Bureaucrat.instance],
          discarded: []);
      playerShouldHave(
          player: playerB,
          hand: startingHand,
          deck: <Card>[Duchy.instance] + startingDeck);
    });
    // TODO(jathak): Test Militia
    // TODO(jathak): Test Spy
    // TODO(jathak): Test Thief
    // TODO(jathak): Test Bandit with no choice
    testPlayAction(Witch.instance, actions: 0, buys: 1, coins: 0, drewCards: 2,
        after: () {
      playerShouldHave(player: playerB, discarded: [Curse.instance]);
    });
    // TODO(jathak): Test reaction with Moat
  }

  gardensTests() {
    test(" with 10 Cards", () async {
      int vp = Gardens.instance.getVictoryPoints(playerA);
      expect(vp, equals(1));
    });
    test(" with 15 Cards", () async {
      for (int i = 0; i < 5; i++) playerA.deck.receive(Copper.instance);
      int vp = Gardens.instance.getVictoryPoints(playerA);
      expect(vp, equals(1));
    });
    test(" with 50 Cards", () async {
      for (int i = 0; i < 40; i++) playerA.deck.receive(Copper.instance);
      int vp = Gardens.instance.getVictoryPoints(playerA);
      expect(vp, equals(5));
    });
    test(" with 99 Cards", () async {
      for (int i = 0; i < 89; i++) playerA.deck.receive(Copper.instance);
      int vp = Gardens.instance.getVictoryPoints(playerA);
      expect(vp, equals(9));
    });
  }
}
