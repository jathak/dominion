// Copyright (c) 2015, Jack Thakar. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library intrigue;

import 'package:dominion_core/dominion_core.dart';

import 'dart:async';

void load() {
  CardRegistry.register(Embargo.instance);
  CardRegistry.register(Haven.instance);
  CardRegistry.register(Lighthouse.instance);
  CardRegistry.register(NativeVillage.instance);
  CardRegistry.register(PearlDiver.instance);
  CardRegistry.register(Ambassador.instance);
  CardRegistry.register(FishingVillage.instance);
  CardRegistry.register(Lookout.instance);
  CardRegistry.register(Smugglers.instance);
  CardRegistry.register(Warehouse.instance);
  CardRegistry.register(Caravan.instance);
  CardRegistry.register(Cutpurse.instance);
  CardRegistry.register(Island.instance);
  CardRegistry.register(Navigator.instance);
  CardRegistry.register(PirateShip.instance);
  CardRegistry.register(Salvager.instance);
  CardRegistry.register(SeaHag.instance);
  CardRegistry.register(TreasureMap.instance);
  CardRegistry.register(Bazaar.instance);
  CardRegistry.register(Explorer.instance);
  CardRegistry.register(GhostShip.instance);
  CardRegistry.register(MerchantShip.instance);
  CardRegistry.register(Outpost.instance);
  CardRegistry.register(Tactician.instance);
  CardRegistry.register(Treasury.instance);
  CardRegistry.register(Wharf.instance);
}

abstract class Seaside {
  final String expansion = "Seaside";
}

class Embargo extends ActionCard with Seaside {
  Embargo._();
  static Embargo instance = new Embargo._();

  final int cost = 2;
  final String name = "Embargo";

  onPlay(Player player) async {}
}
