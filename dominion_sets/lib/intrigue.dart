library intrigue;

import 'package:dominion_core/dominion_core.dart';

import 'dart:async';

abstract class Intrigue {
  final String expansion = "Intrigue";
}

@card
class Courtyard extends Card with Action, Intrigue {
  Courtyard._();
  static Courtyard instance = new Courtyard._();

  final int cost = 2;
  final String name = "Courtyard";

  onPlay(Player player) async {
    player.draw(3);
    CardConditions conds = new CardConditions();
    List<Card> cards =
        await player.controller.selectCardsFromHand(this, conds, 1, 1);
    if (cards.length == 1) {
      player.hand.moveTo(cards[0], player.deck.top);
      player.notifyAnnounce("You return a ${cards[0]} to your deck",
          "returns a card to their deck");
    }
  }
}

@card
class Pawn extends Card with Action, Intrigue {
  Pawn._();
  static Pawn instance = new Pawn._();

  final int cost = 2;
  final String name = "Pawn";

  onPlay(Player player) async {
    String a = "+1 Card";
    String b = "+1 Action";
    String c = "+1 Buy";
    String d = "+1 Coin";
    var options = [a, b, c, d];
    var chosen = [];
    String option1 = await player.controller
        .askQuestion(this, "Pawn: First Choice", options);
    chosen.add(option1);
    options.remove(option1);
    String option2 = await player.controller
        .askQuestion(this, "Pawn: Second Choice", options);
    chosen.add(option2);
    for (String selected in chosen) {
      if (selected == a) {
        player.draw(1);
      } else if (selected == b) {
        player.turn.actions += 1;
      } else if (selected == c) {
        player.turn.buys += 1;
      } else if (selected == d) {
        player.turn.coins += 1;
      }
    }
  }
}

@card
class SecretChamber extends Card with Action, Reaction, Intrigue {
  SecretChamber._();
  static SecretChamber instance = new SecretChamber._();

  final int cost = 2;
  final String name = "Secret Chamber";

  onPlay(Player player) async {
    CardConditions conds = new CardConditions();
    List<Card> cards =
        await player.controller.selectCardsFromHand(this, conds, 0, -1);
    for (Card c in cards) {
      await player.discard(c);
    }
    player.turn.coins += cards.length;
  }

  bool canReactTo(EventType type, Card context) => type == EventType.Attack;

  Future<bool> onReact(Player player) async {
    player.draw(2);
    CardConditions conds = new CardConditions();
    List<Card> cards =
        await player.controller.selectCardsFromHand(this, conds, 2, 2);
    for (Card c in cards) {
      player.hand.moveTo(c, player.deck.top);
    }
    var descrip = "${cards.length} ${cardWord(cards.length)}";
    player.notifyAnnounce("You return $descrip to your deck",
        "returns $descrip cards to their deck");
    return false;
  }
}

@card
class GreatHall extends Card with Action, Victory, Intrigue {
  GreatHall._();
  static GreatHall instance = new GreatHall._();

  final int cost = 3;
  final String name = "Great Hall";

  final int points = 1;

  onPlay(Player player) async {
    player.draw(1);
    player.turn.actions += 1;
  }
}

@card
class Masquerade extends Card with Action, Intrigue {
  Masquerade._();
  static Masquerade instance = new Masquerade._();

  final int cost = 3;
  final String name = "Masquerade";

  onPlay(Player player) async {
    player.draw(2);
    CardConditions conds = new CardConditions();
    Map<Player, Card> passing = {};
    await Future.wait(player.engine.playersFrom(player).map((p) async {
      List<Card> selected =
          await player.controller.selectCardsFromHand(this, conds, 1, 1);
      if (selected.length == 1) {
        passing[p] = selected[0];
      }
    }));
    for (Player p in player.engine.playersFrom(player)) {
      if (passing.containsKey(p)) {
        Player left = player.engine.toLeftOf(p);
        p.hand.moveTo(passing[p], left.hand);
      }
    }
    player.log("All players pass a card to their left");
    List<Card> trashing =
        await player.controller.selectCardsFromHand(this, conds, 0, 1);
    if (trashing.length == 1) {
      await player.trashFrom(trashing[0], player.hand);
    }
  }
}

@card
class ShantyTown extends Card with Action, Intrigue {
  ShantyTown._();
  static ShantyTown instance = new ShantyTown._();

  final int cost = 3;
  final String name = "Shanty Town";

  onPlay(Player player) async {
    player.turn.actions += 2;
    player.notifyAnnounce(
        "You reveal your", "reveals", "hand of ${player.hand}");
    if (!player.hasActions()) {
      player.draw(2);
    }
  }
}

@card
class Steward extends Card with Action, Intrigue {
  Steward._();
  static Steward instance = new Steward._();

  final int cost = 3;
  final String name = "Steward";

  onPlay(Player player) async {
    String a = "+2 Cards";
    String b = "+2 Coins";
    String c = "Trash 2 cards from your hand";
    String option =
        await player.controller.askQuestion(this, "Choose one", [a, b, c]);
    if (option == a) {
      player.draw(2);
    } else if (option == b) {
      player.turn.coins += 2;
    } else if (option == c) {
      CardConditions conds = new CardConditions();
      List<Card> trashing =
          await player.controller.selectCardsFromHand(this, conds, 2, 2);
      for (Card c in trashing) {
        await player.trashFrom(c, player.hand);
      }
    }
  }
}

@card
class Swindler extends Card with Action, Attack, Intrigue {
  Swindler._();
  static Swindler instance = new Swindler._();

  final int cost = 3;
  final String name = "Swindler";

  onPlay(Player player) async {
    player.turn.coins += 2;
    for (Player p in player.engine.playersAfter(player)) {
      bool attackBlocked = await p.reactTo(EventType.Attack, this);
      if (attackBlocked) continue;
      Card trashed = await p.trashDraw(p);
      CardConditions conds = new CardConditions()
        ..cost = trashed.calculateCost(player.turn);
      Card selected = await player.controller
          .selectCardFromSupply(EventType.GainForOpponent, conds, false);
      await p.gain(selected);
    }
  }
}

@card
class WishingWell extends Card with Action, Intrigue {
  WishingWell._();
  static WishingWell instance = new WishingWell._();

  final int cost = 3;
  final String name = "Wishing Well";

  onPlay(Player player) async {
    player.draw(1);
    player.turn.actions += 1;
    CardConditions conds = new CardConditions();
    Card guess = await player.controller
        .selectCardFromSupply(EventType.GuessCard, conds, false);
    player.notifyAnnounce("You guess", "guesses", "$guess");
    CardBuffer buffer = new CardBuffer();
    player.drawTo(buffer);
    if (buffer[0] == guess) {
      player.notifyAnnounce(
          "You reveal", "reveals" "${buffer[0]}. Correct guess!");
      buffer.drawTo(player.hand);
    } else {
      player.notifyAnnounce(
          "You reveal", "reveals" "${buffer[0]}. Incorrect guess");
      buffer.drawTo(player.deck.top);
    }
  }
}

@card
class Baron extends Card with Action, Intrigue {
  Baron._();
  static Baron instance = new Baron._();

  final int cost = 4;
  final String name = "Baron";

  onPlay(Player player) async {
    player.turn.buys += 1;
    bool hasEstate = false;
    for (Card c in player.hand.asList()) {
      if (c == Estate.instance) {
        hasEstate = true;
        break;
      }
    }
    var question = "Discard an Estate for +4 coins?";
    if (hasEstate && await player.controller.confirmAction(this, question)) {
      player.turn.coins += 4;
    } else {
      await player.gain(Estate.instance);
    }
  }
}

@card
class Bridge extends Card with Action, Intrigue {
  Bridge._();
  static Bridge instance = new Bridge._();

  final int cost = 4;
  final String name = "Bridge";

  onPlay(Player player) async {
    player.turn.buys += 1;
    player.turn.coins += 1;
    player.turn.costProcessors.add((card, old) => old - 1);
  }
}

@card
class Conspirator extends Card with Action, Intrigue {
  Conspirator._();
  static Conspirator instance = new Conspirator._();

  final int cost = 4;
  final String name = "Conspirator";

  onPlay(Player player) async {
    player.turn.coins += 2;
    if (player.turn.actionsPlayed >= 3) {
      player.draw(1);
      player.turn.actions += 1;
    }
  }
}

@card
class Coppersmith extends Card with Action, Intrigue {
  Coppersmith._();
  static Coppersmith instance = new Coppersmith._();

  final int cost = 4;
  final String name = "Coppersmith";

  onPlay(Player player) async {
    if (!player.turn.misc.containsKey('coppersmithsPlayed')) {
      player.turn.misc['coppersmithsPlayed'] = 0;
    }
    player.turn.misc['coppersmithsPlayed'] += 1;
  }
}

@card
class Ironworks extends Card with Action, Intrigue {
  Ironworks._();
  static Ironworks instance = new Ironworks._();

  final int cost = 4;
  final String name = "Ironworks";

  onPlay(Player player) async {
    CardConditions conds = new CardConditions()..maxCost = 4;
    Card gaining = await player.selectCardToGain(conditions: conds);
    if (gaining is Action) player.turn.actions += 1;
    if (gaining is Treasure) player.turn.coins += 1;
    if (gaining is Victory) player.draw(1);
  }
}

@card
class MiningVillage extends Card with Action, Intrigue {
  MiningVillage._();
  static MiningVillage instance = new MiningVillage._();

  final int cost = 4;
  final String name = "Mining Village";

  onPlay(Player player) async {
    player.draw(1);
    player.turn.actions += 2;
    bool trash = await player.controller
        .confirmAction(this, "Trash Mining Village for +2 coins?");
    if (trash) {
      bool didTrash = await player.trashFrom(this, player.turn.played);
      if (didTrash) {
        player.turn.coins += 2;
      }
    }
  }
}

@card
class Scout extends Card with Action, Intrigue {
  Scout._();
  static Scout instance = new Scout._();

  final int cost = 4;
  final String name = "Scout";

  onPlay(Player player) async {
    player.turn.actions += 1;
    CardBuffer buffer = new CardBuffer();
    for (int i = 0; i < 4; i++) player.drawTo(buffer);
    player.notifyAnnounce("You reveal", "reveals" "$buffer");
    for (Card c in buffer.asList()) {
      if (c is Victory) {
        buffer.moveTo(c, player.hand);
      }
    }
    List<Card> rearranged = await player.controller.selectCardsFrom(
        buffer.asList(),
        "Select cards in the order you want them returned to the deck.",
        buffer.length,
        buffer.length);
    for (Card c in rearranged) {
      buffer.moveTo(c, player.deck.top);
    }
  }
}

@card
class Duke extends Card with Victory, Intrigue {
  Duke._();
  static Duke instance = new Duke._();

  final int cost = 5;
  final String name = "Duke";

  int getVictoryPoints(Player player) {
    int duchys = 0;
    var cards = player.getAllCards();
    for (Card c in cards) {
      if (c == Duchy.instance) duchys++;
    }
    return duchys;
  }
}

@card
class Minion extends Card with Action, Intrigue {
  Minion._();
  static Minion instance = new Minion._();

  final int cost = 5;
  final String name = "Minion";

  onPlay(Player player) async {
    player.turn.actions += 1;
    var beingAttacked = [];
    for (Player p in player.engine.playersAfter(player)) {
      bool attackBlocked = await p.reactTo(EventType.Attack, this);
      if (attackBlocked) continue;
      beingAttacked.add(p);
    }
    String a = "+2 Coins";
    String b = "Discard your hand for +4 Cards and each other player with at "
        "least 5 cards in hand discards their hand and draws 4 cards";
    String option =
        await player.controller.askQuestion(this, "Choose one", [a, b]);
    if (option == a) {
      player.turn.coins += 2;
    } else if (option == b) {
      while (player.hand.length > 0) {
        await player.discardFrom(player.hand);
      }
      player.draw(4);
      for (Player p in beingAttacked) {
        if (p.hand.length >= 5) {
          while (p.hand.length > 0) {
            await p.discardFrom(p.hand);
          }
          p.draw(4);
        }
      }
    }
  }
}

@card
class Saboteur extends Card with Action, Intrigue {
  Saboteur._();
  static Saboteur instance = new Saboteur._();

  final int cost = 5;
  final String name = "Saboteur";

  onPlay(Player player) async {
    for (Player p in player.engine.playersAfter(player)) {
      bool attackBlocked = await p.reactTo(EventType.Attack, this);
      if (attackBlocked) continue;
      CardBuffer buffer = new CardBuffer();
      while (true) {
        Card drawn = p.drawTo(buffer);
        int cardCost = drawn.calculateCost(player.turn);
        if (cardCost >= 3) {
          p.trashFrom(drawn, buffer);
          CardConditions conds = new CardConditions();
          conds.cost = cardCost - 2;
          Card gaining =
              await p.selectCardToGain(conditions: conds, allowNone: true);
          if (gaining != null) {
            await p.gain(gaining);
          }
          break;
        }
      }
    }
  }
}

@card
class Torturer extends Card with Action, Intrigue {
  Torturer._();
  static Torturer instance = new Torturer._();

  final int cost = 5;
  final String name = "Torturer";

  onPlay(Player player) async {
    player.draw(3);
    for (Player p in player.engine.playersAfter(player)) {
      bool attackBlocked = await p.reactTo(EventType.Attack, this);
      if (attackBlocked) continue;
      String a = "Discard two cards";
      String b = "Gain a curse";
      String option =
          await p.controller.askQuestion(this, "Choose one", [a, b]);
      if (option == a) {
        List<Card> cards = await p.controller
            .selectCardsFromHand(this, new CardConditions(), 2, 2);
        for (Card c in cards) {
          await p.discard(c);
        }
      } else if (option == b) {
        bool result = await p.gain(Curse.instance);
        if (result) p.discarded.moveTo(Curse.instance, p.hand);
      }
    }
  }
}

@card
class TradingPost extends Card with Action, Intrigue {
  TradingPost._();
  static TradingPost instance = new TradingPost._();

  final int cost = 5;
  final String name = "Trading Post";

  onPlay(Player player) async {
    List<Card> cards = await player.controller
        .selectCardsFromHand(this, new CardConditions(), 2, 2);
    for (Card c in cards) {
      await player.trashFrom(c, player.hand);
    }
    if (cards.length == 2) {
      await player.gain(Silver.instance);
      player.discarded.moveTo(Silver.instance, player.hand);
    }
  }
}

@card
class Tribute extends Card with Action, Intrigue {
  Tribute._();
  static Tribute instance = new Tribute._();

  final int cost = 5;
  final String name = "Tribute";

  onPlay(Player player) async {
    Player left = player.engine.toLeftOf(player);
    CardBuffer buffer = new CardBuffer();
    left.drawTo(buffer);
    left.drawTo(buffer);
    left.notifyAnnounce(
        "You reveal and discard", "reveals and discards" "$buffer");
    Set drawn = new Set.from(buffer.asList());
    while (buffer.length > 0) {
      await left.discardFrom(buffer);
    }
    for (Card c in drawn) {
      if (c != null) {
        if (c is Action) player.turn.actions += 2;
        if (c is Treasure) player.turn.coins += 2;
        if (c is Victory) player.draw(2);
      }
    }
  }
}

@card
class Upgrade extends Card with Action, Intrigue {
  Upgrade._();
  static Upgrade instance = new Upgrade._();

  final int cost = 5;
  final String name = "Upgrade";

  onPlay(Player player) async {
    player.draw(1);
    player.turn.actions += 1;
    List<Card> cards = await player.controller
        .selectCardsFromHand(this, new CardConditions(), 1, 1);
    if (cards.length != 1) return;
    await player.trashFrom(cards[0], player.hand);
    CardConditions conds = new CardConditions();
    conds.cost = cards[0].calculateCost(player.turn) + 1;
    Card card = await player.selectCardToGain(conditions: conds);
    if (card == null) return;
    await player.gain(card);
  }
}

@card
class Harem extends Card with Victory, Treasure, Intrigue {
  Harem._();
  static Harem instance = new Harem._();

  final int cost = 6;
  final String name = "Harem";

  final int value = 2;
  final int points = 2;
}

@card
class Nobles extends Card with Victory, Action, Intrigue {
  Nobles._();
  static Nobles instance = new Nobles._();

  final int cost = 6;
  final String name = "Nobles";

  final int points = 2;

  onPlay(Player player) async {
    String threeCards = "+3 Cards";
    String twoActions = "+2 Actions";
    var question = "Nobles: Which action do you want to take?";
    String result = await player.controller
        .askQuestion(this, question, [threeCards, twoActions]);
    if (result == threeCards) {
      player.draw(3);
    } else if (result == twoActions) {
      player.turn.actions += 2;
    }
  }
}
