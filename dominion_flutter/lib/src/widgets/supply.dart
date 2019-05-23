import 'package:flutter/material.dart';

import 'package:dominion_core/dominion_core.dart';
import 'package:dominion_server/client.dart';

import 'card.dart';
import '../state_utils.dart';

class SupplyWidget extends StatelessWidget {
  final GameState state;
  final Supply supply;

  SupplyWidget(this.state, this.supply);

  @override
  Widget build(BuildContext context) => GridView.extent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 0.625,
        children: [
          for (var card in supply?.cardsInSupply ?? [])
            CardWidget(state, card, inSupply: true),
        ],
      );
}

Widget makeSupplyWidget(GameState state) =>
    withSupply(state, builder: (supply) => SupplyWidget(state, supply));
