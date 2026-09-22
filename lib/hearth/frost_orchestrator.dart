import 'dart:async';
import 'dart:io';

import 'harbor/path_verdict.dart';
import 'lore/frost_config.dart';
import 'wireline/beacon_lantern.dart';
import 'wireline/ember_vault.dart';
import 'wireline/oracle_query.dart';
import 'wireline/sky_banner.dart';
import 'wireline/snowdrift_latch.dart';
import 'wireline/warden_bell.dart';

// ============================================================
// FROST ORCHESTRATOR — the one and only routing decision point.
// ============================================================
// [decide] returns a [PathVerdict] sealed type. The boot screen
// destructures via `switch` and pushes exactly one route. NO
// routing logic lives anywhere else in the codebase.
//
// Decision pipeline (branches on the persisted JourneyMark):
//
//   unset (first launch)
//     ├─ no adapter        → BlizzardRealm(returnsToInner:false)
//     ├─ probe fails       → BlizzardRealm(returnsToInner:false)
//     ├─ oracle grants URL → outer  → GatewayRealm(url)
//     └─ oracle dismisses  → inner  → HallRealm
//
//   outer (previously in the WebView)
//     ├─ no adapter        → BlizzardRealm(returnsToInner:false)
//     ├─ cold-tap URL      → GatewayRealm(url, warmTap:true)
//     │                      (bell.boot must run first)
//     ├─ fresh cached URL  → GatewayRealm(cached)
//     ├─ oracle grants URL → GatewayRealm(fresh)
//     ├─ oracle dismisses but cache present
//     │                    → GatewayRealm(cached)  (best-known)
//     └─ otherwise         → BlizzardRealm(false)
//
//   inner (previously in the game)
//     ├─ no adapter        → HallRealm  (never blocks the game)
//     ├─ oracle grants URL → outer  → GatewayRealm(url)
//     └─ otherwise         → HallRealm
//
// Concurrent boots are de-duplicated: the coordinator caches the
// in-flight future so two synchronous [decide] calls (e.g. the
// boot screen briefly building twice) do not fire two POSTs. The
// cache clears on completion so a Retry from the offline scene
// re-runs the whole pipeline fresh.
// ============================================================

class FrostOrchestrator {
  FrostOrchestrator({
    required this.vault,
    required this.lantern,
    required this.banner,
    required this.oracle,
    required this.bell,
  });

  final EmberVault vault;
  final BeaconLantern lantern;
  final SkyBanner banner;
  final OracleQuery oracle;
  final WardenBell bell;

  Future<PathVerdict>? _inFlight;

  Future<PathVerdict> decide({
    void Function(double)? onProgress,
  }) {
    return _inFlight ??= _run(onProgress ?? (_) {})
        .whenComplete(() => _inFlight = null);
  }

  Future<PathVerdict> _run(void Function(double) onProgress) async {
    if (!FrostConfig.credentialsReady) {
      onProgress(1);
      return const HallRealm();
    }

    bell.onTokenChanged = _rerunAfterTokenChange;

    // Arm the bell BEFORE consuming the pending URL. boot() awaits
    // getInitialMessage and writes the vault slot; only then is
    // SnowdriftLatch free to read it. Skipping boot on a cache-hit
    // left listeners dead and opened the cached homepage instead
    // of the tapped campaign.
    try {
      await bell.boot();
    } catch (_) {}

    final String? warmUrl = await SnowdriftLatch.release(vault);
    if (warmUrl != null && warmUrl.isNotEmpty) {
      await vault.stampMark(JourneyMark.outer);
      unawaited(_fireAndForgetVerdict());
      onProgress(1);
      return GatewayRealm(warmUrl, warmTap: true);
    }

    onProgress(0.18);
    final PathVerdict verdict = await switch (vault.mark) {
      JourneyMark.unset => _driveFirstLaunch(onProgress),
      JourneyMark.outer => _driveReturningOuter(onProgress),
      JourneyMark.inner => _driveReturningInner(onProgress),
    };

    // A warm tap during Kindling is queued AND parked. Prefer it
    // over the branch result so an inner-mark user is not dropped
    // into the slot game after tapping a campaign.
    final String? lateUrl = await vault.consumePending();
    if (lateUrl != null && lateUrl.isNotEmpty) {
      await vault.stampMark(JourneyMark.outer);
      return GatewayRealm(lateUrl, warmTap: true);
    }
    return verdict;
  }

  Future<PathVerdict> _driveFirstLaunch(
    void Function(double) onProgress,
  ) async {
    if (!await lantern.hasAdapter()) {
      return const BlizzardRealm(returnsToInner: false);
    }
    onProgress(0.32);
    try {
      await bell.boot();
    } catch (_) {}
    if (!await lantern.canReach()) {
      return const BlizzardRealm(returnsToInner: false);
    }
    onProgress(0.52);
    await banner.ignite();
    await banner.awaitSignals(
      installSeconds: FrostConfig.firstInstallAwaitSeconds,
    );
    onProgress(0.78);
    final OracleAnswer answer = await _askOracle();
    onProgress(1);
    if (answer.hasGateway) {
      await vault.stampMark(JourneyMark.outer);
      return GatewayRealm(answer.url!);
    }
    await vault.stampMark(JourneyMark.inner);
    return const HallRealm();
  }

  Future<PathVerdict> _driveReturningOuter(
    void Function(double) onProgress,
  ) async {
    if (!await lantern.hasAdapter()) {
      return const BlizzardRealm(returnsToInner: false);
    }
    final String? cached = await vault.cachedGateway();
    if (cached != null && !vault.gatewayExpired) {
      onProgress(1);
      return GatewayRealm(cached);
    }

    await Future.wait<void>(<Future<void>>[
      bell.boot(),
      banner.ignite(),
    ]);
    if (!await lantern.canReach()) {
      if (cached != null) return GatewayRealm(cached);
      return const BlizzardRealm(returnsToInner: false);
    }
    onProgress(0.58);
    await banner.awaitSignals(
      installSeconds: FrostConfig.returningInstallAwaitSeconds,
    );
    final OracleAnswer answer = await _askOracle();
    onProgress(1);
    if (answer.hasGateway) return GatewayRealm(answer.url!);
    if (cached != null) return GatewayRealm(cached);
    return const BlizzardRealm(returnsToInner: false);
  }

  Future<PathVerdict> _driveReturningInner(
    void Function(double) onProgress,
  ) async {
    if (!await lantern.hasAdapter()) {
      onProgress(1);
      return const HallRealm();
    }
    await Future.wait<void>(<Future<void>>[
      bell.boot(),
      banner.ignite(),
    ]);
    if (!await lantern.canReach()) {
      onProgress(1);
      return const HallRealm();
    }
    onProgress(0.6);
    await banner.awaitSignals(
      installSeconds: FrostConfig.returningInstallAwaitSeconds,
    );
    final OracleAnswer answer = await _askOracle();
    onProgress(1);
    if (!answer.hasGateway) return const HallRealm();
    await vault.stampMark(JourneyMark.outer);
    return GatewayRealm(answer.url!);
  }

  Future<OracleAnswer> _askOracle({String? tokenOverride}) async {
    final Map<String, dynamic> body = await banner.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: tokenOverride ?? bell.token,
    );
    return oracle.ask(body);
  }

  Future<void> _fireAndForgetVerdict() async {
    try {
      await Future.wait<void>(<Future<void>>[
        bell.boot(),
        banner.ignite(),
      ]);
      await banner.awaitSignals(
        installSeconds: FrostConfig.returningInstallAwaitSeconds,
      );
      await _askOracle();
    } catch (_) {}
  }

  Future<void> _rerunAfterTokenChange(String token) async {
    try {
      await _askOracle(tokenOverride: token);
    } catch (_) {}
  }
}
