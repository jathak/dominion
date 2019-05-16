library test_utils;

import 'package:dominion_core/dominion_core.dart';

import 'package:test/test.dart';

import 'dart:async';

expectBufferHasCards(CardBuffer buffer, List<Card> cards) {
  expect(buffer.asList(), equals(cards));
}

CardBuffer makeBuffer(List<Card> cards) {
  var buffer = CardBuffer();
  for (var c in cards) buffer.receive(c);
  return buffer;
}

Deck makeDeck(List<Card> cards) {
  var deck = Deck();
  for (var c in cards) deck.receive(c);
  return deck;
}

class TestController extends PlayerController {
  TestController(this.name,
      {this.cardsFromHand,
      this.cardFromSupply,
      this.confirm,
      this.ask,
      this.cardsFrom,
      this.actionCard,
      this.treasureCards}) {
    if (cardsFromHand == null)
      cardsFromHand = (player, context, conditions, min, max) async {
        List<Card> cards = [];
        for (var card in player.hand.asList()) {
          if (conditions.allowsFor(card, player)) {
            cards.add(card);
          }
          if (cards.length >= max) break;
        }
        return cards;
      };
    if (cardFromSupply == null)
      cardFromSupply = (player, event, conditions, allowNone) async {
        if (allowNone) return null;
        Supply supply = player.engine.supply;
        for (Card card in supply.cardsInSupply) {
          if (supply.supplyOf(card).count > 0 &&
              conditions.allowsFor(card, player)) {
            return card;
          }
        }
      };
    if (confirm == null) confirm = (player, context, question) async => false;
    if (ask == null)
      ask = (player, context, question, options) async => options[0];
    if (cardsFrom == null)
      cardsFrom =
          (player, cards, question, min, max) async => cards.sublist(0, min);
    if (actionCard == null)
      actionCard = (player) async {
        for (Card c in player.hand.asList()) {
          if (c is Action) return c;
        }
        return null;
      };
    if (treasureCards == null)
      treasureCards = (player) async {
        List<Treasure> cards = [];
        for (Card c in player.hand.asList()) {
          if (c is Treasure) {
            cards.add(c);
          }
        }
      };
  }

  List<String> messages = [];

  void log(String msg) => messages.add(msg);

  String name;

  Future<List<Card>> Function(Player player, Card context,
      CardConditions conditions, int min, int max) cardsFromHand;

  Future<Card> Function(Player player, EventType event,
      CardConditions conditions, bool allowNone) cardFromSupply;

  Future<bool> Function(Player player, Card context, String question) confirm;

  Future<dynamic> Function(
      Player player, Card context, String question, List<dynamic> option) ask;

  Future<List<Card>> Function(
          Player player, List<Card> cards, String question, int min, int max)
      cardsFrom;

  Future<Action> Function(Player player) actionCard;

  Future<List<Treasure>> Function(Player player) treasureCards;

  Player player;

  Future<List<Card>> selectCardsFromHand(
      Card context, CardConditions conditions, int min, int max) {
    return cardsFromHand(player, context, conditions, min, max);
  }

  Future<Card> selectCardFromSupply(
      EventType event, CardConditions conditions, bool allowNone) {
    return cardFromSupply(player, event, conditions, allowNone);
  }

  Future<bool> confirmAction(Card context, String question) {
    return confirm(player, context, question);
  }

  Future askQuestion(Card context, String question, List options) {
    return ask(player, context, question, options);
  }

  Future<List<Card>> selectCardsFrom(
      List<Card> cards, String question, int min, int max) {
    return cardsFrom(player, cards, question, min, max);
  }

  Future<Action> selectActionCard() {
    return actionCard(player);
  }

  Future<List<Treasure>> selectTreasureCards() {
    return treasureCards(player);
  }
}
