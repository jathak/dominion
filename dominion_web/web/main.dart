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
    supply = msg['legacy-supply'];
    var kingdom = convertToCards(supply['kingdom']);
    var treasures = convertToCards(supply['treasures']);
    var vps = convertToCards(supply['vps']);
    makeSupply(kingdom, treasures, vps);
  };
  handlers['hand-update'] = (msg) {
    print("hand-update $msg");
    querySelector(".in-play").text = "In Play";
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
    var mats = querySelector('.mats');
    mats.text = '';
    for (var card in msg['mats']?.keys ?? []) {
      var mat = msg['mats'][card];
      if (mat['type'] == 'PirateShipMat') {
        var coinTokens = mat['coinTokens'];
        mats.append(HeadingElement.h3()
          ..classes = ['mat-label']
          ..text = "Pirate Ship Mat");
        mats.append(DivElement()
          ..classes = ['mat-text']
          ..text = '$coinTokens coin token${coinTokens == 1 ? "" : "s"}');
      } else {
        var name = mat['name'];
        mats.append(HeadingElement.h3()
          ..classes = ['mat-label']
          ..text = name);
        var public = mat['public'];
        if (mat['buffer']['cards'].isEmpty) {
          mats.append(DivElement()
            ..classes = ['mat-text']
            ..text = 'No cards on mat');
        } else if (public || username != null) {
          var container = DivElement()..classes = ['mat-cards'];
          mats.append(container);
          makeHeaders(convertToCards(mat['buffer']['cards']), container);
        } else {
          var count = mat['buffer']['cards'].length;
          mats.append(DivElement()
            ..classes = ['mat-text']
            ..text = '$count card${count == 1 ? "" : "s"} on mat');
        }
      }
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

void makeHeaders(Iterable<CardStub> stubs, Element element) {
  element.innerHtml = '';
  stubs.forEach(makeHeaderAdder(element));
}

final cachedStubs = <String, CardStub>{};
final cachedElements = <String, Element>{};

void makeSupply(Iterable<CardStub> kingdom, Iterable<CardStub> treasures,
    Iterable<CardStub> vps) {
  var supply = querySelector('.supply');
  kingdom.forEach(makeCardAdder(supply.querySelector('.kingdom'), true));
  treasures.forEach(makeCardAdder(supply.querySelector('.treasures'), true));
  vps.forEach(makeCardAdder(supply.querySelector('.vps'), true));
}

makeCardAdder(container, bool forSupply) => (CardStub stub) {
      if (forSupply && cachedStubs.containsKey(stub.name)) {
        if (stub != cachedStubs[stub.name]) {
          var oldElement = cachedElements[stub.name];
          var newElement = makeCardElement(stub);
          oldElement.replaceWith(newElement);
          cachedElements[stub.name] = newElement;
        }
      } else {
        var element = makeCardElement(stub);
        container.append(element);
        if (forSupply) {
          cachedStubs[stub.name] = stub;
          cachedElements[stub.name] = element;
        }
      }
    };

makeHeaderAdder(element) =>
    (CardStub stub) => element.append(makeHeaderElement(stub));

var alreadyLoadedCards = <String>{};

Element makeCardElement(CardStub card) {
  var name = card.name;
  name = name.replaceAll(' ', '_');
  var el = DivElement();
  el.classes = ['card'];
  if (card.count != null && card.count > 0) {
    el.append(DivElement()
      ..text = "${card.count}"
      ..classes = ['status']);
  } else if (card.count != null) {
    el.classes.add('disabled');
  }
  if (card.cost != null) {
    el.append(DivElement()
      ..text = "${card.cost}"
      ..classes = ['cost']);
  }
  if ((card.embargoTokens ?? 0) > 0) {
    var x = card.embargoTokens == 1 ? "" : " x${card.embargoTokens}";
    el.append(DivElement()
      ..text = "Embargo$x"
      ..classes = ['embargo']);
  }
  if (card.selectable) el.classes.add('selectable');
  var hash = md5.convert("$name.jpg".codeUnits).toString();
  var path = hash[0] + '/' + hash.substring(0, 2);
  var domain = "http://wiki.dominionstrategy.com";
  // loadThumb always works, but is not properly cached by the browser
  // thumb will always be present immediately after loadThumb is loaded, and
  // will be properly cached.
  // Therefore, we try loading `thumb` first, then try `loadThumb` if it fails.
  // Once either successfully loads, we can set `thumb` as the background.
  var thumb = "$domain/images/thumb/$path/$name.jpg/300px-$name.jpg";
  var loadThumb = "$domain/index.php/Special:FilePath/$name.jpg?width=300";
  if (alreadyLoadedCards.contains(card.name)) {
    el.style.backgroundImage = 'url("$thumb")';
    return el;
  }
  var image = ImageElement(src: thumb);
  image.onLoad.listen((event) {
    el.style.backgroundImage = 'url("$thumb")';
  });
  image.onError.listen((event) {
    image.src = loadThumb;
  });
  return el;
}

Element makeHeaderElement(CardStub card) {
  return makeCardElement(card)..classes = ['card-header'];
}

class CardStub {
  String name;
  int count;
  int cost;
  int embargoTokens;
  bool selectable = false;
  CardStub(this.name);

  static CardStub fromMsg(cardMsg) {
    var stub = CardStub(cardMsg['name']);
    if (cardMsg.containsKey('count')) stub.count = cardMsg['count'];
    if (cardMsg.containsKey('cost')) stub.cost = cardMsg['cost'];
    if (cardMsg.containsKey('embargoTokens')) {
      stub.embargoTokens = cardMsg['embargoTokens'];
    }
    return stub;
  }

  bool operator ==(other) =>
      other is CardStub &&
      name == other.name &&
      count == other.count &&
      cost == other.cost &&
      embargoTokens == other.embargoTokens &&
      selectable == other.selectable;
}
