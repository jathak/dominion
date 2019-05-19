library base_set;

import 'package:dominion_core/dominion_core.dart';

import 'dart:async';

mixin BaseSet {
  final String expansion = "Base";
  final bool inFirstEdition = true;
  final bool inSecondEdition = true;
}

void registerBaseSet() => CardRegistry.register([
      Cellar.instance,
      Chapel.instance,
      Moat.instance,
      Harbinger.instance,
      Merchant.instance,
      Vassal.instance,
      Village.instance,
      Workshop.instance,
      Bureaucrat.instance,
      Gardens.instance,
      Militia.instance,
      Moneylender.instance,
      Poacher.instance,
      Remodel.instance,
      Smithy.instance,
      ThroneRoom.instance,
      Bandit.instance,
      CouncilRoom.instance,
      Festival.instance,
      Laboratory.instance,
      Library.instance,
      Market.instance,
      Mine.instance,
      Sentry.instance,
      Witch.instance,
      Artisan.instance,
      Chancellor.instance,
      Woodcutter.instance,
      Feast.instance,
      Spy.instance,
      Thief.instance,
      Adventurer.instance
    ]);

class Cellar extends Card with Action, BaseSet {
  Cellar._();
  static Cellar instance = Cellar._();

  final int cost = 2;
  final String name = "Cellar";

  onPlay(Player player) async {
    player.turn.actions += 1;
    var cards = await player.discardFromHand(context: this);
    player.draw(cards.length);
  }
}

class Chapel extends Card with Action, BaseSet {
  Chapel._();
  static Chapel instance = Chapel._();

  final int cost = 2;
  final String name = "Chapel";

  onPlay(Player player) async {
    var cards = await player.controller
        .selectCardsFromHand("Select cards to trash", context: this, max: 4);
    for (var c in cards) {
      await player.trashFrom(c, player.hand);
    }
  }
}

class Moat extends Card with Action, BaseSet, AttackReaction {
  Moat._();
  static Moat instance = Moat._();

  final int cost = 2;
  final String name = "Moat";

  onPlay(Player player) async {
    player.draw(2);
  }

  bool canReactTo(EventType type, Card context, Player player) {
    return type == EventType.Attack;
  }

  Future<bool> onReactToAttack(Player player, Card attack) async => true;
}

class Chancellor extends Card with Action, BaseSet {
  Chancellor._();
  static Chancellor instance = Chancellor._();

  final bool inSecondEdition = false;

  final int cost = 3;
  final String name = "Chancellor";

  onPlay(Player player) async {
    player.turn.coins += 2;
    if (await player.controller
        .confirmAction("Place deck in discard pile?", context: this)) {
      player.deck.dumpTo(player.discarded);
      player.notifyAnnounce("Your discard your", "discards their", "deck");
    }
  }
}

class Harbinger extends Card with Action, BaseSet {
  Harbinger._();
  static Harbinger instance = Harbinger._();

  final bool inFirstEdition = false;

  final int cost = 3;
  final String name = "Harbinger";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions++;
    var card = await player.controller.selectCardFromBuffer(player.discarded,
        "Select a card from your discard pile to place on top of your deck?",
        context: this, optional: true);
    if (card == null) return;
    player.notify("You place a $card on top of your deck");
    player.discarded.moveTo(card, player.deck.top);
  }
}

class Merchant extends Card with Action, BaseSet {
  Merchant._();
  static Merchant instance = Merchant._();

  final bool inFirstEdition = false;

  final int cost = 3;
  final String name = "Merchant";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions++;
    player.turn.playListeners.add((card) {
      if (card is Silver && player.turn.playCounts[card] == 1) {
        player.turn.coins++;
      }
    });
  }
}

class Vassal extends Card with Action, BaseSet {
  Vassal._();
  static Vassal instance = Vassal._();

  final bool inFirstEdition = false;

  final int cost = 3;
  final String name = "Vassal";

  onPlay(Player player) async {
    player.turn.coins += 2;
    var buffer = CardBuffer();
    var card = player.drawTo(buffer);
    if (card is Action &&
        await player.controller
            .confirmAction("Play this $card?", context: this)) {
      player.turn.actions++; // since playAction will use one
      await player.playAction(card, from: buffer);
    } else {
      await player.discardFrom(buffer);
    }
  }
}

class Village extends Card with Action, BaseSet {
  Village._();
  static Village instance = Village._();

  final int cost = 3;
  final String name = "Village";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions += 2;
  }
}

class Woodcutter extends Card with Action, BaseSet {
  Woodcutter._();
  static Woodcutter instance = Woodcutter._();

  final bool inSecondEdition = false;

  final int cost = 3;
  final String name = "Woodcutter";

  onPlay(Player player) async {
    player.turn.buys += 1;
    player.turn.coins += 2;
  }
}

class Workshop extends Card with Action, BaseSet {
  Workshop._();
  static Workshop instance = Workshop._();

  final int cost = 3;
  final String name = "Workshop";

  onPlay(Player player) async {
    CardConditions conds = CardConditions();
    conds.maxCost = 4;
    Card card = await player.selectCardToGain(context: this, conditions: conds);
    await player.gain(card);
  }
}

class Bureaucrat extends Card with Action, BaseSet, Attack {
  Bureaucrat._();
  static Bureaucrat instance = Bureaucrat._();

  final int cost = 4;
  final String name = "Bureaucrat";

  onPlay(Player player) async {
    await player.gain(Silver.instance, to: player.deck.top);
    await for (var opponent in player.engine.attackablePlayers(player, this)) {
      var victories = opponent.hand.whereType<Victory>();
      if (victories.length == 1) {
        opponent.notify("You place a ${victories.first} on top of your deck");
        opponent.hand.moveTo(victories.first, opponent.deck.top);
      } else if (victories.length > 1) {
        var card = await opponent.controller.selectCardFrom(
            victories, "Select a card to place on top of your deck",
            context: this, event: EventType.Attack);
        opponent.notify("You place a $card on top of your deck");
        opponent.hand.moveTo(card, opponent.deck.top);
      } else {
        opponent.notifyAnnounce(
            "You reveal", "reveals", "hand of ${opponent.hand}");
      }
    }
  }
}

class Feast extends Card with Action, BaseSet {
  Feast._();
  static Feast instance = Feast._();

  final bool inSecondEdition = false;

  final int cost = 4;
  final String name = "Feast";

  onPlay(Player player) async {
    await player.trashFrom(this, player.inPlay);
    var card = await player.selectCardToGain(
        context: this, conditions: CardConditions()..maxCost = 5);
    await player.gain(card);
  }
}

class Gardens extends Card with Victory, BaseSet {
  Gardens._();
  static Gardens instance = Gardens._();

  final int cost = 4;
  final String name = "Gardens";

  int getVictoryPoints(Player player) {
    int totalCards = player.getAllCards().length;
    return totalCards ~/ 10;
  }
}

class Militia extends Card with Action, BaseSet, Attack {
  Militia._();
  static Militia instance = Militia._();

  final int cost = 4;
  final String name = "Militia";

  onPlay(Player player) async {
    player.turn.coins += 2;
    await for (var opponent in player.engine.attackablePlayers(player, this)) {
      var x = opponent.hand.length - 3;
      await opponent.discardFromHand(
          context: this, event: EventType.Attack, min: x, max: x);
    }
  }
}

class Moneylender extends Card with Action, BaseSet {
  Moneylender._();
  static Moneylender instance = Moneylender._();

  final int cost = 4;
  final String name = "Moneylender";

  onPlay(Player player) async {
    if (await player.trashFrom(Copper.instance, player.hand)) {
      player.turn.coins += 3;
    }
  }
}

class Poacher extends Card with Action, BaseSet {
  Poacher._();
  static Poacher instance = Poacher._();

  final bool inFirstEdition = false;

  final int cost = 4;
  final String name = "Poacher";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions++;
    player.turn.coins++;
    var empty = player.engine.supply.emptyPiles;
    if (empty == 0) return;
    if (empty >= player.hand.length) {
      while (player.hand.length > 0) {
        await player.discardFrom(player.hand);
      }
    }
    await player.discardFromHand(context: this, min: empty, max: empty);
  }
}

class Remodel extends Card with Action, BaseSet {
  Remodel._();
  static Remodel instance = Remodel._();

  final int cost = 4;
  final String name = "Remodel";

  onPlay(Player player) async {
    var card = await player.controller.selectCardFromHand(
        "Select card to trash",
        context: this,
        event: EventType.TrashCard);
    if (card == null) return;
    await player.trashFrom(card, player.hand);
    var gain = await player.selectCardToGain(
        context: this,
        conditions: CardConditions()..maxCost = card.calculateCost(player) + 2);
    await player.gain(gain);
  }
}

class Smithy extends Card with Action, BaseSet {
  Smithy._();
  static Smithy instance = Smithy._();

  final int cost = 4;
  final String name = "Smithy";

  onPlay(Player player) async {
    player.draw(3);
  }
}

class Spy extends Card with Action, BaseSet, Attack {
  Spy._();
  static Spy instance = Spy._();

  final bool inSecondEdition = false;

  final int cost = 4;
  final String name = "Spy";

  onPlay(Player player) async {
    player.draw(1);
    player.turn.actions += 1;
    for (Player p in player.engine.playersFrom(player)) {
      if (p != player) {
        bool attackBlocked = await p.reactToAttack(this);
        if (attackBlocked) continue;
      }
      CardBuffer buffer = CardBuffer();
      p.drawTo(buffer);
      if (buffer.length == 0) continue;
      bool discard;
      Card card = buffer[0];
      p.notifyAnnounce("You reveal", "reveals", "a $card");
      var question;
      if (p == player) {
        question = "Spy: Discard your $card?";
      } else {
        question = "Spy: Discard ${p.name}'s $card?";
      }
      discard = await player.controller.confirmAction(question, context: this);
      if (discard) {
        await p.discardFrom(buffer);
      } else {
        p.notify("${player.name} returns your $card to your deck");
        buffer.drawTo(p.deck.top);
      }
    }
  }
}

class Thief extends Card with Action, BaseSet, Attack {
  Thief._();
  static Thief instance = Thief._();

  final bool inSecondEdition = false;

  final int cost = 4;
  final String name = "Thief";

  onPlay(Player player) async {
    List<Card> trashed = [];
    await for (var p in player.engine.attackablePlayers(player, this)) {
      CardBuffer buffer = CardBuffer();
      p.drawTo(buffer);
      p.drawTo(buffer);
      p.notifyAnnounce("You reveal", "reveals", "$buffer");
      CardBuffer options = CardBuffer();
      CardBuffer discarding = CardBuffer();
      int length = buffer.length;
      for (int i = 0; i < length; i++) {
        if (buffer[0] is Treasure) {
          buffer.drawTo(options);
        } else {
          buffer.drawTo(discarding);
        }
      }
      if (options.length == 1) {
        var question = "Trash ${p.name}'s ${options[0].name}?";
        bool trash =
            await player.controller.confirmAction(question, context: this);
        if (trash) {
          Card card = options[0];
          await p.trashDraw(options);
          trashed.add(card);
        } else {
          options.drawTo(discarding);
        }
      } else if (options.length == 2) {
        var question = "Trash one of ${p.name}'s cards?";
        var selection = await player.controller.selectCardFrom(
            options.toList(), question,
            context: this, optional: true);
        if (selection != null) {
          await p.trashFrom(selection, options);
          trashed.add(selection);
        }
        options.dumpTo(discarding);
      }
      while (discarding.length > 0) {
        await p.discardFrom(discarding);
      }
    }
    if (trashed.length > 0) {
      var question = "Select treasure(s) to take from trash.";
      List<Card> keeping = await player.controller
          .selectCardsFrom(trashed, question, context: this);
      for (Card c in keeping) {
        player.engine.trashPile.moveTo(c, player.discarded);
        player.notifyAnnounce("You gain", "gains", "a $c from the trash");
        c.onGain(player, false);
      }
    }
  }
}

class ThroneRoom extends Card with Action, BaseSet {
  ThroneRoom._();
  static ThroneRoom instance = ThroneRoom._();

  final int cost = 4;
  final String name = "Throne Room";

  Future<NextTurn> onPlayCanPersist(Player player) async {
    var card = await player.controller.selectActionCard(context: this);
    if (card == null) return null;
    player.turn.actions++; // since playAction will decrement this
    var index = await player.playAction(card);
    player.notifyAnnounce("You play", "plays", "the $card again");
    var secondNT = await player.play(card);
    if (card is Duration) {
      var firstNT = player.inPlay.actions[index];
      var combined = NextTurn.combine([firstNT, secondNT]);
      player.inPlay.actions[index] = combined;
      return combined == null ? null : NextTurn([], blockedOn: combined);
    }
    return null;
  }
}

class Bandit extends Card with Action, Attack, BaseSet {
  Bandit._();
  static Bandit instance = Bandit._();

  final bool inFirstEdition = false;

  final int cost = 5;
  final String name = "Bandit";

  onPlay(Player player) async {
    await player.gain(Gold.instance);
    await for (var opponent in player.engine.attackablePlayers(player, this)) {
      var reveal = CardBuffer();
      opponent.drawTo(reveal);
      opponent.drawTo(reveal);
      opponent.notifyAnnounce("You reveal", "reveals", "$reveal");
      var trashable = reveal
          .toList()
          .where((card) => card is Treasure && card is! Copper)
          .toList();
      if (trashable.length == 1) {
        await opponent.trashFrom(trashable.first, reveal);
      } else if (trashable.length > 1) {
        var trash = await opponent.controller.selectCardFrom(
            trashable, "Which of these do you trash?",
            context: this);
        await opponent.trashFrom(trash, reveal);
      }
      while (reveal.length > 0) {
        await opponent.discardFrom(reveal);
      }
    }
  }
}

class CouncilRoom extends Card with Action, BaseSet {
  CouncilRoom._();
  static CouncilRoom instance = CouncilRoom._();

  final int cost = 5;
  final String name = "Council Room";

  onPlay(Player player) async {
    player.draw(4);
    for (var opponent in player.engine.playersAfter(player)) {
      opponent.draw(1);
    }
    player.turn.buys += 1;
  }
}

class Festival extends Card with Action, BaseSet {
  Festival._();
  static Festival instance = Festival._();

  final int cost = 5;
  final String name = "Festival";

  onPlay(Player player) async {
    player.turn.actions += 2;
    player.turn.buys += 1;
    player.turn.coins += 2;
  }
}

class Laboratory extends Card with Action, BaseSet {
  Laboratory._();
  static Laboratory instance = Laboratory._();

  final int cost = 5;
  final String name = "Laboratory";

  onPlay(Player player) async {
    player.draw(2);
    player.turn.actions += 1;
  }
}

class Library extends Card with Action, BaseSet {
  Library._();
  static Library instance = Library._();

  final int cost = 5;
  final String name = "Library";

  onPlay(Player player) async {
    var buffer = CardBuffer();
    while (player.hand.length < 7) {
      Card card = player.draw();
      if (card == null) break;
      if (card is Action) {
        if (await player.controller
            .confirmAction("Discard $card?", context: this)) {
          player.hand.moveTo(card, buffer);
        }
      }
    }
    while (buffer.length > 0) {
      await player.discardFrom(buffer);
    }
  }
}

class Market extends Card with Action, BaseSet {
  Market._();
  static Market instance = Market._();

  final int cost = 5;
  final String name = "Market";

  onPlay(Player player) async {
    player.draw(1);
    player.turn.actions += 1;
    player.turn.buys += 1;
    player.turn.coins += 1;
  }
}

class Mine extends Card with Action, BaseSet {
  Mine._();
  static Mine instance = Mine._();

  final int cost = 5;
  final String name = "Mine";

  onPlay(Player player) async {
    var trash = await player.controller.selectCardFrom(
        player.hand.whereType<Treasure>(), "Select treasure to trash?",
        context: this, event: EventType.TrashCard, optional: true);
    if (trash == null) return;
    player.trashFrom(trash, player.hand);
    Card card = await player.selectCardToGain(
        context: this,
        conditions: CardConditions()
          ..requiredTypes = [CardType.Treasure]
          ..maxCost = trash.calculateCost(player) + 3);
    await player.gain(card, to: player.hand);
  }
}

class Sentry extends Card with Action, BaseSet {
  Sentry._();
  static Sentry instance = Sentry._();

  final bool inFirstEdition = false;

  final int cost = 5;
  final String name = "Sentry";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions++;
    var buffer = CardBuffer();
    player.drawTo(buffer);
    player.drawTo(buffer);
    var trashing = await player.controller.selectCardsFromBuffer(
        buffer, "Which to trash?",
        context: this, max: 2);
    for (var card in trashing) {
      await player.trashFrom(card, buffer);
    }
    if (buffer.length == 0) return;
    var discarding = await player.controller
        .selectCardsFromBuffer(buffer, "Which to discard?", context: this);
    for (var card in discarding) {
      await player.discardFrom(buffer, card);
    }
    if (buffer.length == 0) return;
    if (buffer.length == 1 || buffer[0] == buffer[1]) {
      buffer.dumpTo(player.deck.top);
    }
    var order = await player.controller.selectCardsFromBuffer(
        buffer, "Sentry: Order to put back on deck",
        context: this, min: 2, max: 2);
    buffer.moveTo(order[0], player.deck.top);
    buffer.moveTo(order[1], player.deck.top);
  }
}

class Witch extends Card with Action, BaseSet, Attack {
  Witch._();
  static Witch instance = Witch._();

  final int cost = 5;
  final String name = "Witch";

  onPlay(Player player) async {
    player.draw(2);
    await for (var opponent in player.engine.attackablePlayers(player, this)) {
      await opponent.gain(Curse.instance);
    }
  }
}

class Adventurer extends Card with Action, BaseSet {
  Adventurer._();
  static Adventurer instance = Adventurer._();

  final bool inSecondEdition = false;

  final int cost = 6;
  final String name = "Adventurer";

  onPlay(Player player) async {
    CardBuffer buffer = CardBuffer();

    int treasureCount = 0;
    while (treasureCount < 2) {
      Card card = player.drawTo(buffer);
      if (card == null) break;
      if (card is Treasure) treasureCount++;
    }

    Card card = buffer.removeTop();
    while (card != null) {
      if (card is Treasure) {
        player.hand.receive(card);
      } else {
        player.discarded.receive(card);
        await card.onDiscard(player);
      }
      card = buffer.removeTop();
    }
  }
}

class Artisan extends Card with Action, BaseSet {
  Artisan._();
  static Artisan instance = Artisan._();

  final bool inFirstEdition = false;

  final int cost = 6;
  final String name = "Artisan";

  onPlay(Player player) async {
    var gain = await player.selectCardToGain(
        context: this, conditions: CardConditions()..maxCost = 5);
    await player.gain(gain, to: player.hand);
    var toDeck = await player.controller.selectCardFromHand(
        "Select a card to put on top of your deck",
        context: this);
    player.hand.moveTo(toDeck, player.deck.top);
  }
}
