import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../lore/frost_config.dart';
import '../wireline/beacon_lantern.dart';
import '../wireline/ember_vault.dart';
import '../wireline/frost_mask.dart';
import '../wireline/runestone_scripts.dart';
import '../wireline/warden_bell.dart';
import 'blizzard_scene.dart';

// ============================================================
// GREAT GATE SCENE — WebView shell (gray content).
// ============================================================
// Responsibilities:
//   • Load `widget.url` with the forged FrostMask User-Agent.
//   • Preserve both orientations; use full-immersive system UI.
//   • Hand off external schemes (tel:, mailto:, intent://).
//   • Bounded retries on redirect loops (-1007 / -9).
//   • Debounced connectivity guard — VPN reconnects and brief
//     cell hops absorb; sustained drops route to BlizzardScene.
//   • Cover the WebView's built-in error page IMMEDIATELY when
//     a main-frame error fires so the Android robot never leaks.
//   • Warm push URL delivery via WardenBell.onWarmUrl.
//   • Native file chooser over a MethodChannel — NO file_picker
//     dependency to avoid the 10.x KGP collision.
//
// The client NEVER classifies the partner site: no funnel
// vocabulary regex, no funnel event emission. Any classification
// the business needs lives entirely server-side.
// ============================================================

class GreatGateScene extends StatefulWidget {
  const GreatGateScene({
    super.key,
    required this.url,
    required this.vault,
    required this.bell,
  });

  final String url;
  final EmberVault vault;
  final WardenBell bell;

  @override
  State<GreatGateScene> createState() => _GreatGateSceneState();
}

class _GreatGateSceneState extends State<GreatGateScene>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinner = true;
  bool _routedOffline = false;
  String? _lastMainFrame;
  int _retryCounter = 0;
  Timer? _dropDebounce;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  final BeaconLantern _pulse = BeaconLantern();

  /// Native file-chooser bridge. Must match the string in
  /// MainActivity.kt.
  static const MethodChannel _uploadBridge =
      MethodChannel('hearth/filepick');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _dressChrome();
    _wireController();

    widget.bell.onWarmUrl = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    _connSub = _pulse.statusStream
        .listen((List<ConnectivityResult> results) {
      final bool allDown = results.isNotEmpty &&
          results.every((ConnectivityResult r) =>
              r == ConnectivityResult.none);
      if (!allDown) {
        _dropDebounce?.cancel();
        return;
      }
      _dropDebounce?.cancel();
      _dropDebounce = Timer(
        Duration(milliseconds: FrostConfig.reachDropDebounceMs),
        _showOffline,
      );
    });
  }

  void _dressChrome() {
    // Full immersive — no status bar, no nav bar. Any inset the
    // WebView still receives from a cutout will be painted PURE
    // BLACK by the outer Scaffold, matching the request that
    // "webview safe zones must be black".
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: const <SystemUiOverlay>[],
    );
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarDividerColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _dressChrome();
    // Reset to page 1 on every re-entry. Any deep partner-site
    // navigation (multi-step form, in-app router state) is
    // discarded, matching what a cold launch would show.
    _lastMainFrame = null;
    _retryCounter = 0;
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _wireController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(FrostMask.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinner = false);
          _retryCounter = 0;
          RunestoneScripts.inscribeAll(_web);
        },
        onWebResourceError: _onError,
        onNavigationRequest: _onNavigate,
      ));

    _configureAndroid();
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _onError(WebResourceError err) {
    if (err.isForMainFrame != true) return;

    final String desc = err.description.toLowerCase();
    final bool isLoop = desc.contains('too_many_redirects') ||
        desc.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;

    if (isLoop &&
        _lastMainFrame != null &&
        _retryCounter < FrostConfig.redirectLoopRetries) {
      _retryCounter++;
      _web.loadRequest(Uri.parse(_lastMainFrame!));
      return;
    }

    // Cover the WebView's native error page IMMEDIATELY so the
    // Android robot / cracked-egg icon never leaks visually.
    if (mounted) setState(() => _spinner = true);

    final bool isConnectivity = desc.contains('name_not_resolved') ||
        desc.contains('address_unreachable') ||
        desc.contains('internet_disconnected') ||
        desc.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21 ||
        err.errorCode == -2 ||
        err.errorCode == -6;

    if (isConnectivity) {
      _showOffline(); // skip redundant DNS re-probe
    } else {
      _guardWithProbe();
    }
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final Uri? uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    const Set<String> inShell = <String>{
      'http',
      'https',
      'about',
      'data',
      'blob',
    };
    if (inShell.contains(uri.scheme)) {
      if (req.isMainFrame) _lastMainFrame = req.url;
      return NavigationDecision.navigate;
    }
    _handOff(uri);
    return NavigationDecision.prevent;
  }

  void _configureAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController android =
        _web.platform as AndroidWebViewController;

    android.setMediaPlaybackRequiresUserGesture(false);
    android.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest r) => r.grant(),
    );
    android.setOnShowFileSelector(_pickFiles);

    final AndroidWebViewCookieManager cookies =
        AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(android, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked =
          await _uploadBridge.invokeMethod<List<Object?>>(
        'pick',
        <String, Object>{
          'multiple': params.mode == FileSelectorMode.openMultiple,
          'mimeTypes': params.acceptTypes
              .where((String t) => t.trim().isNotEmpty)
              .toList(),
        },
      );
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _handOff(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _guardWithProbe() async {
    if (_routedOffline) return;
    final bool online = await _pulse.canReach();
    if (online) return;
    _showOffline();
  }

  void _showOffline() {
    if (_routedOffline || !mounted) return;
    _routedOffline = true;
    final String current = _lastMainFrame ?? widget.url;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BlizzardScene(
          rebuild: (_) => GreatGateScene(
            url: current,
            vault: widget.vault,
            bell: widget.bell,
          ),
        ),
      ),
    );
  }

  Future<void> _stepBack() async {
    if (await _web.canGoBack()) await _web.goBack();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dropDebounce?.cancel();
    _connSub?.cancel();
    widget.bell.onWarmUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _stepBack();
      },
      child: Scaffold(
        // Pure black so the safe-area gutters around a camera
        // cutout / punch-hole read as a matte frame, never as a
        // muddy navy strip against the partner site's background.
        backgroundColor: Colors.black,
        // Keep the WebView full-height when the IME opens. The page
        // lifts the focused field itself (RunestoneScripts watches
        // visualViewport + scrollIntoView). Resizing the native
        // surface on every keyboard frame is what made landscape
        // inputs lag and sit under the IME.
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Pad ONLY for physical cutouts. Never add the keyboard
            // inset — viewInsets would shrink the WebView and hide
            // the focused field under the IME in landscape.
            Padding(
              padding: MediaQuery.viewPaddingOf(context),
              child: WebViewWidget(controller: _web),
            ),
            if (_spinner && !landscape)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF67E7FF),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
