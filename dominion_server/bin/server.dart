import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http_server/http_server.dart';
import 'package:dominion_server/game.dart' as game;
import 'package:dominion_core/dominion_core.dart';

main() async {
  game.load();
  var path = Platform.script.resolve('../../dominion_web/build/web/').toFilePath();
  print(path);
  var staticFiles = new VirtualDirectory(path);
  staticFiles.allowDirectoryListing = true;

  var server = await HttpServer.bind('0.0.0.0', 7777);
  print("Server running on port 7777");
  var testKingdom = [ "Cellar", "Moat", "Village",
    "Gardens", "Militia", "Smithy", "Throne Room",
    "Council Room", "Laboratory", "Market"];
  games["test"] = new game.Game("test", testKingdom, false);
  await for (var request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      upgradeRequest(request);
      continue;
    } else if (request.method == 'POST' && request.uri.path == '/create-game') {
      var httpBody = await HttpBodyHandler.processRequest(request);
      var body = httpBody.body;
      var kingdom = body['kingdomCards'].trim().split('\n');
      bool useProsperity =
          body.containsKey('useProsperity') ? body['useProsperity'] == 'on' : false;
      bool spectate = body.containsKey('spectate') ? body['spectate'] == 'on' : false;
      var id = randomString(5);
      while (games.containsKey(id)) {
        id = randomString(5);
      }
      var newGame = new game.Game(id, kingdom, useProsperity);
      games[id] = newGame;
      request.response.redirect('/game.html?id=$id' + (spectate ? '&spectate' : ''));
      continue;
    } else if (request.method == 'GET' && request.uri.path == '/random') {
      var cards = CardRegistry.getCards()..shuffle();
      var kingdom = new List.generate(10, (x) => cards[x].name);
      bool useProsperity = false;
      var id = randomString(5);
      while (games.containsKey(id)) {
        id = randomString(5);
      }
      var newGame = new game.Game(id, kingdom, useProsperity);
      games[id] = newGame;
      request.response.redirect('/game.html?id=$id');
      continue;
    }
    var requestPath = request.uri.path.substring(1);
    if (requestPath == '') requestPath = 'index.html';
    var uri = new Uri.file(path).resolve(requestPath);
    staticFiles.serveFile(new File(uri.toFilePath()), request);
  }
}

Map<String, game.Game> games = {};

upgradeRequest(request) async {
  WebSocket socket = await WebSocketTransformer.upgrade(request);
  var listener = null;
  var onDone = null;
  await for (var encodedMsg in socket) {
    try {
      var msg = JSON.decode(encodedMsg);
      if (listener != null) {
        listener(msg);
      } else if (msg['type'] == 'join-game') {
        var id = msg['game-id'];
        if (!games.containsKey(id)) {
          send({'type': 'invalid-game'}, socket);
        } else {
          var username = msg['username'];
          var result = games[id].join(username, socket);
          listener = result[0];
          onDone = result[1];
        }
      } else if (msg['type'] == 'spectate-game') {
        var id = msg['game-id'];
        if (!games.containsKey(id)) {
          send({'type': 'invalid-game'}, socket);
        } else {
          onDone = games[id].spectate(socket);
        }
      }
    } catch (e, st) {
      print(e);
      print(st);
    }
  }
  if (onDone != null) onDone();
}

send(msg, socket) {
  var str = JSON.encode(msg);
  socket.add(str);
}

String randomString(int length) {
  var r = new Random();
  fn(i) {
    var number = r.nextInt(52);
    return number + (number < 26 ? 65 : 71);
  }
  var units = new List.generate(length, fn);
  return new String.fromCharCodes(units);
}
