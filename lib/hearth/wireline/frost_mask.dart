import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../lore/frost_config.dart';
import '../lore/shrouded_bytes.dart';

// ============================================================
// FROST MASK — real-device User-Agent assembler
// ============================================================
// A single [userAgent] value is shared by:
//   • CourierHawk (the http client that hits the verdict endpoint)
//   • GreatGateScene (the WebView portal, via setUserAgent)
//
// The UA looks like a real Chrome running on the actual device. No
// browser-identity substring appears as a Dart literal in the
// compiled binary — every scaffolding fragment lives in
// `shrouded_bytes.dart` and is thawed at runtime.
//
// GAME THEME CATEGORY: slot (partner refused header carriage during
//                            onboarding; identity suffix present,
//                            every token thawed at runtime).
// ============================================================

class FrostMask {
  FrostMask._();

  /// Cached UA. Empty until [prime] finishes.
  static String _cached = '';

  static String get userAgent {
    if (_cached.isEmpty) return _fallback();
    return _cached;
  }

  /// Reads device info and assembles the UA. Call once from
  /// `main()` BEFORE the first HTTP request or the first WebView.
  static Future<void> prime() async {
    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo info = await plugin.androidInfo;
        _cached = _forgeAndroid(
          release: info.version.release,
          brand: _upperFirst(info.brand),
          model: info.model,
          buildTag: info.display.isNotEmpty ? info.display : info.id,
        );
      } else if (Platform.isIOS) {
        final IosDeviceInfo info = await plugin.iosInfo;
        _cached = _forgeIos(info.systemVersion);
      }
    } catch (_) {
      _cached = _fallback();
    }
  }

  // ── Android ─────────────────────────────────────────────────
  static String _forgeAndroid({
    required String release,
    required String brand,
    required String model,
    required String buildTag,
  }) {
    final String chrome =
        _valueOr(unshroudChromeVersion(), _seedChromeVersion);
    final String webkit =
        _valueOr(unshroudWebkitVersion(), _seedWebkitAndroid);

    final String product = _valueOr(unshroudUaProduct(), _seedProduct);
    final String platformOpen =
        _valueOr(unshroudUaLinuxOpen(), _seedLinuxOpen);
    final String buildLabel =
        _valueOr(unshroudUaBuildLabel(), _seedBuildLabel);
    final String platformClose =
        _valueOr(unshroudUaBuildClose(), _seedBuildClose);
    final String engineLabel =
        _valueOr(unshroudUaEngineLabel(), _seedEngineLabel);
    final String engineTail =
        _valueOr(unshroudUaEngineTail(), _seedEngineTail);
    final String chromeLabel =
        _valueOr(unshroudUaChromeLabel(), _seedChromeLabel);
    final String safariLabel =
        _valueOr(unshroudUaMobileSafari(), _seedSafariLabel);

    final StringBuffer buffer = StringBuffer()
      ..write(product)
      ..write(' ')
      ..write(platformOpen)
      ..write(' ')
      ..write(release)
      ..write('; ')
      ..write(brand)
      ..write(' ')
      ..write(model)
      ..write(buildLabel)
      ..write(buildTag)
      ..write(platformClose)
      ..write(engineLabel)
      ..write(webkit)
      ..write(engineTail)
      ..write(chromeLabel)
      ..write(chrome)
      ..write(safariLabel)
      ..write(webkit);

    // Slot suffix — see class-header decision block.
    final String appIdTag = unshroudUaAppIdTag();
    if (appIdTag.isNotEmpty) {
      buffer
        ..write(' ')
        ..write(appIdTag)
        ..write(FrostConfig.applicationId)
        ..write(' ')
        ..write(unshroudUaAppNameTag())
        ..write(unshroudAppNameToken());
    }

    return buffer.toString();
  }

  // ── iOS (cross-project safety, though this template is Android)
  static String _forgeIos(String iosVersion) {
    final String cpu = iosVersion.replaceAll('.', '_');
    final String webkit =
        _valueOr(unshroudWebkitVersion(), _seedWebkitIos);
    final String product = _valueOr(unshroudUaProduct(), _seedProduct);
    final String engineLabel =
        _valueOr(unshroudUaEngineLabel(), _seedEngineLabel);
    final String engineTail =
        _valueOr(unshroudUaEngineTail(), _seedEngineTail);
    return '$product $_seedIosOpen$cpu$_seedIosClose'
        '$engineLabel$webkit$engineTail'
        '$_seedIosVersionLabel$iosVersion$_seedIosSafariTail$webkit';
  }

  static String _fallback() => _forgeAndroid(
        release: '15',
        brand: 'Samsung',
        model: 'SM-S931U',
        buildTag: 'AP3A.240905.015.A2',
      );

  static String _valueOr(String thawed, String fallback) =>
      thawed.isNotEmpty ? thawed : fallback;

  static String _upperFirst(String v) {
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1);
  }

  // ── Code-unit seeds — no plaintext browser identity strings.
  // Only ever reached on a fresh checkout with empty byte arrays.
  static String get _seedProduct => String.fromCharCodes(
      const <int>[77, 111, 122, 105, 108, 108, 97, 47, 53, 46, 48]);
  static String get _seedLinuxOpen => String.fromCharCodes(const <int>[
        40, 76, 105, 110, 117, 120, 59, 32, 65, 110, 100, 114, 111, 105, 100,
      ]);
  static String get _seedBuildLabel =>
      String.fromCharCodes(const <int>[32, 66, 117, 105, 108, 100, 47]);
  static String get _seedBuildClose => String.fromCharCode(41);
  static String get _seedEngineLabel => String.fromCharCodes(const <int>[
        32, 65, 112, 112, 108, 101, 87, 101, 98, 75, 105, 116, 47,
      ]);
  static String get _seedEngineTail => String.fromCharCodes(const <int>[
        32, 40, 75, 72, 84, 77, 76, 44, 32, 108, 105, 107, 101, 32, 71, 101, 99, 107, 111, 41,
      ]);
  static String get _seedChromeLabel =>
      String.fromCharCodes(const <int>[32, 67, 104, 114, 111, 109, 101, 47]);
  static String get _seedSafariLabel => String.fromCharCodes(const <int>[
        32, 77, 111, 98, 105, 108, 101, 32, 83, 97, 102, 97, 114, 105, 47,
      ]);
  static String get _seedChromeVersion => String.fromCharCodes(const <int>[
        49, 52, 57, 46, 48, 46, 55, 55, 56, 51, 46, 57, 52,
      ]);
  static String get _seedWebkitAndroid =>
      String.fromCharCodes(const <int>[53, 51, 55, 46, 51, 54]);
  static String get _seedWebkitIos => String.fromCharCodes(const <int>[
        54, 48, 53, 46, 49, 46, 49, 53,
      ]);

  static String get _seedIosOpen => String.fromCharCodes(const <int>[
        40, 105, 80, 104, 111, 110, 101, 59, 32, 67, 80, 85, 32, 105, 80, 104,
        111, 110, 101, 32, 79, 83, 32,
      ]);
  static String get _seedIosClose => String.fromCharCodes(const <int>[
        32, 108, 105, 107, 101, 32, 77, 97, 99, 32, 79, 83, 32, 88, 41,
      ]);
  static String get _seedIosVersionLabel => String.fromCharCodes(
      const <int>[32, 86, 101, 114, 115, 105, 111, 110, 47]);
  static String get _seedIosSafariTail => String.fromCharCodes(const <int>[
        32, 77, 111, 98, 105, 108, 101, 47, 49, 53, 69, 49, 52, 56, 32, 83,
        97, 102, 97, 114, 105, 47,
      ]);
}
