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

class DominionClient {
  final String _server;
  final bool _tls;
  WebSocketChannel channel;
  String gameId;
  String username;
  bool get spectating => username == null;

  GameState state;

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

  void connect() {
    channel = socketConnect((_tls ? 'wss://' : 'ws://') + _server);
    listen() async {
      await for (var data in channel.stream) {
        var msg = json.decode(data);
        switch (msg['type']) {
          case 'supply-update':
            state.updateSupply(msg['supply']);
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
            }
            break;
          default:
            print('$msg');
        }
      }
      channel = null;
    }

    listen();
  }

  void _sendMessage(msg) {
    if (channel == null) connect();
    channel.sink.add(json.encode(msg));
  }

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

  void startSpectating(String gameId) {
    this.gameId = gameId;
    _sendMessage({'type': 'spectate-game', 'game-id': gameId});
  }
}

class GameState {
  Supply _supply;
  var _supplyData;
  Supply get supply => _supply;

  final _supplyCtrl = StreamController<Supply>();
  final _supplyCountCtrl = <Card, StreamController<int>>{};
  final _supplyEmbargoCtrl = <Card, StreamController<int>>{};
  Stream<Supply> get onSupplyChange => _supplyCtrl.stream;
  Stream<int> onSupplyCountChange(Card card) {
    _supplyCountCtrl.putIfAbsent(card, () => StreamController());
    return _supplyCountCtrl[card].stream;
  }

  Stream<int> onSupplyEmbargoChange(Card card) {
    _supplyEmbargoCtrl.putIfAbsent(card, () => StreamController());
    return _supplyEmbargoCtrl[card].stream;
  }

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
      if (oldPile.count != newPile.count) {
        oldPile.count = newPile.count;
        _supplyCountCtrl[card]?.add(newPile.count);
      }
      if (oldPile.embargoTokens != newPile.embargoTokens) {
        oldPile.embargoTokens = newPile.embargoTokens;
        _supplyEmbargoCtrl[card]?.add(newPile.embargoTokens);
      }
      oldPile.used = newPile.used;
    }
    _supplyData = data;
  }

  String _currentPlayer;
  String get currentPlayer => _currentPlayer;
  final _currentPlayerChangeCtrl = StreamController<String>();
  Stream<String> get onCurrentPlayerChange => _currentPlayerChangeCtrl.stream;
  void set currentPlayer(String newCurrentPlayer) {
    if (_currentPlayer == null ||
        !_jsonEqual(newCurrentPlayer, _currentPlayer)) {
      _currentPlayer = newCurrentPlayer;
      _currentPlayerChangeCtrl.add(newCurrentPlayer);
    }
  }

  List<Card> _hand;
  List<Card> get hand => _hand;
  final _handChangeCtrl = StreamController<List<Card>>();
  Stream<List<Card>> get onHandChange => _handChangeCtrl.stream;
  void set hand(List<Card> newHand) {
    if (_hand == null || !_jsonEqual(newHand, _hand)) {
      _hand = newHand;
      _handChangeCtrl.add(newHand);
    }
  }

  List<Card> _inPlay;
  List<Card> get inPlay => _inPlay;
  final _inPlayChangeCtrl = StreamController<List<Card>>();
  Stream<List<Card>> get onInPlayChange => _inPlayChangeCtrl.stream;
  void set inPlay(List<Card> newInPlay) {
    if (_hand == null || !_jsonEqual(newInPlay, _inPlay)) {
      _inPlay = newInPlay;
      _inPlayChangeCtrl.add(newInPlay);
    }
  }

  int _deckSize;
  int get deckSize => _deckSize;
  final _deckSizeChangeCtrl = StreamController<int>();
  Stream<int> get onDeckSizeChange => _deckSizeChangeCtrl.stream;
  void set deckSize(int newDeckSize) {
    if (_deckSize != newDeckSize) {
      _deckSize = newDeckSize;
      _deckSizeChangeCtrl.add(newDeckSize);
    }
  }

  int _discardSize;
  int get discardSize => _discardSize;
  final _discardSizeChangeCtrl = StreamController<int>();
  Stream<int> get onDiscardSizeChange => _discardSizeChangeCtrl.stream;
  void set discardSize(int newDiscardSize) {
    if (_discardSize != newDiscardSize) {
      _discardSize = newDiscardSize;
      _discardSizeChangeCtrl.add(newDiscardSize);
    }
  }

  int _vpTokens;
  int get vpTokens => _vpTokens;
  final _vpTokensChangeCtrl = StreamController<int>();
  Stream<int> get onVpTokensChange => _vpTokensChangeCtrl.stream;
  void set vpTokens(int newVpTokens) {
    if (_vpTokens != newVpTokens) {
      _vpTokens = newVpTokens;
      _vpTokensChangeCtrl.add(newVpTokens);
    }
  }

  TurnMessage _turn;
  TurnMessage get turn => _turn;
  final _turnChangeCtrl = StreamController<TurnMessage>();
  Stream<TurnMessage> get onTurnChange => _turnChangeCtrl.stream;
  void set turn(TurnMessage newTurn) {
    if (_turn != newTurn) {
      _turn = newTurn;
      _turnChangeCtrl.add(newTurn);
    }
  }

  List<Mat> _mats;
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

  final _matsCtrl = StreamController<List<Mat>>();
  final _matCtrl = <int, StreamController<Mat>>{};
  Stream<List<Mat>> get onMatsChange => _matsCtrl.stream;
  Stream<Mat> onMatChange(Mat mat) {
    var index = _mats.indexOf(mat);
    _matCtrl.putIfAbsent(index, () => StreamController());
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

main() async {
  DominionClient('localhost:8000', tls: false).startSpectating('first');
}
