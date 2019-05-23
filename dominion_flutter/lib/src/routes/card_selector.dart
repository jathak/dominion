import 'package:flutter/material.dart' hide Card;
import 'package:flutter/material.dart' as material show Card;

import 'package:dominion_server/client.dart';
import 'package:dominion_core/dominion_core.dart';

import '../controller.dart';
import '../widgets/card.dart';

class CardSelectionScreen extends StatefulWidget {
  final GameState state;
  final SelectCards request;

  CardSelectionScreen(this.state, this.request);

  _CardSelectionState createState() => _CardSelectionState(state, request);
}

class _CardSelectionState extends State<CardSelectionScreen> {
  final GameState state;
  final SelectCards request;
  final selected = <int>[];

  _CardSelectionState(this.state, this.request) {
    // Auto-select all treasures
    if (request.event == EventType.BuyPhase) {
      for (var i = 0; i < request.cards.length; i++) {
        selected.add(i);
      }
    }
  }

  bool _valid() =>
      selected.length >= request.min &&
      (request.max == null || selected.length <= request.max);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(request.context == null
                ? 'Select Cards'
                : '${request.context}: Select Cards'),
            actions: _valid()
                ? [
                    IconButton(
                      icon: Icon(Icons.check),
                      tooltip: "Confirm",
                      onPressed: () {
                        request.completer.complete(
                            [for (var i in selected) request.cards[i]]);
                        Navigator.pop(context);
                      },
                    )
                  ]
                : []),
        body: CustomScrollView(slivers: [
          SliverList(
              delegate: SliverChildListDelegate([
            material.Card(
              elevation: 2,
              child: ListTile(
                  leading: Icon(Icons.announcement),
                  title: Text(request.prompt),
                  subtitle:
                      state.turn == null ? null : Text(_turnMsg(state.turn))),
            ),
          ])),
          SliverGrid.extent(
            maxCrossAxisExtent: 300,
            childAspectRatio: 0.625,
            children: [
              for (var i = 0; i < request.cards.length; i++)
                InkWell(
                  onTap: () {
                    setState(() {
                      if (selected.contains(i)) {
                        if (request.min == 1 && request.max == 1) return;
                        selected.remove(i);
                      } else {
                        if (request.max == 1) {
                          selected.clear();
                        }
                        if (request.max == null ||
                            selected.length < request.max) {
                          selected.add(i);
                        }
                      }
                    });
                  },
                  child: CardWidget(
                    state,
                    request.cards[i],
                    inSupply: [
                      EventType.BuyCard,
                      EventType.Contraband,
                      EventType.GainCard,
                      EventType.GainForOpponent
                    ].contains(request.event),
                    selectedOrder: _order(i),
                  ),
                )
            ],
          ),
        ]),
      );

  int _order(int index) {
    if (!selected.contains(index)) return null;
    if (request.max == 1) return 0;
    return selected.indexOf(index) + 1;
  }

  String _turnMsg(TurnMessage turn) {
    var a = turn.actions == 1 ? "" : "s";
    var b = turn.buys == 1 ? "" : "s";
    var c = turn.coins == 1 ? "" : "s";
    return "You have ${turn.actions} action$a, ${turn.buys} buy$b, and ${turn.coins} coin$c";
  }
}
