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
  }

  nonInteractionTests() {
    test("Moat", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Moat.instance);
      cards.add(playerA.deck[0]);
      cards.add(playerA.deck[1]);
      await playerA.playAction(Moat.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [Moat.instance]);
      expect(playerA.turn.actions, equals(0));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(0));
    });
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
    test("Village", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Village.instance);
      cards.add(playerA.deck[0]);
      await playerA.playAction(Village.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [Village.instance]);
      expect(playerA.turn.actions, equals(2));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(0));
    });
    test("Woodcutter", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Woodcutter.instance);
      await playerA.playAction(Woodcutter.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [Woodcutter.instance]);
      expect(playerA.turn.actions, equals(0));
      expect(playerA.turn.buys, equals(2));
      expect(playerA.turn.coins, equals(2));
    });
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
    test("Poacher - no empty supplies", () async {
      var hand = playerA.hand.toList();
      playerA.hand.receive(Poacher.instance);
      hand.add(playerA.deck[0]);
      await playerA.playAction(Poacher.instance);
      expectBufferHasCards(playerA.hand, hand);
      expectBufferHasCards(playerA.inPlay, [Poacher.instance]);
      expectBufferHasCards(playerA.discarded, []);
      expect(playerA.turn.actions, equals(1));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(1));
    });
    test("Smithy", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Smithy.instance);
      cards.add(playerA.deck[0]);
      cards.add(playerA.deck[1]);
      cards.add(playerA.deck[2]);
      await playerA.playAction(Smithy.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [Smithy.instance]);
      expect(playerA.turn.actions, equals(0));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(0));
    });
    // TODO(jathak): Test Bandit with no choice
    test("CouncilRoom", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(CouncilRoom.instance);
      cards.add(playerA.deck[0]);
      cards.add(playerA.deck[1]);
      cards.add(playerA.deck[2]);
      cards.add(playerA.deck[3]);
      List<Card> cardsB = playerB.hand.toList();
      cardsB.add(playerB.deck[0]);
      await playerA.playAction(CouncilRoom.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerB.hand, cardsB);
      expectBufferHasCards(playerA.inPlay, [CouncilRoom.instance]);
      expect(playerA.turn.actions, equals(0));
      expect(playerA.turn.buys, equals(2));
      expect(playerA.turn.coins, equals(0));
    });
    test("Festival", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Festival.instance);
      await playerA.playAction(Festival.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [Festival.instance]);
      expect(playerA.turn.actions, equals(2));
      expect(playerA.turn.buys, equals(2));
      expect(playerA.turn.coins, equals(2));
    });
    test("Laboratory", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Laboratory.instance);
      cards.add(playerA.deck[0]);
      cards.add(playerA.deck[1]);
      await playerA.playAction(Laboratory.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [Laboratory.instance]);
      expect(playerA.turn.actions, equals(1));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(0));
    });
    test("Market", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Market.instance);
      cards.add(playerA.deck[0]);
      await playerA.playAction(Market.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [Market.instance]);
      expect(playerA.turn.actions, equals(1));
      expect(playerA.turn.buys, equals(2));
      expect(playerA.turn.coins, equals(1));
    });
    test("Witch", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Witch.instance);
      cards.add(playerA.deck[0]);
      cards.add(playerA.deck[1]);
      await playerA.playAction(Witch.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [Witch.instance]);
      expectBufferHasCards(playerB.discarded, [Curse.instance]);
      expect(playerA.turn.actions, equals(0));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(0));
    });
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
    test("with Market", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Market.instance);
      playerA.hand.receive(ThroneRoom.instance);
      cards.add(playerA.deck[0]);
      cards.add(playerA.deck[1]);
      await playerA.playAction(ThroneRoom.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(
          playerA.inPlay, [ThroneRoom.instance, Market.instance]);
      expect(playerA.turn.actions, equals(2));
      expect(playerA.turn.buys, equals(3));
      expect(playerA.turn.coins, equals(2));
    });
    test("with Witch", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(Witch.instance);
      playerA.hand.receive(ThroneRoom.instance);
      cards.add(playerA.deck[0]);
      cards.add(playerA.deck[1]);
      cards.add(playerA.deck[2]);
      cards.add(playerA.deck[3]);
      await playerA.playAction(ThroneRoom.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(
          playerA.inPlay, [ThroneRoom.instance, Witch.instance]);
      expectBufferHasCards(playerB.discarded, [Curse.instance, Curse.instance]);
      expect(playerA.turn.actions, equals(0));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(0));
    });
    test("with Nothing", () async {
      List<Card> cards = playerA.hand.toList();
      playerA.hand.receive(ThroneRoom.instance);
      await playerA.playAction(ThroneRoom.instance);
      expectBufferHasCards(playerA.hand, cards);
      expectBufferHasCards(playerA.inPlay, [ThroneRoom.instance]);
      expect(playerA.turn.actions, equals(0));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(0));
    });
  }

  interactionTests() {
    /*test("Vassal - With Gold", () async {
      var hand = playerA.hand.toList();
      playerA.hand.receive(Vassal.instance);
      playerA.deck.top.receive(Gold.instance);
      ctrlA.confirmAction_ = (question, {context, event}) async {
        expect(context, equals(Vassal.instance));
        return true;
      };
      await playerA.playAction(Vassal.instance);
      expectBufferHasCards(playerA.hand, hand);
      expectBufferHasCards(playerA.inPlay, [Vassal.instance]);
      expectBufferHasCards(playerA.discarded, [Gold.instance]);
      expect(playerA.turn.actions, equals(0));
      expect(playerA.turn.buys, equals(1));
      expect(playerA.turn.coins, equals(2));
    });*/
    testGameplay("Vassal - With Village", () {
      putCardInHand(Vassal.instance);
      putCardOnDeck(Village.instance);
      playAction(Vassal.instance);
      shouldConfirmAction(withContext: Vassal.instance, response: () => true);
      playerShouldHave(
          actions: 2,
          buys: 1,
          coins: 2,
          inPlay: [Vassal.instance, Village.instance],
          discarded: []);
    });
  }
}

/*DominionEngine engine;
Player playerA;
Player playerB;
TestController ctrlA;
TestController ctrlB;

main() {
  setUp(() {
    ctrlA = new TestController("A");
    ctrlB = new TestController("B");
    var kingdom = CardRegistry.cardsWithConditions();
    var supply = new Supply(kingdom, 2, false);
    engine = new DominionEngine(supply, [ctrlA, ctrlB]);
    playerA = engine.players[0];
    playerB = engine.players[1];
    playerA.turn = new Turn();
  });
  group("Simple Cards - ", nonInteractionTests);
  group("Cards with Interaction - ", interactionTests);
  group("Throne Room", throneRoomTests);
  group("Attacks", attackTests);
  group("Gardens", gardensTests);
}



interactionTests() {
  test("Cellar", () async {
    var cards = playerA.hand.toList();
    Card discardB = cards.removeAt(2);
    Card discardA = cards.removeAt(0);
    cards.add(playerA.deck[0]);
    cards.add(playerA.deck[1]);
    playerA.hand.receive(Cellar.instance);

    ctrlA.expectSelectCards(
        withContext: Cellar.instance,
        withMin: 0,
        response: (cards) => [cards[0], cards[2]]);
    await playerA.playAction(Cellar.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [Cellar.instance]);
    expectBufferHasCards(playerA.discarded, [discardA, discardB]);
    expect(playerA.turn.actions, equals(1));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
  test("Chapel", () async {
    List<Card> cards = playerA.hand.toList();
    ctrlA.cardsFromHand = (player, context, conds, min, max) async {
      return [player.hand[0], player.hand[2]];
    };
    Card trashB = cards.removeAt(2);
    Card trashA = cards.removeAt(0);
    playerA.hand.receive(Chapel.instance);
    await playerA.playAction(Chapel.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [Chapel.instance]);
    expectBufferHasCards(engine.trashPile, [trashA, trashB]);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
  test("Chancellor - Don't Discard", () async {
    List<Card> cards = playerA.hand.toList();
    List<Card> deck = playerA.deck.toList();
    ctrlA.confirm = (player, context, question) async => false;
    playerA.hand.receive(Chancellor.instance);
    await playerA.playAction(Chancellor.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [Chancellor.instance]);
    expectBufferHasCards(playerA.discarded, []);
    expectBufferHasCards(playerA.deck, deck);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(2));
  });
  test("Chancellor - Discard Deck", () async {
    List<Card> cards = playerA.hand.toList();
    List<Card> deck = playerA.deck.toList();
    ctrlA.confirm = (player, context, question) async => true;
    playerA.hand.receive(Chancellor.instance);
    await playerA.playAction(Chancellor.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [Chancellor.instance]);
    expectBufferHasCards(playerA.discarded, deck);
    expectBufferHasCards(playerA.deck, []);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(2));
  });
  test("Harbinger", () async {
    var cards = playerA.hand.toList();
    var deck = playerA.deck.toList();
    ctrlA.cardsFrom = (player, cards, question, min, max) async {
      expect(player, equals(playerA));
      expect(cards, equals([Gold.instance]));
      expect(min, 0);
      expect(max, 1);
      return [cards.first];
    };
    playerA.hand.receive(Harbinger.instance);
    playerA.discarded.receive(Gold.instance);
    cards.add(playerA.deck[0]);
    deck[0] = Gold.instance;
    await playerA.playAction(Harbinger.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [Harbinger.instance]);
    expectBufferHasCards(playerA.discarded, []);
    expectBufferHasCards(playerA.deck, deck);
    expect(playerA.turn.actions, equals(1));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
  test("Vassal - With Village", () async {
    var hand = playerA.hand.toList();
    playerA.hand.receive(Vassal.instance);
    playerA.deck.top.receive(Village.instance);
    ctrlA.confirm = (player, context, question) async {
      expect(player, equals(playerA));
      expect(context, equals(Village.instance));
      return true;
    };
    hand.add(playerA.deck[1]);
    await playerA.playAction(Vassal.instance);
    expectBufferHasCards(playerA.hand, hand);
    expectBufferHasCards(playerA.inPlay, [Vassal.instance, Village.instance]);
    expectBufferHasCards(playerA.discarded, []);
    expect(playerA.turn.actions, equals(2));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(2));
  });
  test("Workshop", () async {
    List<Card> cards = playerA.hand.toList();
    ctrlA.cardFromSupply =
        (player, event, conditions, allowNone) async => Silver.instance;
    playerA.hand.receive(Workshop.instance);
    await playerA.playAction(Workshop.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, [Workshop.instance]);
    expectBufferHasCards(playerA.discarded, [Silver.instance]);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
  test("Feast", () async {
    List<Card> cards = playerA.hand.toList();
    ctrlA.cardFromSupply =
        (player, event, conditions, allowNone) async => Duchy.instance;
    playerA.hand.receive(Feast.instance);
    await playerA.playAction(Feast.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.inPlay, []);
    expectBufferHasCards(engine.trashPile, [Feast.instance]);
    expectBufferHasCards(playerA.discarded, [Duchy.instance]);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
  test("Poacher - two empty supplies", () async {
    ctrlA.cardsFromHand = (player, context, conds, min, max) async {
      return [player.hand[0], player.hand[1]];
    };
    for (var i = 0; i < 10; i++) {
      engine.supply.gain(Smithy.instance, playerB, playerB.discarded);
      engine.supply.gain(Village.instance, playerB, playerB.discarded);
    }
    var hand = playerA.hand.toList();
    var discarded = [hand.removeAt(0), hand.removeAt(0)];
    playerA.hand.receive(Poacher.instance);
    hand.add(playerA.deck[0]);
    await playerA.playAction(Poacher.instance);
    expectBufferHasCards(playerA.hand, hand);
    expectBufferHasCards(playerA.inPlay, [Poacher.instance]);
    expectBufferHasCards(playerA.discarded, discarded);
    expect(playerA.turn.actions, equals(1));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(1));
  });
  test("Remodel", () async {
    playerA.hand = makeBuffer([Adventurer.instance, Remodel.instance]);
    ctrlA.cardsFromHand =
        (player, context, conds, min, max) async => [Adventurer.instance];
    ctrlA.cardFromSupply =
        (player, event, conditions, allowNone) async => Province.instance;
    await playerA.playAction(Remodel.instance);
    expectBufferHasCards(playerA.hand, []);
    expectBufferHasCards(playerA.inPlay, [Remodel.instance]);
    expectBufferHasCards(engine.trashPile, [Adventurer.instance]);
    expectBufferHasCards(playerA.discarded, [Province.instance]);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
  // TODO(jathak): Test bandit with a choice
  test("Library - Keep Actions", () async {
    List<Card> cards = playerA.hand.toList();
    playerA.deck = makeDeck(
        [Village.instance, Silver.instance, Smithy.instance, Gold.instance]);
    ctrlA.confirm = (player, _a, _b) async => false;
    playerA.hand.receive(Library.instance);
    cards.add(Village.instance);
    cards.add(Silver.instance);
    await playerA.playAction(Library.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.deck, [Smithy.instance, Gold.instance]);
    expectBufferHasCards(playerA.inPlay, [Library.instance]);
    expectBufferHasCards(playerA.discarded, []);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
  test("Library - Discard Actions", () async {
    List<Card> cards = playerA.hand.toList();
    playerA.deck = makeDeck(
        [Village.instance, Silver.instance, Smithy.instance, Gold.instance]);
    ctrlA.confirm = (player, ctx, _b) async => true;
    playerA.hand.receive(Library.instance);
    cards.add(Silver.instance);
    cards.add(Gold.instance);
    await playerA.playAction(Library.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.deck, []);
    expectBufferHasCards(playerA.inPlay, [Library.instance]);
    expectBufferHasCards(
        playerA.discarded, [Village.instance, Smithy.instance]);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
  test("Mine", () async {
    playerA.hand = makeBuffer([Silver.instance, Mine.instance]);
    ctrlA.cardsFromHand =
        (player, context, conds, min, max) async => [Silver.instance];
    ctrlA.cardFromSupply =
        (player, event, conditions, allowNone) async => Gold.instance;
    await playerA.playAction(Mine.instance);
    expectBufferHasCards(playerA.hand, [Gold.instance]);
    expectBufferHasCards(playerA.inPlay, [Mine.instance]);
    expectBufferHasCards(engine.trashPile, [Silver.instance]);
    expectBufferHasCards(playerA.discarded, []);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
  // TODO(jathak): Test Sentry
  // TODO(jathak): Test Artisan
}

attackTests() {
  test("Bureaucrat", () async {
    List<Card> cards = playerA.hand.toList();
    List<Card> deck = playerA.deck.toList();
    List<Card> deckB = playerB.deck.toList();
    List<Card> cardsB = playerB.hand.toList();
    // default TestController behavior will select first victory card it sees.
    playerB.hand =
        makeBuffer([Province.instance]..addAll(playerB.hand.toList()));

    playerA.hand.receive(Bureaucrat.instance);
    deck.insert(0, Silver.instance);
    deckB.insert(0, Province.instance);
    await playerA.playAction(Bureaucrat.instance);
    expectBufferHasCards(playerA.hand, cards);
    expectBufferHasCards(playerA.deck, deck);
    expectBufferHasCards(playerB.hand, cardsB);
    expectBufferHasCards(playerB.deck, deckB);
    expectBufferHasCards(playerA.inPlay, [Bureaucrat.instance]);
    expect(playerA.turn.actions, equals(0));
    expect(playerA.turn.buys, equals(1));
    expect(playerA.turn.coins, equals(0));
  });
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

    CardRegistry.register(Militia.instance);
    CardRegistry.register(Spy.instance);
    CardRegistry.register(Thief.instance);
    Moat reaction test
*/
