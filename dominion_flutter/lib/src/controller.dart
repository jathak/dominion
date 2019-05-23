import 'dart:async';

import 'package:dominion_core/dominion_core.dart';

class FlutterController extends PlayerController {
  PlayerRequest lastRequest;
  final _requestCtrl = StreamController<PlayerRequest>.broadcast();
  Stream<PlayerRequest> get onRequest => _requestCtrl.stream;

  @override
  Future<String> askQuestion(String prompt, List<String> options,
      {Card context, EventType event}) async {
    var question =
        Question(prompt, options, Completer(), context: context, event: event);
    lastRequest = question;
    _requestCtrl.add(question);
    var result = await question.completer.future;
    lastRequest = null;
    return result;
  }

  @override
  Future<List<T>> selectCardsFrom<T extends Card>(List<T> cards, String prompt,
      {Card context, EventType event, int min = 0, int max}) async {
    var selectCards = SelectCards<T>(cards, prompt, Completer(),
        context: context, event: event, min: min, max: max);
    lastRequest = selectCards;
    _requestCtrl.add(selectCards);
    var result = await selectCards.completer.future;
    lastRequest = null;
    return result;
  }
}

abstract class PlayerRequest {
  final String prompt;
  final Card context;
  final EventType event;

  PlayerRequest(this.prompt, this.context, this.event);
}

class Question extends PlayerRequest {
  final List<String> options;
  final Completer<String> completer;

  Question(String prompt, this.options, this.completer,
      {Card context, EventType event})
      : super(prompt, context, event);
}

class SelectCards<T extends Card> extends PlayerRequest {
  final List<T> cards;
  final int min;
  final int max;
  final Completer<List<T>> completer;

  SelectCards(this.cards, String prompt, this.completer,
      {Card context, EventType event, this.min = 0, this.max})
      : super(prompt, context, event);
}
