// ============================================================
// PATH VERDICT — sealed outcome of the hearth boot pipeline.
// ============================================================
// The orchestrator produces exactly one of three sealed subtypes.
// The boot screen `switch`es on it and cannot forget a branch —
// adding a new destination forces every dispatch site to update.
// ============================================================

/// Persisted routing memory across launches.
///
/// The wire strings live in SharedPreferences; do NOT rename them
/// or legacy installs will forget their last decision.
enum JourneyMark {
  unset,
  outer,
  inner;

  String get wireValue {
    switch (this) {
      case JourneyMark.unset:
        return 'unset';
      case JourneyMark.outer:
        return 'outer';
      case JourneyMark.inner:
        return 'inner';
    }
  }

  static JourneyMark parse(String? raw) {
    switch (raw) {
      case 'outer':
      case 'web':      // legacy fallback
      case 'portal':   // legacy fallback
        return JourneyMark.outer;
      case 'inner':
      case 'game':     // legacy fallback
      case 'native':   // legacy fallback
        return JourneyMark.inner;
      default:
        return JourneyMark.unset;
    }
  }
}

/// Parsed answer from the verdict endpoint.
///
/// Wire keys are `{ok, url, expires, message}` — mapped verbatim,
/// the backend contract is not negotiable.
class OracleAnswer {
  const OracleAnswer({
    required this.granted,
    this.url,
    this.expiresAt,
    this.note,
  });

  factory OracleAnswer.fromJson(Map<String, dynamic> json) {
    final dynamic rawExpiry = json['expires'];
    return OracleAnswer(
      granted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      note: json['message']?.toString(),
    );
  }

  factory OracleAnswer.dismissed(String note) =>
      OracleAnswer(granted: false, note: note);

  final bool granted;
  final String? url;
  final int? expiresAt;
  final String? note;

  bool get hasGateway => granted && url != null && url!.isNotEmpty;
}

/// Sealed decision the orchestrator emits. Consumers `switch` on it
/// exactly once (in the boot screen) and cannot bypass a branch.
sealed class PathVerdict {
  const PathVerdict();
}

/// Continue into the native slot game.
final class HallRealm extends PathVerdict {
  const HallRealm();
}

/// Continue into the WebView portal at [url].
///
/// [warmTap] is true when the launch was triggered by a cold-boot
/// push tap — the URL came from the intent payload rather than the
/// cache, and the boot animation should be shortened.
final class GatewayRealm extends PathVerdict {
  const GatewayRealm(this.url, {this.warmTap = false});

  final String url;
  final bool warmTap;
}

/// Show the offline screen; retry rebuilds the whole boot.
///
/// [returnsToInner] is true when the user was previously in the
/// game — the retry after connectivity comes back can skip the
/// verdict roundtrip and just resume the game.
final class BlizzardRealm extends PathVerdict {
  const BlizzardRealm({required this.returnsToInner});

  final bool returnsToInner;
}
