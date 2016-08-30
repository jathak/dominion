import 'package:dominion_core/dominion_core.dart';
import 'package:dominion_sets/base_set.dart' as base;
import 'package:dominion_sets/intrigue.dart' as intrigue;

import 'dart:convert';
import 'dart:io';
import 'dart:async';

load() {
  base.load();
  intrigue.load();
}

encodeOption(var option) {
  return option is Card ? {'name': option.name, 'expansion': option.expansion} : option.toString();
}

class Game {
  DominionEngine engine;
  List<WebSocket> spectators = [];
  Iterable<Card> kingdomCards;
  bool expensiveBasics;
  String id;
  Map<String, NetworkController> controllers = {};
  Map<String, List<WebSocket>> sockets = {};
  List<WebSocket> allSockets = [];
  Game(this.id, List<String> kingdom, this.expensiveBasics) {
    kingdomCards = kingdom.map((c) => CardRegistry.find(c.trim()));
  }

  startGame(String initiatingUser) {
    logToAll("Starting game...");
    var supply = new Supply(kingdomCards, controllers.length, expensiveBasics);
    engine = new DominionEngine(supply, controllers.values.toList());
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
    var stub = encodeOption(card);
    stub['count'] = engine.supply.supplyOf(card).count;
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
      controllers[username] = new NetworkController(username, this);
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
    return ([e]) {
      allSockets.remove(socket);
      spectators.remove(socket);
      logToAll("A spectator left. ${spectators.length} users now spectating.");
    };
  }

  logTo(var socket, String message, [bool serverLog = true]) {
    if (serverLog) print("LogTo: $message");
    if (socket is WebSocket) {
      safeSend(socket, {'type': 'log', 'message': message});
    } else if (socket is Iterable) {
      socket.forEach((s) => logTo(s, message, false));
    } else {
      throw new Exception("Can't log to $socket");
    }
  }

  safeSend(socket, var msg) {
    try {
      socket.add(JSON.encode(msg));
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  logToAll(String message) {
    print("LogToAll: $message");
    logTo(sockets.values, message, false);
    logTo(spectators, message, false);
  }

  updateHand(Player player) {
    var cards = player.hand.asList().map(encodeOption).toList();
    var msg = {'type': 'hand-update', 'hand': cards};
    msg['currentPlayer'] = engine.currentPlayer.name;
    msg['deckSize'] = player.deck.length;
    if (player.turn != null) {
      msg['turn'] = {
        'actions': player.turn.actions,
        'buys': player.turn.buys,
        'coins': player.turn.coins,
        'phase': player.turn.phase.toString(),
        'played': player.turn.played.asList().map(encodeOption).toList()
      };
    }
    for (var socket in sockets[player.name]) {
      safeSend(socket, msg);
    }
  }

  int currentRequestCount = 0;
  Map<int, PlayerRequest> activeRequests = {};

  requestFromUser(String username, String request, var metadata) {
    var controller = new StreamController();
    var msg = {
      'type': 'request',
      'request': request,
      'metadata': metadata,
      'request-id': currentRequestCount++
    };
    for (var socket in sockets[username]) {
      onResponse(response) => controller.add(response);
      activeRequests[msg['request-id']] = new PlayerRequest(username, msg, onResponse);
      safeSend(socket, msg);
    }
    return controller.stream.first;
  }

  makeSupplyStateMsg() {
    var supply = engine.supply;
    var kingdom = new CardBuffer();
    var treasures = new CardBuffer();
    var vps = new CardBuffer();
    var starter = new CardBuffer.from(supply.cardsInSupply);
    starter.filterInto((card) {
      if ([Copper.instance, Silver.instance, Gold.instance, Platinum.instance, Potion.instance]
          .contains(card)) return treasures;
      if ([Estate.instance, Duchy.instance, Province.instance, Colony.instance, Curse.instance]
          .contains(card)) return vps;
      return kingdom;
    });
    return {
      'type': 'supply-update',
      'supply': {
        'kingdom': (kingdom.asList()..sort()).map(encodeSupply).toList(),
        'treasures': (treasures.asList()..sort()).map(encodeSupply).toList(),
        'vps': (vps.asList()..sort()).map(encodeSupply).toList()
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

  /// returns an ordered list of cards
  /// selected from those meeting conditions
  /// If max is < 0, there is no maximum
  Future<List<Card>> selectCardsFromHand(
      Card context, CardConditions conditions, int min, int max) async {
    var metadata = {
      'context': encodeOption(context),
      'currentPlayer': game.engine.currentPlayer.name,
      'min': min,
      'max': max,
      'validCards': player.hand.asList().where(conditions.allowsFor).map(encodeOption).toList()
    };
    var result = await game.requestFromUser(name, 'selectCardsFromHand', metadata);
    return result.map(CardRegistry.find).toList();
  }

  /// returns a card meeting conditions or null to select no card if allowNone is true
  Future<Card> selectCardFromSupply(
      EventType event, CardConditions conditions, bool allowNone) async {
    var supply = game.engine.supply;
    var supplyCards = supply.cardsInSupply.where((c) => supply.supplyOf(c).count > 0);
    var metadata = {
      'event': event.toString(),
      'currentPlayer': game.engine.currentPlayer.name,
      'allowNone': allowNone,
      'validCards': supplyCards.where(conditions.allowsFor).map(game.encodeSupply).toList()
    };
    var result = await game.requestFromUser(name, 'selectCardFromSupply', metadata);
    return CardRegistry.find(result);
  }

  /// returns true to complete action, false to not
  Future<bool> confirmAction(Card context, String question) {
    var metadata = {
      'context': encodeOption(context),
      'currentPlayer': game.engine.currentPlayer.name,
      'question': question
    };
    return game.requestFromUser(name, 'confirmAction', metadata);
  }

  /// returns option from options
  Future askQuestion(Card context, String question, List options) async {
    var metadata = {
      'context': encodeOption(context),
      'currentPlayer': game.engine.currentPlayer.name,
      'question': question,
      'options': options.map(encodeOption).toList()
    };
    var result = await game.requestFromUser(name, 'askQuestion', metadata);
    var card = CardRegistry.find(result);
    return card ?? result;
  }

  /// like selectCardsFromHand but for any list of cards
  Future<List<Card>> selectCardsFrom(List<Card> cards, String question, int min, int max) async {
    var metadata = {
      'currentPlayer': game.engine.currentPlayer.name,
      'question': question,
      'cards': cards.map(encodeOption).toList(),
      'min': min,
      'max': max
    };
    var result = await game.requestFromUser(name, 'selectCardsFrom', metadata);
    return result.map(CardRegistry.find).toList();
  }

  /// returns an ActionCard or null to prematurely end action phase
  Future<ActionCard> selectActionCard() async {
    var metadata = {
      'cards': player.hand.asList().where((c) => c is ActionCard).map(encodeOption).toList()
    };
    var result = await game.requestFromUser(name, 'selectActionCard', metadata);
    return CardRegistry.find(result);
  }

  /// returns a list of TreasureCards or an empty list to stop playing treasures
  Future<List<TreasureCard>> selectTreasureCards() async {
    var metadata = {
      'cards': player.hand.asList().where((c) => c is TreasureCard).map(encodeOption).toList()
    };
    var result = await game.requestFromUser(name, 'selectTreasureCards', metadata);
    return result.map(CardRegistry.find).toList();
  }

  void log(String msg) {
    game.logTo(game.sockets[name], msg);
    if (player != null && game.engine != null) {
      game.updateHand(player);
      var msg = game.makeSupplyStateMsg();
      for (var socket in game.sockets[name]) {
        game.safeSend(socket, msg);
      }
    }
  }

  /// override this to reset state when game is reset (called after player is changed)
  reset() {
    // nothing yet
  }
}
