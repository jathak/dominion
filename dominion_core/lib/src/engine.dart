part of dominion_core;

class DominionEngine {
  CardBuffer trashPile = CardBuffer();
  Supply supply;

  /// used by various cards to attach data to the entire game
  Map misc = {};

  DominionEngine(this.supply, List<PlayerController> controllers) {
    _players = [];
    for (var pc in controllers) {
      _players.add(Player(this, pc));
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
      newPlayers.add(Player(this, player.controller));
    }
    _players = newPlayers;
    for (var player in _players) {
      player.controller.player = player;
      player.controller.reset();
    }
    trashPile = CardBuffer();
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

  Function onLog;

  void log(String msg) {
    if (onLog != null) onLog(msg);
    for (Player p in players) {
      p.controller.log(msg);
    }
  }

  List<Player> get players => _players;

  Player currentPlayer;

  List<Player> _players;

  Player toLeftOf(Player p) => playersAfter(p).first;
  Player toRightOf(Player p) => playersAfter(p).last;

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

  Stream<Player> attackablePlayers(Player attacker, Card context) async* {
    for (var player in playersAfter(attacker)) {
      var blocked = await player.reactTo(EventType.Attack, context);
      if (!blocked) yield player;
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
    deck = CardBuffer();
    for (int i = 0; i < 3; i++) deck.receive(Estate.instance);
    for (int i = 0; i < 7; i++) deck.receive(Copper.instance);
    deck.shuffle();
    hand = CardBuffer();
    discarded = CardBuffer();
    inPlay = InPlayBuffer();
  }

  Future<Card> selectCardToGain(
      {CardConditions conditions, bool allowNone: false}) {
    if (conditions == null) conditions = CardConditions();
    return controller.selectCardFromSupply(
        EventType.GainCard, conditions, allowNone);
  }

  Future<Card> selectCardToBuy(
      {CardConditions conditions, bool allowNone: true}) {
    if (conditions == null) conditions = CardConditions();
    return controller.selectCardFromSupply(
        EventType.BuyCard, conditions, allowNone);
  }

  bool hasActions() {
    for (int i = 0; i < hand.length; i++) {
      if (hand[i] is Action) return true;
    }
    return false;
  }

  bool hasTreasures() {
    for (int i = 0; i < hand.length; i++) {
      if (hand[i] is Treasure) return true;
    }
    return false;
  }

  log(String msg, [String type = 'everyone']) {
    if (type == 'player') {
      controller.log(msg);
    } else if (type == 'others') {
      if (engine.onLog != null) engine.onLog(msg);
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

  notifyAnnounce(String playerOnly, String othersOnly, [both = ""]) {
    notify("$playerOnly $both");
    announce("$othersOnly $both");
  }

  Future<int> playAction(Action card, {CardSource from}) async {
    if (from == null) from = hand;
    from.remove(card);
    turn.actions -= 1;
    var index = inPlay.receive(card);
    var forNextTurn = await play(card);
    if (forNextTurn != null) inPlay.nextTurn[index] = forNextTurn;
    return index;
  }

  Future<int> playTreasure(Treasure card, {CardSource from}) async {
    if (from == null) from = hand;
    from.remove(card);
    var index = inPlay.receive(card);
    var forNextTurn = await play(card);
    if (forNextTurn != null) inPlay.nextTurn[index] = forNextTurn;
    return index;
  }

  Future<ForNextTurn> play(Card card) async {
    turn.playCounts[card] = turn.playCount(card) + 1;
    for (var listener in turn.playListeners) {
      await listener(card);
    }
    return await card.onPlayCanPersist(this);
  }

  Future takeTurn() async {
    turn = Turn();
    bool takingOutpostTurn = takeOutpostTurn;
    notifyAnnounce("It's your turn!", "starts turn");
    // Run next turn actions for durations
    await inPlay.runNextTurnActions();

    // play actions
    while (turn.actions > 0 && hasActions()) {
      Action actionCard = await controller.selectActionCard();
      if (actionCard == null) break;
      await playAction(actionCard);
      log(null);
    }
    turn.phase = Phase.Buy;
    // play treasures
    while (hasTreasures()) {
      List<Treasure> treasures = await controller.selectTreasureCards();
      if (treasures.length == 0) break;
      for (Treasure treasure in treasures) {
        await playTreasure(treasure);
        log(null);
      }
    }
    // buy cards
    while (turn.buys > 0) {
      CardConditions conds = CardConditions()..maxCost = turn.coins;
      Card toBuy = await selectCardToBuy(conditions: conds);
      if (toBuy == null) break;
      await buy(toBuy);
    }
    turn.phase = Phase.Cleanup;
    // cleanup
    await inPlay.cleanup(this);
    lastTurn = turn;
    turn = null;
    if (takeOutpostTurn && !takingOutpostTurn) {
      draw(3);
      notifyAnnounce("Your turn ends", "ends turn");
      await takeTurn();
    } else {
      draw(5);
      notifyAnnounce("Your turn ends", "ends turn");
      takeOutpostTurn = false;
    }
  }

  int calculateScore() {
    int score = 0;
    var buffers = [
      deck,
      hand,
      discarded,
      inPlay,
      for (var mat in mats.values) mat.buffer
    ];
    for (CardBuffer buffer in buffers) {
      for (int i = 0; i < buffer.length; i++) {
        if (buffer[i] is VictoryOrCurse) {
          score += buffer[i].getVictoryPoints(this);
        }
      }
    }
    // TODO Add VP tokens
    return score;
  }

  // return true if event is blocked
  Future<bool> reactTo(EventType event, Card context) async {
    var blocked = inPlay.asList().any((card) => card.protectsFromAttacks);
    while (true) {
      var options = [];
      for (var card in hand.asList()) {
        if (card is Reaction && card.canReactTo(event, context, this)) {
          options.add(card);
        }
      }
      if (options.length == 0) return blocked;
      options.add("None");
      var response = await controller.askQuestion(
          context, "Select a Reaction card to reveal.", options);
      if (response is Reaction) {
        notifyAnnounce("You reveal", "reveals", "a $response");
        bool result = await response.onReact(this);
        if (result) blocked = true;
      } else {
        return blocked;
      }
    }
  }

  // Discards [card] from the player's hand.
  Future discard(Card card) => discardFrom(hand, card);

  // Discards a card from [source].
  Future discardFrom(CardSource source, [Card card = null]) async {
    if (card == null) {
      card = source.drawTo(discarded);
    } else {
      source.moveTo(card, discarded);
    }
    notifyAnnounce("You discard", "discards", "a $card");
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
        notifyAnnounce("You draw", "draws", "$i ${cardWord(i)}");
        return null;
      }
    }
    notifyAnnounce("You draw", "draws", "$numCards ${cardWord(numCards)}");
    return card;
  }

  List<Card> getAllCards() {
    List<Card> cards = [];
    cards.addAll(deck.asList());
    cards.addAll(hand.asList());
    cards.addAll(discarded.asList());
    cards.addAll(inPlay.asList());
    mats.values.map((mat) => mat.buffer.asList()).forEach(cards.addAll);
    return cards;
  }

  Future<Card> trashDraw(CardSource source) async {
    // hooks of some sort
    Card card = source.drawTo(engine.trashPile);
    notifyAnnounce("You trash", "trashes", "a $card");
    return card;
  }

  Future<bool> trashFrom(Card card, CardSource source) async {
    // hooks of some sort
    bool result = source.moveTo(card, engine.trashPile);
    notifyAnnounce("You trash", "trashes", "a $card");
    return result;
  }

  Future<bool> gain(Card card) async {
    bool result = await engine.supply.gain(card, this);
    if (result) {
      turn.gained.add(card);
      var remain = "${engine.supply.supplyOf(card).count} remain";
      notifyAnnounce("You gain", "gains", "a $card. $remain");
    } else {
      notify("$card cannot be gained!");
    }
    return result;
  }

  Future<bool> buy(Card card) async {
    bool result = await engine.supply.buy(card, this);
    if (!result) return false;
    if (result) {
      turn.bought.add(card);
      turn.gained.add(card);
      var remain = "${engine.supply.supplyOf(card).count} remain";
      notifyAnnounce("You buy", "buys", "a $card. $remain");
    } else {
      notify("$card cannot be bought!");
    }
    return result;
  }

  CardBuffer deck;
  CardBuffer hand;
  CardBuffer discarded;
  InPlayBuffer inPlay;

  Turn turn;
  Turn lastTurn;

  bool takeOutpostTurn = false;

  final mats = <Card, Mat>{};
}

class Supply {
  Map<Card, SupplySource> _supplies;

  Iterable<Card> _kingdomCards;
  int _playerCount;
  bool _expensiveBasics;

  Supply(Iterable<Card> kingdomCards, int playerCount, bool expensiveBasics) {
    _kingdomCards = kingdomCards;
    _playerCount = playerCount;
    _expensiveBasics = expensiveBasics;
    _setup(_kingdomCards, _playerCount, _expensiveBasics);
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
      _supplies[c] = SupplySource(c, c.supplyCount(playerCount));
    }
  }

  SupplySource supplyOf(Card card) => _supplies[card];

  Iterable<Card> get cardsInSupply => _supplies.keys;

  reset() => _setup(_kingdomCards, _playerCount, _expensiveBasics);

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
    for (int i = 0; i < supplyOf(card).embargoTokens; i++) {
      await player.gain(Curse.instance);
    }
    player.turn.buys -= 1;
    player.turn.coins -= cost;
    if (card.requiresPotion) {
      player.turn.potions -= 1;
    }
    await card.onGain(player, true);
    return true;
  }

  int get emptyPiles =>
      cardsInSupply.where((card) => supplyOf(card).count == 0).length;

  bool isGameOver([engine = null]) {
    if (supplyOf(Province.instance).count == 0) {
      engine?.log("All Provinces are gone!");
      return true;
    }
    if (_expensiveBasics && supplyOf(Colony.instance).count == 0) {
      engine?.log("All Colonies are gone!");
      return true;
    }
    int empty = emptyPiles;
    if (_playerCount < 5 && empty >= 3) {
      engine?.log("Three supplies are empty!");
      return true;
    }
    if (empty >= 4) {
      engine?.log("Four supplies are empty!");
      return true;
    }
    return false;
  }
}
