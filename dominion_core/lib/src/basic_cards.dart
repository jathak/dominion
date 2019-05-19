part of dominion_core;

// Basic Treasure Cards

class Copper extends Card with Treasure {
  Copper._();
  static Copper instance = Copper._();

  final int cost = 0;
  final String name = "Copper";

  final int value = 1;

  int supplyCount(int playerCount) => 60 - 7 * playerCount;
}

class Silver extends Card with Treasure {
  Silver._();
  static Silver instance = Silver._();

  final int cost = 3;
  final String name = "Silver";

  final int value = 2;

  int supplyCount(int playerCount) => 40;
}

class Gold extends Card with Treasure {
  Gold._();
  static Gold instance = Gold._();

  final int cost = 6;
  final String name = "Gold";

  final int value = 3;

  int supplyCount(int playerCount) => 30;
}

class Platinum extends Card with Treasure {
  Platinum._();
  static Platinum instance = Platinum._();

  final int cost = 9;
  final String name = "Platinum";

  final int value = 5;

  int supplyCount(int playerCount) => 12;
}

// Basic Victory Point Cards

class Estate extends Card with Victory {
  Estate._();
  static Estate instance = Estate._();

  final int cost = 2;
  final String name = "Estate";

  final int points = 1;
}

class Duchy extends Card with Victory {
  Duchy._();
  static Duchy instance = Duchy._();

  final int cost = 5;
  final String name = "Duchy";

  final int points = 3;
}

class Province extends Card with Victory {
  Province._();
  static Province instance = Province._();

  final int cost = 8;
  final String name = "Province";

  final int points = 6;

  int supplyCount(int playerCount) {
    if (playerCount > 4) {
      return 3 * playerCount;
    }
    return super.supplyCount(playerCount);
  }
}

class Colony extends Card with Victory {
  Colony._();
  static Colony instance = Colony._();

  final int cost = 11;
  final String name = "Colony";

  final int points = 10;
}

// Curse card
class Curse extends Card implements VictoryOrCurse {
  Curse._();
  static Curse instance = Curse._();

  final int cost = 0;
  final String name = "Curse";

  final int points = -1;

  int supplyCount(int playerCount) => 10 * (playerCount - 1);

  int getVictoryPoints(Player player) => points;
}

// Potion card
class Potion extends Card with Treasure {
  Potion._();
  static Potion instance = Potion._();

  final int cost = 4;
  final String name = "Potion";

  final int value = 0;

  int supplyCount(int playerCount) => 16;

  onPlay(Player player) async {
    player.turn.potions += 1;
  }
}
