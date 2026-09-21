import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/audio_service.dart';
import '../core/game_state.dart';

/// Outlined text with an optional gradient fill, used for every heading.
class StrokeText extends StatelessWidget {
  const StrokeText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = AppColors.goldGradient,
    this.strokeColor = const Color(0xFF07122B),
    this.strokeWidth = 4,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final TextStyle style;
  final Gradient? gradient;
  final Color strokeColor;
  final double strokeWidth;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final Widget fill = gradient == null
        ? Text(text, textAlign: textAlign, style: style)
        : ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (Rect bounds) => gradient!.createShader(bounds),
            child: Text(
              text,
              textAlign: textAlign,
              style: style.copyWith(color: Colors.white),
            ),
          );

    return Stack(
      children: <Widget>[
        Text(
          text,
          textAlign: textAlign,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
            shadows: const <Shadow>[
              Shadow(color: Color(0xAA000000), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
        ),
        fill,
      ],
    );
  }
}

/// Translucent navy panel with a gold rim.
class FrostPanel extends StatelessWidget {
  const FrostPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.borderColor = AppColors.gold,
    this.gradient = AppColors.panelGradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor.withValues(alpha: 0.75), width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

enum FrostButtonStyle { gold, ice, crimson, ghost }

class FrostButton extends StatefulWidget {
  const FrostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = FrostButtonStyle.gold,
    this.height = 56,
    this.width,
    this.fontSize = 18,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final FrostButtonStyle style;
  final double height;
  final double? width;
  final double fontSize;
  final bool enabled;

  @override
  State<FrostButton> createState() => _FrostButtonState();
}

class _FrostButtonState extends State<FrostButton> {
  bool _down = false;

  List<Color> get _colors => switch (widget.style) {
    FrostButtonStyle.gold => const <Color>[Color(0xFFFFE489), Color(0xFFE0A81E), Color(0xFF8C5B0B)],
    FrostButtonStyle.ice => const <Color>[Color(0xFFBFF0FF), Color(0xFF3FA8E0), Color(0xFF13497A)],
    FrostButtonStyle.crimson => const <Color>[Color(0xFFFF8A78), Color(0xFFD22B3C), Color(0xFF6B0A14)],
    FrostButtonStyle.ghost => const <Color>[Color(0xFF2A3D6B), Color(0xFF16254A), Color(0xFF0A1226)],
  };

  Color get _labelColor =>
      widget.style == FrostButtonStyle.ghost ? Colors.white : const Color(0xFF241705);

  List<Shadow> get _labelShadows => widget.style == FrostButtonStyle.ghost
      ? const <Shadow>[Shadow(color: Color(0x88000000), offset: Offset(0, 1), blurRadius: 4)]
      : const <Shadow>[Shadow(color: Color(0x66FFFFFF), offset: Offset(0, 1))];

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onPressed != null;
    final double scale = _down ? 0.96 : 1.0;

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: active ? (_) => setState(() => _down = true) : null,
        onTapCancel: active ? () => setState(() => _down = false) : null,
        onTapUp: active ? (_) => setState(() => _down = false) : null,
        onTap: active
            ? () {
                AudioService.instance.click();
                widget.onPressed!.call();
              }
            : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 90),
          child: Opacity(
            opacity: active ? 1 : 0.45,
            child: Container(
              height: widget.height,
              width: widget.width,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _colors,
                ),
                borderRadius: BorderRadius.circular(widget.height / 2.6),
                border: Border.all(color: const Color(0xFFFFEDB0), width: 2),
                boxShadow: <BoxShadow>[
                  const BoxShadow(color: Color(0xAA000000), blurRadius: 12, offset: Offset(0, 6)),
                  BoxShadow(
                    color: _colors[1].withValues(alpha: 0.45),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (widget.icon != null) ...<Widget>[
                    Icon(widget.icon, size: widget.fontSize + 4, color: _labelColor),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: AppText.button(widget.fontSize).copyWith(
                          color: _labelColor,
                          shadows: _labelShadows,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular icon button used in top bars.
class FrostIconButton extends StatelessWidget {
  const FrostIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 42,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = GestureDetector(
      onTap: () {
        AudioService.instance.click();
        onPressed();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1D3163), Color(0xFF0A1226)],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.8), width: 2),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x88000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: AppColors.gold, size: size * 0.52),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Coin balance pill.
class CoinChip extends StatelessWidget {
  const CoinChip({super.key, required this.coins, this.label = 'COINS', this.compact = false});

  final int coins;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 6 : 9),
      decoration: BoxDecoration(
        gradient: AppColors.panelGradient,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.8), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: compact ? 16 : 20,
            height: compact ? 16 : 20,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.goldGradient),
            child: Icon(Icons.star_rounded, size: compact ? 11 : 14, color: AppColors.goldDark),
          ),
          SizedBox(width: compact ? 6 : 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!compact)
                Text(
                  label,
                  style: AppText.body(9, weight: FontWeight.w700).copyWith(
                    color: AppColors.ice.withValues(alpha: 0.8),
                    letterSpacing: 1.4,
                  ),
                ),
              Text(
                formatCoins(coins),
                style: AppText.numeric(compact ? 14 : 16).copyWith(color: AppColors.gold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated number that ticks up to [value].
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 650),
    this.prefix = '',
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double animated, _) =>
          Text('$prefix${formatCoins(animated.round())}', style: style),
    );
  }
}

/// Full-bleed background image with a readability scrim.
class GameBackground extends StatelessWidget {
  const GameBackground({
    super.key,
    required this.asset,
    required this.child,
    this.scrim = 0.45,
    this.alignment = Alignment.center,
  });

  final String asset;
  final Widget child;
  final double scrim;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(asset, fit: BoxFit.cover, alignment: alignment),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                AppColors.night.withValues(alpha: scrim + 0.15),
                AppColors.night.withValues(alpha: scrim),
                AppColors.night.withValues(alpha: scrim + 0.25),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Soft pulsing glow used behind winning symbols and bonus art.
class PulseGlow extends StatefulWidget {
  const PulseGlow({
    super.key,
    required this.child,
    this.color = AppColors.gold,
    this.minScale = 0.98,
    this.maxScale = 1.06,
    this.duration = const Duration(milliseconds: 900),
  });

  final Widget child;
  final Color color;
  final double minScale;
  final double maxScale;
  final Duration duration;

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
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
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: widget.minScale + (widget.maxScale - widget.minScale) * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.25 + 0.35 * t),
                  blurRadius: 24 + 20 * t,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
