library intrigue;

import 'package:dominion_core/dominion_core.dart';

import 'dart:async';

abstract class Intrigue {
  final String expansion = "Intrigue";
  final bool inFirstEdition = true;
  final bool inSecondEdition = true;
}

@card
class Courtyard extends Card with Action, Intrigue {
  Courtyard._();
  static Courtyard instance = Courtyard._();

  final int cost = 2;
  final String name = "Courtyard";

  onPlay(Player player) async {
    player.draw(3);
    CardConditions conds = CardConditions();
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
class Lurker extends Card with Action, Intrigue {
  Lurker._();
  static Lurker instance = Lurker._();

  final bool inFirstEdition = false;

  final int cost = 2;
  final String name = "Lurker";

  onPlay(Player player) async {
    var trash = "Trash an Action card from the Supply";
    var gain = "Gain an Action card from the trash";
    var choice =
        await player.controller.askQuestion(this, "Choose one", [trash, gain]);
    if (choice == gain) {
      var card = await player.controller.selectCardFromSupply(
          EventType.TrashCard,
          CardConditions()..requiredTypes = [CardType.Action],
          false);
      var cardSupply = player.engine.supply.supplyOf(card);
      var remain = "${cardSupply.count} remain";
      player.notifyAnnounce(
          "You trash", "trashes", "a $card from the supply. $remain");
      cardSupply.drawTo(player.engine.trashPile);
    } else if (choice == trash) {
      var card = (await player.controller.selectCardsFromListImpl(
              player.engine.trashPile.toList().where((card) => card is Action),
              "Select an Action card from the trash to gain",
              1,
              1))
          .first;
      player.notifyAnnounce("You gain", "gains", "a $card from the trash");
      player.engine.trashPile.moveTo(card, player.discarded);
    }
  }
}

@card
class Pawn extends Card with Action, Intrigue {
  Pawn._();
  static Pawn instance = Pawn._();

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
class SecretChamber extends Card with Action, AttackReaction, Intrigue {
  SecretChamber._();
  static SecretChamber instance = SecretChamber._();

  final bool inSecondEdition = false;

  final int cost = 2;
  final String name = "Secret Chamber";

  onPlay(Player player) async {
    CardConditions conds = CardConditions();
    List<Card> cards =
        await player.controller.selectCardsFromHand(this, conds, 0, -1);
    for (Card c in cards) {
      await player.discard(c);
    }
    player.turn.coins += cards.length;
  }

  Future<bool> onReactToAttack(Player player, Card attack) async {
    player.draw(2);
    var cards = await player.controller
        .selectCardsFromHand(this, CardConditions(), 2, 2);
    for (var c in cards) {
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
  static GreatHall instance = GreatHall._();

  final bool inSecondEdition = false;

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
  static Masquerade instance = Masquerade._();

  final int cost = 3;
  final String name = "Masquerade";

  onPlay(Player player) async {
    player.draw(2);
    CardConditions conds = CardConditions();
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
  static ShantyTown instance = ShantyTown._();

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
  static Steward instance = Steward._();

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
      CardConditions conds = CardConditions();
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
  static Swindler instance = Swindler._();

  final int cost = 3;
  final String name = "Swindler";

  onPlay(Player player) async {
    player.turn.coins += 2;
    await for (var p in player.engine.attackablePlayers(player, this)) {
      Card trashed = await p.trashDraw(p);
      CardConditions conds = CardConditions()
        ..cost = trashed.calculateCost(player);
      Card selected = await player.controller
          .selectCardFromSupply(EventType.GainForOpponent, conds, false);
      await p.gain(selected);
    }
  }
}

@card
class WishingWell extends Card with Action, Intrigue {
  WishingWell._();
  static WishingWell instance = WishingWell._();

  final int cost = 3;
  final String name = "Wishing Well";

  onPlay(Player player) async {
    player.draw(1);
    player.turn.actions += 1;
    CardConditions conds = CardConditions();
    Card guess = await player.controller
        .selectCardFromSupply(EventType.GuessCard, conds, false);
    player.notifyAnnounce("You guess", "guesses", "$guess");
    CardBuffer buffer = CardBuffer();
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
  static Baron instance = Baron._();

  final int cost = 4;
  final String name = "Baron";

  onPlay(Player player) async {
    player.turn.buys += 1;
    bool hasEstate = false;
    for (Card c in player.hand.toList()) {
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
  static Bridge instance = Bridge._();

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
  static Conspirator instance = Conspirator._();

  final int cost = 4;
  final String name = "Conspirator";

  onPlay(Player player) async {
    player.turn.coins += 2;
    if (player.turn.totalPlayCount((card) => card is Action) >= 3) {
      player.draw(1);
      player.turn.actions += 1;
    }
  }
}

@card
class Coppersmith extends Card with Action, Intrigue {
  Coppersmith._();
  static Coppersmith instance = Coppersmith._();

  final bool inSecondEdition = false;

  final int cost = 4;
  final String name = "Coppersmith";

  onPlay(Player player) async {
    player.turn.playListeners.add((card) {
      if (card is Copper) player.turn.coins++;
    });
  }
}

@card
class Diplomat extends Card with Action, AttackReaction, Intrigue {
  Diplomat._();
  static Diplomat instance = Diplomat._();

  final bool inFirstEdition = false;

  final int cost = 4;
  final String name = "Diplomat";

  onPlay(Player player) async {
    player.draw(2);
    if (player.hand.length <= 5) player.turn.actions += 2;
  }

  bool canReactTo(EventType type, Card context, Player player) {
    return type == EventType.Attack && player.hand.length >= 5;
  }

  Future<bool> onReactToAttack(Player player, Card attack) async {
    player.draw(2);
    var discarding = await player.controller
        .selectCardsFromHand(this, CardConditions(), 3, 3);
    for (var card in discarding) {
      await player.discard(card);
    }
    return false;
  }
}

@card
class Ironworks extends Card with Action, Intrigue {
  Ironworks._();
  static Ironworks instance = Ironworks._();

  final int cost = 4;
  final String name = "Ironworks";

  onPlay(Player player) async {
    CardConditions conds = CardConditions()..maxCost = 4;
    Card gaining = await player.selectCardToGain(conditions: conds);
    if (gaining is Action) player.turn.actions += 1;
    if (gaining is Treasure) player.turn.coins += 1;
    if (gaining is Victory) player.draw(1);
  }
}

@card
class Mill extends Card with Action, Victory, Intrigue {
  Mill._();
  static Mill instance = Mill._();

  final bool inFirstEdition = false;

  final int cost = 4;
  final String name = "Mill";

  final int points = 1;

  onPlay(Player player) async {
    player.draw();
    player.turn.actions++;
    if (!(await player.controller
        .confirmAction(this, "Discard 2 cards for +2 coin?"))) return;
    var discarding = await player.controller.selectCardsFromHand(
        this, CardConditions(), player.hand.length == 1 ? 1 : 2, 2);
    discarding.forEach(player.discard);
    if (discarding.length == 2) player.turn.coins += 2;
  }
}

@card
class MiningVillage extends Card with Action, Intrigue {
  MiningVillage._();
  static MiningVillage instance = MiningVillage._();

  final int cost = 4;
  final String name = "Mining Village";

  onPlay(Player player) async {
    player.draw(1);
    player.turn.actions += 2;
    bool trash = await player.controller
        .confirmAction(this, "Trash Mining Village for +2 coins?");
    if (trash) {
      bool didTrash = await player.trashFrom(this, player.inPlay);
      if (didTrash) {
        player.turn.coins += 2;
      }
    }
  }
}

@card
class SecretPassage extends Card with Action, Intrigue {
  SecretPassage._();
  static SecretPassage instance = SecretPassage._();

  final bool inFirstEdition = false;

  final int cost = 4;
  final String name = "Secret Passage";

  onPlay(Player player) async {
    player.draw(2);
    player.turn.actions += 1;
    var card = (await player.controller
            .selectCardsFromHand(this, CardConditions(), 1, 1))
        .first;
    if (player.deck.length == 0) {
      player.notifyAnnounce("You put a $card on top of your",
          "puts a card on top of their", "deck");
      player.hand.moveTo(card, player.deck.top);
      return;
    }
    var options = ["On Top", "1 card down"];
    var deckLength = player.deck.length;
    for (int i = 2; i <= deckLength; i++) {
      options.add("$i cards down");
    }
    var answer = await player.controller.askQuestion(
        this, "Where in your deck do you want to put your $card?", options);
    if (answer == "On Top") {
      player.notifyAnnounce("You put a $card on top of your",
          "puts a card on top of their", "deck");
      player.hand.moveTo(card, player.deck.top);
      return;
    }
    var depth = int.parse(answer.split(" ").first);
    for (int i = 0; i < depth; i++) {
      player.deck.drawTo(player.deck);
    }
    var plural = depth == 1 ? "" : "s";
    player.notifyAnnounce("You put a $card $depth card$plural deep in your",
        "puts a card $depth card$plural deep in their", "deck");
    player.hand.moveTo(card, player.deck);
    for (int i = depth; i < deckLength; i++) {
      player.deck.drawTo(player.deck);
    }
  }
}

@card
class Scout extends Card with Action, Intrigue {
  Scout._();
  static Scout instance = Scout._();

  final bool inSecondEdition = false;

  final int cost = 4;
  final String name = "Scout";

  onPlay(Player player) async {
    player.turn.actions += 1;
    CardBuffer buffer = CardBuffer();
    for (int i = 0; i < 4; i++) player.drawTo(buffer);
    player.notifyAnnounce("You reveal", "reveals" "$buffer");
    for (Card c in buffer.toList()) {
      if (c is Victory) {
        buffer.moveTo(c, player.hand);
      }
    }
    List<Card> rearranged = await player.controller.selectCardsFromListImpl(
        buffer.toList(),
        "Select cards in the order you want them returned to the deck.",
        buffer.length,
        buffer.length);
    for (Card c in rearranged) {
      buffer.moveTo(c, player.deck.top);
    }
  }
}

@card
class Courtier extends Card with Action, Intrigue {
  Courtier._();
  static Courtier instance = Courtier._();

  final bool inFirstEdition = false;

  final int cost = 5;
  final String name = "Courtier";

  onPlay(Player player) async {
    if (player.hand.length == 0) return;
    var card = (await player.controller
            .selectCardsFromHand(this, CardConditions(), 1, 1))
        .first;
    var types = 0;
    if (card is Action) types++;
    if (card is Treasure) types++;
    if (card is Victory) types++;
    if (card is Curse) types++;
    if (card is Attack) types++;
    if (card is Reaction) types++;
    if (card is Duration) types++;
    var effects = {
      '+1 Action': () => player.turn.actions++,
      '+1 Buy': () => player.turn.buys++,
      '+3 coin': () => player.turn.coins += 3,
      'Gain a gold': () => player.gain(Gold.instance)
    };
    if (types >= 4) {
      for (var effect in effects.values) {
        await effect();
      }
      return;
    }
    while (types > 0) {
      var choice = await player.controller.askQuestion(
          this, "Select an effect ($types remaining)", effects.keys.toList());
      await effects.remove(choice)();
      types--;
    }
  }
}

@card
class Duke extends Card with Victory, Intrigue {
  Duke._();
  static Duke instance = Duke._();

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
class Minion extends Card with Action, Attack, Intrigue {
  Minion._();
  static Minion instance = Minion._();

  final int cost = 5;
  final String name = "Minion";

  onPlay(Player player) async {
    player.turn.actions += 1;
    var beingAttacked = [];
    await for (var p in player.engine.attackablePlayers(player, this)) {
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
class Patrol extends Card with Action, Intrigue {
  Patrol._();
  static Patrol instance = Patrol._();

  final bool inFirstEdition = false;

  final int cost = 5;
  final String name = "Patrol";

  onPlay(Player player) async {
    player.draw(3);
    var buffer = CardBuffer();
    player.drawTo(buffer);
    player.notifyAnnounce("You reveal $buffer", "reveals $buffer");
    for (var card in buffer.toList()) {
      if (card is VictoryOrCurse) {
        buffer.moveTo(card, player.hand);
      }
    }
    if (buffer.length <= 1) {
      buffer.dumpTo(player.deck.top);
      return;
    }
    var order = await player.controller.selectCardsFromListImpl(
        buffer.toList(),
        "Patrol: Select the order to place these cards back on your deck",
        buffer.length,
        buffer.length);
    for (var card in order) {
      buffer.moveTo(card, player.deck.top);
    }
  }
}

@card
class Replace extends Card with Action, Attack, Intrigue {
  Replace._();
  static Replace instance = Replace._();

  final bool inFirstEdition = false;

  final int cost = 5;
  final String name = "Replace";

  onPlay(Player player) async {
    var trash = (await player.controller
            .selectCardsFromHand(this, CardConditions(), 1, 1))
        .first;
    await player.trashFrom(trash, player.hand);
    var gain = await player.controller.selectCardFromSupply(EventType.GainCard,
        CardConditions()..maxCost = trash.calculateCost(player) + 2, false);
    await player.gain(gain,
        to: gain is Action || gain is Treasure
            ? player.deck.top
            : player.discarded);
    await for (var opponent in player.engine.attackablePlayers(player, this)) {
      if (gain is Victory) {
        await opponent.gain(Curse.instance);
      }
    }
  }
}

@card
class Torturer extends Card with Action, Attack, Intrigue {
  Torturer._();
  static Torturer instance = Torturer._();

  final int cost = 5;
  final String name = "Torturer";

  onPlay(Player player) async {
    player.draw(3);
    await for (var p in player.engine.attackablePlayers(player, this)) {
      String a = "Discard two cards";
      String b = "Gain a curse";
      String option =
          await p.controller.askQuestion(this, "Choose one", [a, b]);
      if (option == a) {
        List<Card> cards = await p.controller
            .selectCardsFromHand(this, CardConditions(), 2, 2);
        for (Card c in cards) {
          await p.discard(c);
        }
      } else if (option == b) {
        await p.gain(Curse.instance, to: p.hand);
      }
    }
  }
}

@card
class TradingPost extends Card with Action, Intrigue {
  TradingPost._();
  static TradingPost instance = TradingPost._();

  final int cost = 5;
  final String name = "Trading Post";

  onPlay(Player player) async {
    List<Card> cards = await player.controller
        .selectCardsFromHand(this, CardConditions(), 2, 2);
    for (Card c in cards) {
      await player.trashFrom(c, player.hand);
    }
    if (cards.length == 2) {
      await player.gain(Silver.instance, to: player.hand);
    }
  }
}

@card
class Tribute extends Card with Action, Intrigue {
  Tribute._();
  static Tribute instance = Tribute._();

  final bool inSecondEdition = false;

  final int cost = 5;
  final String name = "Tribute";

  onPlay(Player player) async {
    Player left = player.engine.toLeftOf(player);
    CardBuffer buffer = CardBuffer();
    left.drawTo(buffer);
    left.drawTo(buffer);
    left.notifyAnnounce(
        "You reveal and discard", "reveals and discards" "$buffer");
    Set drawn = Set.from(buffer.toList());
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
  static Upgrade instance = Upgrade._();

  final int cost = 5;
  final String name = "Upgrade";

  onPlay(Player player) async {
    player.draw(1);
    player.turn.actions += 1;
    List<Card> cards = await player.controller
        .selectCardsFromHand(this, CardConditions(), 1, 1);
    if (cards.length != 1) return;
    await player.trashFrom(cards[0], player.hand);
    CardConditions conds = CardConditions();
    conds.cost = cards[0].calculateCost(player) + 1;
    Card card = await player.selectCardToGain(conditions: conds);
    if (card == null) return;
    await player.gain(card);
  }
}

@card
class Harem extends Card with Victory, Treasure, Intrigue {
  Harem._();
  static Harem instance = Harem._();

  final int cost = 6;
  final String name = "Harem";

  final int value = 2;
  final int points = 2;
}

@card
class Nobles extends Card with Victory, Action, Intrigue {
  Nobles._();
  static Nobles instance = Nobles._();

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
