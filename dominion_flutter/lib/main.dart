import 'package:flutter/material.dart';

import 'package:dominion_server/client.dart';

import 'src/state_utils.dart';
import 'src/widgets/supply.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DominionClient client;

  @override
  void initState() {
    super.initState();
    client = DominionClient("dominion.defiant.jenthakar.com");
    client.state.onCurrentPlayerChange.listen((player) => setState(() {}));
    client.startSpectating('first');
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Dominion',
        home: Scaffold(
            appBar: AppBar(
              title: withCurrentPlayer(
                client.state,
                builder: (player) => Text('Current Player: $player'),
              ),
            ),
            body: makeSupplyWidget(client.state)),
      );
}
