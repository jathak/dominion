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

class CardBuffer extends Object with CardSource, CardTarget {
  CardBuffer() {
    top = new TopTarget(this);
  }

  CardBuffer.from(Iterable<Card> cards) {
    top = new TopTarget(this);
    cards.forEach(receive);
  }

  List<Card> _cards = [];

  TopTarget top;

  bool remove(Card card) => _cards.remove(card);

  Card removeTop() {
    if (_cards.length == 0) return null;
    return _cards.removeAt(0);
  }

  receive(Card card) => _cards.add(card);

  int get length => _cards.length;

  shuffle() => _cards.shuffle();

  bool contains(Card card) => _cards.contains(card);

  addToTop(Card card) => _cards.insert(0, card);

  operator [](int index) => _cards[index];

  String toString() => _cards.toString();

  List<Card> asList() => []..addAll(_cards);
}

class TopTarget extends Object with CardTarget {
  CardBuffer buffer;

  TopTarget(this.buffer);

  receive(Card card) => buffer.addToTop(card);
}

class SupplySource extends Object with CardSource {
  int count;
  Card card;
  int embargoTokens = 0;

  SupplySource(this.card, this.count);

  bool remove(Card c) {
    if (c == card && count > 0) {
      count -= 1;
      return true;
    }
    return false;
  }

  Card removeTop() {
    if (count > 0) {
      count -= 1;
      return card;
    }
    return null;
  }
}
