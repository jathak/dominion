import 'package:dominion_core/dominion_core.dart';
// ignore: unused_import
import 'package:dominion_sets/base_set.dart';
// ignore: unused_import
import 'package:dominion_sets/intrigue.dart';
// ignore: unused_import
import 'package:dominion_sets/seaside.dart';
// ignore: unused_import
import 'package:dominion_sets/prosperity.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:async';

Map<String, dynamic> encodeCard(Card card) => card.serialize();

class Game {
  DominionEngine engine;
  List<WebSocket> spectators = [];
  Iterable<Card> kingdomCards;
  bool expensiveBasics;
  String id;
  Map<String, NetworkController> controllers = {};
  Map<String, List<WebSocket>> sockets = {};
  List<WebSocket> allSockets = [];
  Future Function() saveGame;
  int currentRequestCount = 0;
  Map<int, PlayerRequest> activeRequests = {};

  Game(this.id, List<String> kingdom, this.expensiveBasics, this.saveGame) {
    kingdomCards = kingdom.map((c) => CardRegistry.find(c.trim()));
    kingdomCards = kingdomCards.toList()..sort();
  }

  Map<String, dynamic> serialize() => {
        'type': 'Game',
        'id': id,
        'playerNames': controllers.keys.toList(),
        'kingdomCards': kingdomCards.map((card) => card.name).toList(),
        'expensiveBasics': expensiveBasics,
        'currentRequestCount': currentRequestCount,
        'engine': engine.serialize()
      };

  static Game deserialize(data, Future saveGame()) {
    var game = Game(
        data['id'],
        data['kingdomCards'].whereType<String>().toList(),
        data['expensiveBasics'],
        saveGame);
    game.controllers = {
      for (var name in data['playerNames']) name: NetworkController(name, game)
    };
    game.currentRequestCount = (data['currentRequestCount'] ?? 0) + 1;
    game.sockets = {for (var name in data['playerNames']) name: []};
    if (data['engine'] != null) {
      game.engine = DominionEngine.deserialize(data['engine'],
          game.controllers.values.toList(), PirateShipMat.deserialize);
      game.engine.saveGame = saveGame;
    }
    return game;
  }

  void resumeGame() {
    engine.saveGame = saveGame;
    engine.onLog = (msg) {
      updateSupplyState();
      logTo(spectators, msg);
    };
    updateSupplyState();
    for (var player in engine.players) {
      updateHand(player);
    }
    engine.start(skipInitialSave: true);
  }

  void startGame(String initiatingUser) {
    logToAll("Starting game...");
    var supply = Supply(kingdomCards, controllers.length, expensiveBasics);
    engine = DominionEngine(supply, controllers.values.toList());
    engine.saveGame = saveGame;
    engine.onLog = (msg) {
      updateSupplyState();
      logTo(spectators, msg);
    };
    updateSupplyState();
    for (var player in engine.players) {
      updateHand(player);
    }
    engine.start();
  }

  updateSupplyState() {
    var msg = makeSupplyStateMsg();
    for (var socket in allSockets) {
      safeSend(socket, msg);
    }
  }

  encodeSupply(Card card) {
    var stub = encodeCard(card);
    stub['count'] = engine.supply.supplyOf(card).count;
    if (engine.currentPlayer != null) {
      var actualCost = card.calculateCost(engine.currentPlayer);
      if (card.calculateCost(engine.currentPlayer) != card.cost) {
        stub['cost'] = actualCost;
      }
    }
    stub['embargoTokens'] = engine.supply.supplyOf(card).embargoTokens;
    return stub;
  }

  join(String username, WebSocket socket) {
    if (!sockets.containsKey(username)) {
      if (engine != null) {
        logTo(socket, "You can't join a game that's already in progress!");
        return [(m) => null, ([e]) => null];
      }
      sockets[username] = [];
    }
    sockets[username].add(socket);
    var onDone = ([e]) {
      allSockets.remove(socket);
      sockets[username].remove(socket);
      if (sockets[username].isEmpty) {
        if (engine == null) {
          sockets.remove(username);
          controllers.remove(username);
          logToAll("$username has left the game. ${controllers.length} "
              "players connected.");
        } else {
          logToAll("$username has left the game. Someone must connect as them"
              " for the game to continue.");
        }
      } else {
        logTo(sockets[username], "One of your clients disconnected");
      }
    };
    allSockets.add(socket);
    if (!controllers.containsKey(username)) {
      controllers[username] = NetworkController(username, this);
    }
    if (sockets[username].length == 1) {
      logToAll("$username joined. ${controllers.length} players connected.");
    } else {
      logTo(sockets[username], "Another client connected as you.");
    }
    if (engine != null) {
      safeSend(socket, makeSupplyStateMsg());
      updateHand(controllers[username].player);
      for (var request in activeRequests.values) {
        if (request.playerName == username) safeSend(socket, request.msg);
      }
    }
    logTo(socket, "Playing with ${kingdomCards.toList()}");
    var onMessage = (msg) {
      if (msg['type'] == 'request-response') {
        var id = msg['request-id'];
        var response = msg['response'];
        if (activeRequests.containsKey(id)) {
          var request = activeRequests.remove(id);
          request.onResponse(response);
        }
      } else if (msg['type'] == 'start-game') {
        startGame(username);
      }
    };
    return [onMessage, onDone];
  }

  spectate(WebSocket socket) {
    spectators.add(socket);
    allSockets.add(socket);
    // initialize spectator state
    if (engine != null) {
      safeSend(socket, makeSupplyStateMsg());
    }
    logToAll("A spectator joined. ${spectators.length} users now spectating.");
    if (engine != null) {
      updateHand(engine.currentPlayer);
    }
    return ([e]) {
      allSockets.remove(socket);
      spectators.remove(socket);
      logToAll("A spectator left. ${spectators.length} users now spectating.");
    };
  }

  logTo(var socket, String message, [bool serverLog = true]) {
    if (message == null) return;
    //if (serverLog) print("LogTo: $message");
    if (socket is WebSocket) {
      safeSend(socket, {'type': 'log', 'message': message});
    } else if (socket is Iterable) {
      socket.forEach((s) => logTo(s, message, false));
    } else {
      throw Exception("Can't log to $socket");
    }
  }

  bool safeSend(WebSocket socket, var msg) {
    try {
      socket.add(json.encode(msg));
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  logToAll(String message) {
    //print("LogToAll: $message");
    logTo(sockets.values, message, false);
    logTo(spectators, message, false);
  }

  updateHand(Player player) {
    var cards = player.hand.toList().map(encodeCard).toList();
    var msg = {'type': 'hand-update', 'hand': cards};
    msg['currentPlayer'] = engine.currentPlayer.name;
    msg['deckSize'] = player.deck.length;
    msg['inPlay'] = player.inPlay.toList().map(encodeCard).toList();
    msg['vpTokens'] = player.vpTokens;
    msg['mats'] = player.serializeMats();

    var toSendTo = []..addAll(sockets[player.name]);
    if (player.turn != null) {
      msg['turn'] = {
        'actions': player.turn.actions,
        'buys': player.turn.buys,
        'coins': player.turn.coins,
        'phase': player.turn.phase.toString(),
      };
      toSendTo.addAll(spectators);
    }
    for (var socket in toSendTo) {
      safeSend(socket, msg);
    }
  }

  requestFromUser(String username, String request, var metadata) {
    for (var player in engine.players) {
      updateHand(player);
    }
    var completer = Completer();
    var msg = {
      'type': 'request',
      'request': request,
      'metadata': metadata,
      'request-id': currentRequestCount++
    };
    onResponse(response) => completer.complete(response);
    activeRequests[msg['request-id']] =
        PlayerRequest(username, msg, onResponse);
    for (var socket in sockets[username]) {
      safeSend(socket, msg);
    }
    return completer.future;
  }

  makeSupplyStateMsg() {
    var supply = engine.supply;
    var kingdom = CardBuffer();
    var treasures = CardBuffer();
    var vps = CardBuffer();
    var starter = CardBuffer.from(supply.cardsInSupply);
    starter.filterInto((card) {
      if ([
        Copper.instance,
        Silver.instance,
        Gold.instance,
        Platinum.instance,
        Potion.instance
      ].contains(card)) return treasures;
      if ([
        Estate.instance,
        Duchy.instance,
        Province.instance,
        Colony.instance,
        Curse.instance
      ].contains(card)) return vps;
      return kingdom;
    });
    return {
      'type': 'supply-update',
      'supply': {
        'kingdom': (kingdom.toList()..sort()).map(encodeSupply).toList(),
        'treasures': (treasures.toList()..sort()).map(encodeSupply).toList(),
        'vps': (vps.toList()..sort()).map(encodeSupply).toList()
      }
    };
  }
}

class PlayerRequest {
  String playerName;
  var msg;
  Function onResponse;
  PlayerRequest(this.playerName, this.msg, this.onResponse);
}

class NetworkController extends PlayerController {
  Player player;

  /// player's name
  String name;

  Game game;

  NetworkController(this.name, this.game);

  /// returns option from options
  Future<String> askQuestion(String question, List<String> options,
      {Card context, EventType event}) async {
    var metadata = {
      if (context != null) 'context': encodeCard(context),
      if (event != null) 'event': event.toString(),
      'currentPlayer': game.engine.currentPlayer.name,
      'question': question,
      'options': options
    };
    var result = await game.requestFromUser(name, 'askQuestion', metadata);
    var card = result is String ? CardRegistry.find(result) : null;
    return card ?? result;
  }

  Future<List<T>> selectCardsFrom<T extends Card>(
      List<T> cards, String question,
      {Card context, EventType event, int min: 0, int max}) async {
    var metadata = {
      if (context != null) 'context': encodeCard(context),
      if (event != null) 'event': event.toString(),
      'currentPlayer': game.engine.currentPlayer.name,
      'question': question,
      'cards': cards
          .map([
            EventType.BuyCard,
            EventType.Contraband,
            EventType.Embargo,
            EventType.GainCard,
            EventType.GainCard
          ].contains(event)
              ? game.encodeSupply
              : encodeCard)
          .toList(),
      'min': min,
      'max': max
    };
    var result = await game.requestFromUser(name, 'selectCardsFrom', metadata);
    return result
        .whereType<String>()
        .map(CardRegistry.find)
        .whereType<T>()
        .toList();
  }

  void log(String msg) {
    game.logTo(game.sockets[name], msg);
    if (player != null && game.engine != null) {
      game.updateHand(player);
    }
  }

  /// override this to reset state when game is reset (called after player is changed)
  reset() {
    // nothing yet
  }
}

List<String> generateKingdom([List<String> existing]) {
  if (existing == null) existing = [];
  List<Card> cards = existing
      .map(CardRegistry.find)
      .where((c) => c is Card)
      .toList(growable: true);
  var registry = CardRegistry.getCards()..shuffle();
  while (cards.length < 10) {
    var card = registry.removeAt(0);
    if (card.expansion != null && !cards.contains(card)) {
      if (card is BaseSet && !(card as BaseSet).inSecondEdition) continue;
      if (card is Intrigue && !(card as Intrigue).inSecondEdition) continue;
      cards.add(card);
    }
  }
  return cards.map((c) => c.name).toList();
}
