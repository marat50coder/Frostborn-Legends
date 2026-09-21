import 'package:flutter/painting.dart';

import '../core/game_assets.dart';

/// The five wheel bonuses. Each wheel has its own scatter; three matching
/// wheels anywhere on the reels start that wheel's round.
enum BonusGame {
  wheelSnow,
  wheelEmerald,
  wheelAmethyst,
  wheelFire,
  wheelFrost,
}

extension BonusGameInfo on BonusGame {
  String get title => switch (this) {
    BonusGame.wheelSnow => 'Snow Wheel',
    BonusGame.wheelEmerald => 'Emerald Wheel',
    BonusGame.wheelAmethyst => 'Amethyst Wheel',
    BonusGame.wheelFire => 'Fire Wheel',
    BonusGame.wheelFrost => 'Frostborn Wheel',
  };

  String get shortTitle => switch (this) {
    BonusGame.wheelSnow => 'SNOW',
    BonusGame.wheelEmerald => 'EMERALD',
    BonusGame.wheelAmethyst => 'AMETHYST',
    BonusGame.wheelFire => 'FIRE',
    BonusGame.wheelFrost => 'FROSTBORN',
  };

  String get tagline => switch (this) {
    BonusGame.wheelSnow => 'The first wheel of the hall, steady wins and the Mini',
    BonusGame.wheelEmerald => 'Richer segments and another shot at the Mini',
    BonusGame.wheelAmethyst => 'Heavy multipliers guarding the Minor jackpot',
    BonusGame.wheelFire => 'Blazing prizes with the Major jackpot in play',
    BonusGame.wheelFrost => 'The rarest wheel: two Majors and the Grand jackpot',
  };

  String get symbolId => switch (this) {
    BonusGame.wheelSnow => 'bonus_wheel_snow',
    BonusGame.wheelEmerald => 'bonus_wheel_emerald',
    BonusGame.wheelAmethyst => 'bonus_wheel_amethyst',
    BonusGame.wheelFire => 'bonus_wheel_fire',
    BonusGame.wheelFrost => 'bonus_wheel_frost',
  };

  String get artwork => switch (this) {
    BonusGame.wheelSnow => GameAssets.wheelSnow,
    BonusGame.wheelEmerald => GameAssets.wheelEmerald,
    BonusGame.wheelAmethyst => GameAssets.wheelAmethyst,
    BonusGame.wheelFire => GameAssets.wheelFire,
    BonusGame.wheelFrost => GameAssets.wheelGold,
  };

  Color get accent => switch (this) {
    BonusGame.wheelSnow => const Color(0xFFBFEEFF),
    BonusGame.wheelEmerald => const Color(0xFF47E07F),
    BonusGame.wheelAmethyst => const Color(0xFFB36BFF),
    BonusGame.wheelFire => const Color(0xFFFF8A2B),
    BonusGame.wheelFrost => const Color(0xFFFFF0B8),
  };
}

enum SymbolKind { regular, wild, bonus }

class SlotSymbol {
  const SlotSymbol({
    required this.id,
    required this.name,
    required this.kind,
    required this.weight,
    this.pays = const <int, int>{},
    this.bonus,
  });

  final String id;
  final String name;
  final SymbolKind kind;
  final int weight;
  final Map<int, int> pays;
  final BonusGame? bonus;

  String get asset => GameAssets.symbol(id);
}

class SlotSymbols {
  const SlotSymbols._();

  // Payouts tuned so the base game returns ~64% of the total bet and the
  // wheel bonus adds ~31% more, landing around 95% RTP over 100k spins.
  static const List<SlotSymbol> all = <SlotSymbol>[
    SlotSymbol(
      id: 'cherry',
      name: 'Cherries',
      kind: SymbolKind.regular,
      weight: 40,
      pays: <int, int>{2: 3, 3: 24, 4: 76, 5: 240},
    ),
    SlotSymbol(
      id: 'banana',
      name: 'Bananas',
      kind: SymbolKind.regular,
      weight: 36,
      pays: <int, int>{2: 3, 3: 24, 4: 76, 5: 240},
    ),
    SlotSymbol(
      id: 'grapes',
      name: 'Grapes',
      kind: SymbolKind.regular,
      weight: 32,
      pays: <int, int>{3: 32, 4: 96, 5: 310},
    ),
    SlotSymbol(
      id: 'orange',
      name: 'Orange',
      kind: SymbolKind.regular,
      weight: 29,
      pays: <int, int>{3: 32, 4: 96, 5: 310},
    ),
    SlotSymbol(
      id: 'apple',
      name: 'Apple',
      kind: SymbolKind.regular,
      weight: 24,
      pays: <int, int>{3: 44, 4: 128, 5: 430},
    ),
    SlotSymbol(
      id: 'watermelon',
      name: 'Watermelon',
      kind: SymbolKind.regular,
      weight: 21,
      pays: <int, int>{3: 48, 4: 150, 5: 520},
    ),
    SlotSymbol(
      id: 'strawberry',
      name: 'Strawberry',
      kind: SymbolKind.regular,
      weight: 18,
      pays: <int, int>{3: 48, 4: 150, 5: 520},
    ),
    SlotSymbol(
      id: 'pineapple',
      name: 'Pineapple',
      kind: SymbolKind.regular,
      weight: 15,
      pays: <int, int>{3: 70, 4: 210, 5: 700},
    ),
    SlotSymbol(
      id: 'bells',
      name: 'Golden Bells',
      kind: SymbolKind.regular,
      weight: 11,
      pays: <int, int>{3: 100, 4: 290, 5: 950},
    ),
    SlotSymbol(
      id: 'lollipop',
      name: 'Lollipop',
      kind: SymbolKind.regular,
      weight: 5,
      pays: <int, int>{3: 230, 4: 760, 5: 2300},
    ),
    SlotSymbol(
      id: 'gem',
      name: 'Frost Gem',
      kind: SymbolKind.regular,
      weight: 3,
      pays: <int, int>{3: 440, 4: 1550, 5: 5400},
    ),
    SlotSymbol(
      id: 'bonus_fish',
      name: 'Frost Fish',
      kind: SymbolKind.regular,
      weight: 12,
      pays: <int, int>{3: 54, 4: 160, 5: 550},
    ),
    SlotSymbol(
      id: 'bonus_zeus',
      name: 'Zeus',
      kind: SymbolKind.regular,
      weight: 9,
      pays: <int, int>{3: 74, 4: 210, 5: 740},
    ),
    SlotSymbol(
      id: 'bonus_joker',
      name: 'Joker',
      kind: SymbolKind.regular,
      weight: 9,
      pays: <int, int>{3: 74, 4: 210, 5: 740},
    ),
    SlotSymbol(
      id: 'bonus_winter',
      name: 'Winter Scout',
      kind: SymbolKind.regular,
      weight: 12,
      pays: <int, int>{3: 54, 4: 160, 5: 550},
    ),
    SlotSymbol(
      id: 'bar',
      name: 'Bar',
      kind: SymbolKind.wild,
      weight: 8,
      pays: <int, int>{3: 140, 4: 400, 5: 1250},
    ),
    SlotSymbol(
      id: 'wild',
      name: 'Jester',
      kind: SymbolKind.regular,
      weight: 10,
      pays: <int, int>{3: 70, 4: 200, 5: 660},
    ),
    SlotSymbol(
      id: 'bonus_wheel_snow',
      name: 'Snow Wheel',
      kind: SymbolKind.bonus,
      weight: 12,
      bonus: BonusGame.wheelSnow,
    ),
    SlotSymbol(
      id: 'bonus_wheel_emerald',
      name: 'Emerald Wheel',
      kind: SymbolKind.bonus,
      weight: 10,
      bonus: BonusGame.wheelEmerald,
    ),
    SlotSymbol(
      id: 'bonus_wheel_amethyst',
      name: 'Amethyst Wheel',
      kind: SymbolKind.bonus,
      weight: 8,
      bonus: BonusGame.wheelAmethyst,
    ),
    SlotSymbol(
      id: 'bonus_wheel_fire',
      name: 'Fire Wheel',
      kind: SymbolKind.bonus,
      weight: 6,
      bonus: BonusGame.wheelFire,
    ),
    SlotSymbol(
      id: 'bonus_wheel_frost',
      name: 'Frostborn Wheel',
      kind: SymbolKind.bonus,
      weight: 5,
      bonus: BonusGame.wheelFrost,
    ),
  ];

  static final Map<String, SlotSymbol> byId = <String, SlotSymbol>{
    for (final SlotSymbol symbol in all) symbol.id: symbol,
  };

  static final List<SlotSymbol> regular = all
      .where((SlotSymbol s) => s.kind == SymbolKind.regular)
      .toList(growable: false);

  static final List<SlotSymbol> bonuses = all
      .where((SlotSymbol s) => s.kind == SymbolKind.bonus)
      .toList(growable: false);

  static const String wildId = 'bar';
  static const String barId = 'bar';

  static bool isWild(String id) => id == barId;

  static SlotSymbol of(String id) => byId[id]!;
}
