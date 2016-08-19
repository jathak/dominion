part of dominion_core;

// Basic Treasure Cards

class Copper extends TreasureCard {
    Copper._();
    static Copper instance = new Copper._();
    
    final int cost = 0;
    final String name = "Copper";
    
    final int value = 1;
    
    int supplyCount(int playerCount) => 60 - 7*playerCount;
    
    @override
    int getTreasureValue(Turn turn) {
        int actualValue = value;
        if (turn.misc.containsKey("coppersmithsPlayed")) {
            actualValue += turn.misc['coppersmithsPlayed'];
        }
        return actualValue;
    }
}

class Silver extends TreasureCard {
    Silver._();
    static Silver instance = new Silver._();
    
    final int cost = 3;
    final String name = "Silver";
    
    final int value = 2;
    
    int supplyCount(int playerCount) => 40;
}

class Gold extends TreasureCard {
    Gold._();
    static Gold instance = new Gold._();
    
    final int cost = 6;
    final String name = "Gold";
    
    final int value = 3;
    
    int supplyCount(int playerCount) => 30;
}

class Platinum extends TreasureCard {
    Platinum._();
    static Platinum instance = new Platinum._();
    
    final int cost = 9;
    final String name = "Platinum";
    
    final int value = 5;
    
    int supplyCount(int playerCount) => 12;
}


// Basic Victory Point Cards

class Estate extends VictoryCard {
    Estate._();
    static Estate instance = new Estate._();
    
    final int cost = 2;
    final String name = "Estate";
    
    final int points = 1;
}

class Duchy extends VictoryCard {
    Duchy._();
    static Duchy instance = new Duchy._();
    
    final int cost = 5;
    final String name = "Duchy";
    
    final int points = 3;
}

class Province extends VictoryCard {
    Province._();
    static Province instance = new Province._();
    
    final int cost = 8;
    final String name = "Province";
    
    final int points = 6;
    
    int supplyCount(int playerCount) {
        if (playerCount > 4) {
            return 3*playerCount;
        }
        return super.supplyCount(playerCount);
    }
}

class Colony extends VictoryCard {
    Colony._();
    static Colony instance = new Colony._();
    
    final int cost = 11;
    final String name = "Colony";
    
    final int points = 10;
}

// Curse card
class Curse extends CurseCard {
    Curse._();
    static Curse instance = new Curse._();
    
    final int cost = 0;
    final String name = "Curse";
    
    final int points = -1;
    
    int supplyCount(int playerCount) => 10*(playerCount - 1);
}

// Potion card
class Potion extends TreasureCard {
    Potion._();
    static Potion instance = new Potion._();
    
    final int cost = 4;
    final String name = "Potion";
    
    final int value = 0;
    
    int supplyCount(int playerCount) => 16;
    
    onPlay(Player player) async {
        player.turn.potions += 1;
    }
}
