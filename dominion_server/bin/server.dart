import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http_server/http_server.dart';
import 'package:dominion_server/game.dart' as game;

Future<void> main(var args) async {
  int port = args.length > 0 ? int.parse(args[0]) : 7777;
  if (args.length > 1) savedGamesFile = File(args[1]);
  var path = Platform.script.resolve('../../dominion_web/build/').toFilePath();
  print(path);
  var staticFiles = VirtualDirectory(path);
  staticFiles.allowDirectoryListing = true;

  var server = await HttpServer.bind('0.0.0.0', port);
  print("Server running on port $port");
  var testKingdom = [
    "Cellar",
    "Moat",
    "Village",
    "Gardens",
    "Militia",
    "Smithy",
    "Throne Room",
    "Council Room",
    "Laboratory",
    "Market"
  ];
  games["test"] = game.Game("test", testKingdom, false, saveGame("test"));
  await restoreGames();
  await for (var request in server) {
    try {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        upgradeRequest(request);
        continue;
      } else if (request.method == 'GET' &&
          request.uri.path == '/create-game') {
        //var httpBody = await HttpBodyHandler.processRequest(request);
        var body = request.uri.queryParameters;
        var kingdom =
            body['kingdomCards'].replaceAll('\r\n', '\n').trim().split('\n');
        kingdom = game.generateKingdom(kingdom);
        bool useProsperity = body.containsKey('useProsperity')
            ? body['useProsperity'] == 'on'
            : false;
        bool spectate =
            body.containsKey('spectate') ? body['spectate'] == 'on' : false;
        var id = randomString(5);
        while (games.containsKey(id)) {
          id = randomString(5);
        }
        var newGame = game.Game(id, kingdom, useProsperity, saveGame(id));
        games[id] = newGame;
        request.response.redirect(
            Uri.parse('/game.html?id=$id' + (spectate ? '&spectate' : '')));
        continue;
      } else if (request.method == 'GET' && request.uri.path == '/random') {
        var kingdom = game.generateKingdom();
        bool useProsperity = false;
        var id = randomString(5);
        while (games.containsKey(id)) {
          id = randomString(5);
        }
        var newGame = game.Game(id, kingdom, useProsperity, saveGame(id));
        games[id] = newGame;
        request.response.redirect(Uri.parse('/game.html?id=$id'));
        continue;
      }
      var requestPath = request.uri.path.substring(1);
      if (requestPath == '') requestPath = 'index.html';
      var uri = Uri.file(path).resolve(requestPath);
      staticFiles.serveFile(File(uri.toFilePath()), request);
    } catch (e) {
      print(e);
    }
  }
}

Map<String, game.Game> games = {};

Future<void> upgradeRequest(request) async {
  WebSocket socket = await WebSocketTransformer.upgrade(request);
  var listener = null;
  var onDone = null;
  await for (var encodedMsg in socket) {
    try {
      var msg = json.decode(encodedMsg);
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

send(msg, WebSocket socket) {
  var str = json.encode(msg);
  socket.add(str);
}

String randomString(int length) {
  if (!games.containsKey('first')) {
    return "first";
  }
  var r = Random();
  fn(i) {
    var number = r.nextInt(52);
    return number + (number < 26 ? 65 : 71);
  }

  var units = List.generate(length, fn);
  return String.fromCharCodes(units);
}

var savedGamesFile = File('data.json');

restoreGames() async {
  try {
    var contents = await savedGamesFile.readAsString();
    var restored = [
      for (var blob in json.decode(contents).values)
        game.Game.deserialize(blob, saveGame(blob['id']))
    ];
    for (var game in restored) {
      if (games.containsKey(game.id)) continue;
      games[game.id] = game;
      if (!game.engine.gameOver) game.resumeGame();
      print('Restored game ${game.id}');
    }
  } catch (e, st) {
    print('Failed to restore games');
    print(e);
    print(st);
  }
}

Map<String, dynamic> serializedGames = {};

Future Function() saveGame(String id) => () async {
      try {
        if (!games.containsKey(id)) throw Exception('No game "$id" found!');
        if (games[id].engine?.gameOver ?? true) {
          serializedGames.remove(id);
        } else {
          serializedGames[id] = games[id].serialize();
        }
        await savedGamesFile.create();
        await savedGamesFile.writeAsString(json.encode(serializedGames));
        print('Saved game "$id"');
      } catch (e, st) {
        print('Failed to save game "$id"');
        print(e);
        print(st);
      }
    };
