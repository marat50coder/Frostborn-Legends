import 'package:flutter/material.dart';

// ============================================================
// GRAY ACTIONS — buttons used ONLY on the hearth scenes.
// ============================================================
// Distinct from the game's `FrostButton` (defined in
// `../../widgets/frost_ui.dart`). The gray scenes need a
// tighter, more mobile-native look — a squared rectangle with a
// bright cyan gloss for the primary action and a translucent
// slate pill for the secondary. Different silhouette so no piece
// of button pixel geometry is shared between the game surface
// and the gray surface.
// ============================================================

/// Primary action button on the permission and offline scenes.
class GrayPrimaryButton extends StatefulWidget {
  const GrayPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.height = 56,
    this.iconRight,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;
  final double height;
  final IconData? iconRight;

  @override
  State<GrayPrimaryButton> createState() => _GrayPrimaryButtonState();
}

class _GrayPrimaryButtonState extends State<GrayPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final double lift = _pressed ? 0.0 : 4.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        width: widget.width,
        height: widget.height,
        transform: Matrix4.translationValues(0, -lift, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF67E7FF),
              Color(0xFF1F6CD8),
              Color(0xFF0E3572),
            ],
            stops: <double>[0.0, 0.55, 1.0],
          ),
          border: Border.all(
            color: const Color(0xFFEAF9FF),
            width: 2.2,
          ),
          boxShadow: <BoxShadow>[
            const BoxShadow(
              color: Color(0xFF0A2447),
              offset: Offset(0, 6),
              blurRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFF67E7FF).withValues(alpha: 0.45),
              blurRadius: 24,
              spreadRadius: -6,
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Top-half gloss so the button reads as ice, not water.
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      height: 1.0,
                      shadows: <Shadow>[
                        Shadow(
                          color: Color(0xFF0A1F44),
                          offset: Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  if (widget.iconRight != null) ...<Widget>[
                    const SizedBox(width: 10),
                    Icon(widget.iconRight, size: 20, color: Colors.white),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Secondary "Skip" button on the permission scene. Muted pill,
/// still ≥ 44 dp tall so it never becomes a subdued text link
/// (see pitfalls §12 in the sibling template).
class GrayGhostButton extends StatefulWidget {
  const GrayGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.height = 48,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;
  final double height;

  @override
  State<GrayGhostButton> createState() => _GrayGhostButtonState();
}

class _GrayGhostButtonState extends State<GrayGhostButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: _pressed ? 0.75 : 1.0,
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.black.withValues(alpha: 0.55),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1.6,
            ),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
