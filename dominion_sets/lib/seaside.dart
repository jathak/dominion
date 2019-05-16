library seaside;

import 'package:dominion_core/dominion_core.dart';

import 'dart:async';

abstract class Seaside {
  final String expansion = "Seaside";
}

@card
class Embargo extends Card with Action, Seaside {
  Embargo._();
  static Embargo instance = Embargo._();

  final int cost = 2;
  final String name = "Embargo";

  onPlay(Player player) async {
    player.turn.coins += 2;
    await player.trashFrom(this, player.inPlay);
    var card = await player.controller
        .selectCardFromSupply(EventType.Embargo, CardConditions(), false);
    player.engine.supply.supplyOf(card).embargoTokens++;
    player.notifyAnnounce("You place", "places", "an embargo token on $card");
  }
}

@card
class Haven extends Card with Action, Duration, Seaside {
  Haven._();
  static Haven instance = Haven._();

  final int cost = 2;
  final String name = "Haven";

  Future<NextTurnAction> onPlayCanPersist(Player player) async {
    player.draw();
    player.turn.actions++;
    if (player.hand.length == 0) return null;
    var card = (await player.controller
            .selectCardsFromHand(this, CardConditions(), 1, 1))
        .first;
    var stored = CardBuffer();
    player.hand.moveTo(card, stored);
    player.notifyAnnounce(
        "You set aside a $card", "sets aside a card", "with Haven");
    return () async {
      stored.drawTo(player.hand);
      player.notify("You return your $card to your hand");
      return false;
    };
  }
}

@card
class Lighthouse extends Card with Action, Duration, Seaside {
  Lighthouse._();
  static Lighthouse instance = Lighthouse._();

  final int cost = 2;
  final String name = "Lighthouse";

  final bool protectsFromAttacks = true;

  Future<NextTurnAction> onPlayCanPersist(Player player) async {
    player.turn.actions++;
    player.turn.coins++;
    return () async {
      player.turn.coins++;
      return false;
    };
  }
}

@card
class NativeVillage extends Card with Action, Seaside {
  NativeVillage._();
  static NativeVillage instance = NativeVillage._();

  final int cost = 2;
  final String name = "Native Village";

  onPlay(Player player) async {
    player.turn.actions += 2;
    player.mats.putIfAbsent(this, () => Mat("Native Village"));
    var options = [
      "Put top card of deck on mat",
      "Put all cards from mat in hand"
    ];
    var response = await player.controller
        .askQuestion(this, "What do you want to do?", options);
    var mat = player.mats[this].buffer;
    if (response == options.first) {
      player.drawTo(mat);
      player.notifyAnnounce("You place a ${mat.asList().last} on your ",
          "places a card on their", "Native Village mat");
    } else {
      player.notifyAnnounce(
          "You take $mat from your",
          "takes ${mat.length} ${cardWord(mat.length)} from their",
          "Native Village mat");
      mat.dumpTo(player.hand);
    }
  }
}

@card
class PearlDiver extends Card with Action, Seaside {
  PearlDiver._();
  static PearlDiver instance = PearlDiver._();

  final int cost = 2;
  final String name = "Pearl Diver";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions++;
    if (player.deck.length == 0) {
      player.discarded.shuffle();
      player.discarded.dumpTo(player.deck);
    }
    var card = player.deck[player.deck.length - 1];
    if (await player.controller.confirmAction(
        this, "Move a $card from the bottom of your deck to the top?")) {
      player.deck.bottom.drawTo(player.deck.top);
      player.notifyAnnounce(
          "You move a $card", "moves a card", "to top of deck");
    }
  }
}

@card
class Ambassador extends Card with Action, Attack, Seaside {
  Ambassador._();
  static Ambassador instance = Ambassador._();

  final int cost = 3;
  final String name = "Ambassador";

  onPlay(Player player) async {
    var card = (await player.controller
            .selectCardsFromHand(this, CardConditions(), 1, 1))
        .first;
    var returnable = player.hand.asList().where((item) => item == card);
    var toReturn = await player.controller.selectCardsFrom(
        returnable, "Ambassador: Select cards to return", 0, 2);
    for (var card in toReturn) {
      player.hand.moveTo(card, player.engine.supply.supplyOf(card));
    }
    await for (var opponent in player.engine.attackablePlayers(player, this)) {
      await opponent.gain(card);
    }
  }
}

@card
class FishingVillage extends Card with Action, Duration, Seaside {
  FishingVillage._();
  static FishingVillage instance = FishingVillage._();

  final int cost = 3;
  final String name = "Fishing Village";

  final bool protectsFromAttacks = true;

  Future<NextTurnAction> onPlayCanPersist(Player player) async {
    player.turn.actions += 2;
    player.turn.coins++;
    return () async {
      player.turn.actions++;
      player.turn.coins++;
      return false;
    };
  }
}

@card
class Lookout extends Card with Action, Seaside {
  Lookout._();
  static Lookout instance = Lookout._();

  final int cost = 3;
  final String name = "Lookout";

  onPlay(Player player) async {
    player.turn.actions++;
    var buffer = CardBuffer();
    player.drawTo(buffer);
    player.drawTo(buffer);
    player.drawTo(buffer);
    var toTrash = (await player.controller.selectCardsFrom(
            buffer.asList(), "Lookout: Select a card to trash", 1, 1))
        .first;
    await player.trashFrom(toTrash, buffer);
    var toDiscard = (await player.controller.selectCardsFrom(
            buffer.asList(), "Lookout: Select a card to discard", 1, 1))
        .first;
    await player.discardFrom(buffer, toDiscard);
    buffer.drawTo(player.deck.top);
    player.notify("You return $card to the top of your deck");
  }
}

@card
class Smugglers extends Card with Action, Seaside {
  Smugglers._();
  static Smugglers instance = Smugglers._();

  final int cost = 3;
  final String name = "Smugglers";

  onPlay(Player player) async {
    var options = player.engine.toRightOf(player).lastTurn.gained.where(
        (card) =>
            player.engine.supply.supplyOf(card).count > 0 &&
            card.calculateCost(player) <= 6);
    if (options.isEmpty) return;
    var card = options.length == 1
        ? options.first
        : (await player.controller.selectCardsFrom(options.toList(),
                "Smugglers: Which card do you want to gain?", 1, 1))
            .first;
    await player.gain(card);
  }
}

@card
class Warehouse extends Card with Action, Seaside {
  Warehouse._();
  static Warehouse instance = Warehouse._();

  final int cost = 3;
  final String name = "Warehouse";

  onPlay(Player player) async {
    player.draw(3);
    player.turn.actions++;
    var toDiscard = await player.controller
        .selectCardsFromHand(this, CardConditions(), 3, 3);
    for (var card in toDiscard) {
      await player.discard(card);
    }
  }
}

@card
class Caravan extends Card with Action, Duration, Seaside {
  Caravan._();
  static Caravan instance = Caravan._();

  final int cost = 4;
  final String name = "Caravan";

  Future<NextTurnAction> onPlayCanPersist(Player player) async {
    player.draw();
    player.turn.actions++;
    return () async {
      player.draw();
      return false;
    };
  }
}

@card
class Cutpurse extends Card with Action, Attack, Seaside {
  Cutpurse._();
  static Cutpurse instance = Cutpurse._();

  final int cost = 4;
  final String name = "Cutpurse";

  onPlay(Player player) async {
    player.turn.coins += 2;
    await for (var opponent in player.engine.attackablePlayers(player, this)) {
      if (opponent.hand.contains(Copper.instance)) {
        await opponent.discard(Copper.instance);
      } else {
        opponent.notifyAnnounce(
            "You reveal your hand", "reveals a hand of ${opponent.hand}");
      }
    }
  }
}

@card
class Island extends Card with Action, Victory, Seaside {
  Island._();
  static Island instance = Island._();

  final int cost = 4;
  final String name = "Island";

  final int points = 2;

  onPlay(Player player) async {
    player.mats.putIfAbsent(this, () => Mat("Island"));
    var card = player.hand.length == 0
        ? null
        : (await player.controller
                .selectCardsFromHand(this, CardConditions(), 1, 1))
            .first;
    var island = player.mats[this].buffer;
    player.discarded.moveTo(this, island);
    if (card != null) {
      player.discarded.moveTo(card, island);
    }
    var extra = card == null ? "" : " with a $card";
    player.notifyAnnounce("You set", "sets", "aside an Island$extra");
  }
}

@card
class Navigator extends Card with Action, Seaside {
  Navigator._();
  static Navigator instance = Navigator._();

  final int cost = 4;
  final String name = "Navigator";

  onPlay(Player player) async {
    player.turn.coins += 2;
    var buffer = CardBuffer();
    for (var i = 0; i < 5; i++) {
      player.drawTo(buffer);
    }
    player.notify("You look at $buffer");
    var response = await player.controller.askQuestion(
        this, "You draw $buffer", ["Discard them", "Put them back"]);
    if (response == "Discard them") {
      for (var i = 0; i < 5; i++) {
        await player.discardFrom(buffer);
      }
      return;
    }
    var order = await player.controller.selectCardsFrom(
        buffer.asList(),
        "Navigator: In what order should these cards be returned to your deck?",
        buffer.length,
        buffer.length);
    for (var card in order) {
      buffer.moveTo(card, player.deck.top);
    }
  }
}

@card
class PirateShip extends Card with Action, Attack, Seaside {
  PirateShip._();
  static PirateShip instance = PirateShip._();

  final int cost = 4;
  final String name = "Pirate Ship";

  onPlay(Player player) async {
    player.mats.putIfAbsent(this, () => PirateShipMat());
    var attackable =
        await player.engine.attackablePlayers(player, this).toList();
    var mat = player.mats[this] as PirateShipMat;
    var response = await player.controller.askQuestion(this,
        "Take +${mat.coinTokens} coins or attack?", ["Take Money", "Attack"]);
    if (response == "Take Money") {
      player.turn.coins += mat.coinTokens;
      return;
    }
    bool trashedTreasure = false;
    for (var opponent in attackable) {
      var buffer = CardBuffer();
      opponent.drawTo(buffer);
      opponent.drawTo(buffer);
      var treasure = buffer.asList().where((card) => card is Treasure).toList();
      if (treasure.length == 0) {
        await opponent.discardFrom(buffer);
        await opponent.discardFrom(buffer);
      } else if (treasure.length == 1) {
        await opponent.trashFrom(treasure.first, buffer);
        await opponent.discardFrom(buffer);
        trashedTreasure = true;
      } else {
        var trashing = (await player.controller.selectCardsFrom(
                treasure,
                "Pirate Ship: Which of ${opponent.name}'s treasures to trash?",
                1,
                1))
            .first;
        await opponent.trashFrom(trashing, buffer);
        await opponent.discardFrom(buffer);
        trashedTreasure = true;
      }
    }
    if (trashedTreasure) mat.coinTokens++;
  }
}

class PirateShipMat extends Mat {
  int coinTokens = 0;

  PirateShipMat() : super("Pirate Ship");
}

@card
class Salvager extends Card with Action, Seaside {
  Salvager._();
  static Salvager instance = Salvager._();

  final int cost = 4;
  final String name = "Salvager";

  onPlay(Player player) async {
    player.turn.buys++;
    if (player.hand.length == 0) return;
    var card = (await player.controller
            .selectCardsFromHand(this, CardConditions(), 1, 1))
        .first;
    await player.trashFrom(card, player.hand);
    player.turn.coins += card.calculateCost(player);
  }
}

@card
class SeaHag extends Card with Action, Attack, Seaside {
  SeaHag._();
  static SeaHag instance = SeaHag._();

  final int cost = 4;
  final String name = "Sea Hag";

  onPlay(Player player) async {
    await for (var opponent in player.engine.attackablePlayers(player, this)) {
      await opponent.discardFrom(opponent.deck);
      await opponent.gain(Curse.instance, to: opponent.deck.top);
    }
  }
}

@card
class TreasureMap extends Card with Action, Seaside {
  TreasureMap._();
  static TreasureMap instance = TreasureMap._();

  final int cost = 4;
  final String name = "Treasure Map";

  onPlay(Player player) async {
    player.turn.buys++;
    await player.trashFrom(this, player.discarded);
    if (await player.trashFrom(this, player.hand)) {
      for (var i = 0; i < 4; i++) {
        await player.gain(Gold.instance, to: player.deck.top);
      }
    }
  }
}

@card
class Bazaar extends Card with Action, Seaside {
  Bazaar._();
  static Bazaar instance = Bazaar._();

  final int cost = 5;
  final String name = "Bazaar";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions += 2;
    player.turn.coins++;
  }
}

@card
class Explorer extends Card with Action, Seaside {
  Explorer._();
  static Explorer instance = Explorer._();

  final int cost = 5;
  final String name = "Explorer";

  onPlay(Player player) async {
    bool revealProvince = player.hand.contains(Province.instance) &&
        await player.controller
            .confirmAction(this, "Reveal a Province from your hand?");
    Card gaining = Silver.instance;
    if (revealProvince) {
      player.notifyAnnounce("You reveal", "reveals", "a Province");
      gaining = Gold.instance;
    }
    await player.gain(gaining, to: player.hand);
  }
}

@card
class GhostShip extends Card with Action, Attack, Seaside {
  GhostShip._();
  static GhostShip instance = GhostShip._();

  final int cost = 5;
  final String name = "Ghost Ship";

  onPlay(Player player) async {
    player.draw(2);
    await for (var opponent in player.engine.attackablePlayers(player, this)) {
      if (opponent.hand.length < 4) continue;
      var returning = opponent.hand.length - 3;
      var order = await opponent.controller
          .selectCardsFromHand(this, CardConditions(), returning, returning);
      for (var card in order) {
        player.notify("You place a $card back on your deck");
        opponent.hand.moveTo(card, opponent.deck.top);
      }
      player.announce("places $returning cards back on their deck");
    }
  }
}

@card
class MerchantShip extends Card with Action, Duration, Seaside {
  MerchantShip._();
  static MerchantShip instance = MerchantShip._();

  final int cost = 5;
  final String name = "Merchant Ship";

  Future<NextTurnAction> onPlayCanPersist(Player player) async {
    player.turn.coins += 2;
    return () async {
      player.turn.coins += 2;
      return false;
    };
  }
}

@card
class Outpost extends Card with Action, Duration, Seaside {
  Outpost._();
  static Outpost instance = Outpost._();

  final int cost = 5;
  final String name = "Outpost";

  Future<NextTurnAction> onPlayCanPersist(Player player) async {
    if (player.takeOutpostTurn) return null;
    player.takeOutpostTurn = true;
    return () async {
      return false;
    };
  }
}

@card
class Tactician extends Card with Action, Duration, Seaside {
  Tactician._();
  static Tactician instance = Tactician._();

  final int cost = 5;
  final String name = "Tactician";

  Future<NextTurnAction> onPlayCanPersist(Player player) async {
    if (player.hand.length == 0) return null;
    while (player.hand.length > 0) {
      await player.discardFrom(player.hand);
    }
    return () async {
      player.draw(5);
      player.turn.actions++;
      player.turn.buys++;
      return false;
    };
  }
}

@card
class Treasury extends Card with Action, Seaside {
  Treasury._();
  static Treasury instance = Treasury._();

  final int cost = 5;
  final String name = "Treasury";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions++;
    player.turn.coins++;
  }

  @override
  onDiscard(Player player, {bool cleanup = false, List<Card> cleanedUp}) async {
    if (cleanup && !player.turn.bought.any((card) => card is Victory)) {
      if (await player.controller
          .confirmAction(this, "Put Treasury onto your deck?")) {
        player.discarded.moveTo(this, player.deck.top);
      }
    }
  }
}

@card
class Wharf extends Card with Action, Duration, Seaside {
  Wharf._();
  static Wharf instance = Wharf._();

  final int cost = 5;
  final String name = "Wharf";

  Future<NextTurnAction> onPlayCanPersist(Player player) async {
    player.draw(2);
    player.turn.buys++;
    return () async {
      player.draw(2);
      player.turn.buys++;
      return false;
    };
  }
}
