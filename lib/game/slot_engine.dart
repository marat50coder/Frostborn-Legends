import 'dart:math';

import 'package:flutter/foundation.dart';

import 'slot_symbols.dart';

/// 20 fixed paylines over a 5x3 grid. Each entry lists the row index per reel.
const List<List<int>> kPaylines = <List<int>>[
  <int>[1, 1, 1, 1, 1],
  <int>[0, 0, 0, 0, 0],
  <int>[2, 2, 2, 2, 2],
  <int>[0, 1, 2, 1, 0],
  <int>[2, 1, 0, 1, 2],
  <int>[1, 0, 0, 0, 1],
  <int>[1, 2, 2, 2, 1],
  <int>[0, 0, 1, 2, 2],
  <int>[2, 2, 1, 0, 0],
  <int>[1, 0, 1, 2, 1],
  <int>[1, 2, 1, 0, 1],
  <int>[0, 1, 1, 1, 0],
  <int>[2, 1, 1, 1, 2],
  <int>[1, 1, 0, 1, 1],
  <int>[1, 1, 2, 1, 1],
  <int>[0, 1, 0, 1, 0],
  <int>[2, 1, 2, 1, 2],
  <int>[1, 0, 2, 0, 1],
  <int>[1, 2, 0, 2, 1],
  <int>[0, 2, 0, 2, 0],
];

const int kReels = 5;
const int kRows = 3;

class LineWin {
  const LineWin({
    required this.lineIndex,
    required this.symbolId,
    required this.count,
    required this.coins,
  });

  final int lineIndex;
  final String symbolId;
  final int count;
  final int coins;

  /// Grid cells covered by the winning part of the line, as (reel, row).
  List<(int, int)> get cells => <(int, int)>[
    for (int reel = 0; reel < count; reel++) (reel, kPaylines[lineIndex][reel]),
  ];
}

class SpinResult {
  const SpinResult({
    required this.grid,
    required this.lineWins,
    required this.lineCoins,
    required this.triggeredBonus,
    required this.bonusCount,
    required this.bonusCells,
  });

  /// Symbol ids indexed as `grid[reel][row]`.
  final List<List<String>> grid;
  final List<LineWin> lineWins;
  final int lineCoins;
  final BonusGame? triggeredBonus;
  final int bonusCount;
  final List<(int, int)> bonusCells;

  Set<(int, int)> get winningCells => <(int, int)>{
    for (final LineWin win in lineWins) ...win.cells,
    ...bonusCells,
  };
}

class SlotEngine {
  SlotEngine({Random? random}) : _random = random ?? Random() {
    for (int reel = 0; reel < kReels; reel++) {
      final List<String> pool = <String>[];
      for (final SlotSymbol symbol in SlotSymbols.all) {
        for (int i = 0; i < symbol.weight; i++) {
          pool.add(symbol.id);
        }
      }
      _pools.add(pool);
    }
  }

  final Random _random;
  final List<List<String>> _pools = <List<String>>[];

  /// Draws a single reel column. A reel never shows the same bonus symbol
  /// twice, so three scatters always means three different reels.
  List<String> _spinColumn(int reel) {
    final List<String> pool = _pools[reel];
    final List<String> column = <String>[];
    final Set<String> seenBonus = <String>{};
    while (column.length < kRows) {
      final String id = pool[_random.nextInt(pool.length)];
      if (SlotSymbols.of(id).kind == SymbolKind.bonus) {
        if (!seenBonus.add(id)) continue;
      }
      column.add(id);
    }
    return column;
  }

  List<List<String>> randomGrid() =>
      List<List<String>>.generate(kReels, _spinColumn, growable: false);

  /// Evaluates a grid. [lineBet] is the stake on a single payline.
  SpinResult evaluate(List<List<String>> grid, int lineBet) {
    final List<LineWin> wins = <LineWin>[];
    int total = 0;

    for (int lineIndex = 0; lineIndex < kPaylines.length; lineIndex++) {
      final List<int> line = kPaylines[lineIndex];
      final List<String> sequence = <String>[
        for (int reel = 0; reel < kReels; reel++) grid[reel][line[reel]],
      ];

      String? base;
      for (final String id in sequence) {
        final SlotSymbol symbol = SlotSymbols.of(id);
        if (symbol.kind == SymbolKind.regular) {
          base = id;
          break;
        }
        if (symbol.kind != SymbolKind.wild) break;
      }

      int count = 0;
      if (base == null) {
        // A line of only Bars pays the Bar table.
        for (final String id in sequence) {
          if (SlotSymbols.isWild(id)) {
            count++;
          } else {
            break;
          }
        }
        base = SlotSymbols.barId;
      } else {
        for (final String id in sequence) {
          if (id == base || SlotSymbols.isWild(id)) {
            count++;
          } else {
            break;
          }
        }
      }

      final int? pay = SlotSymbols.of(base).pays[count];
      if (pay == null) continue;
      final int coins = pay * lineBet;
      total += coins;
      wins.add(
        LineWin(lineIndex: lineIndex, symbolId: base, count: count, coins: coins),
      );
    }

    wins.sort((LineWin a, LineWin b) => b.coins.compareTo(a.coins));

    BonusGame? triggered;
    int bonusCount = 0;
    List<(int, int)> bonusCells = const <(int, int)>[];
    for (final SlotSymbol symbol in SlotSymbols.bonuses) {
      final List<(int, int)> cells = <(int, int)>[];
      for (int reel = 0; reel < kReels; reel++) {
        for (int row = 0; row < kRows; row++) {
          if (grid[reel][row] == symbol.id) cells.add((reel, row));
        }
      }
      if (cells.length >= 3 && cells.length > bonusCount) {
        triggered = symbol.bonus;
        bonusCount = cells.length;
        bonusCells = cells;
      }
    }

    return SpinResult(
      grid: grid,
      lineWins: wins,
      lineCoins: total,
      triggeredBonus: triggered,
      bonusCount: bonusCount,
      bonusCells: bonusCells,
    );
  }

  SpinResult spin(int lineBet) {
    // Debug builds get a heavily loaded spin so we can showcase the game
    // without waiting for RNG luck. Release builds always use fair RNG.
    if (kDebugMode) return _debugLuckySpin(lineBet);
    return evaluate(randomGrid(), lineBet);
  }

  int _debugSpins = 0;

  /// Debug-only helper: forces a bonus every few spins and otherwise plants a
  /// winning payline of a mid/high-tier symbol on top of a random grid.
  SpinResult _debugLuckySpin(int lineBet) {
    final List<List<String>> grid = randomGrid();
    _debugSpins++;

    // Every 6th spin fire a full bonus trigger so the wheel round is
    // reachable within a handful of taps.
    if (_debugSpins % 6 == 0) {
      final List<SlotSymbol> bonuses = SlotSymbols.bonuses;
      final SlotSymbol bonus = bonuses[_random.nextInt(bonuses.length)];
      // Drop the scatter on three separate reels so the trigger detector fires.
      const List<int> reels = <int>[0, 2, 4];
      for (final int reel in reels) {
        grid[reel][_random.nextInt(kRows)] = bonus.id;
      }
      return evaluate(grid, lineBet);
    }

    // Otherwise plant a healthy payline. Bias toward the juicier symbols so
    // the win banner has something to celebrate.
    final List<SlotSymbol> juicy = <SlotSymbol>[
      for (final SlotSymbol s in SlotSymbols.regular)
        if ((s.pays[3] ?? 0) >= 44 && s.kind == SymbolKind.regular) s,
    ];
    final SlotSymbol pick = juicy[_random.nextInt(juicy.length)];
    final int lineIndex = _random.nextInt(kPaylines.length);
    final int matchCount = 3 + _random.nextInt(3); // 3, 4 or 5 in a row.
    final List<int> line = kPaylines[lineIndex];
    for (int reel = 0; reel < matchCount; reel++) {
      grid[reel][line[reel]] = pick.id;
    }
    // Sprinkle a BAR wild on the reel just after the streak (when it exists)
    // so extended lines pop even when the RNG-filled tail happens to break.
    if (matchCount < kReels && _debugSpins.isOdd) {
      grid[matchCount][line[matchCount]] = SlotSymbols.barId;
    }
    return evaluate(grid, lineBet);
  }

  /// Spin used by free-spin rounds: bonus symbols are swapped out for regular
  /// ones so a bonus cannot retrigger inside another bonus.
  SpinResult spinWithoutBonuses(int lineBet, {int extraWilds = 0}) {
    final List<List<String>> grid = randomGrid();
    for (int reel = 0; reel < kReels; reel++) {
      for (int row = 0; row < kRows; row++) {
        if (SlotSymbols.of(grid[reel][row]).kind == SymbolKind.bonus) {
          grid[reel][row] = _randomRegularId();
        }
      }
    }
    for (int i = 0; i < extraWilds; i++) {
      final int reel = 1 + _random.nextInt(kReels - 2);
      final int row = _random.nextInt(kRows);
      grid[reel][row] = SlotSymbols.barId;
    }
    return evaluate(grid, lineBet);
  }

  String _randomRegularId() {
    int total = 0;
    for (final SlotSymbol symbol in SlotSymbols.regular) {
      total += symbol.weight;
    }
    int roll = _random.nextInt(total);
    for (final SlotSymbol symbol in SlotSymbols.regular) {
      roll -= symbol.weight;
      if (roll < 0) return symbol.id;
    }
    return SlotSymbols.regular.first.id;
  }

  /// Random symbol used to fill the blurred strip while a reel is spinning.
  String decorativeSymbol(int reel) {
    final List<String> pool = _pools[reel];
    return pool[_random.nextInt(pool.length)];
  }
}
