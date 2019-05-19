import 'package:dominion_core/dominion_core.dart';
import 'package:dominion_sets/base_set.dart';
import 'package:dominion_sets/intrigue.dart';
import 'package:dominion_sets/seaside.dart';
import 'package:dominion_sets/prosperity.dart';

import 'dart:io';
import 'dart:async';

List<String> expansions = [];

main(var args) {
  expansions = args;
  registerBaseSet();
  registerIntrigue();
  registerSeaside();
  registerProsperity();
  start();
}

start() async {
  var p1 = new CLIController("Player 1");
  var p2 = new CLIController("Player 2");
  List<PlayerController> controllers = [p1, p2];
  var kingdom = generateKingdom();
  print("Kingdom:");
  print(kingdom);
  Supply supply = new Supply(kingdom, 2, false);
  var engine = new DominionEngine(supply, controllers);
  engine.start();
}

List<Card> generateKingdom() {
  List<Card> cards = [];
  CardConditions conds = new CardConditions();
  conds.allowedExpansions = expansions;
  for (Card card in CardRegistry.cardsWithConditions(conds)) {
    cards.add(card);
    if (cards.length >= 10) break;
  }
  cards.sort();
  return cards;
}

String input([prompt = ""]) {
  stdout.write(prompt);
  return stdin.readLineSync();
}

bool yesNo([prompt = ""]) {
  String result = input(prompt).toLowerCase();
  return result == 'yes' || result == 'y';
}

T selectFromList<T>(List<T> options, [allowNone = true]) {
  if (allowNone) print("0: None");
  int i = 1;
  for (var option in options) {
    print("$i: $option");
    i++;
  }
  String result;
  while (true) {
    try {
      result = input("#: ");
      int number = int.parse(result);
      if (allowNone && number == 0) return null;
      return options[number - 1];
    } catch (_) {
      print("Invalid!");
    }
  }
}

List selectMultiple(List options, [allowNone = true, allowAll = true]) {
  if (allowNone) print("0: None");
  int i = 1;
  for (var option in options) {
    print("$i: $option");
    i++;
  }
  if (allowAll) print("$i: All");
  String result;
  while (true) {
    try {
      result = input("Comma-separated list: ");
      List items = [];
      var parts = result.split(",");
      for (var p in parts) {
        int number = int.parse(p.trim());
        if (allowNone && number == 0) return [];
        if (allowAll && number == options.length + 1) return options;
        items.add(options[number - 1]);
      }
      return items;
    } catch (_) {
      print("Invalid!");
    }
  }
}

class CLIController extends PlayerController {
  CLIController(this.name);

  Player player;

  /// returns option from options
  Future<String> askQuestion(String question, List<String> options,
      {Card context, EventType event}) async {
    print((context == null ? "" : "$context: ") + question);
    return selectFromList(options, false);
  }

  /// like selectCardsFromHand but for any list of cards
  Future<List<T>> selectCardsFrom<T extends Card>(
      List<T> cards, String question,
      {Card context, EventType event, int min: 0, int max}) async {
    print((context == null ? "" : "$context: ") + question);
    if (max == -1) max = cards.length;
    while (true) {
      List<T> selections = selectMultiple(cards, min == 0, max == cards.length);
      if (selections.length >= min && selections.length <= max) {
        return selections;
      }
      print("Please select between $min and $max cards!");
    }
  }

  static String lastMsg = null;

  @override
  void log(String msg) {
    if (msg != lastMsg) {
      print(msg);
      lastMsg = msg;
    }
  }

  /// Player's name
  String name;
}
