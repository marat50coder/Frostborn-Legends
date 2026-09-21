import 'dart:math';
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/audio_service.dart';
import '../core/game_assets.dart';
import '../game/slot_engine.dart';
import '../game/slot_symbols.dart';

/// The 5x3 reel window. A spin is triggered by bumping [spinToken]; the widget
/// animates every reel to the symbols supplied in [grid].
///
/// When two scatters of the same bonus have already landed, the remaining
/// reels go into anticipation: they keep spinning far longer while the whole
/// frame zooms in and the live reel lights up in the bonus colour.
class ReelGrid extends StatefulWidget {
  const ReelGrid({
    super.key,
    required this.engine,
    required this.grid,
    required this.spinToken,
    this.onAllStopped,
    this.highlightCells = const <(int, int)>{},
    this.stickyCells = const <(int, int)>{},
    this.activeLine,
    this.reelDuration = const Duration(milliseconds: 780),
    this.reelStagger = const Duration(milliseconds: 150),
    this.anticipationEnabled = true,
  });

  final SlotEngine engine;
  final List<List<String>> grid;
  final int spinToken;
  final VoidCallback? onAllStopped;
  final Set<(int, int)> highlightCells;
  final Set<(int, int)> stickyCells;
  final List<int>? activeLine;
  final Duration reelDuration;
  final Duration reelStagger;
  final bool anticipationEnabled;

  @override
  State<ReelGrid> createState() => _ReelGridState();
}

class _ReelGridState extends State<ReelGrid> with TickerProviderStateMixin {
  static const int _padAfter = 8;
  // Hot reel spins ~2× longer than normal while two scatters wait for the
  // third — that's the whole point of anticipation, so give it real time.
  static const int _anticipationExtraMs = 1500;

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _progress;
  late List<List<String>> _strips;
  late List<List<String>> _resting;
  int _stopped = kReels;

  List<bool> _anticipateReel = List<bool>.filled(kReels, false);
  BonusGame? _anticipatedBonus;
  int? _anticipationReel;
  Set<(int, int)> _hotCells = <(int, int)>{};

  @override
  void initState() {
    super.initState();
    _resting = _copy(widget.grid);
    _strips = List<List<String>>.generate(kReels, (int reel) => _resting[reel]);
    _controllers = List<AnimationController>.generate(
      kReels,
      (_) => AnimationController(vsync: this, duration: widget.reelDuration),
    );
    _progress = _controllers.map(_buildCurve).toList(growable: false);
    for (int reel = 0; reel < kReels; reel++) {
      _controllers[reel].addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) _onReelStopped(reel);
      });
    }
  }

  Animation<double> _buildCurve(AnimationController controller) {
    return TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: 0.05).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 12,
      ),
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0.05, end: 0.90), weight: 56),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.90, end: 1.04).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 24,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.04, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
    ]).animate(controller);
  }

  List<List<String>> _copy(List<List<String>> source) =>
      source.map((List<String> column) => List<String>.from(column)).toList();

  @override
  void didUpdateWidget(covariant ReelGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinToken != oldWidget.spinToken) {
      _startSpin();
    } else if (!identical(widget.grid, oldWidget.grid) && _stopped == kReels) {
      setState(() {
        _resting = _copy(widget.grid);
        _strips = List<List<String>>.generate(kReels, (int reel) => _resting[reel]);
      });
    }
  }

  /// A reel anticipates while exactly two scatters of the same bonus have
  /// landed before it, so the third one is still live. Once the bonus is
  /// secured the remaining reels stop at their normal pace.
  (List<bool>, List<BonusGame?>) _planAnticipation(List<List<String>> target) {
    final List<bool> flags = List<bool>.filled(kReels, false);
    final List<BonusGame?> hot = List<BonusGame?>.filled(kReels, null);
    if (!widget.anticipationEnabled) return (flags, hot);

    final Map<String, int> counts = <String, int>{};
    for (int reel = 0; reel < kReels; reel++) {
      for (final MapEntry<String, int> entry in counts.entries) {
        if (entry.value == 2) {
          flags[reel] = true;
          hot[reel] = SlotSymbols.of(entry.key).bonus;
          break;
        }
      }
      for (final String id in target[reel]) {
        if (SlotSymbols.of(id).kind == SymbolKind.bonus) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }
    }
    return (flags, hot);
  }

  void _startSpin() {
    final List<List<String>> target = _copy(widget.grid);
    final (List<bool> flags, List<BonusGame?> hot) = _planAnticipation(target);

    setState(() {
      _stopped = 0;
      _anticipateReel = flags;
      _anticipatedBonus = null;
      _anticipationReel = null;
      _hotCells = <(int, int)>{};
      _strips = List<List<String>>.generate(kReels, (int reel) {
        return <String>[
          ...target[reel],
          for (int i = 0; i < _padAfter; i++) widget.engine.decorativeSymbol(reel),
          ..._resting[reel],
        ];
      });
      _resting = target;
    });

    // Stop times must stay strictly ordered left to right even though an
    // anticipating reel runs far longer than its neighbours.
    final int base = widget.reelDuration.inMilliseconds;
    final int stagger = widget.reelStagger.inMilliseconds;
    int previousStart = 0;
    int previousStop = 0;

    for (int reel = 0; reel < kReels; reel++) {
      final int duration = flags[reel] ? base + _anticipationExtraMs : base;
      int start = flags[reel] && reel > 0 ? previousStop - 120 : reel * stagger;
      if (reel > 0) {
        start = max(start, previousStart + 60);
        start = max(start, previousStop + 140 - duration);
      }
      start = max(start, 0);
      previousStart = start;
      previousStop = start + duration;

      final AnimationController controller = _controllers[reel];
      controller.reset();
      controller.duration = Duration(milliseconds: duration);
      Future<void>.delayed(Duration(milliseconds: start), () {
        if (!mounted) return;
        if (flags[reel]) _beginAnticipation(reel, hot[reel]);
        controller.forward();
      });
    }
  }

  void _beginAnticipation(int reel, BonusGame? bonus) {
    if (bonus == null) return;
    final Set<(int, int)> cells = <(int, int)>{};
    for (int r = 0; r < reel; r++) {
      for (int row = 0; row < kRows; row++) {
        if (_resting[r][row] == bonus.symbolId) cells.add((r, row));
      }
    }
    setState(() {
      _anticipatedBonus = bonus;
      _anticipationReel = reel;
      _hotCells = cells;
    });
    AudioService.instance.play(GameSounds.selection, volume: 0.5);
  }

  void _endAnticipation() {
    if (!mounted) return;
    setState(() {
      _anticipatedBonus = null;
      _anticipationReel = null;
      _hotCells = <(int, int)>{};
    });
  }

  void _onReelStopped(int reel) {
    if (!mounted) return;
    AudioService.instance.play(GameSounds.selection, volume: 0.3);
    setState(() => _stopped = max(_stopped, reel + 1));

    final bool moreToCome = <int>[
      for (int i = reel + 1; i < kReels; i++) i,
    ].any((int i) => _anticipateReel[i]);
    if (_anticipationReel == reel && !moreToCome) _endAnticipation();

    if (reel == kReels - 1) {
      _endAnticipation();
      widget.onAllStopped?.call();
    }
  }

  bool get _isSpinning => _stopped < kReels;

  @override
  void dispose() {
    for (final AnimationController controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BonusGame? hot = _anticipatedBonus;
    final Color lamp = hot?.accent ?? AppColors.gold;
    final bool celebrating =
        widget.highlightCells.isNotEmpty || _hotCells.isNotEmpty;

    return AnimatedScale(
      // Zoom-in for anticipation: slower and a touch deeper so the tension
      // is felt while the last reel keeps spinning.
      scale: hot != null ? 1.06 : 1.0,
      duration: Duration(milliseconds: hot != null ? 420 : 260),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFF3C0),
              Color(0xFFE0B13A),
              Color(0xFF8A5A0C),
              Color(0xFFC4922A),
            ],
            stops: <double>[0, 0.28, 0.72, 1],
          ),
          boxShadow: <BoxShadow>[
            const BoxShadow(color: Color(0xCC000000), blurRadius: 22, offset: Offset(0, 10)),
            BoxShadow(
              color: lamp.withValues(alpha: hot != null ? 0.70 : 0.38),
              blurRadius: hot != null ? 36 : 22,
              spreadRadius: -4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            color: const Color(0xFF070B16),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: _MarqueeLights(color: lamp, racing: hot != null || celebrating),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(11),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFFE2B34A), width: 1.7),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFF101A36), Color(0xFF050814)],
                    ),
                  ),
                  padding: const EdgeInsets.all(5),
                  child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints well) {
                            final double cellWidth = well.maxWidth / kReels;
                            final double cellHeight = well.maxHeight / kRows;
                            return Stack(
                              children: <Widget>[
                                const ColoredBox(color: Color(0xFF03060F)),
                                Row(
                                  children: <Widget>[
                                    for (int reel = 0; reel < kReels; reel++)
                                      Expanded(
                                        child: RepaintBoundary(
                                          child: _buildReel(
                                            reel,
                                            cellWidth,
                                            cellHeight,
                                            celebrating: celebrating,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const Positioned.fill(
                                  child: IgnorePointer(child: CustomPaint(painter: _ReelMeshPainter())),
                                ),
                                const Positioned.fill(
                                  child: IgnorePointer(child: _GlassSheen()),
                                ),
                                if (hot != null && _anticipationReel != null)
                                  Positioned(
                                    left: cellWidth * _anticipationReel!,
                                    width: cellWidth,
                                    top: 0,
                                    bottom: 0,
                                    child: IgnorePointer(child: _AnticipationBeam(color: hot.accent)),
                                  ),
                                if (widget.activeLine != null && !_isSpinning)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _PaylinePainter(
                                          rows: widget.activeLine!,
                                          cellWidth: cellWidth,
                                          cellHeight: cellHeight,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildReel(
    int reel,
    double cellWidth,
    double cellHeight, {
    required bool celebrating,
  }) {
    final List<String> strip = _strips[reel];
    final bool compact = strip.length == kRows;
    final double stripHeight = strip.length * cellHeight;
    // Keep waiting reels in the spinning (frameless) look until they land.
    final bool moving = !compact && _stopped <= reel;
    final int travelRows = strip.length - kRows;

    final Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < strip.length; index++)
          _SymbolCell(
            symbolId: strip[index],
            width: cellWidth,
            height: cellHeight,
            highlighted: !moving &&
                index >= 0 &&
                index < kRows &&
                (widget.highlightCells.contains((reel, index)) ||
                    _hotCells.contains((reel, index))),
            sticky: !moving &&
                index >= 0 &&
                index < kRows &&
                widget.stickyCells.contains((reel, index)),
            dimmed: !moving &&
                celebrating &&
                index < kRows &&
                !widget.highlightCells.contains((reel, index)) &&
                !_hotCells.contains((reel, index)) &&
                !widget.stickyCells.contains((reel, index)),
            spinning: moving,
          ),
      ],
    );

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: stripHeight,
        maxHeight: stripHeight,
        child: AnimatedBuilder(
          animation: _progress[reel],
          child: column,
          builder: (BuildContext context, Widget? child) {
            // progress 0: previous symbols sit in the window (strip is shifted
            // up). progress 1: the result sits at y = 0. Increasing Y moves
            // the column down, so symbols enter from the top.
            final double offset = compact
                ? 0
                : (_progress[reel].value - 1) * travelRows * cellHeight;
            return Transform.translate(offset: Offset(0, offset), child: child);
          },
        ),
      ),
    );
  }
}

class _SymbolCell extends StatelessWidget {
  const _SymbolCell({
    required this.symbolId,
    required this.width,
    required this.height,
    required this.highlighted,
    required this.sticky,
    required this.dimmed,
    required this.spinning,
  });

  final String symbolId;
  final double width;
  final double height;
  final bool highlighted;
  final bool sticky;
  final bool dimmed;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final SlotSymbol symbol = SlotSymbols.of(symbolId);
    final int cache = (width * MediaQuery.devicePixelRatioOf(context)).round().clamp(48, 140);
    final Widget image = Image.asset(
      symbol.asset,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: spinning ? FilterQuality.low : FilterQuality.medium,
      cacheWidth: cache,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

    final Widget padded = Padding(
      padding: EdgeInsets.all(width * (spinning ? 0.08 : 0.07)),
      child: image,
    );

    if (spinning) {
      return SizedBox(width: width, height: height, child: padded);
    }

    final Color glowColor = symbol.bonus?.accent ?? AppColors.gold;
    Widget child = padded;
    if (highlighted || sticky) {
      child = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (highlighted) _WinGlow(radius: 10, color: glowColor),
          if (sticky)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.crimsonLight, width: 2),
                color: AppColors.crimson.withValues(alpha: 0.22),
              ),
            ),
          padded,
        ],
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: dimmed ? 0.34 : 1,
        child: child,
      ),
    );
  }
}

/// Chasing bulbs around the gold cabinet. Isolated in its own ticker so the
/// reels are not rebuilt every frame.
class _MarqueeLights extends StatefulWidget {
  const _MarqueeLights({required this.color, required this.racing});

  final Color color;
  final bool racing;

  @override
  State<_MarqueeLights> createState() => _MarqueeLightsState();
}

class _MarqueeLightsState extends State<_MarqueeLights>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void didUpdateWidget(covariant _MarqueeLights oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Duration next = widget.racing
        ? const Duration(milliseconds: 720)
        : const Duration(milliseconds: 1400);
    if (_controller.duration != next) {
      _controller.duration = next;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) => CustomPaint(
        painter: _MarqueePainter(progress: _controller.value, color: widget.color),
      ),
    );
  }
}

class _MarqueePainter extends CustomPainter {
  _MarqueePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const int _bulbs = 36;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
          const Radius.circular(16),
        ),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      for (int i = 0; i < _bulbs; i++) {
        final double along = ((i / _bulbs) + progress) % 1.0 * metric.length;
        final Tangent? tangent = metric.getTangentForOffset(along);
        if (tangent == null) continue;
        final double phase = (i / _bulbs - progress) % 1.0;
        final bool lit = phase < 0.14 || phase > 0.92;
        final double glow = lit ? 1 : 0.22;
        canvas.drawCircle(
          tangent.position,
          lit ? 3.4 : 2.4,
          Paint()..color = color.withValues(alpha: 0.22 + 0.78 * glow),
        );
        if (lit) {
          canvas.drawCircle(
            tangent.position,
            5.8,
            Paint()..color = color.withValues(alpha: 0.22),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MarqueePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _GlassSheen extends StatelessWidget {
  const _GlassSheen();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: <Color>[Color(0x22FFFFFF), Color(0x00000000)],
        ),
      ),
    );
  }
}

class _ReelMeshPainter extends CustomPainter {
  const _ReelMeshPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint reelPaint = Paint()
      ..color = const Color(0x55E2B34A)
      ..strokeWidth = 1.2;
    for (int i = 1; i < kReels; i++) {
      final double x = size.width / kReels * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), reelPaint);
    }
    final Paint rowPaint = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 1;
    for (int i = 1; i < kRows; i++) {
      final double y = size.height / kRows * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Column of light over the reel that still has to deliver the third scatter.
class _AnticipationBeam extends StatefulWidget {
  const _AnticipationBeam({required this.color});

  final Color color;

  @override
  State<_AnticipationBeam> createState() => _AnticipationBeamState();
}

class _AnticipationBeamState extends State<_AnticipationBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final double t = Curves.easeInOut.transform(_controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                widget.color.withValues(alpha: 0.30 + 0.22 * t),
                widget.color.withValues(alpha: 0.06 + 0.10 * t),
                widget.color.withValues(alpha: 0.30 + 0.22 * t),
              ],
            ),
            border: Border.symmetric(
              vertical: BorderSide(
                color: widget.color.withValues(alpha: 0.75 + 0.25 * t),
                width: 2.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WinGlow extends StatefulWidget {
  const _WinGlow({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  State<_WinGlow> createState() => _WinGlowState();
}

class _WinGlowState extends State<_WinGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final double t = Curves.easeInOut.transform(_controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: widget.color.withValues(alpha: 0.75 + 0.25 * t), width: 2.8),
            gradient: RadialGradient(
              colors: <Color>[
                widget.color.withValues(alpha: 0.34 + 0.22 * t),
                widget.color.withValues(alpha: 0.06),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.color.withValues(alpha: 0.45 + 0.35 * t),
                blurRadius: 12 + 14 * t,
                spreadRadius: 0,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaylinePainter extends CustomPainter {
  _PaylinePainter({required this.rows, required this.cellWidth, required this.cellHeight});

  final List<int> rows;
  final double cellWidth;
  final double cellHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();
    for (int reel = 0; reel < rows.length; reel++) {
      final Offset point = Offset(
        cellWidth * (reel + 0.5),
        cellHeight * (rows[reel] + 0.5),
      );
      if (reel == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xCC07122B),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = AppColors.goldGradient.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _PaylinePainter oldDelegate) =>
      oldDelegate.rows != rows ||
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.cellHeight != cellHeight;
}
