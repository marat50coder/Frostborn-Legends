import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio_service.dart';
import '../core/game_assets.dart';
import '../core/game_state.dart';
import '../game/jackpots.dart';
import '../game/slot_engine.dart';
import '../game/slot_symbols.dart';
import '../widgets/frost_ui.dart';
import '../widgets/reel_grid.dart';
import 'bonus/bonus_common.dart';
import 'bonus/wheel_bonus.dart';
import 'paytable_screen.dart';
import 'settings_screen.dart';

class SlotScreen extends StatefulWidget {
  const SlotScreen({super.key});

  @override
  State<SlotScreen> createState() => _SlotScreenState();
}

class _SlotScreenState extends State<SlotScreen> {
  final SlotEngine _engine = SlotEngine();

  late List<List<String>> _grid = _engine.randomGrid();
  SpinResult? _result;
  Set<(int, int)> _highlight = <(int, int)>{};
  List<int>? _activeLine;
  String? _lineLabel;
  Timer? _cycleTimer;
  int _cycleIndex = 0;

  int _spinToken = 0;
  int _winDisplay = 0;
  bool _spinning = false;
  bool _bonusRunning = false;
  bool _autoPlay = false;

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  bool get _busy => _spinning || _bonusRunning;

  void _stopPresentation() {
    _cycleTimer?.cancel();
    _cycleTimer = null;
    _activeLine = null;
    _lineLabel = null;
    _highlight = <(int, int)>{};
  }

  void _spin() {
    if (_busy) return;
    final GameState state = context.read<GameState>();
    if (!state.canAffordSpin) {
      setState(() => _autoPlay = false);
      AudioService.instance.error();
      _showOutOfCoins();
      return;
    }

    state.placeBet();
    final SpinResult result = _engine.spin(state.lineBet);
    setState(() {
      _stopPresentation();
      _result = result;
      _grid = result.grid;
      _spinToken++;
      _spinning = true;
      _winDisplay = 0;
    });
  }

  Future<void> _onReelsStopped() async {
    if (!mounted) return;
    final SpinResult? result = _result;
    if (result == null) return;
    final GameState state = context.read<GameState>();

    setState(() => _spinning = false);

    if (result.lineCoins > 0) {
      state.addWin(result.lineCoins);
      if (result.lineCoins >= state.totalBet * 15) {
        AudioService.instance.victory();
      } else {
        AudioService.instance.reward();
      }
      setState(() {
        _winDisplay = result.lineCoins;
        _highlight = result.winningCells;
      });
      _startLineCycle(result);
    }

    if (result.triggeredBonus != null) {
      _cycleTimer?.cancel();
      setState(() {
        _highlight = result.bonusCells.toSet();
        _activeLine = null;
        _lineLabel = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      await _runBonus(result.triggeredBonus!, result.bonusCount);
      return;
    }

    if (_autoPlay) {
      await Future<void>.delayed(
        Duration(milliseconds: result.lineCoins > 0 ? 1600 : 500),
      );
      if (mounted && _autoPlay && !_busy) _spin();
    }
  }

  void _startLineCycle(SpinResult result) {
    if (result.lineWins.isEmpty) return;
    _cycleIndex = 0;
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 1150), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _cycleIndex = (_cycleIndex + 1) % (result.lineWins.length + 1);
      setState(() {
        if (_cycleIndex == 0) {
          _highlight = result.winningCells;
          _activeLine = null;
          _lineLabel = null;
        } else {
          final LineWin win = result.lineWins[_cycleIndex - 1];
          _highlight = win.cells.toSet();
          _activeLine = kPaylines[win.lineIndex];
          _lineLabel =
              'LINE ${win.lineIndex + 1}  •  ${win.count}x ${SlotSymbols.of(win.symbolId).name}'
              '  •  ${formatCoins(win.coins)}';
        }
      });
    });
  }

  Future<void> _runBonus(BonusGame bonus, int symbolCount) async {
    final GameState state = context.read<GameState>();
    setState(() => _bonusRunning = true);

    await showBonusIntro(context, bonus, symbolCount);
    if (!mounted) return;

    final int? won = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => _buildBonusScreen(bonus, symbolCount, state),
      ),
    );
    if (!mounted) return;

    if (won != null && won > 0) {
      state.addWin(won);
      setState(() => _winDisplay = won);
    }
    setState(() {
      _bonusRunning = false;
      _stopPresentation();
    });

    if (_autoPlay) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted && _autoPlay && !_busy) _spin();
    }
  }

  Widget _buildBonusScreen(BonusGame bonus, int symbolCount, GameState state) {
    return WheelBonusScreen(
      bonus: bonus,
      totalBet: state.totalBet,
      symbolCount: symbolCount,
    );
  }

  Future<void> _showOutOfCoins() async {
    final GameState state = context.read<GameState>();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: FrostPanel(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StrokeText('NOT ENOUGH COINS', style: AppText.title(20)),
              const SizedBox(height: 10),
              Text(
                'You need ${formatCoins(state.totalBet)} fun coins for this spin. '
                'Lower your bet or grab a free top-up.',
                textAlign: TextAlign.center,
                style: AppText.body(12).copyWith(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 18),
              FrostButton(
                label: state.canClaimFreeCoins
                    ? 'GET ${formatCoins(GameState.freeCoinsAmount)} FREE'
                    : 'FREE COINS ON COOLDOWN',
                width: double.infinity,
                height: 50,
                fontSize: 16,
                enabled: state.canClaimFreeCoins,
                onPressed: () {
                  state.claimFreeCoins();
                  AudioService.instance.reward();
                  Navigator.of(dialogContext).pop();
                },
              ),
              const SizedBox(height: 8),
              FrostButton(
                label: 'LOWER BET',
                style: FrostButtonStyle.ghost,
                width: double.infinity,
                height: 46,
                fontSize: 15,
                onPressed: () {
                  state.decreaseBet();
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final GameState state = context.watch<GameState>();

    return Scaffold(
      body: GameBackground(
        asset: GameAssets.bgHall,
        scrim: 0.55,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _TopBar(coins: state.coins, busy: _busy),
              const SizedBox(height: 6),
              _JackpotStrip(totalBet: state.totalBet),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    // The reel window is width-driven; whatever vertical space
                    // is left over is handed to the logo and the bonus hint so
                    // tall screens do not end up with a dead gap.
                    final double gridWidth = constraints.maxWidth - 20;
                    final double gridHeight = gridWidth * kRows / kReels;
                    final double spare = constraints.maxHeight - gridHeight;
                    final double logoHeight = (spare * 0.40).clamp(0.0, 118.0);
                    final double hintHeight = (spare * 0.30).clamp(0.0, 86.0);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        if (logoHeight >= 44)
                          SizedBox(
                            height: logoHeight,
                            child: Image.asset(GameAssets.logo, fit: BoxFit.contain),
                          ),
                        SizedBox(
                          width: gridWidth,
                          height: gridHeight,
                          child: ReelGrid(
                            engine: _engine,
                            grid: _grid,
                            spinToken: _spinToken,
                            highlightCells: _highlight,
                            activeLine: _activeLine,
                            onAllStopped: _onReelsStopped,
                          ),
                        ),
                        if (hintHeight >= 44) SizedBox(height: hintHeight, child: const _BonusHint()),
                      ],
                    );
                  },
                ),
              ),
              _WinBanner(win: _winDisplay, lineLabel: _lineLabel, spinning: _spinning),
              _ControlPanel(
                state: state,
                busy: _busy,
                autoPlay: _autoPlay,
                onSpin: _spin,
                onToggleAuto: () {
                  setState(() => _autoPlay = !_autoPlay);
                  if (_autoPlay && !_busy) _spin();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.coins, required this.busy});

  final int coins;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: <Widget>[
          FrostIconButton(
            icon: Icons.home_rounded,
            tooltip: 'Main menu',
            onPressed: busy ? () {} : () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(child: CoinChip(coins: coins)),
          const SizedBox(width: 8),
          FrostIconButton(
            icon: Icons.menu_book_rounded,
            tooltip: 'Paytable',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PaytableScreen()),
            ),
          ),
          const SizedBox(width: 8),
          FrostIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _JackpotStrip extends StatelessWidget {
  const _JackpotStrip({required this.totalBet});

  final int totalBet;

  static const List<(JackpotTier, Color)> _lamps = <(JackpotTier, Color)>[
    (JackpotTier.mini, Color(0xFF3DDC84)),
    (JackpotTier.minor, Color(0xFF4FC3F7)),
    (JackpotTier.major, Color(0xFFCE93D8)),
    (JackpotTier.grand, Color(0xFFFFD54A)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
      child: Row(
        children: <Widget>[
          for (final (JackpotTier tier, Color lamp) in _lamps.reversed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFF151A28), Color(0xFF05070E)],
                    ),
                    border: Border.all(color: lamp.withValues(alpha: 0.85), width: 1.4),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: lamp.withValues(alpha: 0.28), blurRadius: 8, spreadRadius: -2),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        tier.label,
                        style: AppText.body(8, weight: FontWeight.w900).copyWith(
                          color: lamp,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Image.asset(tier.badge, height: 22, fit: BoxFit.contain),
                      const SizedBox(height: 2),
                      FittedBox(
                        child: Text(
                          formatCoins(tier.valueFor(totalBet)),
                          style: AppText.numeric(11).copyWith(
                            color: lamp,
                            shadows: <Shadow>[Shadow(color: lamp.withValues(alpha: 0.7), blurRadius: 8)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reminder of the five wheel scatters sitting under the reels.
class _BonusHint extends StatelessWidget {
  const _BonusHint();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xCC050814),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
          ),
          child: Text(
            'LAND 3 MATCHING WHEELS TO SPIN THAT BONUS',
            style: AppText.body(8, weight: FontWeight.w800).copyWith(
              color: AppColors.ice.withValues(alpha: 0.9),
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Flexible(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const int count = 5;
              const double gap = 6;
              final double side = min(
                constraints.maxHeight,
                (constraints.maxWidth - gap * count) / count,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final BonusGame bonus in BonusGame.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: gap / 2),
                      child: Container(
                        width: side,
                        height: side,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black.withValues(alpha: 0.5),
                          border: Border.all(
                            color: bonus.accent.withValues(alpha: 0.8),
                            width: 1.4,
                          ),
                        ),
                        child: Image.asset(
                          GameAssets.symbol(bonus.symbolId),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WinBanner extends StatelessWidget {
  const _WinBanner({required this.win, required this.lineLabel, required this.spinning});

  final int win;
  final String? lineLabel;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final bool hit = win > 0 && !spinning;
    final String message = spinning
        ? 'GOOD LUCK'
        : (lineLabel ?? (hit ? 'YOU WIN' : '20 LINES  •  SPIN TO PLAY'));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0B1220), Color(0xFF03060C)],
          ),
          border: Border.all(
            color: hit ? AppColors.gold : const Color(0xFF2A3A22),
            width: 1.8,
          ),
          boxShadow: hit
              ? const <BoxShadow>[
                  BoxShadow(color: Color(0x88F7CE4B), blurRadius: 16, spreadRadius: -4),
                ]
              : const <BoxShadow>[],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (hit)
              CountUpText(
                value: win,
                style: AppText.numeric(24).copyWith(
                  color: const Color(0xFF7CFF6A),
                  shadows: const <Shadow>[Shadow(color: Color(0xAA7CFF6A), blurRadius: 10)],
                ),
              ),
            Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(11, weight: FontWeight.w800).copyWith(
                color: hit ? const Color(0xFFB6FF8A) : const Color(0xFF6BFF7A),
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.state,
    required this.busy,
    required this.autoPlay,
    required this.onSpin,
    required this.onToggleAuto,
  });

  final GameState state;
  final bool busy;
  final bool autoPlay;
  final VoidCallback onSpin;
  final VoidCallback onToggleAuto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1C2744), Color(0xFF0A1020)],
          ),
          border: Border.all(color: const Color(0xFFE0B03A), width: 2.2),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0xAA000000), blurRadius: 16, offset: Offset(0, 8)),
            BoxShadow(color: Color(0x44F7CE4B), blurRadius: 18, spreadRadius: -6),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'TOTAL BET',
                    style: AppText.body(9, weight: FontWeight.w800).copyWith(
                      color: AppColors.ice,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _StepButton(
                        icon: Icons.remove_rounded,
                        enabled: state.canBetLower && !busy,
                        onPressed: state.decreaseBet,
                      ),
                      Expanded(
                        child: FittedBox(
                          child: Text(
                            formatCoins(state.totalBet),
                            style: AppText.numeric(18).copyWith(color: AppColors.gold),
                          ),
                        ),
                      ),
                      _StepButton(
                        icon: Icons.add_rounded,
                        enabled: state.canBetHigher && !busy,
                        onPressed: state.increaseBet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: busy
                        ? null
                        : () {
                            AudioService.instance.click();
                            state.maxBet();
                          },
                    child: Text(
                      'MAX BET',
                      style: AppText.body(10, weight: FontWeight.w800).copyWith(
                        color: busy ? Colors.white30 : AppColors.crimsonLight,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _SpinButton(enabled: !busy, spinning: busy, onPressed: onSpin),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'LINE BET',
                    style: AppText.body(9, weight: FontWeight.w800).copyWith(
                      color: AppColors.ice,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    child: Text(
                      '${formatCoins(state.lineBet)} x ${kPaylines.length}',
                      style: AppText.numeric(14).copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      AudioService.instance.click();
                      onToggleAuto();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: autoPlay
                            ? AppColors.emerald.withValues(alpha: 0.28)
                            : Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: autoPlay ? AppColors.emerald : AppColors.ice.withValues(alpha: 0.5),
                          width: 1.6,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            autoPlay ? Icons.stop_rounded : Icons.autorenew_rounded,
                            size: 14,
                            color: autoPlay ? AppColors.emerald : AppColors.ice,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            autoPlay ? 'STOP' : 'AUTO',
                            style: AppText.body(10, weight: FontWeight.w800).copyWith(
                              color: autoPlay ? AppColors.emerald : AppColors.ice,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.enabled, required this.onPressed});

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled
          ? () {
              AudioService.instance.click();
              onPressed();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.goldGradient,
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Icon(icon, size: 18, color: AppColors.goldDark),
        ),
      ),
    );
  }
}

class _SpinButton extends StatefulWidget {
  const _SpinButton({required this.enabled, required this.spinning, required this.onPressed});

  final bool enabled;
  final bool spinning;
  final VoidCallback onPressed;

  @override
  State<_SpinButton> createState() => _SpinButtonState();
}

class _SpinButtonState extends State<_SpinButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _ring.repeat();
  }

  @override
  void didUpdateWidget(covariant _SpinButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !oldWidget.spinning) {
      _ring.repeat();
    } else if (!widget.spinning && oldWidget.spinning) {
      _ring
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: widget.enabled ? 1 : 0.94,
        duration: const Duration(milliseconds: 150),
        child: SizedBox(
          width: 96,
          height: 96,
          child: AnimatedBuilder(
            animation: _ring,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                painter: _SpinRingPainter(progress: _ring.value, spinning: widget.spinning),
                child: child,
              );
            },
            child: Center(
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFFFFB199), Color(0xFFE02338), Color(0xFF6A0814)],
                  ),
                  border: Border.all(color: const Color(0xFFFFE7A0), width: 2.4),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0xAA000000), blurRadius: 14, offset: Offset(0, 6)),
                    BoxShadow(color: Color(0x66FF4D4D), blurRadius: 18, spreadRadius: -4),
                  ],
                ),
                child: Center(
                  child: widget.spinning
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6),
                        )
                      : StrokeText('SPIN', style: AppText.title(22), strokeWidth: 4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpinRingPainter extends CustomPainter {
  _SpinRingPainter({required this.progress, required this.spinning});

  final double progress;
  final bool spinning;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 2;
    const int ticks = 16;
    for (int i = 0; i < ticks; i++) {
      final double t = i / ticks + (spinning ? progress : 0);
      final double angle = t * pi * 2;
      final double phase = (i / ticks - progress) % 1.0;
      final bool lit = !spinning || phase < 0.22 || phase > 0.88;
      final Offset a = Offset(center.dx + cos(angle) * (radius - 5), center.dy + sin(angle) * (radius - 5));
      final Offset b = Offset(center.dx + cos(angle) * radius, center.dy + sin(angle) * radius);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = Color.fromRGBO(247, 206, 75, lit ? 1 : 0.28)
          ..strokeWidth = lit ? 3.2 : 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpinRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.spinning != spinning;
}
