import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dominion_core/dominion_core.dart' as game;
import 'package:dominion_server/client.dart';

import '../state_utils.dart';

class CardWidget extends StatelessWidget {
  final GameState state;
  final game.Card card;
  final bool inSupply;
  final bool onlyHeader;
  CardWidget(this.state, this.card,
      {this.inSupply: false, this.onlyHeader: false});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        return Card(
          color: card is game.Treasure
              ? Colors.yellow[600]
              : card is game.Duration
                  ? Colors.orange
                  : card is game.Reaction
                      ? Colors.blue
                      : card is game.Victory
                          ? Colors.green
                          : card is game.Curse ? Colors.purple : Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          borderOnForeground: true,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                child: Text(
                  "$card",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (!onlyHeader)
                withCardCost(
                  state,
                  card: card,
                  builder: (cost) => _badge(
                        value: cost,
                        alignment: Alignment.bottomLeft,
                        background: Colors.amber,
                        textColor: Colors.black,
                        ratio: constraints.maxWidth / 300,
                      ),
                ),
              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                child: imageForCard(
                  card,
                  ratio: constraints.maxWidth / 300,
                  onlyHeader: onlyHeader,
                ),
              ),
              if (!onlyHeader)
                withCardCost(
                  state,
                  card: card,
                  builder: (cost) => cost == null || cost == card.cost
                      ? Container(width: 0, height: 0)
                      : _badge(
                          value: cost,
                          alignment: Alignment.bottomLeft,
                          background: Colors.amber,
                          textColor: Colors.red[800],
                          ratio: constraints.maxWidth / 300,
                        ),
                ),
              if (inSupply && !onlyHeader)
                withSupplyCount(
                  state,
                  card: card,
                  builder: (count) => _badge(
                        value: count,
                        alignment: Alignment.topRight,
                        background: Colors.blue,
                        ratio: pow(constraints.maxWidth / 300, 0.5),
                      ),
                )
            ],
          ),
        );
      });
}

Widget imageForCard(game.Card card,
    {int width: 300, double ratio: 1.0, bool onlyHeader: false}) {
  var path = "http://wiki.dominionstrategy.com/index.php/"
      "Special:FilePath/${card.name.replaceAll(' ', '_')}.jpg?width=$width";
  var footerHeight = 54.0;
  if (card.expansion == null) footerHeight = 64.0;
  if (card is game.Curse) footerHeight = 60.0;
  return Stack(
    alignment: Alignment.bottomCenter,
    children: [
      Image.network(
        path,
        fit: BoxFit.fitWidth,
        width: width.toDouble(),
        height: onlyHeader ? 33 * ratio : 480 * ratio,
        alignment: onlyHeader && card.expansion == null
            ? Alignment(0, -0.93)
            : Alignment.topCenter,
      ),
      if (!onlyHeader)
        Container(
          alignment: Alignment.bottomCenter,
          width: width.toDouble(),
          height: footerHeight * ratio,
          child: ClipRect(
            child: Image.network(
              path,
              fit: BoxFit.fitWidth,
              width: width.toDouble(),
              alignment: Alignment.bottomCenter,
            ),
          ),
        )
    ],
  );
}

Widget _badge(
        {@required int value,
        @required Alignment alignment,
        @required Color background,
        Color textColor: Colors.white,
        double ratio: 1.0}) =>
    Container(
      width: 300,
      height: 480,
      padding: EdgeInsets.only(
        left: 14 * ratio,
        bottom: 18 * ratio,
        top: 8 * ratio,
        right: 8 * ratio,
      ),
      alignment: alignment,
      child: Container(
        width: 36 * ratio,
        height: 36 * ratio,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: background,
          shape: CircleBorder(),
        ),
        child: Text(
          "$value",
          style: TextStyle(
            fontSize: 20 * pow(ratio, 0.5),
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
