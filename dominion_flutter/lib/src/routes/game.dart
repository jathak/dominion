import 'package:dominion_flutter/src/routes/card_selector.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/material.dart' as material show Card;

import 'package:dominion_server/client.dart';
import 'package:dominion_core/dominion_core.dart';

import '../controller.dart';
import '../state_utils.dart';
import '../widgets/card.dart';
import 'supply.dart';

class GameScreen extends StatelessWidget {
  static const routeName = '/game';
  final DominionClient<FlutterController> client;

  GameScreen(this.client);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.grey[300],
        appBar: AppBar(title: Text('Game')),
        body: CustomScrollView(slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              material.Card(
                elevation: 2,
                child: ListTile(
                  leading: Icon(Icons.account_balance_wallet),
                  title: Text('View Supply'),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SupplyScreen(client)));
                  },
                ),
              ),
              material.Card(
                elevation: 2,
                child: Column(children: [
                  ListTile(
                    title: withCurrentPlayer(
                      client.state,
                      builder: (player) => player == null
                          ? Container(width: 0, height: 0)
                          : Text(
                              player == client.username
                                  ? "Your Turn"
                                  : "$player's Turn",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  withTurn(
                    client.state,
                    builder: (turn) => turn == null
                        ? Container(width: 0, height: 0)
                        : ListTile(
                            title: Text("${turn.phaseWord} Phase\n" +
                                _plural(turn.actions, "Action") +
                                '\n' +
                                _plural(turn.buys, "Buy") +
                                '\n' +
                                _plural(turn.coins, "Coin") +
                                '\n'),
                          ),
                  ),
                ]),
              ),
              withPlayerRequest(
                client.controller,
                builder: (request) => request == null
                    ? Container(width: 0, height: 0)
                    : material.Card(
                        color: client.username == client.state.currentPlayer
                            ? Colors.green[700]
                            : Colors.orange[700],
                        elevation: 2,
                        child: ListTile(
                          leading: Icon(
                            Icons.announcement,
                            color: Colors.white,
                          ),
                          title: Text(
                            request.prompt,
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            if (request is SelectCards) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => CardSelectionScreen(
                                          client.state, request)));
                            }
                          },
                        ),
                      ),
              ),
            ]),
          ),
          withInPlay(
            client.state,
            builder: (cards) => _headerList("In Play", cards),
          ),
          SliverList(
              delegate: SliverChildListDelegate([
            ListTile(
                title: Text(
                    "${client.username == null ? 'Their' : 'Your'} Hand",
                    style: TextStyle(fontSize: 20)))
          ])),
          withHand(
            client.state,
            builder: (cards) => _cardGrid(cards),
          ),
        ]),
      );

  String _plural(int count, String thing) =>
      '$count $thing${count == 1 ? '' : 's'}';

  Widget _headerList(String title, List<Card> cards) => SliverList(
        delegate: SliverChildListDelegate([
          ListTile(title: Text(title, style: TextStyle(fontSize: 20))),
          for (var card in cards ?? [])
            CardWidget(client.state, card, onlyHeader: true)
        ]),
      );
  Widget _cardGrid(List<Card> cards) => SliverGrid.extent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 0.625,
        children: [
          for (var card in cards ?? []) CardWidget(client.state, card)
        ],
      );
}
