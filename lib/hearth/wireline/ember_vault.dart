import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harbor/path_verdict.dart';
import '../lore/frost_config.dart';

// ============================================================
// EMBER VAULT — persisted state (prefs + secure storage).
// ============================================================
// Booleans and timestamps go into SharedPreferences (they survive
// clear cache but not clear-data). URLs go into the platform's
// encrypted secure storage. Every key uses a short random prefix
// so a `pm-user-cache` dump of the shared-prefs file never reveals
// intent.
// ============================================================

/// Storage key prefix — short ASCII, unique to this project.
const String _keyPrefix = 'kx7_';

class EmberVault {
  EmberVault({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const String _kMark = '${_keyPrefix}mark';
  static const String _kGateway = '${_keyPrefix}gate';
  static const String _kGatewayTtl = '${_keyPrefix}gate_ttl';
  static const String _kBellHush = '${_keyPrefix}bell_hush';
  static const String _kBellOk = '${_keyPrefix}bell_ok';
  static const String _kBellDenied = '${_keyPrefix}bell_denied';
  static const String _kPending = '${_keyPrefix}pending';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<void> prime() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Journey mark ──────────────────────────────────────────
  JourneyMark get mark => JourneyMark.parse(_prefs.getString(_kMark));

  Future<void> stampMark(JourneyMark value) =>
      _prefs.setString(_kMark, value.wireValue);

  // ── Cached destination URL (secure) ───────────────────────
  Future<String?> cachedGateway() => _secure.read(key: _kGateway);

  Future<void> cacheGateway(String url, int? expiresUnix) async {
    await _secure.write(key: _kGateway, value: url);
    if (expiresUnix != null) {
      await _prefs.setInt(_kGatewayTtl, expiresUnix);
    } else {
      // Fall back to the config-driven lifetime when the backend
      // sends no explicit `expires`.
      await _prefs.setInt(
        _kGatewayTtl,
        _nowSeconds() + FrostConfig.cachedUrlLifetimeSeconds,
      );
    }
  }

  bool get gatewayExpired {
    final int? until = _prefs.getInt(_kGatewayTtl);
    if (until == null) return true;
    return _nowSeconds() >= until;
  }

  // ── Permission / bell state ───────────────────────────────
  bool get bellGranted => _prefs.getBool(_kBellOk) ?? false;

  Future<void> markBellGranted(bool value) =>
      _prefs.setBool(_kBellOk, value);

  bool get bellHardDenied => _prefs.getBool(_kBellDenied) ?? false;

  Future<void> markBellHardDenied() => _prefs.setBool(_kBellDenied, true);

  Future<void> writeBellHushUntil(int unixSeconds) =>
      _prefs.setInt(_kBellHush, unixSeconds);

  /// Should the permission stage appear before the WebView?
  ///
  /// Never asks again once granted, never asks again after a hard
  /// OS denial (Android 13+ permanently suppresses re-prompts),
  /// otherwise gated on the snooze window.
  bool get shouldOfferBell {
    if (bellGranted) return false;
    if (bellHardDenied) return false;
    final int? until = _prefs.getInt(_kBellHush);
    if (until == null) return true;
    return _nowSeconds() >= until;
  }

  // ── One-shot push URL (secure) ────────────────────────────
  Future<void> stashPending(String? url) async {
    if (url == null || url.isEmpty) {
      await _secure.delete(key: _kPending);
    } else {
      await _secure.write(key: _kPending, value: url);
    }
  }

  Future<String?> consumePending() async {
    final String? url = await _secure.read(key: _kPending);
    if (url != null) await _secure.delete(key: _kPending);
    return url;
  }

  static int _nowSeconds() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
