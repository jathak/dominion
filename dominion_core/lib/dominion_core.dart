library dominion_core;

import 'dart:async';

@MirrorsUsed(metaTargets: card)
import 'dart:mirrors';

part 'src/basic_cards.dart';
part 'src/card_models.dart';
part 'src/card_registry.dart';
part 'src/card_structs.dart';
part 'src/engine.dart';
part 'src/engine_structs.dart';


class _CardAnnotation { const _CardAnnotation(); }

const card = const _CardAnnotation();
