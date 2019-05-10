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
        if (conditions.allowedExpansions.length == 0 ||
            conditions.allowedExpansions.contains(card.expansion)) {
          if (conditions.maxSetsUsed < 1 ||
              expansSoFar.length < conditions.maxSetsUsed ||
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
  /// use empty list for any registered sets
  List<String> allowedExpansions = [];

  /// set to less than 1 for any number of sets (within allowedSets)
  int maxSetsUsed = -1;

  int minCost = -1;

  int maxCost = -1;

  /// sets both minCost and maxCost
  set cost(int c) {
    minCost = c;
    maxCost = c;
  }

  /// selected cards must have at least one
  /// of the following types (unless list is empty)
  List<CardType> requiredTypes = [];

  /// selected cards must not have any of the
  /// following types
  List<CardType> invalidTypes = [];

  /// returns true if conditions allow for this card
  bool allowsFor(Card card, [Player player]) {
    if (allowedExpansions.length > 0 &&
        !allowedExpansions.contains(card.expansion)) {
      return false;
    }
    int cardCost = card.cost;
    if (player != null) cardCost = card.calculateCost(player.turn);
    if (minCost > -1 && cardCost < minCost) return false;
    if (maxCost > -1 && cardCost > maxCost) return false;
    bool meetsReq = requiredTypes.length == 0;
    if (card is Action) {
      if (invalidTypes.contains(CardType.Action)) return false;
      if (requiredTypes.contains(CardType.Action)) meetsReq = true;
    } else if (card is Treasure) {
      if (invalidTypes.contains(CardType.Treasure)) return false;
      if (requiredTypes.contains(CardType.Treasure)) meetsReq = true;
    } else if (card is Victory) {
      if (invalidTypes.contains(CardType.Victory)) return false;
      if (requiredTypes.contains(CardType.Victory)) meetsReq = true;
    } else if (card is Curse) {
      if (invalidTypes.contains(CardType.Curse)) return false;
      if (requiredTypes.contains(CardType.Curse)) meetsReq = true;
    } else if (card is Duration) {
      if (invalidTypes.contains(CardType.Duration)) return false;
      if (requiredTypes.contains(CardType.Duration)) meetsReq = true;
    } else if (card is Attack) {
      if (invalidTypes.contains(CardType.Attack)) return false;
      if (requiredTypes.contains(CardType.Attack)) meetsReq = true;
    } else if (card is Reaction) {
      if (invalidTypes.contains(CardType.Reaction)) return false;
      if (requiredTypes.contains(CardType.Reaction)) meetsReq = true;
    }
    return meetsReq;
  }
}

enum CardType { Action, Treasure, Victory, Curse, Duration, Attack, Reaction }
