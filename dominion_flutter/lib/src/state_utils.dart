/// Helper methods for building widgets that depend on game state.

import 'package:flutter/widgets.dart';

import 'package:dominion_core/dominion_core.dart';
import 'package:dominion_server/client.dart';

Widget _build<T>(T initial, Stream<T> stream, Widget builder(T data)) =>
    StreamBuilder(
        initialData: initial,
        stream: stream,
        builder: (context, snapshot) => builder(snapshot.data));

Widget withSupply(GameState state, {@required Widget builder(Supply supply)}) =>
    _build(state.supply, state.onSupplyChange, builder);

Widget withSupplyCount(GameState state,
        {@required Card card, @required Widget builder(int count)}) =>
    _build(state.supply?.supplyOf(card)?.count, state.onSupplyCountChange(card),
        builder);

Widget withCardCost(GameState state,
        {@required Card card, @required Widget builder(int currentCost)}) =>
    _build(state.supply?.supplyOf(card)?.currentCost,
        state.onCardCostChange(card), builder);

Widget withEmbargoTokens(GameState state,
        {@required Card card, @required Widget builder(int embargoTokens)}) =>
    _build(state.supply?.supplyOf(card)?.embargoTokens,
        state.onSupplyEmbargoChange(card), builder);

Widget withSupplyPile(GameState state,
        {@required Card card, @required Widget builder(SupplyPile pile)}) =>
    _build(
        state.supply?.supplyOf(card), state.onSupplyPileChange(card), builder);

Widget withCurrentPlayer(GameState state,
        {@required Widget builder(String currentPlayer)}) =>
    _build(state.currentPlayer, state.onCurrentPlayerChange, builder);

Widget withHand(GameState state, {@required Widget builder(List<Card> hand)}) =>
    _build(state.hand, state.onHandChange, builder);

Widget withTurn(GameState state,
        {@required Widget builder(TurnMessage turn)}) =>
    _build(state.turn, state.onTurnChange, builder);

Widget withInPlay(GameState state,
        {@required Widget builder(List<Card> inPlay)}) =>
    _build(state.inPlay, state.onInPlayChange, builder);

Widget withDeckSize(GameState state,
        {@required Widget builder(int deckSize)}) =>
    _build(state.deckSize, state.onDeckSizeChange, builder);

Widget withDiscardSize(GameState state,
        {@required Widget builder(int discardSize)}) =>
    _build(state.discardSize, state.onDiscardSizeChange, builder);

Widget withVpTokens(GameState state,
        {@required Widget builder(int vpTokens)}) =>
    _build(state.vpTokens, state.onVpTokensChange, builder);
