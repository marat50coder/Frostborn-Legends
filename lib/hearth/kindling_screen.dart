import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio_service.dart';
import '../core/game_assets.dart';
import '../core/game_state.dart';
import '../screens/menu_screen.dart';
import 'frost_orchestrator.dart';
import 'harbor/path_verdict.dart';
import 'lore/frost_config.dart';
import 'scenes/bell_invite_scene.dart';
import 'scenes/blizzard_scene.dart';
import 'scenes/great_gate_scene.dart';
import 'wireline/beacon_lantern.dart';
import 'wireline/ember_vault.dart';
import 'wireline/warden_bell.dart';

// ============================================================
// KINDLING SCREEN — the sole startup surface.
// ============================================================
// Displays the Frostborn loading art with a progress bar while
// [FrostOrchestrator.decide] resolves, then destructures the
// sealed [PathVerdict] and pushes exactly one route.
//
// On [HallRealm] the boot screen warms the native game's assets
// itself (piggy-backing on the existing GameAssets.preload list)
// before entering MenuScreen — so cold-boot straight into the
// game never shows a second loading UI.
// ============================================================

class KindlingScreen extends StatefulWidget {
  const KindlingScreen({
    super.key,
    required this.orchestrator,
    required this.vault,
    required this.bell,
  });

  final FrostOrchestrator orchestrator;
  final EmberVault vault;
  final WardenBell bell;

  @override
  State<KindlingScreen> createState() => _KindlingScreenState();
}

class _KindlingScreenState extends State<KindlingScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _dotsPeriod = Duration(milliseconds: 1250);

  double _progress = 0.04;
  bool _launched = false;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(vsync: this, duration: _dotsPeriod)
      ..repeat();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    hideSystemBars();
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  Future<void> _drive() async {
    // Pre-flight: if credentials are ready AND no adapter is up,
    // jump STRAIGHT to the blizzard screen — no loading bar
    // flashes first, no verdict POST is composed. Skipped entirely
    // when credentials are not packed (the game path never gates
    // on connectivity, so the loading bar carries on into the
    // slot game as normal).
    if (FrostConfig.credentialsReady) {
      final BeaconLantern preflight = BeaconLantern();
      final bool anyAdapter = await preflight.hasAdapter();
      if (!mounted) return;
      if (!anyAdapter) {
        _launched = true;
        _enterBlizzard();
        return;
      }
    }

    final PathVerdict outcome = await widget.orchestrator.decide(
      onProgress: _liftProgress,
    );
    if (!mounted || _launched) return;
    _launched = true;

    switch (outcome) {
      case HallRealm():
        await _settle();
        if (!mounted) return;
        await _enterGame();
        return;
      case GatewayRealm(url: final String url):
        await _settle();
        if (!mounted) return;
        _enterGateway(url);
        return;
      case BlizzardRealm():
        // Do NOT settle — offline should feel instant.
        _enterBlizzard();
        return;
    }
  }

  Future<void> _enterGame() async {
    // The game itself is portrait-only.
    await SystemChrome.setPreferredOrientations(
      const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ],
    );
    await hideSystemBars();
    // Warm every game asset before pushing MenuScreen so the very
    // first frame is not a black flash.
    await AudioService.instance.init();
    if (!mounted) return;
    final GameState state = context.read<GameState>();
    await state.load();
    await _warmGameAssets();
    if (!mounted) return;
    AudioService.instance.playMusic(GameSounds.menuMusic);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 460),
        pageBuilder: (_, __, ___) => const MenuScreen(),
        transitionsBuilder:
            (_, Animation<double> a, __, Widget child) =>
                FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Future<void> _warmGameAssets() async {
    for (final String path in GameAssets.preload) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
    // The slot symbol art lives in the same asset folder — warm
    // them too so the first slot frame is instant.
    for (final String id in const <String>[
      'cherry', 'banana', 'grapes', 'orange', 'apple', 'watermelon',
      'strawberry', 'pineapple', 'bells', 'bar', 'lollipop', 'gem', 'wild',
      'bonus_fish', 'bonus_zeus', 'bonus_joker', 'bonus_winter',
      'bonus_wheel_snow', 'bonus_wheel_emerald', 'bonus_wheel_amethyst',
      'bonus_wheel_fire', 'bonus_wheel_frost',
    ]) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(GameAssets.symbol(id)), context);
      } catch (_) {}
    }
  }

  void _enterGateway(String url) {
    Widget next;
    if (widget.vault.shouldOfferBell) {
      next = BellInviteScene(
        vault: widget.vault,
        bell: widget.bell,
        gatewayUrl: url,
      );
    } else {
      next = GreatGateScene(
        url: url,
        vault: widget.vault,
        bell: widget.bell,
      );
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => next),
    );
  }

  void _enterBlizzard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BlizzardScene(
          rebuild: (_) => KindlingScreen(
            orchestrator: widget.orchestrator,
            vault: widget.vault,
            bell: widget.bell,
          ),
        ),
      ),
    );
  }

  void _liftProgress(double value) {
    if (mounted) setState(() => _progress = value);
  }

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 320));

  @override
  Widget build(BuildContext context) {
    final Orientation orientation = MediaQuery.orientationOf(context);
    final bool portrait = orientation == Orientation.portrait;
    final Size size = MediaQuery.sizeOf(context);
    final double barWidth =
        portrait ? size.width * 0.78 : size.width * 0.52;
    final String bg = portrait
        ? 'assets/frost_boot_stage/boot_portrait.webp'
        : 'assets/frost_boot_stage/boot_landscape.webp';

    return Scaffold(
      backgroundColor: AppColors.night,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x00000000),
                  Color(0x22000000),
                  Color(0xCC030817),
                ],
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
                  SizedBox(
                    width: barWidth,
                    child: _KindlingBar(value: _progress),
                  ),
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: _dots,
                    builder: (BuildContext ctx, _) {
                      final int n = (_dots.value * 4).floor() % 4;
                      return Text(
                        'Loading${'.' * n}',
                        style: const TextStyle(
                          color: Color(0xFFEAF9FF),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          height: 1.0,
                          shadows: <Shadow>[
                            Shadow(
                              color: Color(0xAA000000),
                              offset: Offset(0, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      );
                    },
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

/// Progress bar with an obvious animation:
///   • the fill width lerps toward [value] whenever it changes,
///   • a diagonal shine sweeps across the fill continuously so
///     the user can see the bar is alive even during long steps.
class _KindlingBar extends StatefulWidget {
  const _KindlingBar({required this.value});

  final double value;

  @override
  State<_KindlingBar> createState() => _KindlingBarState();
}

class _KindlingBarState extends State<_KindlingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: widget.value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      builder: (BuildContext ctx, double shown, _) {
        return Container(
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xCC03091C),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: const Color(0xFFF7CE4B).withValues(alpha: 0.9),
              width: 2,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0xAA000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: shown,
                      child: AnimatedBuilder(
                        animation: _shine,
                        builder: (BuildContext ctx, _) => _FillPaint(
                          shineT: _shine.value,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FillPaint extends StatelessWidget {
  const _FillPaint({required this.shineT});

  final double shineT;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFF2E8FD6),
            Color(0xFF7FD8FF),
            Color(0xFFFFF3B0),
            Color(0xFFF7CE4B),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints c) {
          // Shine band is 30 % of the fill width; it slides from
          // fully off-screen left to fully off-screen right so the
          // motion is obvious even when the fill is short.
          final double bandWidth = (c.maxWidth * 0.3).clamp(24.0, 160.0);
          final double travel = c.maxWidth + bandWidth;
          final double x = -bandWidth + travel * shineT;
          return Stack(
            children: <Widget>[
              // A soft top gloss so the fill looks glossy, not flat.
              Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.42,
                  widthFactor: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
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
              // Moving shine band. Rotated slightly for a diagonal
              // sweep that reads as "in motion".
              Positioned.fill(
                child: ClipRect(
                  child: Transform.translate(
                    offset: Offset(x, 0),
                    child: Transform.rotate(
                      angle: -0.35,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: bandWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: <Color>[
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.70),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              stops: const <double>[0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
