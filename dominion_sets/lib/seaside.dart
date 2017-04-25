// Copyright (c) 2015, Jack Thakar. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library intrigue;

import 'package:dominion_core/dominion_core.dart';

abstract class Seaside {
  final String expansion = "Seaside";
}

@card
class Embargo extends ActionCard with Seaside {
  Embargo._();
  static Embargo instance = new Embargo._();

  final int cost = 2;
  final String name = "Embargo";

  onPlay(Player player) async {}
}
