import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/audio_service.dart';
import '../../core/game_assets.dart';
import '../../core/game_state.dart';
import '../../game/jackpots.dart';
import '../../game/slot_symbols.dart';
import '../../widgets/frost_ui.dart';
import 'bonus_common.dart';

/// The wheel bonus. Every scatter triggers the same three-tier wheel game;
/// which scatter landed only decides the starting tier and the extra spins
/// awarded for 4- or 5-symbol hits.
///
/// Every tier is a 12-cell wheel. On tiers 1 and 2 three cells sitting 120°
/// apart are UPGRADE cells: landing on one advances the wheel to the next
/// tier where the prizes are richer. Tier 3 has no upgrades and packs the
/// Mini / Minor / Grand jackpots alongside its top multipliers.
class WheelBonusScreen extends StatefulWidget {
  const WheelBonusScreen({
    super.key,
    required this.bonus,
    required this.totalBet,
    required this.symbolCount,
  });

  final BonusGame bonus;
  final int totalBet;

  /// Four or five scatters start the round with extra spins.
  final int symbolCount;

  @override
  State<WheelBonusScreen> createState() => _WheelBonusScreenState();
}

enum _SegmentType { coins, jackpot, upgrade }

class _Segment {
  const _Segment.coins(this.multiplier)
    : type = _SegmentType.coins,
      jackpot = null;
  const _Segment.jackpot(JackpotTier tier)
    : type = _SegmentType.jackpot,
      multiplier = 0,
      jackpot = tier;
  const _Segment.upgrade()
    : type = _SegmentType.upgrade,
      multiplier = 0,
      jackpot = null;

  final _SegmentType type;
  final int multiplier;
  final JackpotTier? jackpot;

  bool get isUpgrade => type == _SegmentType.upgrade;

  String labelFor(int totalBet) => switch (type) {
    _SegmentType.coins => formatCoins(multiplier * totalBet),
    _SegmentType.jackpot => jackpot!.label,
    _SegmentType.upgrade => 'LEVEL\nUP',
  };

  int valueFor(int totalBet) => switch (type) {
    _SegmentType.coins => multiplier * totalBet,
    _SegmentType.jackpot => jackpot!.valueFor(totalBet),
    _SegmentType.upgrade => 0,
  };
}

/// Three tiers, twelve cells each. Positions 0/4/8 on tier 1 and tier 2 are
/// UPGRADE cells (120° apart). Numbers match the RTP simulator in
/// `tool/rtp_sim.dart` so the bonus contributes ~31% to the total 95% RTP.
const List<List<_Segment>> _tiers = <List<_Segment>>[
  <_Segment>[
    _Segment.upgrade(), _Segment.coins(3), _Segment.coins(4), _Segment.coins(2),
    _Segment.upgrade(), _Segment.coins(5), _Segment.coins(3), _Segment.coins(4),
    _Segment.upgrade(), _Segment.coins(2), _Segment.coins(6), _Segment.coins(4),
  ],
  <_Segment>[
    _Segment.upgrade(), _Segment.coins(7), _Segment.coins(9), _Segment.coins(11),
    _Segment.upgrade(), _Segment.coins(9), _Segment.coins(7), _Segment.coins(14),
    _Segment.upgrade(), _Segment.coins(7), _Segment.coins(18), _Segment.coins(11),
  ],
  <_Segment>[
    _Segment.coins(20), _Segment.coins(28), _Segment.coins(15),
    _Segment.jackpot(JackpotTier.mini),
    _Segment.coins(32), _Segment.coins(22), _Segment.coins(40),
    _Segment.jackpot(JackpotTier.minor),
    _Segment.coins(24), _Segment.coins(60),
    _Segment.jackpot(JackpotTier.grand),
    _Segment.coins(32),
  ],
];

int _startingTierFor(BonusGame bonus) => switch (bonus) {
  BonusGame.wheelSnow => 0,
  BonusGame.wheelEmerald => 0,
  BonusGame.wheelAmethyst => 1,
  BonusGame.wheelFire => 1,
  BonusGame.wheelFrost => 2,
};

String _artworkFor(int tier) => switch (tier) {
  0 => GameAssets.wheelSnow,
  1 => GameAssets.wheelAmethyst,
  _ => GameAssets.wheelGold,
};

Color _accentFor(int tier) => switch (tier) {
  0 => const Color(0xFFBFEEFF),
  1 => const Color(0xFFB36BFF),
  _ => const Color(0xFFFFE484),
};

String _tierName(int tier) => switch (tier) {
  0 => 'BRONZE',
  1 => 'SILVER',
  _ => 'GOLD',
};

enum _Phase { entering, ready, spinning, revealing, leveling, finished }

class _WheelBonusScreenState extends State<WheelBonusScreen> with TickerProviderStateMixin {
  final Random _random = Random();

  late int _tier = _startingTierFor(widget.bonus);
  late List<_Segment> _segments = _tiers[_tier];

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Uses a wider ranged controller so we can drive one long, decelerating
  // rotation from a single Tween instead of chaining animations.
  late final AnimationController _spinner = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  // Tier-swap animation: shrink the wheel out, swap art, blossom back in.
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late Animation<double> _rotation = const AlwaysStoppedAnimation<double>(0);

  _Phase _phase = _Phase.entering;
  double _angle = 0;
  int _spinsLeft = 1;
  int _collected = 0;
  _Segment? _lastResult;

  @override
  void initState() {
    super.initState();
    _spinsLeft = 1 + (widget.symbolCount - 3).clamp(0, 2);
    AudioService.instance.bigBonus();
    _entrance.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _phase = _Phase.ready);
      Future<void>.delayed(const Duration(milliseconds: 480), _spin);
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _spinner.dispose();
    _swap.dispose();
    super.dispose();
  }

  void _spin() {
    if (!mounted || _phase == _Phase.spinning || _phase == _Phase.finished) return;

    final int index = _random.nextInt(_segments.length);
    final double step = 2 * pi / _segments.length;
    const double turn = 2 * pi;

    // Segment i is painted with its centre at -π/2 + i·step (12 o'clock for
    // i = 0). A clockwise Transform.rotate of -i·step puts that centre
    // exactly under the pointer — no half-step, so we never land on a spoke.
    final double aligned = (turn - (index * step) % turn) % turn;
    final double base = _angle - (_angle % turn);
    double target = base + aligned;
    if (target <= _angle + 0.01) target += turn;
    // 5-7 full turns before landing. Range gives a satisfying long spin
    // without dragging out the round.
    target += (5 + _random.nextInt(3)) * turn;

    _rotation = Tween<double>(begin: _angle, end: target).animate(
      // easeOutQuint gives a firm push and a long, buttery deceleration
      // instead of the previous bouncy landing.
      CurvedAnimation(parent: _spinner, curve: Curves.easeOutQuint),
    );

    setState(() {
      _phase = _Phase.spinning;
      _lastResult = null;
    });
    AudioService.instance.play(GameSounds.selection, volume: 0.9);

    _spinner
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;
        _angle = target;
        _reveal(_segments[index]);
      });
  }

  Future<void> _reveal(_Segment segment) async {
    setState(() {
      _phase = _Phase.revealing;
      _lastResult = segment;
      if (segment.type == _SegmentType.coins || segment.type == _SegmentType.jackpot) {
        _collected += segment.valueFor(widget.totalBet);
      }
    });

    if (segment.type == _SegmentType.jackpot) {
      AudioService.instance.bigBonus();
    } else if (segment.isUpgrade) {
      AudioService.instance.play(GameSounds.majorBonus, volume: 0.9);
    } else {
      AudioService.instance.reward();
    }

    final int hold = segment.type == _SegmentType.jackpot
        ? 2200
        : segment.isUpgrade
            ? 1200
            : 1400;
    await Future<void>.delayed(Duration(milliseconds: hold));
    if (!mounted) return;

    if (segment.isUpgrade && _tier < _tiers.length - 1) {
      await _levelUp();
      if (!mounted) return;
    } else {
      _spinsLeft -= 1;
    }

    if (_spinsLeft > 0) {
      _spin();
      return;
    }

    setState(() => _phase = _Phase.finished);
    await showBonusResult(
      context,
      coins: _collected,
      title: 'Wheel bonus complete',
      subtitle: 'You reached ${_tierName(_tier)} tier.',
      artwork: _artworkFor(_tier),
    );
  }

  Future<void> _levelUp() async {
    setState(() => _phase = _Phase.leveling);
    // Shrink out.
    await _swap.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _tier += 1;
      _segments = _tiers[_tier];
      _angle = 0;
      _rotation = const AlwaysStoppedAnimation<double>(0);
    });
    // Blossom back in.
    await _swap.reverse();
    if (!mounted) return;
    setState(() => _phase = _Phase.ready);
    await Future<void>.delayed(const Duration(milliseconds: 220));
  }

  @override
  Widget build(BuildContext context) {
    return BonusScaffold(
      title: '${_tierName(_tier)} Wheel',
      background: GameAssets.bgCrystal,
      collected: _collected,
      subtitle: _phase == _Phase.leveling
          ? 'LEVEL UP!'
          : _spinsLeft > 1
              ? '$_spinsLeft spins left  •  ${_tierName(_tier)} tier ${_tier + 1}/3'
              : 'Tier ${_tier + 1}/3  •  ${_tierName(_tier)} rewards',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double size = min(constraints.maxWidth - 12, constraints.maxHeight - 96);
          return Column(
            children: <Widget>[
              const SizedBox(height: 4),
              _TierIndicator(tier: _tier),
              Expanded(
                child: Center(
                  child: SizedBox(width: size, height: size, child: _buildWheel(size)),
                ),
              ),
              SizedBox(height: 78, child: Center(child: _buildCallout())),
              const SizedBox(height: 10),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWheel(double size) {
    final Color accent = _accentFor(_tier);
    // Compose the entire wheel (art + our own 12-cell overlay + labels) once,
    // then only re-rotate it via a Transform so we do not re-decode the
    // artwork each frame.
    final Widget stationary = RepaintBoundary(
      key: ValueKey<int>(_tier),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Decorative frame (gold scrollwork + gems + centre gem) — comes
            // from the artwork. We paint our own pie on top so cell counts
            // match the code.
            Image.asset(_artworkFor(_tier), width: size, height: size, fit: BoxFit.contain),
            CustomPaint(
              size: Size(size, size),
              painter: _SegmentPainter(
                segments: _segments,
                totalBet: widget.totalBet,
                accent: accent,
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_entrance, _spinner, _swap]),
      child: stationary,
      builder: (BuildContext context, Widget? child) {
        // Entrance: light drop-in with a soft spin.
        final double entryT = Curves.easeOutCubic.transform(_entrance.value.clamp(0.0, 1.0));
        final double entryScale = 0.30 + 0.70 * entryT;
        final double entrySpin = (1 - entryT) * -1.6 * pi;

        // Tier swap: pinch in, out.
        final double swapT = _swap.value; // 0 → 1 while shrinking
        final double swapScale = 1 - 0.75 * Curves.easeInOutCubic.transform(swapT);
        final double swapSpin = swapT * 2 * pi;

        final double angle =
            (_spinner.isAnimating ? _rotation.value : _angle) + entrySpin + swapSpin;

        return Opacity(
          opacity: entryT,
          child: Transform.scale(
            scale: entryScale * swapScale,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Halo behind the wheel — colour follows the tier.
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.55),
                        blurRadius: 46,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: SizedBox(width: size * 0.82, height: size * 0.82),
                ),
                Transform.rotate(angle: angle, child: child),
                Positioned(
                  top: 0,
                  child: CustomPaint(
                    size: Size(size * 0.13, size * 0.15),
                    painter: _PointerPainter(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCallout() {
    final _Segment? result = _lastResult;
    if (_phase == _Phase.leveling) {
      return _CalloutText(
        'LEVEL UP! ${_tierName(_tier + 1 > _tiers.length - 1 ? _tier : _tier + 1)} TIER',
        gradient: AppColors.goldGradient,
        big: true,
      );
    }
    if (_phase == _Phase.spinning || result == null) {
      return _CalloutText(
        _phase == _Phase.spinning ? 'GOOD LUCK!' : 'GET READY...',
        gradient: AppColors.iceGradient,
      );
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey<Object>(result.labelFor(widget.totalBet) + _collected.toString()),
      tween: Tween<double>(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double scale, Widget? child) =>
          Transform.scale(scale: scale, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (result.isUpgrade)
            StrokeText(
              'LEVEL UP!',
              style: AppText.title(30),
              gradient: AppColors.goldGradient,
            )
          else if (result.type == _SegmentType.jackpot)
            StrokeText(
              '${result.jackpot!.label} JACKPOT!',
              style: AppText.title(24),
              gradient: AppColors.goldGradient,
            )
          else
            StrokeText(
              '+${formatCoins(result.valueFor(widget.totalBet))}',
              style: AppText.title(28),
              gradient: AppColors.iceGradient,
            ),
        ],
      ),
    );
  }
}

class _CalloutText extends StatelessWidget {
  const _CalloutText(this.text, {required this.gradient, this.big = false});

  final String text;
  final Gradient gradient;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return StrokeText(text, style: AppText.title(big ? 24 : 20), gradient: gradient);
  }
}

class _TierIndicator extends StatelessWidget {
  const _TierIndicator({required this.tier});

  final int tier;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < 3; i++) ...<Widget>[
          _TierPip(active: i == tier, filled: i <= tier, label: _tierName(i), color: _accentFor(i)),
          if (i < 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                width: 22,
                height: 2,
                decoration: BoxDecoration(
                  color: (i < tier ? AppColors.gold : AppColors.ice).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _TierPip extends StatelessWidget {
  const _TierPip({
    required this.active,
    required this.filled,
    required this.label,
    required this.color,
  });

  final bool active;
  final bool filled;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: filled ? color.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.36),
        border: Border.all(
          color: active ? color : color.withValues(alpha: 0.4),
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? <BoxShadow>[BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10)]
            : const <BoxShadow>[],
      ),
      child: Text(
        label,
        style: AppText.body(9, weight: FontWeight.w900).copyWith(
          color: filled ? Colors.white : Colors.white70,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// Draws a clean 12-cell pie over the wheel artwork so cell divisions match
/// the code exactly. Every element — fills, spokes, labels — stays inside
/// the [outerR]/[innerR] ring so nothing spills past the decorative frame.
class _SegmentPainter extends CustomPainter {
  _SegmentPainter({
    required this.segments,
    required this.totalBet,
    required this.accent,
  });

  final List<_Segment> segments;
  final int totalBet;
  final Color accent;

  static const Color _rim = Color(0xFFE2B34A);
  static const Color _spoke = Color(0xFFF6D97A);
  static const Color _fillA = Color(0xFF1A2C60);
  static const Color _fillB = Color(0xFF0E1A44);
  static const Color _upgradeFill = Color(0xFFD9A02A);
  static const Color _upgradeFillHi = Color(0xFFFFE38B);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    // Radii tuned to the actual pie area of the wheel artwork; the gold rim
    // + snowflake frame around it occupy the outer ~10 % of the image, and
    // the centre gem the inner ~11 %.
    final double outerR = size.shortestSide * 0.395;
    final double innerR = size.shortestSide * 0.115;
    final double midR = (outerR + innerR) / 2;
    final double step = 2 * pi / segments.length;

    // Solid dark backdrop covering the pie region — hides the artwork's own
    // (8-cell) division so our 12 cells read cleanly.
    final Path ring = Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerR))
      ..addOval(Rect.fromCircle(center: center, radius: innerR))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(ring, Paint()..color = const Color(0xF0060B1C));

    // Per-cell fills.
    for (int i = 0; i < segments.length; i++) {
      final _Segment segment = segments[i];
      final double start = -pi / 2 - step / 2 + i * step;
      final Path wedge = _wedgePath(center, innerR, outerR, start, step);
      final Paint fill = Paint();
      if (segment.isUpgrade) {
        fill.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const <Color>[_upgradeFillHi, _upgradeFill, Color(0xFF8A5D0A)],
        ).createShader(Rect.fromCircle(center: center, radius: outerR));
      } else if (segment.type == _SegmentType.jackpot) {
        fill.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            accent.withValues(alpha: 0.95),
            accent.withValues(alpha: 0.55),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: outerR));
      } else {
        fill.color = i.isEven ? _fillA : _fillB;
      }
      canvas.drawPath(wedge, fill);
    }

    // Radial spokes at every cell boundary.
    final Paint spokePaint = Paint()
      ..color = _spoke
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.0055
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < segments.length; i++) {
      final double a = -pi / 2 - step / 2 + i * step;
      canvas.drawLine(
        Offset(center.dx + cos(a) * innerR, center.dy + sin(a) * innerR),
        Offset(center.dx + cos(a) * outerR, center.dy + sin(a) * outerR),
        spokePaint,
      );
    }

    // Outer and inner rims.
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.008
      ..color = _rim;
    canvas.drawCircle(center, outerR, rimPaint);
    canvas.drawCircle(center, innerR, rimPaint);

    // Labels.
    for (int i = 0; i < segments.length; i++) {
      _drawLabel(
        canvas: canvas,
        center: center,
        angleCenter: -pi / 2 + i * step,
        segment: segments[i],
        midR: midR,
        step: step,
        cellDepth: outerR - innerR,
      );
    }
  }

  /// A wedge-shaped path between two radii around [center].
  Path _wedgePath(Offset c, double r0, double r1, double start, double sweep) {
    return Path()
      ..moveTo(c.dx + cos(start) * r0, c.dy + sin(start) * r0)
      ..lineTo(c.dx + cos(start) * r1, c.dy + sin(start) * r1)
      ..arcTo(Rect.fromCircle(center: c, radius: r1), start, sweep, false)
      ..lineTo(
        c.dx + cos(start + sweep) * r0,
        c.dy + sin(start + sweep) * r0,
      )
      ..arcTo(Rect.fromCircle(center: c, radius: r0), start + sweep, -sweep, false)
      ..close();
  }

  void _drawLabel({
    required Canvas canvas,
    required Offset center,
    required double angleCenter,
    required _Segment segment,
    required double midR,
    required double step,
    required double cellDepth,
  }) {
    final String label = segment.labelFor(totalBet);
    final Color color = segment.isUpgrade
        ? const Color(0xFF2A1300)
        : segment.type == _SegmentType.jackpot
            ? const Color(0xFF231400)
            : Colors.white;

    // Chord width at the label's mid-radius sets the horizontal room. Leave a
    // safe 15 % padding on each side so glyphs never touch the spokes.
    final double chord = 2 * midR * sin(step / 2);
    final double maxTextWidth = chord * 0.86;
    final double maxTextHeight = cellDepth * 0.78;

    final double baseSize = segment.isUpgrade
        ? 11
        : segment.type == _SegmentType.jackpot
            ? 13
            : 14;

    final TextPainter painter = _layoutFitted(
      label,
      baseSize: baseSize,
      color: color,
      maxWidth: maxTextWidth,
      maxHeight: maxTextHeight,
      shadowed: !segment.isUpgrade && segment.type != _SegmentType.jackpot,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Rotate so the text's baseline sits along the radial axis with the top
    // of the glyphs pointing outward. Translate to the mid-radius.
    canvas.rotate(angleCenter + pi / 2);
    canvas.translate(-painter.width / 2, -midR - painter.height / 2);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  /// Lays out the label and shrinks the font a step at a time until both
  /// dimensions fit inside the cell. Keeps text strictly inside its wedge.
  TextPainter _layoutFitted(
    String label, {
    required double baseSize,
    required Color color,
    required double maxWidth,
    required double maxHeight,
    required bool shadowed,
  }) {
    double fontSize = baseSize;
    TextPainter painter;
    while (true) {
      painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: color,
            height: 1.02,
            shadows: shadowed
                ? const <Shadow>[Shadow(color: Colors.black, blurRadius: 3)]
                : const <Shadow>[],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '',
      )..layout(maxWidth: maxWidth);
      final bool fits = painter.width <= maxWidth && painter.height <= maxHeight;
      if (fits || fontSize <= 7) return painter;
      fontSize -= 1;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.totalBet != totalBet ||
      oldDelegate.accent != accent;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, size.height * 0.16)
      ..quadraticBezierTo(size.width / 2, -size.height * 0.16, size.width, size.height * 0.16)
      ..close();

    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawPath(
      path,
      Paint()..shader = AppColors.goldGradient.createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF6A4405),
    );
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => false;
}
