library base_set;

import 'package:dominion_core/dominion_core.dart';

import 'dart:async';

mixin BaseSet {
  final String expansion = "Base";
  final bool inFirstEdition = true;
  final bool inSecondEdition = true;
}

@card
class Cellar extends Card with Action, BaseSet {
  Cellar._();
  static Cellar instance = Cellar._();

  final int cost = 2;
  final String name = "Cellar";

  onPlay(Player player) async {
    player.turn.actions += 1;
    List<Card> cards = await player.controller
        .selectCardsFromHand(this, CardConditions(), 0, -1);
    for (Card c in cards) {
      await player.discard(c);
    }
    player.draw(cards.length);
  }
}

@card
class Chapel extends Card with Action, BaseSet {
  Chapel._();
  static Chapel instance = Chapel._();

  final int cost = 2;
  final String name = "Chapel";

  onPlay(Player player) async {
    List<Card> cards = await player.controller
        .selectCardsFromHand(this, CardConditions(), 0, 4);
    for (Card c in cards) {
      await player.trashFrom(c, player.hand);
    }
  }
}

@card
class Moat extends Card with Action, BaseSet, Reaction {
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

  Future<bool> onReact(Player player) async {
    return true;
  }
}

@card
class Chancellor extends Card with Action, BaseSet {
  Chancellor._();
  static Chancellor instance = Chancellor._();

  final bool inSecondEdition = false;

  final int cost = 3;
  final String name = "Chancellor";

  onPlay(Player player) async {
    player.turn.coins += 2;
    bool discardDeck = await player.controller
        .confirmAction(this, "Chancellor: Place deck in discard pile?");
    if (discardDeck) {
      player.deck.dumpTo(player.discarded);
      player.notifyAnnounce("Your discard your", "discards their", "deck");
    }
  }
}

@card
class Harbinger extends Card with Action, BaseSet {
  Harbinger._();
  static Harbinger instance = Harbinger._();

  final bool inFirstEdition = false;

  final int cost = 3;
  final String name = "Harbinger";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions++;
    var discards = player.discarded.asList().toSet().toList();
    var cards = await player.controller.selectCardsFrom(
        discards,
        "Harbinger: Select a card from your discard "
        "pile to place on top of your deck?",
        0,
        1);
    if (cards.length == 1) {
      player.discarded.moveTo(cards.first, player.deck.top);
    }
  }
}

@card
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

@card
class Vassal extends Card with Action, BaseSet {
  Vassal._();
  static Vassal instance = Vassal._();

  final bool inFirstEdition = false;

  final int cost = 3;
  final String name = "Vassal";

  onPlay(Player player) async {
    player.turn.coins += 2;
    var card = player.deck[0];
    await player.discardFrom(player.deck);
    if (card is Action &&
        await player.controller.confirmAction(card, "Play this card?")) {
      player.turn.actions++; // since playAction will use one
      await player.playAction(card, from: player.discarded);
    }
  }
}

@card
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

@card
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

@card
class Workshop extends Card with Action, BaseSet {
  Workshop._();
  static Workshop instance = Workshop._();

  final int cost = 3;
  final String name = "Workshop";

  onPlay(Player player) async {
    CardConditions conds = CardConditions();
    conds.maxCost = 4;
    Card card = await player.selectCardToGain(conditions: conds);
    await player.gain(card);
  }
}

@card
class Bureaucrat extends Card with Action, BaseSet, Attack {
  Bureaucrat._();
  static Bureaucrat instance = Bureaucrat._();

  final int cost = 4;
  final String name = "Bureaucrat";

  onPlay(Player player) async {
    await player.gain(Silver.instance);
    player.discarded.moveTo(Silver.instance, player.deck.top);
    await for (Player p in player.engine.attackablePlayers(player, this)) {
      List<Card> victories = [];
      for (Card c in p.hand.asList()) {
        if (c is Victory) victories.add(c);
      }
      if (victories.length == 1) {
        p.hand.moveTo(victories[0], p.deck.top);
      } else if (victories.length > 1) {
        CardConditions conds = CardConditions()
          ..requiredTypes = [CardType.Victory];
        List<Card> cards =
            await p.controller.selectCardsFromHand(this, conds, 1, 1);
        if (cards.length == 1) {
          p.hand.moveTo(cards[0], p.deck.top);
        }
      } else {
        p.notifyAnnounce("You reveal", "reveals", "hand of ${p.hand}");
      }
    }
  }
}

@card
class Feast extends Card with Action, BaseSet {
  Feast._();
  static Feast instance = Feast._();

  final bool inSecondEdition = false;

  final int cost = 4;
  final String name = "Feast";

  onPlay(Player player) async {
    await player.trashFrom(this, player.inPlay);
    CardConditions conds = CardConditions();
    conds.maxCost = 5;
    Card card = await player.selectCardToGain(conditions: conds);
    await player.gain(card);
  }
}

@card
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

@card
class Militia extends Card with Action, BaseSet, Attack {
  Militia._();
  static Militia instance = Militia._();

  final int cost = 4;
  final String name = "Militia";

  onPlay(Player player) async {
    player.turn.coins += 2;
    await for (var p in player.engine.attackablePlayers(player, this)) {
      bool attackBlocked = await p.reactTo(EventType.Attack, this);
      if (!attackBlocked) {
        int x = p.hand.length - 3;
        List<Card> cards = await p.controller
            .selectCardsFromHand(this, CardConditions(), x, x);
        for (Card c in cards) {
          await p.discard(c);
        }
      }
    }
  }
}

@card
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

@card
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
      for (var i = 0; i < player.hand.length; i++) {
        await player.discardFrom(player.hand);
      }
    }
    var discarding =
        await player.controller.selectCardsFromHand(this, null, empty, empty);
    for (var card in discarding) {
      await player.discard(card);
    }
  }
}

@card
class Remodel extends Card with Action, BaseSet {
  Remodel._();
  static Remodel instance = Remodel._();

  final int cost = 4;
  final String name = "Remodel";

  onPlay(Player player) async {
    List<Card> cards = await player.controller
        .selectCardsFromHand(this, CardConditions(), 1, 1);
    if (cards.length != 1) return;
    await player.trashFrom(cards[0], player.hand);
    CardConditions conds = CardConditions();
    conds.maxCost = cards[0].calculateCost(player.turn) + 2;
    Card card = await player.selectCardToGain(conditions: conds);
    await player.gain(card);
  }
}

@card
class Smithy extends Card with Action, BaseSet {
  Smithy._();
  static Smithy instance = Smithy._();

  final int cost = 4;
  final String name = "Smithy";

  onPlay(Player player) async {
    player.draw(3);
  }
}

@card
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
        bool attackBlocked = await p.reactTo(EventType.Attack, this);
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
      discard = await player.controller.confirmAction(card, question);
      if (discard) {
        await p.discardFrom(buffer);
      } else {
        p.notify("${player.name} returns your $card to your deck");
        buffer.drawTo(p.deck.top);
      }
    }
  }
}

@card
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
        var question = "Thief: Trash ${p.name}'s ${options[0].name}?";
        bool trash =
            await player.controller.confirmAction(options[0], question);
        if (trash) {
          Card card = options[0];
          await p.trashDraw(options);
          trashed.add(card);
        } else {
          options.drawTo(discarding);
        }
      } else if (options.length == 2) {
        List choices = [options[0], options[1], "Neither"];
        var question =
            "Thief: Which of ${p.name}'s cards do you want to trash?";
        var selection =
            await player.controller.askQuestion(this, question, choices);
        if (selection is Card) {
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
      var question = "Thief: Select treasure(s) to take from trash.";
      List<Card> keeping =
          await player.controller.selectCardsFrom(trashed, question, 0, -1);
      for (Card c in keeping) {
        player.engine.trashPile.moveTo(c, player.discarded);
        player.notifyAnnounce("You gain", "gains", "a $c from the trash");
        c.onGain(player, false);
      }
    }
  }
}

@card
class ThroneRoom extends Card with Action, BaseSet {
  ThroneRoom._();
  static ThroneRoom instance = ThroneRoom._();

  final int cost = 4;
  final String name = "Throne Room";

  Future<ForNextTurn> onPlayCanPersist(Player player) async {
    var card = await player.controller.selectActionCard();
    ForNextTurn forNextTurn;
    if (card != null) {
      player.turn.actions++; // since playAction will decrement this
      var index = await player.playAction(card);
      player.notifyAnnounce("You play", "plays", "the $card again");
      var secondFNT = await player.play(card);
      if (card is Duration) {
        forNextTurn = ForNextTurn(true, () async => false);
        var firstFNT = player.inPlay.nextTurn[index];
        if (firstFNT == null) {
          player.inPlay.nextTurn[index] = secondFNT;
        } else {
          player.inPlay.nextTurn[index] =
              ForNextTurn(firstFNT.persists || secondFNT.persists, () async {
            var first = await firstFNT.action();
            var second = await secondFNT.action();
            return first || second;
          });
        }
      }
    }
    return forNextTurn;
  }
}

@card
class Bandit extends Card with Action, Attack, BaseSet {
  Bandit._();
  static Bandit instance = Bandit._();

  final bool inFirstEdition = false;

  final int cost = 5;
  final String name = "Bandit";

  onPlay(Player player) async {
    await player.gain(Gold.instance);
    await for (var p in player.engine.attackablePlayers(player, this)) {
      var reveal = CardBuffer();
      p.drawTo(reveal);
      p.drawTo(reveal);
      p.notifyAnnounce("You reveal", "reveals", "$reveal");
      var trashable = reveal
          .asList()
          .where((card) => card is Treasure && card is! Copper)
          .toList();
      if (trashable.length == 1) {
        await p.trashFrom(trashable.first, reveal);
      } else if (trashable.length > 1) {
        var trash = await p.controller.selectCardsFrom(
            trashable, "Bandit: Which of these do you trash?", 1, 1);
        await p.trashFrom(trash.first, reveal);
      }
      while (reveal.length > 0) {
        await p.discardFrom(reveal);
      }
    }
  }
}

@card
class CouncilRoom extends Card with Action, BaseSet {
  CouncilRoom._();
  static CouncilRoom instance = CouncilRoom._();

  final int cost = 5;
  final String name = "Council Room";

  onPlay(Player player) async {
    player.draw(4);
    for (Player p in player.engine.playersAfter(player)) {
      p.draw(1);
    }
    player.turn.buys += 1;
  }
}

@card
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

@card
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

@card
class Library extends Card with Action, BaseSet {
  Library._();
  static Library instance = Library._();

  final int cost = 5;
  final String name = "Library";

  onPlay(Player player) async {
    CardBuffer buffer = CardBuffer();
    while (player.hand.length < 7) {
      Card card = player.draw();
      if (card == null) break;
      if (card is Action) {
        bool setAside = await player.controller
            .confirmAction(card, "Library: Set aside ${card}?");
        if (setAside) {
          player.hand.moveTo(card, buffer);
        }
      }
    }
    while (buffer.length > 0) {
      await player.discardFrom(buffer);
    }
  }
}

@card
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

@card
class Mine extends Card with Action, BaseSet {
  Mine._();
  static Mine instance = Mine._();

  final int cost = 5;
  final String name = "Mine";

  onPlay(Player player) async {
    CardConditions trashConds = CardConditions()
      ..requiredTypes = [CardType.Treasure];
    List<Card> cards =
        await player.controller.selectCardsFromHand(this, trashConds, 0, 1);
    if (cards.length != 1) return;
    int cost = cards[0].calculateCost(player.turn);
    player.trashFrom(cards[0], player.hand);
    CardConditions gainConds = CardConditions();
    gainConds..requiredTypes = [CardType.Treasure];
    gainConds..maxCost = cost + 3;
    Card card = await player.selectCardToGain(conditions: gainConds);
    await player.gain(card);
    player.discarded.moveTo(card, player.hand);
  }
}

@card
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
    var trashing = await player.controller
        .selectCardsFrom(buffer.asList(), "Sentry: Which to trash?", 0, 2);
    for (var card in trashing) {
      await player.trashFrom(card, buffer);
    }
    if (buffer.length == 0) return;
    var discarding = await player.controller.selectCardsFrom(
        buffer.asList(), "Sentry: Which to discard?", 0, buffer.length);
    for (var card in discarding) {
      await player.discardFrom(buffer, card);
    }
    if (buffer.length == 0) return;
    if (buffer.length == 1 || buffer[0] == buffer[1]) {
      buffer.dumpTo(player.deck.top);
    }
    var order = await player.controller.selectCardsFrom(
        buffer.asList(), "Sentry: Order to put back on deck", 2, 2);
    buffer.moveTo(order[0], player.deck.top);
    buffer.moveTo(order[1], player.deck.top);
  }
}

@card
class Witch extends Card with Action, BaseSet, Attack {
  Witch._();
  static Witch instance = Witch._();

  final int cost = 5;
  final String name = "Witch";

  onPlay(Player player) async {
    player.draw(2);
    await for (var p in player.engine.attackablePlayers(player, this)) {
      bool attackBlocked = await p.reactTo(EventType.Attack, this);
      if (!attackBlocked) {
        await p.gain(Curse.instance);
      }
    }
  }
}

@card
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

@card
class Artisan extends Card with Action, BaseSet {
  Artisan._();
  static Artisan instance = Artisan._();

  final bool inFirstEdition = false;

  final int cost = 6;
  final String name = "Artisan";

  onPlay(Player player) async {
    var gain = await player.selectCardToGain(
        conditions: CardConditions()..maxCost = 5);
    if (await player.gain(gain)) {
      player.discarded.moveTo(gain, player.hand);
    }
    var toDeck = await player.controller
        .selectCardsFromHand(this, CardConditions(), 1, 1);
    player.hand.moveTo(toDeck.first, player.deck.top);
  }
}
