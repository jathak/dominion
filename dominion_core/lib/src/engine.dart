part of dominion_core;

class DominionEngine {
  CardBuffer trashPile = new CardBuffer();
  Supply supply;

  /// used by various cards to attach data to the entire game
  Map misc = {};

  DominionEngine(this.supply, List<PlayerController> controllers) {
    _players = [];
    for (var pc in controllers) {
      _players.add(new Player(this, pc));
    }
    for (var player in _players) {
      player.controller.player = player;
    }
    currentPlayer = _players[0];
    for (var player in _players) {
      player.draw(5);
    }
  }

  reset() {
    var newPlayers = [];
    for (var player in _players) {
      newPlayers.add(new Player(this, player.controller));
    }
    _players = newPlayers;
    for (var player in _players) {
      player.controller.player = player;
      player.controller.reset();
    }
    trashPile = new CardBuffer();
    supply.reset();
    misc = {};
    currentPlayer = _players[0];
  }

  start() async {
    while (true) {
      await currentPlayer.takeTurn();
      if (supply.isGameOver()) break;
      currentPlayer = toLeftOf(currentPlayer);
    }
    List<Player> maxPlayers = [];
    int maxScore = -100;
    for (var player in players) {
      int score = player.calculateScore();
      log("${player.name} scored $score points");
      if (score > maxScore) {
        maxScore = score;
        maxPlayers = [player];
      } else if (score == maxScore) {
        maxPlayers.add(player);
      }
    }
    declareWinner(maxPlayers);
  }

  declareWinner(List<Player> maxPlayers) {
    if (maxPlayers.length == 1) {
      log("${maxPlayers[0].name} wins!");
    } else if (maxPlayers.length > 1) {
      var missingTurn = [];
      int currentIndex = players.indexOf(currentPlayer);
      for (Player p in maxPlayers) {
        if (players.indexOf(p) > currentIndex) missingTurn.add(p);
      }
      if (missingTurn.length == 1) {
        log("${missingTurn[0].name} wins!");
      } else if (missingTurn.length == 0) {
        print("Tie between: $maxPlayers");
      } else {
        print("Tie between: $missingTurn");
      }
    }
  }

  void log(String msg) {
    for (Player p in players) {
      p.controller.log(msg);
    }
  }

  List<Player> get players => _players;

  Player currentPlayer;

  List<Player> _players;

  Player toLeftOf(Player p) => playersAfter(p).first;

  Iterable<Player> playersFrom(Player startFrom) sync* {
    int start = _players.indexOf(startFrom);
    yield _players[start];
    int i = (start + 1) % _players.length;
    while (i != start) {
      yield _players[i];
      i = (i + 1) % _players.length;
    }
  }

  Iterable<Player> playersAfter(Player startFrom) sync* {
    int start = _players.indexOf(startFrom);
    int i = (start + 1) % _players.length;
    while (i != start) {
      yield _players[i];
      i = (i + 1) % _players.length;
    }
  }
}

class Player extends Object with CardSource {
  DominionEngine engine;
  PlayerController controller;

  /// used by various cards to attach data to a particular player
  Map misc = {};

  String get name => controller.name;

  Player(this.engine, this.controller) {
    deck = new CardBuffer();
    for (int i = 0; i < 3; i++) deck.receive(Estate.instance);
    for (int i = 0; i < 7; i++) deck.receive(Copper.instance);
    deck.shuffle();
    hand = new CardBuffer();
    discarded = new CardBuffer();
  }

  Future<Card> selectCardToGain({CardConditions conditions, bool allowNone: false}) {
    if (conditions == null) conditions = new CardConditions();
    return controller.selectCardFromSupply(EventType.GainCard, conditions, allowNone);
  }

  Future<Card> selectCardToBuy({CardConditions conditions, bool allowNone: true}) {
    if (conditions == null) conditions = new CardConditions();
    return controller.selectCardFromSupply(EventType.BuyCard, conditions, allowNone);
  }

  bool hasActions() {
    for (int i = 0; i < hand.length; i++) {
      if (hand[i] is ActionCard) return true;
    }
    return false;
  }

  bool hasTreasures() {
    for (int i = 0; i < hand.length; i++) {
      if (hand[i] is TreasureCard) return true;
    }
    return false;
  }

  log(String msg, [String type='everyone']) {
    if (type == 'player') {
      controller.log(msg);
    } else if (type == 'others') {
      for (var player in engine.playersAfter(this)) {
        player.controller.log(msg);
      }
    } else {
      engine.log(msg);
    }
  }

  notify(String msg) => log(msg, 'player');
  announce(String msg) => log("$name $msg", 'others');
  announceAll(String msg) => log("$name $msg", 'everyone');

  Future playAction(ActionCard card) async {
    hand.moveTo(card, turn.played);
    turn.actions -= 1;
    turn.actionsPlayed += 1;
    notify("You play a $card");
    announce("plays a $card");
    await card.onPlay(this);
  }

  Future playTreasure(TreasureCard card) async {
    hand.moveTo(card, turn.played);
    await card.onPlay(this);
  }

  Future takeTurn() async {
    turn = new Turn();
    notify("It's your turn!");
    announce("starts turn");
    // play actions
    while (turn.actions > 0 && hasActions()) {
      ActionCard actionCard = await controller.selectActionCard();
      if (actionCard == null) break;
      await playAction(actionCard);
    }
    turn.phase = Phase.Buy;
    // play treasures
    while (hasTreasures()) {
      List<TreasureCard> treasures = await controller.selectTreasureCards();
      if (treasures.length == 0) break;
      for (TreasureCard treasure in treasures) {
        await playTreasure(treasure);
      }
    }
    // buy cards
    while (turn.buys > 0) {
      CardConditions conds = new CardConditions()..maxCost = turn.coins;
      Card toBuy = await selectCardToBuy(conditions: conds);
      if (toBuy == null) break;
      await buy(toBuy);
    }
    turn.phase = Phase.Cleanup;
    // cleanup
    List<Card> cleanedUp = [];
    while (turn.played.length > 0) {
      cleanedUp.add(turn.played.drawTo(discarded));
    }
    while (hand.length > 0) {
      cleanedUp.add(hand.drawTo(discarded));
    }
    for (Card card in cleanedUp) {
      await card.onDiscard(this, cleanup: true, cleanedUp: cleanedUp);
    }
    turn = null;
    draw(5);
    notify("Your turn ends");
    announce("ends turn");
  }

  int calculateScore() {
    int score = 0;
    List<CardBuffer> buffers = [deck, hand, discarded];
    if (turn != null) buffers.add(turn.played);
    for (CardBuffer buffer in buffers) {
      for (int i = 0; i < buffer.length; i++) {
        if (buffer[i] is VPCard) {
          score += buffer[i].getVictoryPoints(this);
        }
      }
    }
    // TODO Add VP tokens
    return score;
  }

  // return true if event is blocked
  Future<bool> reactTo(EventType event, Card context) async {
    bool blocked = false;
    List<Reaction> revealed = [];
    while (true) {
      List options = [];
      for (int i = 0; i < hand.length; i++) {
        if (!revealed.contains(hand[i]) && hand[i] is Reaction && hand[i].canReactTo(event)) {
          options.add(hand[i]);
        }
      }
      if (options.length == 0) return blocked;
      options.add("None");
      var response =
          await controller.askQuestion(context, "Select a Reaction card to reveal.", options);
      if (response is Reaction) {
        notify("You reveal $response");
        announce("reveals $response");
        revealed.add(response);
        bool result = await response.onReact(this);
        if (result) blocked = true;
      } else {
        return blocked;
      }
    }
  }

  Future discard(Card card) => discardFrom(hand, card);

  Future discardFrom(CardSource source, [Card card = null]) async {
    if (card == null) {
      card = source.drawTo(discarded);
    } else {
      source.moveTo(card, discarded);
    }
    await card.onDiscard(this);
  }

  /// Ambiguous for Player
  bool remove(Card card) => false;

  /// Removes card from top of deck
  Card removeTop() {
    Card deckTop = deck.removeTop();
    if (deckTop == null) {
      discarded.shuffle();
      discarded.dumpTo(deck);
      return deck.removeTop();
    }
    return deckTop;
  }

  Card draw([int numCards = 1]) {
    Card card;
    for (int i = 0; i < numCards; i++) {
      card = drawTo(hand);
      if (card == null) {
        notify("You draw $i ${cardWord(i)}");
          notify("draws $i ${cardWord(i)}");
        return null;
      }
    }
    notify("You draw $numCards ${cardWord(numCards)}");
    announce("draws $numCards ${cardWord(numCards)}");
    return card;
  }

  List<Card> getAllCards() {
    List<Card> cards = [];
    cards.addAll(deck.asList());
    cards.addAll(hand.asList());
    cards.addAll(discarded.asList());
    if (turn != null) {
      cards.addAll(turn.played.asList());
    }
    return cards;
  }

  Future<Card> trashDraw(CardSource source) async {
    // hooks of some sort
    Card card = source.drawTo(engine.trashPile);
    notify("You trash a $card");
    announce("trashes a $card");
    return card;
  }

  Future<bool> trashFrom(Card card, CardSource source) async {
    // hooks of some sort
    bool result = source.moveTo(card, engine.trashPile);
    notify("You trash a $card");
    announce("trashes a $card");
    return result;
  }

  Future<bool> gain(Card card) async {
    bool result = await engine.supply.gain(card, this);
    if (result) {
      var remain = "${engine.supply.supplyOf(card).count} remain";
      notify("You gain a $card. $remain");
      announce("gains a $card. $remain");
    } else {
      notify("$card cannot be gained!");
    }
    return result;
  }

  Future<bool> buy(Card card) async {
    bool result = await engine.supply.buy(card, this);
    if (!result) return false;
    if (result) {
      var remain = "${engine.supply.supplyOf(card).count} remain";
      notify("You buy a $card. $remain");
      announce("buys a $card. $remain");
    } else {
      notify("$card cannot be bought!");
    }
    return result;
  }

  CardBuffer deck;
  CardBuffer hand;
  CardBuffer discarded;

  Turn turn = null;
}

class Supply {
  Map<Card, SupplySource> _supplies;

  Iterable<Card> _kc;
  int _pc;
  bool _eb;

  Supply(Iterable<Card> kingdomCards, int playerCount, bool expensiveBasics) {
    _kc = kingdomCards;
    _pc = playerCount;
    _eb = expensiveBasics;
    _setup(_kc, _pc, _eb);
  }

  _setup(Iterable<Card> kingdomCards, int playerCount, bool expensiveBasics) {
    _supplies = {};
    var cards = [
      Copper.instance,
      Silver.instance,
      Gold.instance,
      Estate.instance,
      Duchy.instance,
      Province.instance,
      Curse.instance
    ];
    if (expensiveBasics) {
      cards.add(Platinum.instance);
      cards.add(Colony.instance);
    }
    bool addPotions = false;
    for (Card k in kingdomCards) {
      if (k.requiresPotion) addPotions = true;
      cards.add(k);
    }
    if (addPotions) cards.add(Potion.instance);
    for (Card c in cards) {
      _supplies[c] = new SupplySource(c, c.supplyCount(playerCount));
    }
  }

  SupplySource supplyOf(Card card) => _supplies[card];

  Iterable<Card> get cardsInSupply => _supplies.keys;

  reset() => _setup(_kc, _pc, _eb);

  Future<bool> gain(Card card, Player player) async {
    Card result = supplyOf(card).drawTo(player.discarded);
    if (result == null) return false;
    await card.onGain(player, false);
    return true;
  }

  Future<bool> buy(Card card, Player player) async {
    int cost = card.calculateCost(player.turn);
    bool notEnoughPotions = card.requiresPotion && player.turn.potions < 1;
    if (player.turn.buys < 1 || player.turn.coins < cost || notEnoughPotions) {
      return false;
    }
    Card result = supplyOf(card).drawTo(player.discarded);
    if (result == null) return false;
    player.turn.buys -= 1;
    player.turn.coins -= cost;
    if (card.requiresPotion) {
      player.turn.potions -= 1;
    }
    await card.onGain(player, true);
    return true;
  }

  bool isGameOver() {
    if (supplyOf(Province.instance).count == 0) return true;
    if (_eb && supplyOf(Colony.instance).count == 0) return true;
    int empty = 0;
    for (Card c in cardsInSupply) {
      if (supplyOf(c).count == 0) empty++;
    }
    return empty >= 4 || (_pc < 5 && empty >= 3);
  }
}
