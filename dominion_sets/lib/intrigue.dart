// Copyright (c) 2015, Jack Thakar. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library intrigue;

import 'package:dominion_core/dominion_core.dart';

import 'dart:async';

void load() {
    CardRegistry.register(Courtyard.instance);
    CardRegistry.register(Pawn.instance);
    CardRegistry.register(SecretChamber.instance);
    CardRegistry.register(GreatHall.instance);
    CardRegistry.register(Masquerade.instance);
    CardRegistry.register(ShantyTown.instance);
    CardRegistry.register(Steward.instance);
    CardRegistry.register(Swindler.instance);
    CardRegistry.register(WishingWell.instance);
    CardRegistry.register(Baron.instance);
    CardRegistry.register(Bridge.instance);
    CardRegistry.register(Conspirator.instance);
    CardRegistry.register(Coppersmith.instance);
    CardRegistry.register(Ironworks.instance);
    CardRegistry.register(MiningVillage.instance);
    CardRegistry.register(Scout.instance);
    CardRegistry.register(Duke.instance);
    CardRegistry.register(Minion.instance);
    CardRegistry.register(Saboteur.instance);
    CardRegistry.register(Torturer.instance);
    CardRegistry.register(TradingPost.instance);
    CardRegistry.register(Tribute.instance);
    CardRegistry.register(Upgrade.instance);
    CardRegistry.register(Harem.instance);
    CardRegistry.register(Nobles.instance);
}

abstract class Intrigue {
    final String expansion = "Intrigue";
}

class Courtyard extends ActionCard with Intrigue {
    Courtyard._();
    static Courtyard instance = new Courtyard._();
    
    final int cost = 2;
    final String name = "Courtyard";
    
    onPlay(Player player) async {
        player.draw(3);
        CardConditions conds = new CardConditions();
        List<Card> cards = await player.controller.selectCardsFromHand(this, conds, 1, 1);
        if (cards.length == 1) {
            player.hand.moveTo(cards[0], player.deck.top);
        }
    }
}

class Pawn extends ActionCard with Intrigue {
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
        String option1 = await player.controller.askQuestion(this, "Pawn: First Choice", options);
        chosen.add(option1);
        options.remove(option1);
        String option2 = await player.controller.askQuestion(this, "Pawn: Second Choice", options);
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

class SecretChamber extends ActionCard with Reaction, Intrigue {
    SecretChamber._();
    static SecretChamber instance = new SecretChamber._();
    
    final int cost = 2;
    final String name = "Secret Chamber";
    
    onPlay(Player player) async {
        CardConditions conds = new CardConditions();
        List<Card> cards = await player.controller.selectCardsFromHand(this, conds, 0, -1);
        for (Card c in cards) {
            await player.discard(c);
        }
        player.turn.coins += cards.length;
    }
    
    bool canReactTo(EventType type, Card context) => type == EventType.Attack;
    
    Future<bool> onReact(Player player) async {
        player.draw(2);
        CardConditions conds = new CardConditions();
        List<Card> cards = await player.controller.selectCardsFromHand(this, conds, 2, 2);
        for (Card c in cards) {
            player.hand.moveTo(c, player.deck.top);
        }
        return false;
    }
}

class GreatHall extends VictoryCard with ActionCard, Intrigue {
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

class Masquerade extends ActionCard with Intrigue {
    Masquerade._();
    static Masquerade instance = new Masquerade._();
    
    final int cost = 3;
    final String name = "Masquerade";
    
    onPlay(Player player) async {
        player.draw(2);
        CardConditions conds = new CardConditions();
        Map<Player, Card> passing = {};
        for (Player p in player.engine.playersFrom(player)) {
            List<Card> selected = await player.controller.selectCardsFromHand(this, conds, 1, 1);
            if (selected.length == 1) {
                passing[p] = selected[0];
            }
        }
        for (Player p in player.engine.playersFrom(player)) {
            if (passing.containsKey(p)) {
                Player left = player.engine.toLeftOf(p);
                p.hand.moveTo(passing[p], left.hand);
            }
        }
        List<Card> trashing = await player.controller.selectCardsFromHand(this, conds, 0, 1);
        if (trashing.length == 1) {
            await player.trashFrom(trashing[0], player.hand);
        }
    }
}

class ShantyTown extends ActionCard with Intrigue {
    ShantyTown._();
    static ShantyTown instance = new ShantyTown._();
    
    final int cost = 3;
    final String name = "Shanty Town";
    
    onPlay(Player player) async {
        player.turn.actions += 2;
        player.announce("reveals hand of ${player.hand}");
        if (!player.hasActions()) {
            player.draw(2);
        }
    }
}

class Steward extends ActionCard with Intrigue {
    Steward._();
    static Steward instance = new Steward._();
    
    final int cost = 3;
    final String name = "Steward";
    
    onPlay(Player player) async {
        String a = "+2 Cards";
        String b = "+2 Coins";
        String c = "Trash 2 cards from your hand";
        String option = await player.controller.askQuestion(this, "Choose one", [a, b, c]);
        if (option == a) {
            player.draw(2);
        } else if (option == b) {
            player.turn.coins += 2;
        } else if (option == c) {
            CardConditions conds = new CardConditions();
            List<Card> trashing = await player.controller.selectCardsFromHand(this, conds, 2, 2);
            for (Card c in trashing) {
                await player.trashFrom(c, player.hand);
            }
        }
    }
}

class Swindler extends ActionCard with Attack, Intrigue {
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
            CardConditions conds = new CardConditions()..cost = trashed.calculateCost(player.turn);
            Card selected = await player.controller.selectCardFromSupply(EventType.GainForOpponent, conds, false);
            await p.gain(selected);
        }
    }
}

class WishingWell extends ActionCard with Intrigue {
    WishingWell._();
    static WishingWell instance = new WishingWell._();
    
    final int cost = 3;
    final String name = "Wishing Well";
    
    onPlay(Player player) async {
        player.draw(1);
        player.turn.actions += 1;
        CardConditions conds = new CardConditions();
        Card guess = await player.controller.selectCardFromSupply(EventType.GuessCard, conds, false);
        CardBuffer buffer = new CardBuffer();
        player.drawTo(buffer);
        player.announce("reveals ${buffer[0]}");
        if (buffer[0] == guess) {
            player.announce("guessed correctly!");
            buffer.drawTo(player.hand);
        } else {
            player.announce("guessed incorrectly");
            buffer.drawTo(player.deck.top);
        }
    }
}

class Baron extends ActionCard with Intrigue {
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
        if (hasEstate && await player.controller.confirmAction(this, "Discard an Estate for +4 coins?")) {
            player.turn.coins += 4;
        } else {
            await player.gain(Estate.instance);
        }
    }
}

class Bridge extends ActionCard with Intrigue {
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

class Conspirator extends ActionCard with Intrigue {
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

class Coppersmith extends ActionCard with Intrigue {
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

class Ironworks extends ActionCard with Intrigue {
    Ironworks._();
    static Ironworks instance = new Ironworks._();
    
    final int cost = 4;
    final String name = "Ironworks";
    
    onPlay(Player player) async {
        CardConditions conds = new CardConditions()..maxCost = 4;
        Card gaining = await player.selectCardToGain(conditions: conds);
        if (gaining is ActionCard) player.turn.actions += 1;
        if (gaining is TreasureCard) player.turn.coins += 1;
        if (gaining is VictoryCard) player.draw(1);
    }
}

class MiningVillage extends ActionCard with Intrigue {
    MiningVillage._();
    static MiningVillage instance = new MiningVillage._();
    
    final int cost = 4;
    final String name = "Mining Village";
    
    onPlay(Player player) async {
        player.draw(1);
        player.turn.actions += 2;
        bool trash = await player.controller.confirmAction(this, "Trash Mining Village for +2 coins?");
        if (trash) {
            bool didTrash = await player.trashFrom(this, player.turn.played);
            if (didTrash) {
                player.turn.coins += 2;
            }
        }
    }
}

class Scout extends ActionCard with Intrigue {
    Scout._();
    static Scout instance = new Scout._();
    
    final int cost = 4;
    final String name = "Scout";
    
    onPlay(Player player) async {
        player.turn.actions += 1;
        CardBuffer buffer = new CardBuffer();
        for (int i = 0; i < 4; i++) player.drawTo(buffer);
        player.announce("reveals $buffer");
        for (Card c in buffer.asList()) {
            if (c is VictoryCard) {
                buffer.moveTo(c, player.hand);
            }
        }
        List<Card> rearranged = await player.controller.selectCardsFrom(buffer.asList(),
                "Select cards in the order you want them returned to the deck.",
                buffer.length, buffer.length);
        for (Card c in rearranged) {
            buffer.moveTo(c, player.deck.top);
        }
    }
}

class Duke extends VictoryCard with Intrigue {
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

class Minion extends ActionCard with Intrigue {
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
        String b = "Discard your hand for +4 Cards and each other player with at least 5 cards in hand discards their hand and draws 4 cards";
        String option = await player.controller.askQuestion(this, "Choose one", [a, b]);
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

class Saboteur extends ActionCard with Intrigue {
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
                    Card gaining = await p.selectCardToGain(conditions: conds, allowNone: true);
                    if (gaining != null) {
                        await p.gain(gaining);
                    }
                    break;
                }
            }
        }
    }
}

class Torturer extends ActionCard with Intrigue {
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
            String option = await player.controller.askQuestion(this, "Choose one", [a, b]);
            if (option == a) {
                List<Card> cards = await p.controller.selectCardsFromHand(this, new CardConditions(), 2, 2);
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

class TradingPost extends ActionCard with Intrigue {
    TradingPost._();
    static TradingPost instance = new TradingPost._();
    
    final int cost = 5;
    final String name = "Trading Post";
    
    onPlay(Player player) async {
        List<Card> cards = await player.controller.selectCardsFromHand(this, new CardConditions(), 2, 2);
        for (Card c in cards) {
            await player.trashFrom(c, player.hand);
        }
        if (cards.length == 2) {
            await player.gain(Silver.instance);
            player.discarded.moveTo(Silver.instance, player.hand);
        }
    }
}

class Tribute extends ActionCard with Intrigue {
    Tribute._();
    static Tribute instance = new Tribute._();
    
    final int cost = 5;
    final String name = "Tribute";
    
    onPlay(Player player) async {
        Player left = player.engine.toLeftOf(player);
        CardBuffer buffer = new CardBuffer();
        left.drawTo(buffer);
        left.drawTo(buffer);
        left.announce("reveals $buffer");
        Set drawn = new Set.from(buffer.asList());
        while (buffer.length > 0) {
            await left.discardFrom(buffer);
        }
        for (Card c in drawn) {
            if (c != null) {
                if (c is ActionCard) player.turn.actions += 2;
                if (c is TreasureCard) player.turn.coins += 2;
                if (c is VictoryCard) player.draw(2);
            }
        }
    }
}

class Upgrade extends ActionCard with Intrigue {
    Upgrade._();
    static Upgrade instance = new Upgrade._();
    
    final int cost = 5;
    final String name = "Upgrade";
    
    onPlay(Player player) async {
        player.draw(1);
        player.turn.actions += 1;
        List<Card> cards = await player.controller.selectCardsFromHand(this, new CardConditions(), 1, 1);
        if (cards.length != 1) return;
        await player.trashFrom(cards[0], player.hand);
        CardConditions conds = new CardConditions();
        conds.cost = cards[0].calculateCost(player.turn) + 1;
        Card card = await player.selectCardToGain(conditions: conds);
        if (card == null) return;
        await player.gain(card);
    }
}

class Harem extends VictoryCard with TreasureCard, Intrigue {
    Harem._();
    static Harem instance = new Harem._();
    
    final int cost = 6;
    final String name = "Harem";
    
    final int value = 2;
    final int points = 2;
}

class Nobles extends VictoryCard with ActionCard, Intrigue {
    Nobles._();
    static Nobles instance = new Nobles._();
    
    final int cost = 6;
    final String name = "Nobles";
    
    final int points = 2;
    
    onPlay(Player player) async {
        String threeCards = "+3 Cards";
        String twoActions = "+2 Actions";
        String result = await player.controller.askQuestion(this,
            "Nobles: Which action do you want to take?", 
            [threeCards, twoActions]);
        if (result == threeCards) {
            player.draw(3);
        } else if (result == twoActions) {
            player.turn.actions += 2;
        }
    }
}


