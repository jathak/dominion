import 'package:flutter/material.dart' hide Card;

import 'package:dominion_server/client.dart';
import 'package:dominion_core/dominion_core.dart';

import '../state_utils.dart';
import '../widgets/card.dart';
import 'supply.dart';

class GameScreen extends StatelessWidget {
  static const routeName = '/game';
  final DominionClient client;

  GameScreen(this.client);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Game')),
        body: CustomScrollView(slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              ListTile(
                leading: Icon(Icons.account_balance_wallet),
                title: Text('View Supply'),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SupplyScreen(client)));
                },
              ),
              ListTile(
                title: withCurrentPlayer(
                  client.state,
                  builder: (player) => Text(
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
          withInPlay(
            client.state,
            builder: (cards) => _headers(client.state, "In Play", cards),
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
            builder: (cards) => _cards(client.state, cards),
          ),
        ]),
      );
}

String _plural(int count, String thing) =>
    '$count $thing${count == 1 ? '' : 's'}';

Widget _headers(GameState state, String title, List<Card> cards) => SliverList(
      delegate: SliverChildListDelegate([
        ListTile(title: Text(title, style: TextStyle(fontSize: 20))),
        for (var card in cards ?? []) CardWidget(state, card, onlyHeader: true)
      ]),
    );
Widget _cards(GameState state, List<Card> cards) => SliverGrid.extent(
      maxCrossAxisExtent: 300,
      childAspectRatio: 0.625,
      children: [for (var card in cards ?? []) CardWidget(state, card)],
    );
