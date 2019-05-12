part of dominion_core;

abstract class Card implements Comparable<Card> {
  /// Should be the one and only instance or this class
  /// as the constructor should be private
  static const Card instance = null;

  /// Raw cost of card, prior to modifications by others
  final int cost = null;

  /// Calculates cost based on raw cost and cards in play
  int calculateCost(Turn turn) {
    if (turn == null) return cost;
    int calcCost = cost;
    for (var fn in turn.costProcessors) {
      calcCost = fn(this, calcCost);
    }
    // TODO: Handle cards which decrease card cost - cards like Peddler will override
    return calcCost >= 0 ? calcCost : 0;
  }

  /// Returns number of cards of this type in supply
  /// Defaults to 10
  int supplyCount(int playerCount) => 10;

  /// True if card requires a potion to buy
  final bool requiresPotion = false;

  /// Name of card
  final String name = null;

  /// Name of expansion (kingdom cards in base set use "Base")
  /// Null is used for the basic cards (including Platinum, Colony, and Potion)
  final String expansion = null;

  /// Called when player gains this card
  onGain(Player player, bool bought) async => null;

  /// Called when player plays this card
  onPlay(Player player) async => null;

  /// Called when player plays this turn.
  ///
  /// Most non-durations should override onPlay instead.
  Future<ForNextTurn> onPlayCanPersist(Player player) async {
    await onPlay(player);
    return null;
  }

  /// Called when player discards this card
  onDiscard(Player player,
          {bool cleanup: false, List<Card> cleanedUp: null}) async =>
      null;

  /// Called when player trashes this card
  onTrash(Player player) async => null;

  @override
  int compareTo(Card other) {
    if (this.cost == other.cost) {
      return this.name.compareTo(other.name);
    }
    return this.cost - other.cost;
  }

  String toString() => name;
}

mixin Treasure on Card {
  /// Default treasure value of this card
  /// Set to null for no default value
  final int value = null;

  /// Calculates value of treasure
  int getTreasureValue(Turn turn) => value;

  /// Called when treasure is played
  onPlay(Player player) async {
    player.turn.coins += getTreasureValue(player.turn);
  }
}

/// Includes Victory and Curse cards
mixin VictoryOrCurse on Card {
  /// Default victory point value of this card
  /// Set to null for no default value
  final int points = null;

  /// Calculates victory points
  int getVictoryPoints(Player player) => points;
}

mixin Victory on Card implements VictoryOrCurse {
  final int points = null;

  int getVictoryPoints(Player player) => points;

  int supplyCount(int playerCount) {
    if (playerCount == 2) return 8;
    return 12;
  }
}

/// No special behavior in class definition,
/// as each action is different.
mixin Action on Card {}

/// Only used to check whether a card is an attack
mixin Attack on Card {}

mixin Reaction on Card {
  bool canReactTo(EventType type, Card context, Player player);

  Future<bool> onReact(Player player);
}

/// This is a subtype, so it doesn't directly extend Card
/// as all Durations also extend one of the main types
mixin Duration on Card {}

class ForNextTurn {
  bool persists;
  NextTurnAction action;

  ForNextTurn(this.persists, this.action);
}

typedef Future<bool> NextTurnAction();
