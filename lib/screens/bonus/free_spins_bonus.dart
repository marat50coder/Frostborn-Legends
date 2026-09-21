import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/audio_service.dart';
import '../../core/game_assets.dart';
import '../../core/game_state.dart';
import '../../game/slot_engine.dart';
import '../../game/slot_symbols.dart';
import '../../widgets/frost_ui.dart';
import '../../widgets/reel_grid.dart';
import 'bonus_common.dart';

enum FreeSpinsMode {
  /// Zeus strikes random positions and turns them wild; the multiplier climbs
  /// as the round goes on.
  thunder,

  /// Every wild that lands stays locked for the rest of the round.
  stickyWilds,
}

class FreeSpinsBonus extends StatefulWidget {
  const FreeSpinsBonus({
    super.key,
    required this.totalBet,
    required this.lineBet,
    required this.scatterCount,
    required this.mode,
  });

  final int totalBet;
  final int lineBet;
  final int scatterCount;
  final FreeSpinsMode mode;

  @override
  State<FreeSpinsBonus> createState() => _FreeSpinsBonusState();
}

class _FreeSpinsBonusState extends State<FreeSpinsBonus> with SingleTickerProviderStateMixin {
  final SlotEngine _engine = SlotEngine();
  final Random _random = Random();

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  late int _spinsLeft = _baseSpins + (widget.scatterCount - 3) * 2;
  late List<List<String>> _grid = _engine.spinWithoutBonuses(widget.lineBet).grid;

  final Set<(int, int)> _sticky = <(int, int)>{};
  Set<(int, int)> _highlight = <(int, int)>{};
  int _spinToken = 0;
  int _spinsPlayed = 0;
  int _collected = 0;
  int _lastWin = 0;
  bool _running = false;
  bool _finished = false;

  int get _baseSpins => widget.mode == FreeSpinsMode.thunder ? 6 : 5;

  bool get _isThunder => widget.mode == FreeSpinsMode.thunder;

  /// Thunder doubles for the back half of the round; sticky wilds carry the
  /// Joker round on their own and stay at x1.
  int get _multiplier => _isThunder ? (_spinsPlayed >= _baseSpins ~/ 2 ? 2 : 1) : 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSpin());
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  Future<void> _runSpin() async {
    if (!mounted || _running || _finished || _spinsLeft <= 0) return;
    setState(() {
      _running = true;
      _highlight = <(int, int)>{};
      _lastWin = 0;
    });

    final int extraWilds = _isThunder ? _random.nextInt(2) : 0;
    final List<List<String>> grid = _engine.spinWithoutBonuses(
      widget.lineBet,
      extraWilds: extraWilds,
    ).grid;

    for (final (int, int) cell in _sticky) {
      grid[cell.$1][cell.$2] = SlotSymbols.wildId;
    }

    final SpinResult result = _engine.evaluate(grid, widget.lineBet);
    setState(() {
      _grid = result.grid;
      _spinToken++;
    });
    if (_isThunder && extraWilds > 0) _flash.forward(from: 0);

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await _present(result);
  }

  Future<void> _present(SpinResult result) async {
    if (widget.mode == FreeSpinsMode.stickyWilds) {
      for (int reel = 0; reel < kReels; reel++) {
        for (int row = 0; row < kRows; row++) {
          if (result.grid[reel][row] == SlotSymbols.wildId) _sticky.add((reel, row));
        }
      }
    }

    final int win = result.lineCoins * _multiplier;
    setState(() {
      _highlight = result.winningCells;
      _lastWin = win;
      _collected += win;
      _spinsPlayed++;
      _spinsLeft--;
      _running = false;
    });
    if (win > 0) AudioService.instance.reward();

    await Future<void>.delayed(Duration(milliseconds: win > 0 ? 1500 : 700));
    if (!mounted) return;

    if (_spinsLeft > 0) {
      await _runSpin();
    } else {
      _finished = true;
      await showBonusResult(
        context,
        coins: _collected,
        title: _isThunder ? 'Olympus rewarded you' : 'The Joker paid up',
        subtitle: '$_spinsPlayed free spins played.',
        artwork: _isThunder ? GameAssets.zeus : GameAssets.joker,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String character = _isThunder ? GameAssets.zeus : GameAssets.joker;

    return BonusScaffold(
      title: _isThunder ? 'Thunder of Olympus' : "Joker's Wild",
      subtitle: _isThunder
          ? 'Free spins left: $_spinsLeft   •   Multiplier x$_multiplier'
          : 'Free spins left: $_spinsLeft   •   Wilds stay locked',
      background: _isThunder ? GameAssets.bgCrystal : GameAssets.bgHall,
      collected: _collected,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Opacity(
                      opacity: 0.3,
                      child: Image.asset(character, fit: BoxFit.fitHeight),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AspectRatio(
                      aspectRatio: kReels / kRows,
                      child: ReelGrid(
                        engine: _engine,
                        grid: _grid,
                        spinToken: _spinToken,
                        highlightCells: _highlight,
                        stickyCells: widget.mode == FreeSpinsMode.stickyWilds
                            ? _sticky
                            : const <(int, int)>{},
                        reelDuration: const Duration(milliseconds: 620),
                        reelStagger: const Duration(milliseconds: 110),
                      ),
                    ),
                  ),
                ),
                if (_isThunder)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _flash,
                        builder: (BuildContext context, _) => Opacity(
                          opacity: (1 - _flash.value) * (_flash.isAnimating ? 0.55 : 0),
                          child: const ColoredBox(color: Color(0xFFBFE8FF)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
            child: Column(
              children: <Widget>[
                if (_lastWin > 0)
                  StrokeText(
                    'WIN ${formatCoins(_lastWin)}',
                    style: AppText.title(24),
                  )
                else
                  Text(
                    _isThunder
                        ? 'Every lightning strike locks in a new wild.'
                        : 'Wilds stay on the reels until the round ends.',
                    textAlign: TextAlign.center,
                    style: AppText.body(12).copyWith(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
