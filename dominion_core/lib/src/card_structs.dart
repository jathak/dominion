part of dominion_core;

abstract class CardSource {
  /// return true if card removed, false otherwise
  bool remove(Card card);

  /// moves a given card from this to the given target
  bool moveTo(Card card, CardTarget target) {
    if (remove(card)) {
      target.receive(card);
      return true;
    }
    return false;
  }

  /// removes the top card or null if none
  Card removeTop();

  /// draws the top card from this to the given target
  /// returns the drawn card if any
  Card drawTo(CardTarget target) {
    Card card = removeTop();
    if (card == null) return null;
    target.receive(card);
    return card;
  }

  /// empties this into the given target
  dumpTo(CardTarget target) {
    Card card = removeTop();
    while (card != null) {
      target.receive(card);
      card = removeTop();
    }
  }

  /// Draws count cards into the target returned by fn(card)
  /// If count is less than 0, filter all cards in source
  /// Count defaults to -1
  filterInto(var fn, [int count = -1]) {
    if (count < 0) {
      Card card = removeTop();
      while (card != null) {
        fn(card).receive(card);
        card = removeTop();
      }
    } else {
      for (int i = 0; i < count; i++) {
        Card card = removeTop();
        if (card == null) return;
        fn(card).receive(card);
      }
    }
  }
}

abstract class CardTarget {
  receive(Card card);
}

abstract class CardSourceAndTarget with CardSource, CardTarget {}

class CardBuffer extends CardSourceAndTarget {
  CardBuffer();

  CardBuffer.from(Iterable<Card> cards) {
    cards.forEach(receive);
  }

  List<Card> _cards = [];

  bool remove(Card card) => _cards.remove(card);

  Card removeTop() {
    if (_cards.length == 0) return null;
    return _cards.removeAt(0);
  }

  receive(Card card) => _cards.add(card);

  int get length => _cards.length;

  shuffle() => _cards.shuffle();

  bool contains(Card card) => _cards.contains(card);

  operator [](int index) => _cards[index];

  String toString() => _cards.toString();

  List<Card> toList() => _cards.toList();

  List<T> whereType<T extends Card>() => _cards.whereType<T>().toList();

  Map<String, dynamic> serialize() => {
        'type': 'CardBuffer',
        'cards': _cards.map((card) => card.serialize()).toList()
      };

  static CardBuffer deserialize(data) =>
      CardBuffer.from(Card.deserializeList(data['cards']));
}

class Deck extends CardBuffer {
  Deck();

  Deck.from(Iterable<Card> cards) : super.from(cards);

  TopOfDeck get top => TopOfDeck(this);
  BottomOfDeck get bottom => BottomOfDeck(this);

  addToTop(Card card) => _cards.insert(0, card);

  Card removeFromBottom() => _cards.removeLast();

  Map<String, dynamic> serialize() => {
        'type': 'Deck',
        'cards': _cards.map((card) => card.serialize()).toList()
      };

  static Deck deserialize(data) =>
      Deck.from(Card.deserializeList(data['cards']));
}

class TopOfDeck extends CardSourceAndTarget {
  final Deck deck;

  TopOfDeck(this.deck);

  receive(Card card) => deck.addToTop(card);

  bool remove(Card card) => deck.remove(card);

  Card removeTop() => deck.removeTop();
}

class BottomOfDeck extends CardSourceAndTarget {
  final Deck deck;

  BottomOfDeck(this.deck);

  bool remove(Card card) {
    throw Exception(
        "Do not use CardBuffer.bottom when removing specific cards!");
  }

  /// This actually removes from the bottom of the deck.
  Card removeTop() => deck.removeFromBottom();

  @override
  receive(Card card) => deck.receive(card);
}

class SupplyPile extends CardSourceAndTarget {
  /// The number of cards left in this supply pile.
  int count;

  /// The card this supply pile contains.
  Card card;

  /// The number of embargo tokens on this supply pile.
  int embargoTokens = 0;

  /// Whether someone has taken a card from this pile or not.
  bool used = false;

  /// The current cost of this card.
  ///
  /// Note: This should always be null on the server. It should only be set
  /// by the deserializer on the client.
  int currentCost;

  SupplyPile(this.card, this.count);

  bool remove(Card c) {
    if (c == card && count > 0) {
      used = true;
      count -= 1;
      return true;
    }
    return false;
  }

  Card removeTop() {
    if (count > 0) {
      used = true;
      count -= 1;
      return card;
    }
    return null;
  }

  receive(Card received) {
    if (card != received) {
      throw Exception("Cannot return $received to the $card pile!");
    }
    count++;
  }

  Map<String, dynamic> serialize({Player includeCostFor}) => {
        'type': 'SupplyPile',
        'card': card.serialize(),
        'count': count,
        'used': used,
        'embargoTokens': embargoTokens,
        if (includeCostFor != null)
          'currentCost': card.calculateCost(includeCostFor)
      };

  static SupplyPile deserialize(data) =>
      SupplyPile(Card.deserialize(data['card']), data['count'])
        ..used = data['used']
        ..embargoTokens = data['embargoTokens']
        ..currentCost = data['currentCost'];
}
