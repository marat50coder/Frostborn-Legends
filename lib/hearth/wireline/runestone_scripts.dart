import 'package:webview_flutter/webview_flutter.dart';

import '../lore/shrouded_bytes.dart';

// ============================================================
// RUNESTONE SCRIPTS — WebView JS enhancer runner.
// ============================================================
// The three enhancer bodies live encoded in `shrouded_bytes.dart`
// and are thawed on demand — no plaintext JS ships in the binary.
// Each body carries its own window-sentinel flag, so calling
// [inscribeAll] on every `onPageFinished` is safely idempotent.
//
// The keyboard body docks the focused field via visualViewport
// (the WebView is never resized — see GreatGateScene). A single
// delayed scrollIntoView after the IME settles; never a smooth
// scroll that fights the compositor.
// ============================================================

class RunestoneScripts {
  RunestoneScripts._();

  /// Run the ORDERED sequence of enhancers on [controller].
  static Future<void> inscribeAll(WebViewController controller) async {
    for (final String body in _bodies()) {
      if (body.isEmpty) continue;
      try {
        await controller.runJavaScript(body);
      } catch (_) {
        // Some frames finish loading twice; ignore the harmless
        // "context destroyed" error the WebView throws.
      }
    }
  }

  static List<String> _bodies() => <String>[
        unshroudJsSafeAreaScript(),
        unshroudJsKeyboardScript(),
        unshroudJsAutoplayScript(),
      ];
}
