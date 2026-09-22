import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/game_state.dart';
import 'hearth/frost_orchestrator.dart';
import 'hearth/kindling_screen.dart';
import 'hearth/lore/frost_config.dart';
import 'hearth/scenes/great_gate_scene.dart';
import 'hearth/wireline/beacon_lantern.dart';
import 'hearth/wireline/ember_vault.dart';
import 'hearth/wireline/frost_mask.dart';
import 'hearth/wireline/oracle_query.dart';
import 'hearth/wireline/sky_banner.dart';
import 'hearth/wireline/warden_bell.dart';

// ============================================================
// main.dart — bootstrap wiring only.
// ============================================================
// Order of operations (DO NOT reorder without reading hearth/
// docstrings first):
//   1. WidgetsFlutterBinding      — required before any plugin call.
//   2. Firebase + AppCheck        — wrapped in try/catch. A build
//      without google-services.json still boots and lands in the
//      native slot game (see FrostConfig.credentialsReady).
//   3. Preferred orientations + status-bar chrome — set once so
//      the kindling screen renders edge-to-edge on frame one.
//   4. FrostMask.prime            — assembles the forged UA. MUST
//      run before any HTTP client or the WebView is constructed.
//   5. EmberVault.prime           — hydrates the shared_prefs so
//      the orchestrator's decision is synchronous.
//   6. Assemble pipeline, mount FrostbornApp with a top-level
//      ChangeNotifierProvider so both the game surface and the
//      hearth's kindling screen share ONE GameState instance.
// ============================================================

/// App-wide navigator key. Used by [WardenBell.onGlobalWarmUrl]
/// to swap in a fresh WebView from any scene — including the
/// slot game — when a push tap arrives with no sink attached.
final GlobalKey<NavigatorState> hearthNavKey =
    GlobalKey<NavigatorState>(debugLabel: 'hearth');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(hearthBellIsolate);
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {
    // No google-services.json yet, or Play Integrity offline. The
    // orchestrator handles the credential-missing case by
    // returning HallRealm — the app keeps working as a slot game.
  }

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await FrostMask.prime();

  final EmberVault vault = EmberVault();
  await vault.prime();

  final BeaconLantern lantern = BeaconLantern();
  final SkyBanner banner = SkyBanner();
  final OracleQuery oracle = OracleQuery(vault);
  final WardenBell bell = WardenBell(vault);

  // Global fallback for warm push taps. Fires when the user is on
  // Kindling, the invite scene, or inside the slot game — any
  // surface that hasn't hooked GreatGateScene's per-instance
  // sink. We tear the stack down to a fresh WebView bound to the
  // pushed URL, matching what a cold tap would do.
  bell.onGlobalWarmUrl = (String url) {
    final NavigatorState? nav = hearthNavKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => GreatGateScene(
          url: url,
          vault: vault,
          bell: bell,
        ),
      ),
      (_) => false,
    );
  };

  final FrostOrchestrator orchestrator = FrostOrchestrator(
    vault: vault,
    lantern: lantern,
    banner: banner,
    oracle: oracle,
    bell: bell,
  );

  runApp(FrostbornApp(
    orchestrator: orchestrator,
    vault: vault,
    bell: bell,
  ));
}

class FrostbornApp extends StatelessWidget {
  const FrostbornApp({
    super.key,
    required this.orchestrator,
    required this.vault,
    required this.bell,
  });

  final FrostOrchestrator orchestrator;
  final EmberVault vault;
  final WardenBell bell;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameState>(
      create: (_) => GameState(),
      child: MaterialApp(
        title: FrostConfig.displayName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        navigatorKey: hearthNavKey,
        builder: (BuildContext context, Widget? child) =>
            MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
          child: child ?? const SizedBox.shrink(),
        ),
        home: KindlingScreen(
          orchestrator: orchestrator,
          vault: vault,
          bell: bell,
        ),
      ),
    );
  }
}
