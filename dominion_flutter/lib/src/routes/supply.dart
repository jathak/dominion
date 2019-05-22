import 'package:flutter/material.dart';

import 'package:dominion_server/client.dart';

import '../widgets/supply.dart';

class SupplyScreen extends StatelessWidget {
  static const routeName = '/game/supply';
  final DominionClient client;

  SupplyScreen(this.client);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Supply'),
        ),
        body: makeSupplyWidget(client.state),
      );
}
