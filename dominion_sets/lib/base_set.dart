library base_set;

import 'package:dominion_core/dominion_core.dart';

import 'dart:async';

abstract class BaseSet {
  final String expansion = "Base";
}

@card
class Cellar extends ActionCard with BaseSet {
  Cellar._();
  static Cellar instance = new Cellar._();

  final int cost = 2;
  final String name = "Cellar";

  onPlay(Player player) async {
    player.turn.actions += 1;
    List<Card> cards =
        await player.controller.selectCardsFromHand(this, new CardConditions(), 0, -1);
    for (Card c in cards) {
      await player.discard(c);
    }
    player.draw(cards.length);
  }
}

@card
class Chapel extends ActionCard with BaseSet {
  Chapel._();
  static Chapel instance = new Chapel._();

  final int cost = 2;
  final String name = "Chapel";

  onPlay(Player player) async {
    List<Card> cards =
        await player.controller.selectCardsFromHand(this, new CardConditions(), 0, 4);
    for (Card c in cards) {
      await player.trashFrom(c, player.hand);
    }
  }
}

@card
class Moat extends ActionCard with BaseSet, Reaction {
  Moat._();
  static Moat instance = new Moat._();

  final int cost = 2;
  final String name = "Moat";

  onPlay(Player player) async {
    player.draw(2);
  }

  bool canReactTo(EventType type, Card context) {
    return type == EventType.Attack;
  }

  Future<bool> onReact(Player player) async {
    return true;
  }
}

@card
class Chancellor extends ActionCard with BaseSet {
  Chancellor._();
  static Chancellor instance = new Chancellor._();

  final int cost = 3;
  final String name = "Chancellor";

  onPlay(Player player) async {
    player.turn.coins += 2;
    bool discardDeck =
        await player.controller.confirmAction(this, "Chancellor: Place deck in discard pile?");
    if (discardDeck) {
      player.deck.dumpTo(player.discarded);
      player.notifyAnnounce("Your discard your", "discards their", "deck");
    }
  }
}

@card
class Village extends ActionCard with BaseSet {
  Village._();
  static Village instance = new Village._();

  final int cost = 3;
  final String name = "Village";

  onPlay(Player player) async {
    player.draw();
    player.turn.actions += 2;
  }
}

@card
class Woodcutter extends ActionCard with BaseSet {
  Woodcutter._();
  static Woodcutter instance = new Woodcutter._();

  final int cost = 3;
  final String name = "Woodcutter";

  onPlay(Player player) async {
    player.turn.buys += 1;
    player.turn.coins += 2;
  }
}

@card
class Workshop extends ActionCard with BaseSet {
  Workshop._();
  static Workshop instance = new Workshop._();

  final int cost = 3;
  final String name = "Workshop";

  onPlay(Player player) async {
    CardConditions conds = new CardConditions();
    conds.maxCost = 4;
    Card card = await player.selectCardToGain(conditions: conds);
    await player.gain(card);
  }
}

@card
class Bureaucrat extends ActionCard with BaseSet, Attack {
  Bureaucrat._();
  static Bureaucrat instance = new Bureaucrat._();

  final int cost = 4;
  final String name = "Bureaucrat";

  onPlay(Player player) async {
    await player.gain(Silver.instance);
    player.discarded.moveTo(Silver.instance, player.deck.top);
    for (Player p in player.engine.playersAfter(player)) {
      bool attackBlocked = await p.reactTo(EventType.Attack, this);
      if (attackBlocked) continue;
      List<Card> victories = [];
      for (Card c in p.hand.asList()) {
        if (c is VictoryCard) victories.add(c);
      }
      if (victories.length == 1) {
        p.hand.moveTo(victories[0], p.deck.top);
      } else if (victories.length > 1) {
        CardConditions conds = new CardConditions()..requiredTypes = [CardType.Victory];
        List<Card> cards = await p.controller.selectCardsFromHand(this, conds, 1, 1);
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
class Feast extends ActionCard with BaseSet {
  Feast._();
  static Feast instance = new Feast._();

  final int cost = 4;
  final String name = "Feast";

  onPlay(Player player) async {
    await player.trashFrom(this, player.turn.played);
    CardConditions conds = new CardConditions();
    conds.maxCost = 5;
    Card card = await player.selectCardToGain(conditions: conds);
    await player.gain(card);
  }
}

@card
class Gardens extends VictoryCard with BaseSet {
  Gardens._();
  static Gardens instance = new Gardens._();

  final int cost = 4;
  final String name = "Gardens";

  int getVictoryPoints(Player player) {
    int totalCards = player.getAllCards().length;
    return totalCards ~/ 10;
  }
}

@card
class Militia extends ActionCard with BaseSet, Attack {
  Militia._();
  static Militia instance = new Militia._();

  final int cost = 4;
  final String name = "Militia";

  onPlay(Player player) async {
    player.turn.coins += 2;
    for (Player p in player.engine.playersAfter(player)) {
      bool attackBlocked = await p.reactTo(EventType.Attack, this);
      if (!attackBlocked) {
        int x = p.hand.length - 3;
        List<Card> cards = await p.controller.selectCardsFromHand(this, new CardConditions(), x, x);
        for (Card c in cards) {
          await p.discard(c);
        }
      }
    }
  }
}

@card
class Moneylender extends ActionCard with BaseSet {
  Moneylender._();
  static Moneylender instance = new Moneylender._();

  final int cost = 4;
  final String name = "Moneylender";

  onPlay(Player player) async {
    if (await player.trashFrom(Copper.instance, player.hand)) {
      player.turn.coins += 3;
    }
  }
}

@card
class Remodel extends ActionCard with BaseSet {
  Remodel._();
  static Remodel instance = new Remodel._();

  final int cost = 4;
  final String name = "Remodel";

  onPlay(Player player) async {
    List<Card> cards =
        await player.controller.selectCardsFromHand(this, new CardConditions(), 1, 1);
    if (cards.length != 1) return;
    await player.trashFrom(cards[0], player.hand);
    CardConditions conds = new CardConditions();
    conds.maxCost = cards[0].calculateCost(player.turn) + 2;
    Card card = await player.selectCardToGain(conditions: conds);
    await player.gain(card);
  }
}

@card
class Smithy extends ActionCard with BaseSet {
  Smithy._();
  static Smithy instance = new Smithy._();

  final int cost = 4;
  final String name = "Smithy";

  onPlay(Player player) async {
    player.draw(3);
  }
}

@card
class Spy extends ActionCard with BaseSet, Attack {
  Spy._();
  static Spy instance = new Spy._();

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
      CardBuffer buffer = new CardBuffer();
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
class Thief extends ActionCard with BaseSet, Attack {
  Thief._();
  static Thief instance = new Thief._();

  final int cost = 4;
  final String name = "Thief";

  onPlay(Player player) async {
    List<Card> trashed = [];
    for (Player p in player.engine.playersAfter(player)) {
      bool attackBlocked = await p.reactTo(EventType.Attack, this);
      if (attackBlocked) continue;
      CardBuffer buffer = new CardBuffer();
      p.drawTo(buffer);
      p.drawTo(buffer);
      p.notifyAnnounce("You reveal", "reveals", "$buffer");
      CardBuffer options = new CardBuffer();
      CardBuffer discarding = new CardBuffer();
      int length = buffer.length;
      for (int i = 0; i < length; i++) {
        if (buffer[0] is TreasureCard) {
          buffer.drawTo(options);
        } else {
          buffer.drawTo(discarding);
        }
      }
      if (options.length == 1) {
        var question = "Thief: Trash ${p.name}'s ${options[0].name}?";
        bool trash = await player.controller.confirmAction(options[0], question);
        if (trash) {
          Card card = options[0];
          await p.trashDraw(options);
          trashed.add(card);
        } else {
          options.drawTo(discarding);
        }
      } else if (options.length == 2) {
        List choices = [options[0], options[1], "Neither"];
        var question = "Thief: Which of ${p.name}'s cards do you want to trash?";
        var selection = await player.controller.askQuestion(this, question, choices);
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
      List<Card> keeping = await player.controller.selectCardsFrom(trashed, question, 0, -1);
      for (Card c in keeping) {
        player.engine.trashPile.moveTo(c, player.discarded);
        player.notifyAnnounce("You gain", "gains", "a $c from the trash");
        c.onGain(player, false);
      }
    }
  }
}

@card
class ThroneRoom extends ActionCard with BaseSet {
  ThroneRoom._();
  static ThroneRoom instance = new ThroneRoom._();

  final int cost = 4;
  final String name = "Throne Room";

  onPlay(Player player) async {
    ActionCard card = await player.controller.selectActionCard();
    if (card != null) {
      player.hand.moveTo(card, player.turn.played);
      player.turn.actionsPlayed += 1;
      player.notifyAnnounce("You play", "plays", "a $card");
      await card.onPlay(player);
      player.turn.actionsPlayed += 1;
      player.notifyAnnounce("You play", "plays", "the $card again");
      await card.onPlay(player);
    }
  }
}

@card
class CouncilRoom extends ActionCard with BaseSet {
  CouncilRoom._();
  static CouncilRoom instance = new CouncilRoom._();

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
class Festival extends ActionCard with BaseSet {
  Festival._();
  static Festival instance = new Festival._();

  final int cost = 5;
  final String name = "Festival";

  onPlay(Player player) async {
    player.turn.actions += 2;
    player.turn.buys += 1;
    player.turn.coins += 2;
  }
}

@card
class Laboratory extends ActionCard with BaseSet {
  Laboratory._();
  static Laboratory instance = new Laboratory._();

  final int cost = 5;
  final String name = "Laboratory";

  onPlay(Player player) async {
    player.draw(2);
    player.turn.actions += 1;
  }
}

@card
class Library extends ActionCard with BaseSet {
  Library._();
  static Library instance = new Library._();

  final int cost = 5;
  final String name = "Library";

  onPlay(Player player) async {
    CardBuffer buffer = new CardBuffer();
    while (player.hand.length < 7) {
      Card card = player.draw();
      if (card == null) break;
      if (card is ActionCard) {
        bool setAside = await player.controller.confirmAction(card, "Library: Set aside ${card}?");
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
class Market extends ActionCard with BaseSet {
  Market._();
  static Market instance = new Market._();

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
class Mine extends ActionCard with BaseSet {
  Mine._();
  static Mine instance = new Mine._();

  final int cost = 5;
  final String name = "Mine";

  onPlay(Player player) async {
    CardConditions trashConds = new CardConditions()..requiredTypes = [CardType.Treasure];
    List<Card> cards = await player.controller.selectCardsFromHand(this, trashConds, 1, 1);
    if (cards.length != 1) return;
    int cost = cards[0].calculateCost(player.turn);
    player.trashFrom(cards[0], player.hand);
    CardConditions gainConds = new CardConditions();
    gainConds..requiredTypes = [CardType.Treasure];
    gainConds..maxCost = cost + 3;
    Card card = await player.selectCardToGain(conditions: gainConds);
    await player.gain(card);
    player.discarded.moveTo(card, player.hand);
  }
}

@card
class Witch extends ActionCard with BaseSet, Attack {
  Witch._();
  static Witch instance = new Witch._();

  final int cost = 5;
  final String name = "Witch";

  onPlay(Player player) async {
    player.draw(2);
    for (Player p in player.engine.playersAfter(player)) {
      bool attackBlocked = await p.reactTo(EventType.Attack, this);
      if (!attackBlocked) {
        await p.gain(Curse.instance);
      }
    }
  }
}

@card
class Adventurer extends ActionCard with BaseSet {
  Adventurer._();
  static Adventurer instance = new Adventurer._();

  final int cost = 6;
  final String name = "Adventurer";

  onPlay(Player player) async {
    CardBuffer buffer = new CardBuffer();

    int treasureCount = 0;
    while (treasureCount < 2) {
      Card card = player.drawTo(buffer);
      if (card == null) break;
      if (card is TreasureCard) treasureCount++;
    }

    Card card = buffer.removeTop();
    while (card != null) {
      if (card is TreasureCard) {
        player.hand.receive(card);
      } else {
        player.discarded.receive(card);
        await card.onDiscard(player);
      }
      card = buffer.removeTop();
    }
  }
}
