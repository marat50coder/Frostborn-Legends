import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/audio_service.dart';
import '../../core/game_assets.dart';
import '../../core/game_state.dart';
import '../../widgets/frost_ui.dart';
import 'bonus_common.dart';

class _Catch {
  const _Catch(this.asset, this.name, this.multiplier, this.extraCast);

  final String asset;
  final String name;
  final int multiplier;
  final bool extraCast;
}

/// Tap to cast, reel in a fish, bank its value. The round ends when the casts
/// run out; golden fish can hand back an extra cast.
class IceFishingBonus extends StatefulWidget {
  const IceFishingBonus({super.key, required this.totalBet, required this.scatterCount});

  final int totalBet;
  final int scatterCount;

  @override
  State<IceFishingBonus> createState() => _IceFishingBonusState();
}

class _IceFishingBonusState extends State<IceFishingBonus> with TickerProviderStateMixin {
  final Random _random = Random();

  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  late final AnimationController _cast = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late int _castsLeft = widget.scatterCount + 1;
  int _collected = 0;
  bool _busy = false;
  bool _finished = false;
  _Catch? _lastCatch;

  @override
  void initState() {
    super.initState();
    _cast.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) _resolveCast();
    });
  }

  @override
  void dispose() {
    _drift.dispose();
    _cast.dispose();
    super.dispose();
  }

  _Catch _rollCatch() {
    final int roll = _random.nextInt(100);
    if (roll < 55) {
      return _Catch(GameAssets.fishRed, 'Ruby Perch', 1 + _random.nextInt(2), false);
    }
    if (roll < 87) {
      return _Catch(GameAssets.fishBlue, 'Frost Carp', 2 + _random.nextInt(4), false);
    }
    return _Catch(
      GameAssets.fishGold,
      'Golden Catch',
      6 + _random.nextInt(10),
      _random.nextInt(100) < 35,
    );
  }

  void _startCast() {
    if (_busy || _finished || _castsLeft <= 0) return;
    setState(() {
      _busy = true;
      _lastCatch = null;
    });
    AudioService.instance.select();
    _cast.forward(from: 0);
  }

  Future<void> _resolveCast() async {
    final _Catch result = _rollCatch();
    final int coins = result.multiplier * widget.totalBet;
    AudioService.instance.reward();
    setState(() {
      _lastCatch = result;
      _collected += coins;
      _castsLeft += result.extraCast ? 0 : -1;
      _busy = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    if (_castsLeft <= 0) {
      _finished = true;
      await showBonusResult(
        context,
        coins: _collected,
        title: 'Great catch!',
        subtitle: 'The frozen lake has been generous.',
        artwork: GameAssets.fishermanFront,
      );
    } else {
      setState(() => _lastCatch = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BonusScaffold(
      title: 'Ice Fishing',
      subtitle: 'Casts left: $_castsLeft',
      background: GameAssets.loadingPortrait,
      scrim: 0.58,
      collected: _collected,
      child: Column(
        children: <Widget>[
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double height = constraints.maxHeight;
                return Stack(
                  children: <Widget>[
                    Positioned(
                      left: 10,
                      top: 0,
                      height: height * 0.34,
                      child: Image.asset(GameAssets.fishermanSide, fit: BoxFit.fitHeight),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: height * 0.32,
                      bottom: 0,
                      child: _Water(drift: _drift),
                    ),
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _cast,
                        builder: (BuildContext context, _) {
                          final double t = Curves.easeInOut.transform(_cast.value);
                          return CustomPaint(
                            painter: _LinePainter(
                              progress: _cast.isAnimating || _cast.isCompleted ? t : 0,
                              start: Offset(constraints.maxWidth * 0.34, height * 0.10),
                              end: Offset(constraints.maxWidth * 0.55, height * 0.72),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_lastCatch != null)
                      Positioned.fill(child: _CatchBanner(result: _lastCatch!, bet: widget.totalBet)),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 22),
            child: Column(
              children: <Widget>[
                Text(
                  'Golden catches can return an extra cast.',
                  textAlign: TextAlign.center,
                  style: AppText.body(11).copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                FrostButton(
                  label: _busy ? 'REELING IN...' : 'CAST THE LINE',
                  width: double.infinity,
                  height: 58,
                  fontSize: 19,
                  enabled: !_busy && !_finished,
                  onPressed: _startCast,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Water extends StatelessWidget {
  const _Water({required this.drift});

  final Animation<double> drift;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xCC1B6FA8), Color(0xE6062647), Color(0xF2020F22)],
          ),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return AnimatedBuilder(
              animation: drift,
              builder: (BuildContext context, _) {
                return Stack(
                  children: <Widget>[
                    for (int i = 0; i < 4; i++)
                      _DriftingFish(
                        asset: const <String>[
                          GameAssets.fishBlue,
                          GameAssets.fishRed,
                          GameAssets.fishGold,
                          GameAssets.fishBlue,
                        ][i],
                        width: constraints.maxWidth,
                        top: constraints.maxHeight * (0.18 + 0.2 * i),
                        size: constraints.maxWidth * (0.20 + 0.03 * (i % 3)),
                        phase: (drift.value + i * 0.27) % 1,
                        reversed: i.isOdd,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DriftingFish extends StatelessWidget {
  const _DriftingFish({
    required this.asset,
    required this.width,
    required this.top,
    required this.size,
    required this.phase,
    required this.reversed,
  });

  final String asset;
  final double width;
  final double top;
  final double size;
  final double phase;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final double x = reversed ? (1 - phase) * (width + size) - size : phase * (width + size) - size;
    return Positioned(
      left: x,
      top: top,
      child: Opacity(
        opacity: 0.85,
        child: Transform.flip(
          flipX: !reversed,
          child: Image.asset(asset, width: size, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.progress, required this.start, required this.end});

  final double progress;
  final Offset start;
  final Offset end;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final Offset tip = Offset.lerp(start, end, progress)!;
    canvas.drawLine(
      start,
      tip,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(tip, 7, Paint()..color = AppColors.crimsonLight);
    canvas.drawCircle(
      tip,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => oldDelegate.progress != progress;
}

class _CatchBanner extends StatelessWidget {
  const _CatchBanner({required this.result, required this.bet});

  final _Catch result;
  final int bet;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (BuildContext context, double t, Widget? child) =>
            Transform.scale(scale: 0.7 + 0.3 * t, child: Opacity(opacity: t, child: child)),
        child: FrostPanel(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: 92, child: Image.asset(result.asset, fit: BoxFit.contain)),
              const SizedBox(height: 8),
              StrokeText(result.name.toUpperCase(), style: AppText.title(17)),
              const SizedBox(height: 6),
              Text(
                '+${formatCoins(result.multiplier * bet)}',
                style: AppText.numeric(24).copyWith(color: AppColors.gold),
              ),
              if (result.extraCast) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  '+1 EXTRA CAST',
                  style: AppText.body(12, weight: FontWeight.w800).copyWith(color: AppColors.ice),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
