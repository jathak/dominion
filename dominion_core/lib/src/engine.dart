part of dominion_core;

class DominionEngine {
  CardBuffer trashPile = CardBuffer();
  Supply supply;

  bool gameOver = false;

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

  DominionEngine._(this.supply);

  Map<String, dynamic> serialize() => {
        'type': 'Engine',
        'currentPlayer': _players.indexOf(currentPlayer),
        'players': [for (var player in players) player.serialize()],
        'supply': supply.serialize(),
        'trashPile': trashPile.serialize(),
        'gameOver': gameOver
      };

  static DominionEngine deserialize(data, List<PlayerController> controllers,
      Mat pirateShipDeserializer(data)) {
    var engine = DominionEngine._(Supply.deserialize(data['supply']));
    if (controllers.length != data['players']?.length) {
      throw Exception("Invalid serialized game! "
          "Expected ${controllers.length} players, "
          "got ${data['players']?.length}");
    }
    engine._players = [
      for (var i = 0; i < controllers.length; i++)
        Player.deserialize(
            data['players'][i], engine, controllers[i], pirateShipDeserializer)
    ];
    engine.currentPlayer = engine._players[data['currentPlayer']];
    engine.trashPile = CardBuffer.deserialize(data['trashPile']);
    engine.gameOver = data['gameOver'];
    return engine;
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
    currentPlayer = _players[0];
  }

  Future Function() saveGame = () async => null;

  start({bool skipInitialSave = false}) async {
    while (true) {
      if (!skipInitialSave) await saveGame();
      skipInitialSave = false;
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
    await saveGame();
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
        log("Tie between ${maxPlayers.map((p) => p.name).toList()}");
      } else {
        log("Tie between ${missingTurn.map((p) => p.name).toList()}");
      }
    }
    gameOver = true;
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
      var blocked = await player.reactToAttack(context);
      if (!blocked) yield player;
    }
  }
}

class Player extends Object with CardSource {
  DominionEngine engine;
  PlayerController controller;

  String get name => controller.name;

  Player(this.engine, this.controller) {
    deck = Deck();
    for (int i = 0; i < 3; i++) deck.receive(Estate.instance);
    for (int i = 0; i < 7; i++) deck.receive(Copper.instance);
    deck.shuffle();
    hand = CardBuffer();
    discarded = CardBuffer();
    inPlay = InPlayBuffer();
  }

  Player._(this.engine, this.controller);

  Future<Card> selectCardToGain(
      {@required Card context,
      CardConditions conditions,
      bool optional: false}) {
    conditions ??= CardConditions();
    conditions.mustBeAvailable = true;
    return controller.selectCardFromSupply(
        "Select a card to gain", EventType.GainCard,
        context: context, conditions: conditions, optional: optional);
  }

  Future<Card> selectCardToBuy() =>
      controller.selectCardFromSupply("Select a card to buy", EventType.BuyCard,
          context: null, conditions: turn.buyConditions, optional: true);

  /// Prompts the user to discard cards from their hand.
  Future<List<Card>> discardFromHand(
      {@required Card context,
      CardConditions conditions,
      EventType event,
      int min: 0,
      int max}) async {
    var cards = await controller.selectCardsFromHand("Select cards to discard",
        context: context,
        conditions: conditions,
        event: event,
        min: min,
        max: max);
    await discardAll(cards);
    return cards;
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
    var nextTurnAction = await play(card);
    if (nextTurnAction != null) inPlay.actions[index] = nextTurnAction;
    return index;
  }

  Future<int> playTreasure(Treasure card, {CardSource from}) async {
    if (from == null) from = hand;
    from.remove(card);
    var index = inPlay.receive(card);
    var nextTurnAction = await play(card);
    if (nextTurnAction != null) inPlay.actions[index] = nextTurnAction;
    return index;
  }

  Future<NextTurn> play(Card card) async {
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
      Action actionCard =
          await controller.selectActionCard(event: EventType.ActionPhase);
      if (actionCard == null) break;
      await playAction(actionCard);
      log(null);
    }
    turn.phase = Phase.Buy;
    // play treasures
    while (hasTreasures()) {
      List<Treasure> treasures =
          await controller.selectTreasureCards(event: EventType.BuyPhase);
      if (treasures.length == 0) break;
      for (Treasure treasure in treasures) {
        await playTreasure(treasure);
        log(null);
      }
    }
    // buy cards
    while (turn.buys > 0) {
      turn.buyConditions.maxCost = turn.coins;
      var toBuy = await selectCardToBuy();
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
    int score = vpTokens;
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
    return score;
  }

  // return true if event is blocked
  Future<bool> reactToAttack(Card context) async {
    var blocked = inPlay.toList().any((card) => card.protectsFromAttacks);
    while (true) {
      var options = <Reaction>[];
      for (var card in hand.toList()) {
        if (card is Reaction &&
            card.canReactTo(EventType.Attack, context, this)) {
          options.add(card);
        }
      }
      if (options.length == 0) return blocked;
      var response = await controller.selectCardFrom(
          options, "Select a Reaction card to reveal?",
          context: context, event: EventType.Reaction, optional: true);
      if (response == null) return blocked;
      notifyAnnounce("You reveal", "reveals", "a $response");
      if (await response.onReactToAttack(this, context)) {
        blocked = true;
      }
    }
  }

  Future reactToGain(Card card, CardSource location, bool bought) async {
    while (true) {
      var options = <Reaction>[];
      for (var card in hand.toList()) {
        if (card is Reaction &&
            card.canReactTo(
                bought ? EventType.BuyCard : EventType.GainCard, card, this)) {
          options.add(card);
        }
      }
      if (options.length == 0) return location;
      var response = await controller.selectCardFrom(
          options, "Select a Reaction card to reveal?",
          context: card, event: EventType.Reaction, optional: true);
      if (response == null) return location;
      notifyAnnounce("You reveal", "reveals", "a $response");
      location = await response.onReactToGain(this, card, location, bought);
    }
  }

  // Discards [card] from the player's hand.
  Future discard(Card card) => discardFrom(hand, card);

  // Discards [cards] from the player's hand.
  Future discardAll(List<Card> cards) async {
    for (var card in cards) {
      await discard(card);
    }
  }

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
    cards.addAll(deck.toList());
    cards.addAll(hand.toList());
    cards.addAll(discarded.toList());
    cards.addAll(inPlay.toList());
    mats.values.map((mat) => mat.buffer.toList()).forEach(cards.addAll);
    return cards;
  }

  Future<Card> trashDraw(CardSource source) async {
    // hooks of some sort
    Card card = source.drawTo(engine.trashPile);
    if (card != null) notifyAnnounce("You trash", "trashes", "a $card");
    return card;
  }

  Future<bool> trashFrom(Card card, CardSource source) async {
    // hooks of some sort
    bool result = source.moveTo(card, engine.trashPile);
    if (result) notifyAnnounce("You trash", "trashes", "a $card");
    return result;
  }

  Future<bool> gain(Card card, {CardSourceAndTarget to}) async {
    bool result = await engine.supply.gain(card, this, to ?? discarded);
    if (result) {
      turn?.gained?.add(card);
      var location = await reactToGain(card, to, false);
      for (var card in inPlay.toList()) {
        if (card is GainListener) {
          location = card.onGainCardWhileInPlay(this, card, location, false);
        }
      }
      var remain = "${engine.supply.supplyOf(card).count} remain";
      notifyAnnounce("You gain", "gains", "a $card. $remain");
    } else {
      notify("$card cannot be gained!");
    }
    return result;
  }

  Future<bool> buy(Card card, {CardSourceAndTarget to}) async {
    bool result = await engine.supply.buy(card, this, to ?? discarded);
    if (!result) return false;
    if (result) {
      turn?.bought?.add(card);
      turn?.gained?.add(card);
      var location = await reactToGain(card, to, true);
      for (var card in inPlay.toList()) {
        if (card is GainListener) {
          location = card.onGainCardWhileInPlay(this, card, location, true);
        }
      }
      var remain = "${engine.supply.supplyOf(card).count} remain";
      notifyAnnounce("You buy", "buys", "a $card. $remain");
    } else {
      notify("$card cannot be bought!");
    }
    return result;
  }

  Deck deck;
  CardBuffer hand;
  CardBuffer discarded;
  InPlayBuffer inPlay;

  int vpTokens = 0;

  Turn turn;
  TurnStub lastTurn;

  bool takeOutpostTurn = false;

  Map<Card, Mat> mats = {};

  Map<String, dynamic> serializeMats() =>
      {for (var card in mats.keys) card.name: mats[card].serialize()};

  static Map<Card, Mat> deserializeMats(
          data, Mat pirateShipDeserializer(data)) =>
      {
        for (var cardName in data.keys)
          CardRegistry.find(cardName):
              (data[cardName]['type'] == 'PirateShipMat'
                  ? pirateShipDeserializer(data[cardName])
                  : Mat.deserialize(data))
      };

  /// Serialize this player (only valid between turns)
  Map<String, dynamic> serialize() => {
        'type': 'Player',
        'name': name,
        'deck': deck.serialize(),
        'hand': hand.serialize(),
        'discarded': discarded.serialize(),
        'inPlay': inPlay.serialize(),
        'vpTokens': vpTokens,
        'lastTurn': lastTurn?.serialize(),
        'takeOutpostTurn': takeOutpostTurn,
        'mats': serializeMats()
      };

  static Player deserialize(data, DominionEngine engine,
      PlayerController controller, Mat pirateShipDeserializer(data)) {
    var player = Player._(engine, controller);
    controller.player = player;
    return player
      ..deck = Deck.deserialize(data['deck'])
      ..hand = CardBuffer.deserialize(data['hand'])
      ..discarded = CardBuffer.deserialize(data['discarded'])
      ..inPlay = InPlayBuffer.deserialize(data['inPlay'], player)
      ..vpTokens = data['vpTokens']
      ..lastTurn = data['lastTurn'] == null
          ? null
          : TurnStub.deserialize(data['lastTurn'])
      ..takeOutpostTurn = data['takeOutpostTurn']
      ..mats = deserializeMats(data['mats'], pirateShipDeserializer);
  }
}

class Supply {
  Map<Card, SupplyPile> _supplies;

  Iterable<Card> _kingdomCards;
  int _playerCount;
  bool _expensiveBasics;

  Supply(Iterable<Card> kingdomCards, int playerCount, bool expensiveBasics) {
    _kingdomCards = kingdomCards;
    _playerCount = playerCount;
    _expensiveBasics = expensiveBasics;
    _setup(_kingdomCards, _playerCount, _expensiveBasics);
  }

  Supply._();

  _setup(Iterable<Card> kingdomCards, int playerCount, bool expensiveBasics) {
    _supplies = Map.fromEntries([
      Copper.instance,
      Silver.instance,
      Gold.instance,
      if (expensiveBasics) Platinum.instance,
      if (kingdomCards.where((card) => card.requiresPotion).isNotEmpty)
        Potion.instance,
      Estate.instance,
      Duchy.instance,
      Province.instance,
      if (expensiveBasics) Colony.instance,
      Curse.instance,
      ...kingdomCards
    ].map((card) =>
        MapEntry(card, SupplyPile(card, card.supplyCount(playerCount)))));
  }

  SupplyPile supplyOf(Card card) => _supplies[card];

  Iterable<Card> get cardsInSupply => _supplies.keys;

  reset() => _setup(_kingdomCards, _playerCount, _expensiveBasics);

  Future<bool> gain(Card card, Player player, CardTarget location) async {
    Card result = supplyOf(card).drawTo(location);
    if (result == null) return false;
    await card.onGain(player, false);
    return true;
  }

  Future<bool> buy(Card card, Player player, CardTarget location) async {
    int cost = card.calculateCost(player);
    bool notEnoughPotions = card.requiresPotion && player.turn.potions < 1;
    if (player.turn.buys < 1 || player.turn.coins < cost || notEnoughPotions) {
      return false;
    }
    if (!card.buyable(player)) return false;
    Card result = supplyOf(card).drawTo(location);
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

  Map<String, dynamic> serialize({Player includeCostFor}) => {
        'type': 'Supply',
        'supplies': {
          for (var card in _supplies.keys)
            card.name: _supplies[card].serialize(includeCostFor: includeCostFor)
        },
        'kingdomCards': _kingdomCards.map((card) => card.name).toList(),
        'playerCount': _playerCount,
        'expensiveBasics': _expensiveBasics,
      };

  static Supply deserialize(data) => Supply._()
    .._supplies = {
      for (var name in data['supplies'].keys)
        CardRegistry.find(name): SupplyPile.deserialize(data['supplies'][name])
    }
    .._kingdomCards = [
      for (var name in data['kingdomCards']) CardRegistry.find(name)
    ]
    .._playerCount = data['playerCount']
    .._expensiveBasics = data['expensiveBasics'];
}
