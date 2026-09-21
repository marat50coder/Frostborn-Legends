import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/audio_service.dart';
import '../../core/game_state.dart';
import '../../game/slot_symbols.dart';
import '../../widgets/frost_ui.dart';

/// Announcement shown on the slot screen right before a bonus round starts.
Future<void> showBonusIntro(BuildContext context, BonusGame bonus, int symbolCount) {
  AudioService.instance.bigBonus();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (BuildContext context, _, __) => _BonusIntro(bonus: bonus, symbolCount: symbolCount),
    transitionBuilder: (BuildContext context, Animation<double> animation, _, Widget child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );
}

class _BonusIntro extends StatefulWidget {
  const _BonusIntro({required this.bonus, required this.symbolCount});

  final BonusGame bonus;
  final int symbolCount;

  @override
  State<_BonusIntro> createState() => _BonusIntroState();
}

class _BonusIntroState extends State<_BonusIntro> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                StrokeText(
                  'BONUS!',
                  style: AppText.title(46),
                  gradient: AppColors.iceGradient,
                  strokeWidth: 6,
                ),
                const SizedBox(height: 10),
                PulseGlow(
                  color: AppColors.ice,
                  child: SizedBox(
                    height: 190,
                    child: Image.asset(widget.bonus.artwork, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 14),
                StrokeText(widget.bonus.title.toUpperCase(), style: AppText.title(26)),
                const SizedBox(height: 8),
                Text(
                  '${widget.symbolCount} bonus symbols',
                  style: AppText.body(14, weight: FontWeight.w700).copyWith(color: AppColors.gold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.bonus.tagline,
                  textAlign: TextAlign.center,
                  style: AppText.body(13).copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared chrome for every bonus round.
class BonusScaffold extends StatelessWidget {
  const BonusScaffold({
    super.key,
    required this.title,
    required this.background,
    required this.child,
    this.collected,
    this.subtitle,
    this.scrim = 0.62,
    this.onQuit,
  });

  final String title;
  final String background;

  /// Running total for the round, or null for bonuses that pay out only once.
  final int? collected;
  final Widget child;
  final String? subtitle;
  final double scrim;
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      child: Scaffold(
        body: GameBackground(
          asset: background,
          scrim: scrim,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Column(
                    children: <Widget>[
                      StrokeText(title.toUpperCase(), style: AppText.title(22)),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: AppText.body(12).copyWith(color: AppColors.ice),
                        ),
                      ],
                      if (collected != null) ...<Widget>[
                        const SizedBox(height: 8),
                        _CollectedBar(collected: collected!),
                      ],
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectedBar extends StatelessWidget {
  const _CollectedBar({required this.collected});

  final int collected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppColors.panelGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.8), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'BONUS WIN  ',
            style: AppText.body(11, weight: FontWeight.w800).copyWith(
              color: AppColors.ice,
              letterSpacing: 1.4,
            ),
          ),
          CountUpText(
            value: collected,
            duration: const Duration(milliseconds: 450),
            style: AppText.numeric(20).copyWith(color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

/// Closing screen of a bonus round. Pops the bonus route with [coins].
Future<void> showBonusResult(
  BuildContext context, {
  required int coins,
  required String title,
  String? subtitle,
  String? artwork,
}) async {
  if (coins > 0) {
    AudioService.instance.victory();
  } else {
    AudioService.instance.defeat();
  }
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (BuildContext dialogContext, _, __) {
      // Without a Material ancestor the dialog text falls back to Flutter's
      // yellow underlined debug style.
      return Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: FrostPanel(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (artwork != null)
                    SizedBox(height: 120, child: Image.asset(artwork, fit: BoxFit.contain)),
                  if (artwork != null) const SizedBox(height: 12),
                  StrokeText(title.toUpperCase(), style: AppText.title(24)),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppText.body(12).copyWith(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 16),
                  CountUpText(
                    value: coins,
                    duration: const Duration(milliseconds: 900),
                    style: AppText.numeric(38).copyWith(
                      color: AppColors.gold,
                      shadows: const <Shadow>[Shadow(color: Colors.black87, blurRadius: 10)],
                    ),
                  ),
                  Text(
                    'FUN COINS',
                    style: AppText.body(10, weight: FontWeight.w800).copyWith(
                      color: AppColors.ice,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FrostButton(
                    label: 'COLLECT',
                    width: double.infinity,
                    height: 52,
                    fontSize: 18,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (BuildContext context, Animation<double> animation, _, Widget child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );
  if (context.mounted) Navigator.of(context).pop(coins);
}

/// Small pill describing a prize value in coins.
class PrizeTag extends StatelessWidget {
  const PrizeTag({super.key, required this.coins, this.label, this.color = AppColors.gold});

  final int coins;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1.5),
      ),
      child: Text(
        label ?? formatCoins(coins),
        style: AppText.numeric(13).copyWith(color: color),
      ),
    );
  }
}
