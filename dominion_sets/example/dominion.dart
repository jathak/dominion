import 'package:dominion_core/dominion_core.dart';
// ignore: unused_import
import 'package:dominion_sets/base_set.dart';
// ignore: unused_import
import 'package:dominion_sets/intrigue.dart';
// ignore: unused_import
import 'package:dominion_sets/seaside.dart';

import 'dart:io';
import 'dart:async';

List<String> expansions = [];

main(var args) {
  expansions = args;
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

  /// returns an ordered list of cards
  /// selected from those meeting conditions
  /// If max is < 0, there is no maximum
  Future<List<Card>> selectCardsFromHand(
      Card context, CardConditions conditions, int min, int max) async {
    List<Card> cards = [];
    for (int i = 0; i < player.hand.length; i++) {
      Card c = player.hand[i];
      if (conditions.allowsFor(c, player)) {
        cards.add(c);
      }
    }
    if (max == -1) max = cards.length;
    while (true) {
      List<Card> selections =
          selectMultiple(cards, min == 0, max == cards.length);
      if (selections.length >= min && selections.length <= max) {
        return selections;
      }
      print("Please select between $min and $max cards!");
    }
  }

  /// returns a single card type
  Future<Card> selectCardFromSupply(
      EventType event, CardConditions conditions, bool allowNone) async {
    var extra = "";
    if (event == EventType.GainCard) extra = " to gain";
    if (event == EventType.BuyCard)
      extra =
          " to buy. You have ${player.turn.coins} coins and ${player.turn.buys} buys";
    print("Select a card$extra.");
    List<Card> cards = [];
    for (Card c in player.engine.supply.cardsInSupply) {
      if (conditions.allowsFor(c, player)) {
        cards.add(c);
      }
    }
    return selectFromList(cards, allowNone);
  }

  /// returns true to complete action, false to not
  Future<bool> confirmAction(Card context, String question) async {
    print(question);
    print("Context: $context");
    return yesNo("(y/n): ");
  }

  /// returns option from options
  Future askQuestion(Card context, String question, List options) async {
    print(question);
    return selectFromList(options, false);
  }

  /// like selectCardsFromHand but for any list of cards
  Future<List<Card>> selectCardsFromListImpl(
      List<Card> cards, String question, int min, int max) async {
    print(question);
    if (max == -1) max = cards.length;
    while (true) {
      List<Card> selections =
          selectMultiple(cards, min == 0, max == cards.length);
      if (selections.length >= min && selections.length <= max) {
        return selections;
      }
      print("Please select between $min and $max cards!");
    }
  }

  /// returns an ActionCard or null to prematurely end action phase
  Future<Action> selectActionCard() async {
    print("Select an action card to play");
    List<Action> cards = [];
    for (int i = 0; i < player.hand.length; i++) {
      Card c = player.hand[i];
      if (c is Action) {
        cards.add(c);
      }
    }
    return selectFromList(cards);
  }

  /// returns a list of TreasureCards or an empty list to stop playing treasures
  Future<List<Treasure>> selectTreasureCards() async {
    print("Select treasure cards to play");
    List<Treasure> cards = [];
    for (int i = 0; i < player.hand.length; i++) {
      Card c = player.hand[i];
      if (c is Treasure) {
        cards.add(c);
      }
    }
    return selectMultiple(cards);
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
