import 'dart:async';
import 'dart:convert';

import 'package:dominion_core/dominion_core.dart';
import 'package:dominion_sets/base_set.dart' show registerBaseSet;
import 'package:dominion_sets/intrigue.dart' show registerIntrigue;
import 'package:dominion_sets/seaside.dart' show registerSeaside, PirateShipMat;
import 'package:dominion_sets/prosperity.dart' show registerProsperity;

import 'package:http/http.dart' as http;

import 'src/socket.dart';

bool _registeredCards = false;

/// A client that can be used to connect to a Dominion server.
class DominionClient {
  final String _server;
  final bool _tls;
  WebSocketChannel _channel;

  String gameId;
  String username;
  PlayerController controller;

  bool get spectating => username == null;

  /// The current state of the game as exposed to this client.
  final state = GameState();

  final _logCtrl = StreamController<String>.broadcast();

  /// Stream of log messages from the game.
  Stream<String> get log => _logCtrl.stream;

  /// Constructs a new Dominion client.
  ///
  /// Server should be the domain name of the server this client should
  /// communicate with
  DominionClient(String server, {bool tls: true})
      : _server = server,
        _tls = tls {
    if (!_registeredCards) {
      registerBaseSet();
      registerIntrigue();
      registerSeaside();
      registerProsperity();
      _registeredCards = true;
    }
  }

  Future disconnect() async {
    var oldChannel = _channel;
    _channel = null;
    await oldChannel?.sink?.close();
  }

  /// Connects to the server over websockets.
  void connect() {
    _channel = socketConnect((_tls ? 'wss://' : 'ws://') + _server);
    listen() async {
      await for (var data in _channel.stream) {
        var msg = json.decode(data);
        switch (msg['type']) {
          case 'log':
            _logCtrl.add(msg['message'].toString());
            break;
          case 'supply-update':
            state.updateSupply(msg['supply']);
            if (_connectionCompleter != null &&
                !_connectionCompleter.isCompleted) {
              _connectionCompleter.complete();
            }
            break;
          case 'hand-update':
            state.currentPlayer = msg['currentPlayer'];
            state.hand = Card.deserializeList(msg['hand']);
            state.inPlay = Card.deserializeList(msg['inPlay']);
            state.deckSize = msg['deckSize'];
            state.discardSize = msg['discardSize'];
            state.vpTokens = msg['vpTokens'];
            state.mats =
                Player.deserializeMats(msg['mats'], PirateShipMat.deserialize)
                    .values
                    .toList();
            if (msg['turn'] != null) {
              var turn = msg['turn'];
              state.turn = TurnMessage(turn['actions'], turn['buys'],
                  turn['coins'], Phase.values[turn['phaseIndex']]);
            } else {
              state.turn = null;
            }
            break;
          case 'request':
            // Don't await here, since we don't want to block future messages
            // on this response
            _handleRequest(msg);
            break;
          default:
            print('$msg');
        }
      }
      if (_channel != null) connect();
    }

    listen();
  }

  void _handleRequest(msg) async {
    if (controller == null) return;
    var meta = msg['metadata'];
    var result = null;
    var context =
        meta.containsKey('context') ? Card.deserialize(meta['context']) : null;
    var event = meta.containsKey('eventIndex')
        ? EventType.values[meta['eventIndex']]
        : null;
    switch (msg['request']) {
      case 'askQuestion':
        result = await controller.askQuestion(meta['question'], meta['options'],
            context: context, event: event);
        break;
      case 'selectCardsFrom':
        result = (await controller.selectCardsFrom(
                Card.deserializeList(['cards']), meta['question'],
                context: context,
                event: event,
                min: meta['min'],
                max: meta['max']))
            .map((card) => card.name)
            .toList();
        break;
    }
    _sendMessage({
      'type': 'request-response',
      'response': result,
      'request-id': msg['request-id']
    });
  }

  void _sendMessage(msg) {
    if (_channel == null) connect();
    _channel.sink.add(json.encode(msg));
  }

  /// Sends a request to the server to create a new game, returning the game ID.
  Future<String> createGame(List<Card> kingdomCards,
      {bool useProsperity: false}) async {
    var kingdom = Uri.encodeQueryComponent(kingdomCards.join("\n"));
    var request = http.Request(
        'GET',
        Uri.parse("http${_tls ? 's' : ''}://$_server/create-game?kingdomCards="
            "$kingdom${useProsperity ? '&useProsperity=on' : ''}"));
    request.followRedirects = false;
    var response = await request.send();
    return Uri.parse(response.headers['location']).queryParameters['id'];
  }

  Completer _connectionCompleter;
  Future get _connection {
    if (_connectionCompleter != null && !_connectionCompleter.isCompleted) {
      _connectionCompleter.completeError(null);
    }
    _connectionCompleter = Completer();
    return _connectionCompleter.future;
  }

  /// Connects the client to a game as a spectator.
  Future startSpectating(String gameId) async {
    this.gameId = gameId;
    username = null;
    _sendMessage({'type': 'spectate-game', 'game-id': gameId});
    await _connection;
  }

  /// Connects this client to a game as [username].
  ///
  /// Note: The only methods that will ever be called on [controller] are
  /// `askQuestion` and `selectCardsFrom`
  Future joinGame(
      String username, String gameId, PlayerController controller) async {
    this.gameId = gameId;
    this.username = username;
    this.controller = controller;
    _sendMessage(
        {'type': 'join-game', 'game-id': gameId, 'username': username});
    await _connection;
  }
}

/// Contains information about the game's state provided to the client.
/// Users can listen for when certain properties of subproperties change.
class GameState {
  Supply _supply;
  var _supplyData;
  Supply get supply => _supply;

  final _supplyCtrl = StreamController<Supply>();
  final _supplyCountCtrl = <Card, StreamController<int>>{};
  final _supplyCostCtrl = <Card, StreamController<int>>{};
  final _supplyEmbargoCtrl = <Card, StreamController<int>>{};
  final _supplyPileCtrl = <Card, StreamController<SupplyPile>>{};

  /// Triggers when the set of cards in the supply changes.
  Stream<Supply> get onSupplyChange => _supplyCtrl.stream;

  /// Triggers when the number of [card] in the supply changes.
  ///
  /// This will not trigger if `onSupplyChange` fired for this event.
  Stream<int> onSupplyCountChange(Card card) {
    _supplyCountCtrl.putIfAbsent(card, () => StreamController.broadcast());
    return _supplyCountCtrl[card].stream;
  }

  /// Triggers when the cost of [card] changes.
  ///
  /// This will not trigger if `onSupplyChange` fired for this event.
  Stream<int> onCardCostChange(Card card) {
    _supplyCostCtrl.putIfAbsent(card, () => StreamController.broadcast());
    return _supplyCostCtrl[card].stream;
  }

  /// Triggers when the number of embargo tokens on [card] changes.
  ///
  /// This will not trigger if `onSupplyChange` fired for this event.
  Stream<int> onSupplyEmbargoChange(Card card) {
    _supplyEmbargoCtrl.putIfAbsent(card, () => StreamController.broadcast());
    return _supplyEmbargoCtrl[card].stream;
  }

  /// Triggers when any property of a supply pile changes.
  ///
  /// This will not trigger if `onSupplyChange` fired for this event.
  Stream<SupplyPile> onSupplyPileChange(Card card) {
    _supplyPileCtrl.putIfAbsent(card, () => StreamController.broadcast());
    return _supplyPileCtrl[card].stream;
  }

  /// Updates the supply from a serialized Supply.
  void updateSupply(data) {
    var newSupply = Supply.deserialize(data);
    if (_supply == null ||
        !_jsonEqual(data['kingdomCards'], _supplyData['kingdomCards']) ||
        data['playerCount'] != _supplyData['playerCount'] ||
        data['expensiveBasics'] != _supplyData['expensiveBasics']) {
      _supply = newSupply;
      _supplyData = data;
      _supplyCtrl.add(newSupply);
      return;
    }
    for (var card in newSupply.cardsInSupply) {
      var newPile = newSupply.supplyOf(card);
      var oldPile = _supply.supplyOf(card);
      if (oldPile == null) {
        _supply = newSupply;
        _supplyData = data;
        _supplyCtrl.add(newSupply);
        return;
      }
      bool changed = oldPile.used != newPile.used;
      if (oldPile.count != newPile.count) {
        changed = true;
        oldPile.count = newPile.count;
        _supplyCountCtrl[card]?.add(newPile.count);
      }
      if (oldPile.currentCost != newPile.currentCost) {
        changed = true;
        oldPile.currentCost = newPile.currentCost;
        _supplyCostCtrl[card]?.add(newPile.currentCost);
      }
      if (oldPile.embargoTokens != newPile.embargoTokens) {
        changed = true;
        oldPile.embargoTokens = newPile.embargoTokens;
        _supplyEmbargoCtrl[card]?.add(newPile.embargoTokens);
      }
      oldPile.used = newPile.used;
      if (changed) _supplyPileCtrl[card]?.add(oldPile);
    }
    _supplyData = data;
  }

  String _currentPlayer;

  /// The username of the player whose turn it currently is.
  String get currentPlayer => _currentPlayer;
  final _currentPlayerChangeCtrl = StreamController<String>.broadcast();
  Stream<String> get onCurrentPlayerChange => _currentPlayerChangeCtrl.stream;
  void set currentPlayer(String newCurrentPlayer) {
    if (_currentPlayer == null ||
        !_jsonEqual(newCurrentPlayer, _currentPlayer)) {
      _currentPlayer = newCurrentPlayer;
      _currentPlayerChangeCtrl.add(newCurrentPlayer);
    }
  }

  List<Card> _hand;

  /// The connected user's hand, or the current player's hand if spectating.
  List<Card> get hand => _hand;
  final _handChangeCtrl = StreamController<List<Card>>.broadcast();
  Stream<List<Card>> get onHandChange => _handChangeCtrl.stream;
  void set hand(List<Card> newHand) {
    if (_hand == null || !_jsonEqual(newHand, _hand)) {
      _hand = newHand;
      _handChangeCtrl.add(newHand);
    }
  }

  List<Card> _inPlay;

  /// The cards the connected user has in play (or those of the current player
  /// if spectating).
  List<Card> get inPlay => _inPlay;
  final _inPlayChangeCtrl = StreamController<List<Card>>.broadcast();
  Stream<List<Card>> get onInPlayChange => _inPlayChangeCtrl.stream;
  void set inPlay(List<Card> newInPlay) {
    if (_hand == null || !_jsonEqual(newInPlay, _inPlay)) {
      _inPlay = newInPlay;
      _inPlayChangeCtrl.add(newInPlay);
    }
  }

  int _deckSize;

  /// The number of cards left in the connected user's deck (current player if
  /// spectating).
  int get deckSize => _deckSize;
  final _deckSizeChangeCtrl = StreamController<int>.broadcast();
  Stream<int> get onDeckSizeChange => _deckSizeChangeCtrl.stream;
  void set deckSize(int newDeckSize) {
    if (_deckSize != newDeckSize) {
      _deckSize = newDeckSize;
      _deckSizeChangeCtrl.add(newDeckSize);
    }
  }

  int _discardSize;

  /// The number of cards in the connected user's discard pile (current player
  /// if spectating).
  int get discardSize => _discardSize;
  final _discardSizeChangeCtrl = StreamController<int>.broadcast();
  Stream<int> get onDiscardSizeChange => _discardSizeChangeCtrl.stream;
  void set discardSize(int newDiscardSize) {
    if (_discardSize != newDiscardSize) {
      _discardSize = newDiscardSize;
      _discardSizeChangeCtrl.add(newDiscardSize);
    }
  }

  int _vpTokens;

  /// The connected user's VP tokens (current player if spectating).
  int get vpTokens => _vpTokens;
  final _vpTokensChangeCtrl = StreamController<int>.broadcast();
  Stream<int> get onVpTokensChange => _vpTokensChangeCtrl.stream;
  void set vpTokens(int newVpTokens) {
    if (_vpTokens != newVpTokens) {
      _vpTokens = newVpTokens;
      _vpTokensChangeCtrl.add(newVpTokens);
    }
  }

  TurnMessage _turn;

  /// The stats for the connected user's current turn (or the current turn of
  /// any player if spectating).
  ///
  /// If it is not currently the connected user's turn, this will be null.
  TurnMessage get turn => _turn;
  final _turnChangeCtrl = StreamController<TurnMessage>.broadcast();
  Stream<TurnMessage> get onTurnChange => _turnChangeCtrl.stream;
  void set turn(TurnMessage newTurn) {
    if (_turn != newTurn) {
      _turn = newTurn;
      _turnChangeCtrl.add(newTurn);
    }
  }

  List<Mat> _mats;

  /// The connected user's mats (the current player's if spectating).
  List<Mat> get mats => _mats;
  void set mats(List<Mat> newMats) {
    if (_mats == null || _mats.length != newMats.length) {
      _mats = newMats;
      _matsCtrl.add(newMats);
      return;
    }
    for (var i = 0; i < _mats.length; i++) {
      if (_mats[i] != newMats[i]) {
        _mats[i] = newMats[i];
        _matCtrl[i].add(newMats[i]);
      }
    }
  }

  final _matsCtrl = StreamController<List<Mat>>.broadcast();
  final _matCtrl = <int, StreamController<Mat>>{};

  /// Triggers when the number of mats in [mats] changes.
  Stream<List<Mat>> get onMatsChange => _matsCtrl.stream;

  /// Triggers when `mats[i]` changes.
  ///
  /// This will not trigger if `onMatsChange` already fired for this event.
  Stream<Mat> onMatChange(int index) {
    _matCtrl.putIfAbsent(index, () => StreamController.broadcast());
    return _matCtrl[index].stream;
  }
}

class TurnMessage {
  int actions;
  int buys;
  int coins;
  Phase phase;

  TurnMessage(int actions, int buys, int coins, Phase phase);

  operator ==(other) =>
      other is TurnMessage &&
      actions == other.actions &&
      buys == other.buys &&
      coins == other.coins &&
      phase == other.phase;
}

bool _jsonEqual(blobA, blobB) {
  if (blobA == blobB) return true;
  if (blobA is List && blobB is List) {
    if (blobA.length != blobB.length) return false;
    for (var i = 0; i < blobA.length; i++) {
      if (!_jsonEqual(blobA[i], blobB[i])) return false;
    }
    return true;
  } else if (blobA is Map && blobB is Map) {
    if (blobA.length != blobB.length) return false;
    for (var key in blobA.keys) {
      if (!blobB.containsKey(key)) return false;
      if (!_jsonEqual(blobA[key], blobB[key])) return false;
    }
    return true;
  }
  return false;
}
