import 'package:flutter/material.dart';

import 'package:dominion_server/client.dart';

import 'src/routes/game.dart';

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
    client.startSpectating('first');
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'Dominion', home: GameScreen(client));
}
