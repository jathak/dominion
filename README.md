# dominion

This is an implementation of the [Dominion][wiki] card game in Dart.

While it's playable, please play the [official online implementation][online]
or buy the [physical game][board-game] from your local game store instead.

I wrote this as a personal project to play around with, though I'm posting the
source code because I imagine it could be useful in playtesting custom cards or
writing bots.

The base set and Intrigue are both implemented, though Intrigue isn't thoroughly
tested. I might get around to adding Seaside or Prosperity eventually, though
both of those will require additional mechanics implemented in the core game
engine. Note: I implemented the base set and Intrigue cards before the second
edition was released, so they currently use the first edition cards.

Running this requires Dart 1.13 or higher. It is divided into four packages:

* `dominion_core` implements the core game engine, including the basic treasures
and victory cards (anything not in the kingdom)

* `dominion_sets` contains a library for each implemented expansion (currently
the base set and Intrigue). When one or more of these are imported, their cards
will be registered in `CardRegistry` (this is done reflectively, so you'll want
to suppress the unused import warning).

* `dominion_server` runs a web server (defaults to port 7777, include a port as
your only argument to override) that attempts to host the contents of
`dominion_web/build/web` as well as a web socket server for communication between
the server and multiple web interfaces. The server runs the engine and maintains
all game state.

* `dominion_web` is largely standalone. It depends on the message format used by
`dominion_server`, but does not import the game engine (it actually can't at the
moment, since the engine uses mirrors and mixins with superclasses). The server
expects the built web interface to be in `dominion_web/build/web`, so run
`pub build` from this directory before running the server. 


### How to Start a Game

1. `pub get` and `pub build` from `dominion_web`. This only needs to be run each
time the web interface is changed.
2. `pub get` and `dart bin/server.dart` from `dominion_server`. Add a port as
the only argument to change from the default port of 7777.
3. One player should go to `localhost:7777` (or wherever the server is hosted),
enter 10 kingdom cards and click the Create Game button. If you enter fewer than
10 cards, the rest of the kingdom will be chosen randomly.
4. Each player or spectator should go to `localhost:7777/game.html?id=<game id>`
and either enter a player name or leave it blank to become a spectator.
5. Once all players have joined, someone should click the Start Game button.
6. Spectators can join at any time.
7. Any clients connected with the same username are considered the same player.
Any client can take actions for that player.
8. If all clients playing as a particular player disconnect, the game is paused
until someone with the same username reconnects.
9. One way that works well to play is to have a spectator connect on a computer
to show the kingdom cards and current player's status and each player connects
on their phone.
10. [Ngrok](https://ngrok.com/) is a great tool that you can use to allow other
computers to connect to a locally run server.

### Tips for Development

* If you add any additional expansion libraries, I recommend adding a corresponding
test file to the `test` directory of `dominion_sets`. See `dominion_sets/test/base_test.dart`
for examples (Intrigue does not yet have all cards tested). You'll also want to
make sure to import the new library in `dominion_server/lib/game.dart` to make
sure your cards are included.

* Add the `@card` annotation on the line immediately above the class definition
to make a card available to the game engine.

* Card classes should be defined with a private constructor and a static `instance`
attribute that should contain the only instance of that card ever created.

* The `CardSource` and `CardTarget` abstract classes represent sources and
targets for cards respectively. `CardBuffer` represents both and is the most
common way the engine keeps track of where cards are. Any time a game action
causes a card to be moved somewhere, it should be put in the proper buffer.
`List<Card>` is only used when prompting the player to select cards or card
types.

* The game engine and cards make heavy use of async/await. Any action that could
potentially require player input is asynchronous, and should be awaited when called.
This allows the cards to be written as if all user input is made synchronously, even
though it's not.

* The web interface is separate from the server and game engine, so you can rebuild
it to make changes even while a game is running. If you plan on making frequent
changes, you should run the web interface from a separate server with `pub serve`
and then provide the URL of the engine server with a `url` query parameter.

[wiki]: https://en.wikipedia.org/wiki/Dominion_(card_game)
[board-game]: http://riograndegames.com/Game/278-Dominion
[online]: https://dominion.games
