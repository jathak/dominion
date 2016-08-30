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

main() async {
  var params = Uri.base.queryParameters;
  ident = params['id'];
  bool spectating = params.containsKey("spectate");
  var socketUrl = params.containsKey("url") ? params['url'] : '${Uri.base.host}:${Uri.base.port}';
  socket = new WebSocket("ws://$socketUrl");
  await socket.onOpen.first;
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
  socket.onClose.listen((e) {
    log.appendText('Disconnected from server.\n');
    log.scrollTop = log.scrollHeight;
  });
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

startSpectating() {
  var msg = {'type': 'spectate-game', 'game-id': ident};
  socket.send(JSON.encode(msg));
}

joinGame() {
  username = context['prompt'].apply(['Enter username']);
  if (username == null || username.trim() == '') {
    window.location.hash += '-spectator';
    startSpectating();
    return;
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
    makeHand(hand);
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

void makeHand(Iterable<CardStub> hand) {
  var element = querySelector('.hand');
  element.innerHtml = "";
  hand.forEach(makeHeaderAdder(element));
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

  operator == (other) => identical(this, other);
}
