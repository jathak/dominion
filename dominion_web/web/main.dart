library main;

import 'dart:async';
import 'dart:html';
import 'dart:js';
import 'dart:convert';

import 'package:crypto/crypto.dart' show md5;

part 'requests.dart';

WebSocket socket;

String ident;

String username;

Map<String, Function> handlers = {};

var log = querySelector('.log');

Future main() async {
  var params = Uri.base.queryParameters;
  ident = params['id'];
  username = params['username'];
  bool spectating = params.containsKey("spectate");
  var socketUrl = params.containsKey("url")
      ? params['url']
      : '${Uri.base.host}:${Uri.base.port}';
  var socketScheme = Uri.base.scheme == 'https' ? 'wss://' : 'ws://';
  socket = new WebSocket(socketScheme + socketUrl);
  socket.onClose.listen(socketClosed);
  socket.onError.listen(socketClosed);
  await socket.onOpen.first;
  if (params.containsKey('attempt-refresh')) {
    var allBut =
        window.location.href.substring(0, window.location.href.length - 16);
    window.location.href = allBut;
  }
  if (spectating) {
    startSpectating();
  } else {
    joinGame();
  }
  loadHandlers();
  querySelector(".start-game").onClick.listen((e) {
    var msg = {'type': 'start-game'};
    socket.send(json.encode(msg));
  });
  if (spectating) querySelector('.start-game').style.display = 'none';
  await for (var event in socket.onMessage) {
    try {
      var msg = json.decode(event.data);
      print('Message: $msg');
      if (msg.containsKey('type')) handlers[msg['type']](msg);
    } catch (e, st) {
      print(e);
      print(st);
    }
  }
}

socketClosed(e) {
  log.appendText('Disconnected from server.\n');
  log.scrollTop = log.scrollHeight;
  if (!Uri.base.queryParameters.containsKey('attempt-refresh')) {
    window.location.href += '&attempt-refresh';
  } else {
    var disc = querySelector('.disconnected');
    disc.style.display = 'block';
    disc.onClick.listen((e) => window.location.reload());
  }
}

startSpectating() {
  var msg = {'type': 'spectate-game', 'game-id': ident};
  socket.send(json.encode(msg));
  var hand = querySelector('.hand');
  var handLabel = querySelector('.hand-label');
  hand.onClick.listen((e) => hand.style.display = 'none');
  handLabel.onClick.listen((e) => hand.style.display = 'block');
}

joinGame() {
  if (username == null) {
    username = context['prompt'].apply(['Enter username']);
    if (username == null || username.trim() == '') {
      window.location.href += '&spectate';
      return;
    } else {
      window.location.href += '&username=$username';
      return;
    }
  }
  username = username.trim();
  var msg = {'type': 'join-game', 'game-id': ident, 'username': username};
  socket.send(json.encode(msg));
}

var supply = null;

void loadHandlers() {
  handlers['supply-update'] = (msg) {
    print("supply-update $msg");
    querySelector('.start-game').style.display = "none";
    supply = msg['supply'];
    var kingdom = convertToCards(supply['kingdom']);
    var treasures = convertToCards(supply['treasures']);
    var vps = convertToCards(supply['vps']);
    makeSupply(kingdom, treasures, vps);
  };
  handlers['hand-update'] = (msg) {
    print("hand-update $msg");
    var hand = convertToCards(msg['hand']);
    makeHeaders(hand, querySelector('.hand'));
    var player = msg['currentPlayer'];
    querySelector('.current-player').text =
        player == username ? "Your Turn" : "$player's Turn";
    querySelector('.deck-size').text = "${msg['deckSize']} cards left in deck";
    querySelector('.vp-tokens').text = msg['vpTokens'] > 0
        ? "${msg['vpTokens']} victory points from tokens"
        : "";
    var label = querySelector('.hand-label');
    if (username == null) {
      label.text = 'Their Hand';
    } else {
      label.text = 'Your Hand';
    }
    querySelector('.hand-label').text =
        username == null ? 'Their Hand' : 'Your Hand';
    // TODO(jathak): Better display for durations
    makeHeaders(convertToCards(msg['inPlay']), querySelector(".played"));
    if (msg.containsKey('turn')) {
      var turn = msg['turn'];
      querySelector('.turn-wrapper').style.display = 'block';
      querySelector('.phase').text = turn['phase'].split('.').last;
      querySelector('.actions').text = turn['actions'].toString();
      querySelector('.buys').text = turn['buys'].toString();
      querySelector('.coins').text = turn['coins'].toString();
    } else {
      querySelector('.turn-wrapper').style.display = 'none';
    }
  };
  handlers['log'] = (msg) {
    String message = msg['message'];
    log.appendText(message + '\n');
    log.scrollTop = log.scrollHeight;
  };
  handlers['request'] = (msg) async {
    var result = null;
    switch (msg['request']) {
      case 'askQuestion':
        result = await askQuestion(msg['metadata']);
        break;
      case 'selectCardsFrom':
        result = await selectCardsFrom(msg['metadata']);
        break;
    }
    var response = {
      'type': 'request-response',
      'response': result,
      'request-id': msg['request-id']
    };
    print("Response $response");
    socket.send(json.encode(response));
  };
}

Iterable<CardStub> convertToCards(var cardListFromMsg) sync* {
  if (cardListFromMsg is! List) throw Exception("$cardListFromMsg not a list");
  for (var item in cardListFromMsg) {
    yield CardStub.fromMsg(item);
  }
}

void makeHeaders(Iterable<CardStub> stubs, var element) {
  element.innerHtml = "";
  stubs.forEach(makeHeaderAdder(element));
}

void makeSupply(Iterable<CardStub> kingdom, Iterable<CardStub> treasures,
    Iterable<CardStub> vps) {
  var supply = querySelector('.supply');
  kingdom
      .forEach(makeCardAdder(supply.querySelector('.kingdom')..innerHtml = ""));
  treasures.forEach(
      makeCardAdder(supply.querySelector('.treasures')..innerHtml = ""));
  vps.forEach(makeCardAdder(supply.querySelector('.vps')..innerHtml = ""));
}

makeCardAdder(element) =>
    (CardStub stub) => element.append(makeCardElement(stub));
makeHeaderAdder(element) =>
    (CardStub stub) => element.append(makeHeaderElement(stub));

Element makeCardElement(CardStub card) {
  var name = card.name;
  name = name.replaceAll(' ', '_');
  var el = new DivElement();
  el.classes = ['card'];
  if (card.count != null && card.count > 0) {
    var status = new DivElement()
      ..text = "${card.count}"
      ..classes = ['status'];
    el.append(status);
  } else if (card.count != null) {
    el.classes.add('disabled');
  }
  if (card.cost != null) {
    var cost = new DivElement()
      ..text = "${card.cost}"
      ..classes = ['cost'];
    el.append(cost);
  }
  if (card.selectable) el.classes.add('selectable');
  var hash = md5.convert("$name.jpg".codeUnits).toString();
  var path = hash[0] + '/' + hash.substring(0, 2);
  el.style.backgroundImage =
      'url("http://wiki.dominionstrategy.com/images/$path/$name.jpg")';
  return el;
}

Element makeHeaderElement(CardStub card) {
  return makeCardElement(card)..classes = ['card-header'];
}

class CardStub {
  String name, expansion;
  int count;
  int cost;
  bool selectable = false;
  CardStub(this.name, [this.expansion]);

  static CardStub fromMsg(cardMsg) {
    var stub = new CardStub(cardMsg['name'], cardMsg['expansion']);
    if (cardMsg.containsKey('count')) stub.count = cardMsg['count'];
    if (cardMsg.containsKey('cost')) stub.cost = cardMsg['cost'];
    return stub;
  }
}
