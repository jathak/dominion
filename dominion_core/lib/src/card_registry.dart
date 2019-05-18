part of dominion_core;

class CardRegistry {
  static Map<String, Card> _cards = null;

  static _init() {
    _cards = {};
    for (LibraryMirror lib in currentMirrorSystem().libraries.values) {
      for (DeclarationMirror decl in lib.declarations.values) {
        if (decl is ClassMirror) {
          if (decl.metadata.contains(reflect(card))) {
            Card instance =
                decl.getField(new Symbol('instance')).reflectee as Card;
            _cards[instance.name] = instance;
          }
        }
      }
    }
  }

  static Card find(String name) {
    if (_cards == null) _init();
    return _cards[name];
  }

  static Iterable<Card> cardsWithConditions([CardConditions conditions]) sync* {
    if (_cards == null) _init();
    if (conditions == null) conditions = new CardConditions();
    var allCards = getCards();
    allCards.shuffle();
    Set<String> expansSoFar = new Set<String>();
    for (Card card in allCards) {
      if (card.expansion != null) {
        if (conditions.allowedExpansions == null ||
            conditions.allowedExpansions.contains(card.expansion)) {
          if (conditions.maxExpansionsUsed == null ||
              expansSoFar.length < conditions.maxExpansionsUsed ||
              expansSoFar.contains(card.expansion)) {
            expansSoFar.add(card.expansion);
            yield card;
          }
        }
      }
    }
  }

  static getCards() => new List.from(_cards.values);
}

class CardConditions {
  /// List of expansions allowed by these conditions, or null if all expansions
  /// are allowed.
  List<String> allowedExpansions;

  /// Maximum number of expansions cards may come from (for kingdom selection).
  /// If null, no maximum.
  int maxExpansionsUsed;

  /// Minimum card cost (if null, no minimum)
  int minCost;

  /// Maximum card cost (if null, no maximum);
  int maxCost;

  /// Whether `card.buyable` must return true for the given player.
  bool mustBeBuyable = false;

  /// Sets both minCost and maxCost
  set cost(int c) {
    minCost = c;
    maxCost = c;
  }

  /// Types that cards are required to have at least one of (or null if no
  /// types are required).
  List<CardType> requiredTypes;

  /// Types that exclude a card from these conditions
  List<CardType> invalidTypes = [];

  /// Cards that are explicitly disallowed by these conditions.
  List<Card> bannedCards = [];

  /// If set, only cards within this list are allowed.
  List<Card> requiredCards;

  /// Returns true if conditions allow for this card
  bool allowsFor(Card card, Player player) {
    if (requiredCards != null && !requiredCards.contains(card.expansion)) {
      return false;
    }
    if (bannedCards.contains(card)) return false;
    if (allowedExpansions != null &&
        !allowedExpansions.contains(card.expansion)) {
      return false;
    }
    for (var type in invalidTypes) {
      if (_cardHasType(card, type)) return false;
    }
    if (requiredTypes != null) {
      bool meetsRequirement = false;
      for (var type in requiredTypes) {
        if (_cardHasType(card, type)) meetsRequirement = true;
      }
      if (!meetsRequirement) return false;
    }
    if (player != null && mustBeBuyable && !card.buyable(player)) return false;
    int cardCost = card.cost;
    if (player != null) cardCost = card.calculateCost(player);
    if (minCost != null && cardCost < minCost) return false;
    if (maxCost != null && cardCost > maxCost) return false;
    return true;
  }

  static bool _cardHasType(Card card, CardType type) {
    switch (type) {
      case CardType.Action:
        return card is Action;
      case CardType.Treasure:
        return card is Treasure;
      case CardType.Victory:
        return card is Victory;
      case CardType.Curse:
        return card is Curse;
      case CardType.Duration:
        return card is Duration;
      case CardType.Attack:
        return card is Attack;
      case CardType.Reaction:
        return card is Reaction;
    }
    return false;
  }
}

enum CardType { Action, Treasure, Victory, Curse, Duration, Attack, Reaction }
