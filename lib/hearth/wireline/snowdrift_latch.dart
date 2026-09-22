import 'ember_vault.dart';

// ============================================================
// SNOWDRIFT LATCH — cold-boot push URL reader.
// ============================================================
// Cold-boot push taps deliver the URL through the launch intent.
// The WardenBell.getInitialMessage handler writes it into the
// vault's pending slot; this class is the ONE-SHOT reader the
// orchestrator uses, symmetric with the returning-launch code
// path.
// ============================================================

class SnowdriftLatch {
  SnowdriftLatch._();

  /// Read and clear the pending URL. Returns null when no cold-
  /// boot push tap was recorded.
  static Future<String?> release(EmberVault vault) =>
      vault.consumePending();
}
