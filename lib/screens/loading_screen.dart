import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio_service.dart';
import '../core/game_assets.dart';
import '../core/game_state.dart';
import '../widgets/frost_ui.dart';
import 'menu_screen.dart';

/// Boot screen. It supports both orientations; the rest of the game is locked
/// to portrait once loading finishes.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  static const Duration _minimumDuration = Duration(milliseconds: 2800);

  /// The bar never reaches 100% while work is still pending; it only completes
  /// in the moment right before the menu is pushed.
  static const double _waitingCap = 0.96;

  double _progress = 0;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    unawaited(hideSystemBars());
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  void _set(double value) {
    if (!mounted) return;
    setState(() => _progress = value.clamp(0, _waitingCap));
  }

  Future<void> _boot() async {
    final Stopwatch watch = Stopwatch()..start();
    final GameState state = context.read<GameState>();

    _set(0.06);
    await AudioService.instance.init();
    _set(0.16);
    await state.load();
    _set(0.26);

    const List<String> images = GameAssets.preload;
    for (int i = 0; i < images.length; i++) {
      if (!mounted) return;
      await precacheImage(AssetImage(images[i]), context);
      _set(0.26 + 0.52 * ((i + 1) / images.length));
    }

    if (!mounted) return;
    final List<String> symbols = _symbolAssets;
    for (int i = 0; i < symbols.length; i++) {
      if (!mounted) return;
      await precacheImage(AssetImage(symbols[i]), context);
      _set(0.78 + 0.18 * ((i + 1) / symbols.length));
    }

    final Duration remaining = _minimumDuration - watch.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (!mounted) return;

    // Everything is ready: fill the bar completely, then launch.
    setState(() => _progress = 1);
    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (!mounted || _navigated) return;
    _navigated = true;

    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    await hideSystemBars();
    if (!mounted) return;
    unawaited(AudioService.instance.playMusic(GameSounds.menuMusic));
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const MenuScreen(),
        transitionsBuilder: (_, Animation<double> animation, __, Widget child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  List<String> get _symbolAssets => <String>[
    for (final String id in <String>[
      'cherry', 'banana', 'grapes', 'orange', 'apple', 'watermelon',
      'strawberry', 'pineapple', 'bells', 'bar', 'lollipop', 'gem', 'wild',
      'bonus_fish', 'bonus_zeus', 'bonus_joker', 'bonus_winter',
      'bonus_wheel_snow', 'bonus_wheel_emerald', 'bonus_wheel_amethyst',
      'bonus_wheel_fire', 'bonus_wheel_frost',
    ])
      GameAssets.symbol(id),
  ];

  @override
  Widget build(BuildContext context) {
    final Orientation orientation = MediaQuery.orientationOf(context);
    final bool portrait = orientation == Orientation.portrait;
    final Size size = MediaQuery.sizeOf(context);
    final double barWidth = portrait ? size.width * 0.78 : size.width * 0.52;

    return Scaffold(
      backgroundColor: AppColors.night,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            portrait ? GameAssets.loadingPortrait : GameAssets.loadingLandscape,
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x00000000), Color(0x22000000), Color(0xCC030817)],
                stops: <double>[0.0, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: portrait ? 46 : 22),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  SizedBox(width: barWidth, child: _ProgressBar(value: _progress)),
                  const SizedBox(height: 14),
                  const _LoadingLabel(),
                  const SizedBox(height: 10),
                  Text(
                    'Free to play • Fun coins only • No real money gambling',
                    textAlign: TextAlign.center,
                    style: AppText.body(10, weight: FontWeight.w600).copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      builder: (BuildContext context, double shown, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xCC03091C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.85), width: 2),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x99000000), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: shown.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: <Color>[
                              Color(0xFF2E8FD6),
                              Color(0xFF7FD8FF),
                              Color(0xFFFFF3B0),
                              Color(0xFFF7CE4B),
                            ],
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(color: Color(0x887FD8FF), blurRadius: 12),
                          ],
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: FractionallySizedBox(
                            heightFactor: 0.42,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(shown * 100).round()}%',
              textAlign: TextAlign.center,
              style: AppText.numeric(12).copyWith(
                color: AppColors.ice,
                shadows: const <Shadow>[Shadow(color: Colors.black87, blurRadius: 6)],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoadingLabel extends StatefulWidget {
  const _LoadingLabel();

  @override
  State<_LoadingLabel> createState() => _LoadingLabelState();
}

class _LoadingLabelState extends State<_LoadingLabel> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

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
        final int dots = (_controller.value * 4).floor() % 4;
        // The dots live in a fixed-width slot so the word does not jitter.
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StrokeText('Loading', style: AppText.title(22), strokeWidth: 3.5),
            SizedBox(
              width: 34,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StrokeText(
                  '.' * dots,
                  style: AppText.title(22),
                  strokeWidth: 3.5,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
