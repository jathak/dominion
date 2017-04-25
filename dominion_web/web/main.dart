// Copyright (c) 2015, Jack Thakar. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
library main;

import 'dart:async';
import 'dart:html';
import 'dart:js';
import 'dart:convert';

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
  var socketUrl = params.containsKey("url") ? params['url'] : '${Uri.base.host}:${Uri.base.port}';
  var socketScheme = Uri.base.scheme == 'https' ? 'wss://' : 'ws://';
  socket = new WebSocket(socketScheme + socketUrl);
  socket.onClose.listen(socketClosed);
  socket.onError.listen(socketClosed);
  await socket.onOpen.first;
  if (params.containsKey('attempt-refresh')) {
    var allBut = window.location.href.substring(0, window.location.href.length - 16);
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
    socket.send(JSON.encode(msg));
  });
  if (spectating) querySelector('.start-game').style.display = 'none';
  await for (var event in socket.onMessage) {
    try {
      var msg = JSON.decode(event.data);
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
    disc.onClick.listen((e)=>window.location.reload());
  }
}

startSpectating() {
  var msg = {'type': 'spectate-game', 'game-id': ident};
  socket.send(JSON.encode(msg));
  var hand = querySelector('.hand');
  var handLabel = querySelector('.hand-label');
  hand.onClick.listen((e)=>hand.style.display='none');
  handLabel.onClick.listen((e)=>hand.style.display='block');
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
  socket.send(JSON.encode(msg));
}

var supply = null;

void loadHandlers() {
  handlers['supply-update'] = (msg) {
    querySelector('.start-game').style.display = "none";
    supply = msg['supply'];
    var kingdom = supply['kingdom'].map(CardStub.fromMsg);
    var treasures = supply['treasures'].map(CardStub.fromMsg);
    var vps = supply['vps'].map(CardStub.fromMsg);
    makeSupply(kingdom, treasures, vps);
  };
  handlers['hand-update'] = (msg) {
    var hand = msg['hand'].map(CardStub.fromMsg);
    makeHeaders(hand, querySelector('.hand'));
    var player = msg['currentPlayer'];
    querySelector('.current-player').text = player == username ? "Your Turn" : "$player's Turn";
    querySelector('.deck-size').text= "${msg['deckSize']} cards left in deck";
    var label = querySelector('.hand-label');
    if (username == null) {
      label.text = 'Their Hand';
    } else {
      label.text = 'Your Hand';
    }
    if (msg.containsKey('turn')) {
      var turn = msg['turn'];
      querySelector('.turn-wrapper').style.display = 'block';
      querySelector('.phase').text = turn['phase'].split('.').last;
      querySelector('.actions').text = turn['actions'].toString();
      querySelector('.buys').text = turn['buys'].toString();
      querySelector('.coins').text = turn['coins'].toString();
      makeHeaders(turn['played'].map(CardStub.fromMsg), querySelector(".played"));
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
      case 'selectCardsFromHand':
        result = await selectCardsFromHand(msg['metadata']);
        break;
      case 'selectCardFromSupply':
        result = await selectCardFromSupply(msg['metadata']);
        break;
      case 'confirmAction':
        result = await confirmAction(msg['metadata']);
        break;
      case 'askQuestion':
        result = await askQuestion(msg['metadata']);
        break;
      case 'selectCardsFrom':
        result = await selectCardsFrom(msg['metadata']);
        break;
      case 'selectActionCard':
        result = await selectActionCard(msg['metadata']);
        break;
      case 'selectTreasureCards':
        result = await selectTreasureCards(msg['metadata']);
        break;
    }
    var response = {
      'type': 'request-response',
      'response': result,
      'request-id': msg['request-id']
    };
    socket.send(JSON.encode(response));
  };
}

void makeHeaders(Iterable<CardStub> stubs, var element) {
  element.innerHtml = "";
  stubs.forEach(makeHeaderAdder(element));
}

void makeSupply(Iterable<CardStub> kingdom, Iterable<CardStub> treasures, Iterable<CardStub> vps) {
  var supply = querySelector('.supply');
  kingdom.forEach(makeCardAdder(supply.querySelector('.kingdom')..innerHtml = ""));
  treasures.forEach(makeCardAdder(supply.querySelector('.treasures')..innerHtml = ""));
  vps.forEach(makeCardAdder(supply.querySelector('.vps')..innerHtml = ""));
}

makeCardAdder(element) => (CardStub stub) => element.append(makeCardElement(stub));
makeHeaderAdder(element) => (CardStub stub) => element.append(makeHeaderElement(stub));

Element makeCardElement(CardStub card) {
  var expansion = card.expansion;
  var name = card.name;
  if (expansion == null) expansion = 'common';
  name = name.toLowerCase().replaceAll(' ', '');
  expansion = expansion.toLowerCase().replaceAll(' ', '');
  if (name == 'potion') expansion = 'alchemy';
  if (name == 'platinum' || name == 'colony') expansion = 'prosperity';
  var el = new DivElement();
  el.classes = ['card', 'set-$expansion', 'type-$name'];
  if (card.count != null && card.count > 0) {
    var status = new DivElement()
      ..text = "${card.count}"
      ..classes = ['status'];
    el.append(status);
  } else {
    el.classes.add('disabled');
  }
  if (card.selectable) el.classes.add('selectable');
  el.style.backgroundImage = 'url("http://dominion.diehrstraits.com/scans/$expansion/$name.jpg")';
  return el;
}

Element makeHeaderElement(CardStub card) {
  var expansion = card.expansion;
  var name = card.name;
  if (expansion == null) expansion = 'common';
  name = name.toLowerCase().replaceAll(' ', '');
  expansion = expansion.toLowerCase().replaceAll(' ', '');
  if (name == 'potion') expansion = 'alchemy';
  if (name == 'platinum' || name == 'colony') expansion = 'prosperity';
  var el = new DivElement();
  el.classes = ['card-header', 'set-$expansion', 'type-$name'];
  el.style.backgroundImage = 'url("http://dominion.diehrstraits.com/scans/$expansion/$name.jpg")';
  return el;
}

class CardStub {
  String name, expansion;
  int count = null;
  bool selectable = false;
  CardStub(this.name, [this.expansion = null]);

  static CardStub fromMsg(cardMsg) {
    var stub = new CardStub(cardMsg['name'], cardMsg['expansion']);
    if (cardMsg.containsKey('count')) {
      stub.count = cardMsg['count'];
    }
    return stub;
  }
}
