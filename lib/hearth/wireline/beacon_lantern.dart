import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../lore/frost_config.dart';

// ============================================================
// BEACON LANTERN — adapter + DNS reachability probe.
// ============================================================
// `connectivity_plus` alone is unreliable — a captive portal, a
// half-brought-up VPN interface, or a mobile-data cell without
// a route all report as "connected". We layer a real DNS lookup
// on top so the pipeline never commits to online routing without
// a working DNS path.
//
// The probe host list is intentionally short (2 hosts) and
// rotates a private index across calls so a temporarily-
// unresolvable host does not immediately fail the check.
// Neither host is a partner or backend of Frostborn Legends —
// probing our own hosts would create traffic before the verdict
// and a correlation edge in traffic sniffs.
// ============================================================

const List<String> _probeHosts = <String>[
  'wikipedia.org',
  'cloudflare.com',
];

const Set<ConnectivityResult> _liveAdapters = <ConnectivityResult>{
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn, // ← VPN counts as real connectivity.
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

class BeaconLantern {
  BeaconLantern({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Rotor index — advances only when a probe SUCCEEDS so a bad
  /// host does not force a retry with the same bad host.
  int _rotor = 0;

  /// True if at least one adapter reports "connected". Does NOT
  /// run a DNS probe — use [canReach] for that.
  Future<bool> hasAdapter() async {
    try {
      final List<ConnectivityResult> states =
          await _connectivity.checkConnectivity();
      return states.any(_liveAdapters.contains);
    } catch (_) {
      return false;
    }
  }

  /// True if we can resolve at least one probe host within the
  /// configured timeout.
  Future<bool> canReach() async {
    if (!await hasAdapter()) return false;
    final Duration timeout =
        Duration(seconds: FrostConfig.reachProbeTimeoutSeconds);
    for (int step = 0; step < _probeHosts.length; step++) {
      final String host =
          _probeHosts[(_rotor + step) % _probeHosts.length];
      try {
        final List<InternetAddress> answer =
            await InternetAddress.lookup(host).timeout(timeout);
        if (answer.any((InternetAddress a) => a.rawAddress.isNotEmpty)) {
          _rotor = (_rotor + 1) % _probeHosts.length;
          return true;
        }
      } catch (_) {
        // Try the next host before declaring offline.
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get statusStream =>
      _connectivity.onConnectivityChanged;
}
