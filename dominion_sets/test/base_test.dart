import "package:dominion_core/dominion_core.dart";
import "package:dominion_sets/base_set.dart";

import "package:test/test.dart";
import "package:dominion_core/test_utils.dart";

DominionEngine engine;
Player playerA;
Player playerB;
TestController ctrlA;
TestController ctrlB;

main() {
    load();
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
    group("Cards with Interaction - ", interactionTests);
    group("Throne Room", throneRoomTests);
    group("Attacks", attackTests);
    group("Gardens", gardensTests);
}

nonInteractionTests() {
    test("Moat", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Moat.instance);
        cards.add(playerA.deck[0]);
        cards.add(playerA.deck[1]);
        await playerA.playAction(Moat.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Moat.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("Village", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Village.instance);
        cards.add(playerA.deck[0]);
        await playerA.playAction(Village.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Village.instance]);
        expect(playerA.turn.actions, equals(2));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("Woodcutter", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Woodcutter.instance);
        await playerA.playAction(Woodcutter.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Woodcutter.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(2));
        expect(playerA.turn.coins, equals(2));
    });
    test("Moneylender", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Moneylender.instance);
        await playerA.playAction(Moneylender.instance);
        cards.remove(Copper.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Moneylender.instance]);
        expectBufferHasCards(engine.trashPile, [Copper.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(3));
    });
    test("Smithy", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Smithy.instance);
        cards.add(playerA.deck[0]);
        cards.add(playerA.deck[1]);
        cards.add(playerA.deck[2]);
        await playerA.playAction(Smithy.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Smithy.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("CouncilRoom", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(CouncilRoom.instance);
        cards.add(playerA.deck[0]);
        cards.add(playerA.deck[1]);
        cards.add(playerA.deck[2]);
        cards.add(playerA.deck[3]);
        List<Card> cardsB = playerB.hand.asList();
        cardsB.add(playerB.deck[0]);
        await playerA.playAction(CouncilRoom.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerB.hand, cardsB);
        expectBufferHasCards(playerA.turn.played, [CouncilRoom.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(2));
        expect(playerA.turn.coins, equals(0));
    });
    test("Festival", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Festival.instance);
        await playerA.playAction(Festival.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Festival.instance]);
        expect(playerA.turn.actions, equals(2));
        expect(playerA.turn.buys, equals(2));
        expect(playerA.turn.coins, equals(2));
    });
    test("Laboratory", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Laboratory.instance);
        cards.add(playerA.deck[0]);
        cards.add(playerA.deck[1]);
        await playerA.playAction(Laboratory.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Laboratory.instance]);
        expect(playerA.turn.actions, equals(1));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("Market", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Market.instance);
        cards.add(playerA.deck[0]);
        await playerA.playAction(Market.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Market.instance]);
        expect(playerA.turn.actions, equals(1));
        expect(playerA.turn.buys, equals(2));
        expect(playerA.turn.coins, equals(1));
    });
    test("Witch", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Witch.instance);
        cards.add(playerA.deck[0]);
        cards.add(playerA.deck[1]);
        await playerA.playAction(Witch.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Witch.instance]);
        expectBufferHasCards(playerB.discarded, [Curse.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("Adventurer", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Adventurer.instance);
        playerA.deck = makeBuffer([Silver.instance, Duchy.instance, Gold.instance, Province.instance]);
        await playerA.playAction(Adventurer.instance);
        cards.add(Silver.instance);
        cards.add(Gold.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Adventurer.instance]);
        expectBufferHasCards(playerA.deck, [Province.instance]);
        expectBufferHasCards(playerA.discarded, [Duchy.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
}

throneRoomTests() {
    test("with Market", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Market.instance);
        playerA.hand.receive(ThroneRoom.instance);
        cards.add(playerA.deck[0]);
        cards.add(playerA.deck[1]);
        await playerA.playAction(ThroneRoom.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [ThroneRoom.instance, Market.instance]);
        expect(playerA.turn.actions, equals(2));
        expect(playerA.turn.buys, equals(3));
        expect(playerA.turn.coins, equals(2));
    });
    test("with Witch", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(Witch.instance);
        playerA.hand.receive(ThroneRoom.instance);
        cards.add(playerA.deck[0]);
        cards.add(playerA.deck[1]);
        cards.add(playerA.deck[2]);
        cards.add(playerA.deck[3]);
        await playerA.playAction(ThroneRoom.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [ThroneRoom.instance, Witch.instance]);
        expectBufferHasCards(playerB.discarded, [Curse.instance, Curse.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("with Nothing", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.hand.receive(ThroneRoom.instance);
        await playerA.playAction(ThroneRoom.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [ThroneRoom.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
}

interactionTests() {
    test("Cellar", () async {
        List<Card> cards = playerA.hand.asList();
        ctrlA.cardsFromHand = (player, context, conds, min, max) async {
            return [player.hand[0], player.hand[2]];
        };
        Card discardB = cards.removeAt(2);
        Card discardA = cards.removeAt(0);
        cards.add(playerA.deck[0]);
        cards.add(playerA.deck[1]);
        playerA.hand.receive(Cellar.instance);
        await playerA.playAction(Cellar.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Cellar.instance]);
        expectBufferHasCards(playerA.discarded, [discardA, discardB]);
        expect(playerA.turn.actions, equals(1));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("Chapel", () async {
        List<Card> cards = playerA.hand.asList();
        ctrlA.cardsFromHand = (player, context, conds, min, max) async {
            return [player.hand[0], player.hand[2]];
        };
        Card trashB = cards.removeAt(2);
        Card trashA = cards.removeAt(0);
        playerA.hand.receive(Chapel.instance);
        await playerA.playAction(Chapel.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Chapel.instance]);
        expectBufferHasCards(engine.trashPile, [trashA, trashB]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("Chancellor - Don't Discard", () async {
        List<Card> cards = playerA.hand.asList();
        List<Card> deck = playerA.deck.asList();
        ctrlA.confirm = (player, context, question) async => false;
        playerA.hand.receive(Chancellor.instance);
        await playerA.playAction(Chancellor.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Chancellor.instance]);
        expectBufferHasCards(playerA.discarded, []);
        expectBufferHasCards(playerA.deck, deck);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(2));
    });
    test("Chancellor - Discard Deck", () async {
        List<Card> cards = playerA.hand.asList();
        List<Card> deck = playerA.deck.asList();
        ctrlA.confirm = (player, context, question) async => true;
        playerA.hand.receive(Chancellor.instance);
        await playerA.playAction(Chancellor.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Chancellor.instance]);
        expectBufferHasCards(playerA.discarded, deck);
        expectBufferHasCards(playerA.deck, []);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(2));
    });
    test("Workshop", () async {
        List<Card> cards = playerA.hand.asList();
        ctrlA.cardFromSupply = (player, event, conditions, allowNone) async => Silver.instance;
        playerA.hand.receive(Workshop.instance);
        await playerA.playAction(Workshop.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, [Workshop.instance]);
        expectBufferHasCards(playerA.discarded, [Silver.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("Feast", () async {
        List<Card> cards = playerA.hand.asList();
        ctrlA.cardFromSupply = (player, event, conditions, allowNone) async => Duchy.instance;
        playerA.hand.receive(Feast.instance);
        await playerA.playAction(Feast.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.turn.played, []);
        expectBufferHasCards(engine.trashPile, [Feast.instance]);
        expectBufferHasCards(playerA.discarded, [Duchy.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("Remodel", () async {
        playerA.hand = makeBuffer([Adventurer.instance, Remodel.instance]);
        ctrlA.cardsFromHand = (player, context, conds, min, max) async => [Adventurer.instance];
        ctrlA.cardFromSupply = (player, event, conditions, allowNone) async => Province.instance;
        await playerA.playAction(Remodel.instance);
        expectBufferHasCards(playerA.hand, []);
        expectBufferHasCards(playerA.turn.played, [Remodel.instance]);
        expectBufferHasCards(engine.trashPile, [Adventurer.instance]);
        expectBufferHasCards(playerA.discarded, [Province.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("Mine", () async {
        playerA.hand = makeBuffer([Silver.instance, Mine.instance]);
        ctrlA.cardsFromHand = (player, context, conds, min, max) async => [Silver.instance];
        ctrlA.cardFromSupply = (player, event, conditions, allowNone) async => Gold.instance;
        await playerA.playAction(Mine.instance);
        expectBufferHasCards(playerA.hand, [Gold.instance]);
        expectBufferHasCards(playerA.turn.played, [Mine.instance]);
        expectBufferHasCards(engine.trashPile, [Silver.instance]);
        expectBufferHasCards(playerA.discarded, []);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("Library - Keep Actions", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.deck = makeBuffer([Village.instance, Silver.instance, Smithy.instance, Gold.instance]);
        ctrlA.confirm = (player, _a, _b) async => false;
        playerA.hand.receive(Library.instance);
        cards.add(Village.instance);
        cards.add(Silver.instance);
        await playerA.playAction(Library.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.deck, [Smithy.instance, Gold.instance]);
        expectBufferHasCards(playerA.turn.played, [Library.instance]);
        expectBufferHasCards(playerA.discarded, []);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
    test("Library - Discard Actions", () async {
        List<Card> cards = playerA.hand.asList();
        playerA.deck = makeBuffer([Village.instance, Silver.instance, Smithy.instance, Gold.instance]);
        ctrlA.confirm = (player, ctx, _b) async => true;
        playerA.hand.receive(Library.instance);
        cards.add(Silver.instance);
        cards.add(Gold.instance);
        await playerA.playAction(Library.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.deck, []);
        expectBufferHasCards(playerA.turn.played, [Library.instance]);
        expectBufferHasCards(playerA.discarded, [Village.instance, Smithy.instance]);
        expect(playerA.turn.actions, equals(0));
        expect(playerA.turn.buys, equals(1));
        expect(playerA.turn.coins, equals(0));
    });
}

attackTests() {
    test("Bureaucrat", () async {
        List<Card> cards = playerA.hand.asList();
        List<Card> deck = playerA.deck.asList();
        List<Card> deckB = playerB.deck.asList();
        List<Card> cardsB = playerB.hand.asList();
        // default TestController behavior will select first victory card it sees.
        playerB.hand.top.receive(Province.instance);
        
        playerA.hand.receive(Bureaucrat.instance);
        deck.insert(0, Silver.instance);
        deckB.insert(0, Province.instance);
        await playerA.playAction(Bureaucrat.instance);
        expectBufferHasCards(playerA.hand, cards);
        expectBufferHasCards(playerA.deck, deck);
        expectBufferHasCards(playerB.hand, cardsB);
        expectBufferHasCards(playerB.deck, deckB);
        expectBufferHasCards(playerA.turn.played, [Bureaucrat.instance]);
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
/*
    CardRegistry.register(Militia.instance);
    CardRegistry.register(Spy.instance);
    CardRegistry.register(Thief.instance);
    Moat reaction test
*/