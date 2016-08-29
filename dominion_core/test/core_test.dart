import "package:test/test.dart";
import "package:dominion_core/test_utils.dart";

import "package:dominion_core/dominion_core.dart";

void main() {
  group("CardBuffer", cardBufferTests);
  group("Basic Cards", basicCardsTests);
}

void cardBufferTests() {
  test("receive", () {
    CardBuffer buffer = new CardBuffer();
    buffer.receive(Copper.instance);
    buffer.receive(Silver.instance);
    buffer.receive(Province.instance);
    expect(buffer[0], equals(Copper.instance));
    expect(buffer[1], equals(Silver.instance));
    expect(buffer[2], equals(Province.instance));
  });
  test("drawTo", () {
    List<Card> cards = [Copper.instance, Silver.instance, Province.instance];
    CardBuffer source = makeBuffer(cards);
    CardBuffer target = new CardBuffer();
    expectBufferHasCards(source, cards);
    Card c = source.drawTo(target);
    expect(c, equals(Copper.instance));
    expectBufferHasCards(source, [Silver.instance, Province.instance]);
    expectBufferHasCards(target, [Copper.instance]);
    c = source.drawTo(target);
    expect(c, equals(Silver.instance));
    expectBufferHasCards(source, [Province.instance]);
    expectBufferHasCards(target, [Copper.instance, Silver.instance]);
    c = source.drawTo(target);
    expect(c, equals(Province.instance));
    expectBufferHasCards(source, []);
    expectBufferHasCards(target, cards);
    c = source.drawTo(target);
    expect(c, equals(null));
    expectBufferHasCards(source, []);
    expectBufferHasCards(target, cards);
  });
  test("dumpTo", () {
    List<Card> cards = [Copper.instance, Silver.instance, Province.instance];
    CardBuffer a = makeBuffer(cards);
    CardBuffer b = new CardBuffer();
    expectBufferHasCards(a, cards);
    expectBufferHasCards(b, []);
    a.dumpTo(b);
    expectBufferHasCards(b, cards);
    expectBufferHasCards(a, []);
    b.dumpTo(a);
    expectBufferHasCards(a, cards);
    expectBufferHasCards(b, []);
  });
  test("moveTo", () {
    List<Card> cards = [Copper.instance, Silver.instance, Province.instance];
    CardBuffer source = makeBuffer(cards);
    CardBuffer target = new CardBuffer();
    expectBufferHasCards(source, cards);
    expect(source.moveTo(Gold.instance, target), equals(false));
    bool result = source.moveTo(Silver.instance, target);
    expect(result, equals(true));
    expectBufferHasCards(source, [Copper.instance, Province.instance]);
    expectBufferHasCards(target, [Silver.instance]);
    result = source.moveTo(Province.instance, target);
    expect(result, equals(true));
    expectBufferHasCards(source, [Copper.instance]);
    expectBufferHasCards(target, [Silver.instance, Province.instance]);
    result = source.moveTo(Copper.instance, target);
    expect(result, equals(true));
    expectBufferHasCards(source, []);
    expectBufferHasCards(target, [Silver.instance, Province.instance, Copper.instance]);
    result = source.moveTo(Copper.instance, target);
    expect(result, equals(false));
    expectBufferHasCards(source, []);
    expectBufferHasCards(target, [Silver.instance, Province.instance, Copper.instance]);
  });
}

void basicCardsTests() {
  test("Treasures", () async {
    Player player = new Player(null, new TestController("Tester"));
    player.turn = new Turn();
    player.turn.phase = Phase.Buy;
    expect(player.turn.coins, equals(0));
    expect(player.turn.potions, equals(0));
    await Copper.instance.onPlay(player);
    expect(player.turn.coins, equals(1));
    expect(player.turn.potions, equals(0));
    await Silver.instance.onPlay(player);
    expect(player.turn.coins, equals(3));
    expect(player.turn.potions, equals(0));
    await Gold.instance.onPlay(player);
    expect(player.turn.coins, equals(6));
    expect(player.turn.potions, equals(0));
    await Platinum.instance.onPlay(player);
    expect(player.turn.coins, equals(11));
    expect(player.turn.potions, equals(0));
    await Potion.instance.onPlay(player);
    expect(player.turn.coins, equals(11));
    expect(player.turn.potions, equals(1));
    expect(player.turn.actions, 1);
    expect(player.turn.buys, 1);
    expectBufferHasCards(player.turn.played, []);
    for (int i = 1; i <= 4; i++) {
      expect(Copper.instance.supplyCount(i), 60 - 7 * i);
      expect(Silver.instance.supplyCount(i), 40);
      expect(Gold.instance.supplyCount(i), 30);
      expect(Platinum.instance.supplyCount(i), 12);
      expect(Potion.instance.supplyCount(i), 16);
    }
  });
  test("Others", () async {
    Player player = new Player(null, new TestController("Tester"));
    expect(await Estate.instance.getVictoryPoints(player), equals(1));
    expect(await Duchy.instance.getVictoryPoints(player), equals(3));
    expect(await Province.instance.getVictoryPoints(player), equals(6));
    expect(await Colony.instance.getVictoryPoints(player), equals(10));
    expect(await Curse.instance.getVictoryPoints(player), equals(-1));
  });
}
