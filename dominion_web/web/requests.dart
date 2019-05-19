part of main;

/*selectCardFromSupply(var metadata) {
  var event = metadata['event'];
  //var name = metadata['currentPlayer'];
  var stubs = metadata['validCards'].map(CardStub.fromMsg);
  var question = "Select a card from the supply";
  print(event);
  if (event == "EventType.GainCard") {
    question = "Select a card from the supply to gain";
  } else if (event == "EventType.BuyCard") {
    question = "Select a card from the supply to buy";
  } else if (event == "EventType.BlockCard") {
    question = "Select a card from the supply to block";
  } else if (event == "EventType.GuessCard") {
    question = "Guess a card from the supply";
  } else if (event == "EventType.GainForOpponent") {
    question = "Select a card for an opponent to gain";
  }
  return firstOrNull(
      cardSelector(stubs, question, metadata['allowNone'] ? 0 : 1, 1));
}

confirmAction(var metadata) async {
  var question = metadata['question'];
  if (metadata.containsKey('context')) {
    question = metadata['context']['name'] + ": $question";
  }
  var answer = await firstOrNull(cardSelector(['Yes', 'No'], question, 1, 1));
  return answer == 'Yes';
}*/

askQuestion(var metadata) {
  var question = metadata['question'];
  if (metadata.containsKey('context')) {
    question = metadata['context']['name'] + ": $question";
  }
  var options =
      metadata['options'].map((c) => c is String ? c : CardStub.fromMsg(c));
  return firstOrNull(cardSelector(options, question, 1, 1));
}

selectCardsFrom(var metadata) {
  var question = metadata['question'];
  if (metadata.containsKey('context')) {
    question = metadata['context']['name'] + ": $question";
  }
  var stubs = metadata['cards'].map(CardStub.fromMsg);
  return cardSelector(stubs, question, metadata['min'], metadata['max'],
      selectAll: metadata['event'] == "EventType.BuyPhase");
}

firstOrNull(var futureList) async {
  var list = await futureList;
  if (list.isEmpty) return null;
  return list.first;
}

cardSelector(Iterable<dynamic> stubsIter, String prompt, int min, int max,
    {bool selectAll: false}) async {
  var stubs = stubsIter.toList();
  var overlay = querySelector('.overlay');
  var promptEl = overlay.querySelector('.prompt')..innerHtml = "";
  var subpromptEl = overlay.querySelector('.subprompt')..innerHtml = "";
  var numbersEl = overlay.querySelector('.numbers')..innerHtml = "";
  var cardsEl = overlay.querySelector('.cards')..innerHtml = "";
  var confirm = overlay.querySelector('.confirm');
  promptEl.text = prompt;
  String subprompt = "Select at least $min and at most $max";
  if (min == max) subprompt = "Select exactly $min";
  if (min == 0) subprompt = "Select at most $max";
  if (max == null) subprompt = "Select at least $min";
  if (min == 0 && max == null) subprompt = "Select any amount (including none)";
  if (max == null) max = stubs.length;
  subpromptEl.text = subprompt;
  if (querySelector('.current-player').text == "Your Turn") {
    numbersEl.text = "You have ${querySelector('.actions').text} actions, "
        "${querySelector('.buys').text} buys, "
        "and ${querySelector('.coins').text} coins";
  }
  var selected = [];
  if (selectAll) selected.addAll(stubs);
  updateButton() {
    if (selected.length >= min && selected.length <= max) {
      confirm.classes.add('enabled');
    } else {
      confirm.classes.remove('enabled');
    }
  }

  var orders = [];
  for (var stub in stubs) {
    var cardEl;
    if (stub is CardStub) {
      cardEl = makeCardElement(stub);
    } else {
      cardEl = new DivElement();
      cardEl.classes = ['card', 'selectable'];
      cardEl.style.backgroundColor = "#444";
      cardEl.style.color = "#fff";
      cardEl.append(new DivElement()
        ..text = stub.toString()
        ..classes = ['text']);
    }
    var order = new DivElement()..classes = ['order'];
    cardEl.append(order);
    orders.add(order);
    cardEl.classes = ['card', 'selectable'];
    if (selectAll) {
      order.text = "${orders.length}";
      cardEl.classes.add('selected');
    }
    cardEl.onClick.listen((e) {
      if (cardEl.classes.contains('selected')) {
        selected.remove(stub);
        cardEl.classes.remove('selected');
        var myText = cardEl.querySelector('.order').text;
        if (max > 1) {
          int current = int.parse(myText);
          for (var order in orders) {
            int orderNum = int.tryParse(order.text) ?? 0;
            if (orderNum == current) {
              order.text = "";
            } else if (orderNum > current) {
              order.text = "${orderNum - 1}";
            }
          }
        }
      } else {
        if (max == 1) {
          selected.clear();
          cardsEl.querySelectorAll('.selected').classes.remove('selected');
        }
        if (selected.length < max) {
          selected.add(stub);
          cardEl.classes.add('selected');
          if (max > 1) {
            cardEl.querySelector('.order').text = "${selected.length}";
          }
        }
      }
      updateButton();
    });
    cardsEl.append(cardEl);
  }
  updateButton();
  overlay.style.display = 'block';
  await confirm.onClick
      .firstWhere((e) => selected.length >= min && selected.length <= max);
  overlay.style.display = 'none';
  return selected
      .map((stub) => stub is CardStub ? stub.name : "$stub")
      .toList();
}
