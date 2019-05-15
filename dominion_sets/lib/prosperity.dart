library prosperity;

import 'package:dominion_core/dominion_core.dart';

import 'dart:async';

abstract class Prosperity {
  final String expansion = "Prosperity";
}

@card
class Loan extends Card with Treasure, Prosperity {
  Loan._();
  static Loan instance = Loan._();

  final int cost = 3;
  final String name = "Loan";

  final int value = 1;

  onPlay(Player player) async {
    await super.onPlay(player);
    var buffer = CardBuffer();
    var card = player.deck.drawTo(buffer);
    while (card is! Treasure && card != null) {
      player.notifyAnnounce("You reveal", "reveals", "a $card");
      card = player.deck.drawTo(buffer);
    }
    if (card != null) {
      var choice = await player.controller.askQuestion(
          this, "Discard or trash your $card?", ["Discard it", "Trash it"]);
      if (choice == "Discard it") {
        await player.discardFrom(buffer, card);
      } else {
        await player.trashFrom(card, buffer);
      }
    }
    while (buffer.length > 0) {
      await player.discardFrom(buffer);
    }
  }
}

@card
class TradeRoute extends Card with Action, Prosperity {
  TradeRoute._();
  static TradeRoute instance = TradeRoute._();

  final int cost = 3;
  final String name = "Trade Route";

  onPlay(Player player) async {
    player.turn.buys++;
    player.turn.coins += player.engine.supply.cardsInSupply
        .where((card) =>
            card is Victory && player.engine.supply.supplyOf(card).used)
        .length;
  }
}

@card
class Watchtower extends Card with Action, GainReaction, Prosperity {
  Watchtower._();
  static Watchtower instance = Watchtower._();

  final int cost = 3;
  final String name = "Watchtower";

  onPlay(Player player) async {
    while (player.hand.length < 6) {
      player.draw();
    }
  }

  bool canReactTo(EventType type, Card context, Player player) {
    return type == EventType.GainCard || type == EventType.BuyCard;
  }

  onReactToGain(
      Player player, Card card, CardSource location, bool bought) async {
    var response = await player.controller.askQuestion(
        card, "Trash or put on top of deck?", ["Trash", "Put on top of deck"]);
    if (response == "Trash") {
      await player.trashFrom(card, location);
    } else {
      player.notifyAnnounce(
          "You put $card on top of your", "puts $card on top of their", "deck");
      location.moveTo(card, player.deck.top);
    }
  }
}

@card
class Bishop extends Card with Action, Prosperity {
  Bishop._();
  static Bishop instance = Bishop._();

  final int cost = 4;
  final String name = "Bishop";

  onPlay(Player player) async {
    player.turn.coins++;
    player.vpTokens++;
    if (player.hand.length > 0) {
      var card = (await player.controller
              .selectCardsFromHand(this, CardConditions(), 1, 1))
          .first;
      await player.trashFrom(card, player.hand);
      player.vpTokens += card.calculateCost(player) ~/ 2;
    }
    for (var opponent in player.engine.playersAfter(player)) {
      var card = (await opponent.controller
              .selectCardsFromHand(this, CardConditions(), 1, 1))
          .first;
      await opponent.trashFrom(card, opponent.hand);
    }
  }
}

@card
class Monument extends Card with Action, Prosperity {
  Monument._();
  static Monument instance = Monument._();

  final int cost = 4;
  final String name = "Monument";

  onPlay(Player player) async {
    player.turn.coins += 2;
    player.vpTokens++;
  }
}

@card
class Quarry extends Card with Treasure, Prosperity {
  Quarry._();
  static Quarry instance = Quarry._();

  final int cost = 4;
  final String name = "Quarry";

  final int value = 1;

  onPlay(Player player) async {
    await super.onPlay(player);
    player.turn.costProcessors.add((card, cost) {
      if (card is Action) cost -= 2;
      return cost < 0 ? 0 : cost;
    });
  }
}

@card
class Talisman extends Card with Treasure, GainListener, Prosperity {
  Talisman._();
  static Talisman instance = Talisman._();

  final int cost = 4;
  final String name = "Talisman";

  final int value = 1;

  Future<CardSource> onGainCardWhileInPlay(
      Player player, Card card, CardSource location, bool bought) async {
    if (bought && card is! Victory && card.calculateCost(player) <= 4) {
      await player.gain(card);
    }
    return location;
  }
}

@card
class WorkersVillage extends Card with Action, Prosperity {
  WorkersVillage._();
  static WorkersVillage instance = WorkersVillage._();

  final int cost = 4;
  final String name = "Worker's Village";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions += 2;
    player.turn.buys++;
  }
}

@card
class City extends Card with Action, Prosperity {
  City._();
  static City instance = City._();

  final int cost = 5;
  final String name = "City";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions += 2;
    var empty = player.engine.supply.emptyPiles;
    if (empty >= 1) player.draw();
    if (empty >= 2) {
      player.turn.buys++;
      player.turn.coins++;
    }
  }
}

@card
class Contraband extends Card with Treasure, Prosperity {
  Contraband._();
  static Contraband instance = Contraband._();

  final int cost = 5;
  final String name = "Contraband";

  final int value = 3;

  onPlay(Player player) async {
    await super.onPlay(player);
    player.turn.buys++;
    var banned = await player.engine
        .toLeftOf(player)
        .controller
        .selectCardFromSupply(EventType.Contraband, CardConditions(), false);
    player.turn.buyConditions.bannedCards.add(banned);
  }
}

@card
class CountingHouse extends Card with Action, Prosperity {
  CountingHouse._();
  static CountingHouse instance = CountingHouse._();

  final int cost = 5;
  final String name = "Counting House";

  onPlay(Player player) async {
    int coppers =
        player.discarded.asList().where((card) => card is Copper).length;
    for (var i = 0; i < coppers; i++) {
      player.discarded.moveTo(Copper.instance, player.hand);
    }
    player.notifyAnnounce(
        "You put $coppers Copper ${cardWord(coppers)} in your hand",
        "puts $coppers Copper ${cardWord(coppers)} in their hand");
  }
}

@card
class Mint extends Card with Action, Prosperity {
  Mint._();
  static Mint instance = Mint._();

  final int cost = 5;
  final String name = "Mint";

  onPlay(Player player) async {
    var cards = await player.controller.selectCardsFromHand(
        this, CardConditions()..requiredTypes = [CardType.Treasure], 0, 1);
    if (cards.isNotEmpty) {
      await player.gain(cards.first);
    }
  }

  onGain(Player player, bool bought) async {
    if (bought) {
      for (var card in player.inPlay.asList()) {
        if (card is Treasure) {
          await player.trashFrom(card, player.inPlay);
        }
      }
    }
  }
}

@card
class Mountebank extends Card with Action, Attack, Prosperity {
  Mountebank._();
  static Mountebank instance = Mountebank._();

  final int cost = 5;
  final String name = "Mountebank";

  onPlay(Player player) async {
    player.turn.coins += 2;
    await for (var opponent in player.engine.attackablePlayers(player, this)) {
      bool discardCurse = opponent.hand.contains(Curse.instance) &&
          await opponent.controller.confirmAction(this, "Discard a curse?");
      if (discardCurse) {
        await opponent.discard(Curse.instance);
      } else {
        await opponent.gain(Curse.instance);
        await opponent.gain(Copper.instance);
      }
    }
  }
}

@card
class Rabble extends Card with Action, Attack, Prosperity {
  Rabble._();
  static Rabble instance = Rabble._();

  final int cost = 5;
  final String name = "Rabble";

  onPlay(Player player) async {
    player.draw(3);
    await for (var opponent in player.engine.attackablePlayers(player, this)) {
      var buffer = CardBuffer();
      opponent.drawTo(buffer);
      opponent.drawTo(buffer);
      opponent.drawTo(buffer);
      opponent.notifyAnnounce("You reveal", "reveals", "$buffer");
      for (var card in buffer.asList()) {
        if (card is Action || card is Treasure) {
          await opponent.discardFrom(buffer);
        }
      }
      if (buffer.length <= 1) {
        buffer.dumpTo(opponent.deck.top);
        return;
      }
      var order = await player.controller.selectCardsFrom(
          buffer.asList(),
          "Rabble: Select order to put back on deck",
          buffer.length,
          buffer.length);
      for (var card in order) {
        buffer.moveTo(card, opponent.deck.top);
      }
    }
  }
}

@card
class RoyalSeal extends Card with Treasure, GainListener, Prosperity {
  RoyalSeal._();
  static RoyalSeal instance = RoyalSeal._();

  final int cost = 5;
  final String name = "Royal Seal";

  final int value = 2;

  Future<CardSource> onGainCardWhileInPlay(
      Player player, Card card, CardSource location, bool bought) async {
    if (await player.controller
        .confirmAction(card, "Put on top of your deck?")) {
      player.notifyAnnounce("You put the $card on top of your",
          "puts the $card on top of their", "deck");
      location.moveTo(card, player.deck.top);
      return player.deck.top;
    }
    return location;
  }
}

@card
class Vault extends Card with Action, Prosperity {
  Vault._();
  static Vault instance = Vault._();

  final int cost = 5;
  final String name = "Vault";

  onPlay(Player player) async {
    player.draw(2);
    var discarding = await player.controller
        .selectCardsFromHand(this, CardConditions(), 0, player.hand.length);
    for (var card in discarding) {
      await player.discard(card);
      player.turn.coins++;
    }
    for (var opponent in player.engine.playersAfter(player)) {
      if (opponent.hand.length < 2 ||
          !(await opponent.controller
              .confirmAction(this, "Discard two cards to draw one?"))) {
        continue;
      }
      var discarding = await opponent.controller
          .selectCardsFromHand(this, CardConditions(), 2, 2);
      for (var card in discarding) {
        await opponent.discard(card);
      }
      opponent.draw();
    }
  }
}

@card
class Venture extends Card with Treasure, Prosperity {
  Venture._();
  static Venture instance = Venture._();

  final int cost = 5;
  final String name = "Venture";

  final int value = 1;

  onPlay(Player player) async {
    await super.onPlay(player);
    var buffer = CardBuffer();
    var card = player.deck.drawTo(buffer);
    while (card is! Treasure && card != null) {
      player.notifyAnnounce("You reveal", "reveals", "a $card");
      card = player.deck.drawTo(buffer);
    }
    buffer.remove(card);
    while (buffer.length > 0) {
      await player.discardFrom(buffer);
    }
    if (card != null) await player.play(card);
  }
}

@card
class Goons extends Card with Action, Attack, GainListener, Prosperity {
  Goons._();
  static Goons instance = Goons._();

  final int cost = 6;
  final String name = "Goons";

  onPlay(Player player) async {
    player.turn.buys++;
    player.turn.coins += 2;
    await for (var p in player.engine.attackablePlayers(player, this)) {
      var x = p.hand.length - 3;
      var cards =
          await p.controller.selectCardsFromHand(this, CardConditions(), x, x);
      for (var c in cards) {
        await p.discard(c);
      }
    }
  }

  Future<CardSource> onGainCardWhileInPlay(
      Player player, Card card, CardSource location, bool bought) async {
    if (bought) {
      await player.vpTokens++;
    }
    return location;
  }
}

@card
class GrandMarket extends Card with Action, Prosperity {
  GrandMarket._();
  static GrandMarket instance = GrandMarket._();

  final int cost = 6;
  final String name = "Grand Market";

  bool buyable(Player player) => !player.inPlay.contains(Copper.instance);

  onPlay(Player player) async {
    player.draw();
    player.turn.actions++;
    player.turn.buys++;
    player.turn.coins += 2;
  }
}

@card
class Hoard extends Card with Treasure, GainListener, Prosperity {
  Hoard._();
  static Hoard instance = Hoard._();

  final int cost = 6;
  final String name = "Hoard";

  final int value = 2;

  Future<CardSource> onGainCardWhileInPlay(
      Player player, Card card, CardSource location, bool bought) async {
    if (bought && card is! Victory) {
      await player.gain(Gold.instance);
    }
    return location;
  }
}

@card
class Bank extends Card with Treasure, Prosperity {
  Bank._();
  static Bank instance = Bank._();

  final int cost = 7;
  final String name = "Bank";

  int getTreasureValue(Player player) =>
      player.inPlay.asList().where((card) => card is Treasure).length;
}

@card
class Expand extends Card with Action, Prosperity {
  Expand._();
  static Expand instance = Expand._();

  final int cost = 7;
  final String name = "Expand";

  onPlay(Player player) async {
    var cards = await player.controller
        .selectCardsFromHand(this, CardConditions(), 1, 1);
    if (cards.length != 1) return;
    await player.trashFrom(cards[0], player.hand);
    var card = await player.selectCardToGain(
        conditions: CardConditions()
          ..maxCost = cards.first.calculateCost(player) + 3);
    await player.gain(card);
  }
}

@card
class Forge extends Card with Action, Prosperity {
  Forge._();
  static Forge instance = Forge._();

  final int cost = 7;
  final String name = "Forge";

  onPlay(Player player) async {
    var cards = await player.controller
        .selectCardsFromHand(this, CardConditions(), 0, player.hand.length);
    var cost = 0;
    for (var card in cards) {
      cost += card.calculateCost(player);
      await player.trashFrom(card, player.hand);
    }
    var card = await player.selectCardToGain(
        conditions: CardConditions()..cost = cost);
    await player.gain(card);
  }
}

@card
class KingsCourt extends Card with Action, Prosperity {
  KingsCourt._();
  static KingsCourt instance = KingsCourt._();

  final int cost = 7;
  final String name = "King's Court";

  Future<ForNextTurn> onPlayCanPersist(Player player) async {
    var card = await player.controller.selectActionCard();
    if (card == null) return null;
    player.turn.actions++; // since playAction will decrement this
    var index = await player.playAction(card);
    player.notifyAnnounce("You play", "plays", "the $card again");
    var secondFNT = await player.play(card);
    player.notifyAnnounce("You play", "plays", "the $card a third time");
    var thirdFNT = await player.play(card);
    if (card is Duration) {
      var firstFNT = player.inPlay.nextTurn[index];
      var fnts = [firstFNT, secondFNT, thirdFNT];
      fnts.removeWhere((fnt) => fnt == null);
      if (fnts.length == 1) {
        player.inPlay.nextTurn[index] = fnts.first;
      } else {
        player.inPlay.nextTurn[index] =
            ForNextTurn(fnts.any((fnt) => fnt.persists), () async {
          var persist = false;
          for (var fnt in fnts) {
            persist = await fnt.action() || persist;
          }
          return persist;
        });
      }
      return ForNextTurn(true, () async => false);
    }
    return null;
  }
}

@card
class Peddler extends Card with Action, Prosperity {
  Peddler._();
  static Peddler instance = Peddler._();

  final int cost = 8;
  final String name = "Peddler";

  int calculateCost(Player player) {
    var calcCost = super.calculateCost(player);
    if (player.turn?.phase != Phase.Buy) return calcCost;
    calcCost -=
        2 * player.inPlay.asList().where((card) => card is Action).length;
    return calcCost < 0 ? 0 : calcCost;
  }

  onPlay(Player player) async {
    player.draw();
    player.turn.actions++;
    player.turn.coins++;
  }
}
