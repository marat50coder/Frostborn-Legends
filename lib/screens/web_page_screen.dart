import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_theme.dart';
import '../widgets/frost_ui.dart';

class WebPageScreen extends StatefulWidget {
  const WebPageScreen({super.key, required this.title, required this.url});

  static const String privacyPolicyUrl = 'https://aether-gems.link/privacy-policy';
  static const String supportUrl = 'https://frostbornlegends.com/support.html';

  final String title;
  final String url;

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) async {
            // Force a clean black-on-white look regardless of the host's own
            // styling so the policy is always legible in-app.
            await _controller.runJavaScript(_injectReaderStyle);
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted || !(error.isForMainFrame ?? true)) return;
            setState(() {
              _loading = false;
              _error = error.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // Injected on every page load. Overrides body/text colours and pulls the
  // content in a bit so long paragraphs breathe on a phone screen.
  static const String _injectReaderStyle = '''
    (function() {
      var css = "html,body{background:#ffffff !important;color:#111111 !important;"
        + "font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif !important;"
        + "font-size:16px !important;line-height:1.55 !important;padding:14px 16px !important;margin:0 !important;}"
        + "h1,h2,h3,h4,h5,h6{color:#0a0a0a !important;}"
        + "p,li,span,div,td,th{color:#111111 !important;background:transparent !important;}"
        + "a{color:#0a5ec7 !important;}"
        + "img{max-width:100% !important;height:auto !important;}"
        + "*{text-shadow:none !important;box-shadow:none !important;}";
      var style = document.createElement('style');
      style.appendChild(document.createTextNode(css));
      document.head.appendChild(style);
    })();
  ''';

  void _reload() {
    setState(() {
      _error = null;
      _loading = true;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Dark bar keeps the game chrome above the now-white article page.
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: AppColors.night,
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: <Widget>[
                  FrostIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: StrokeText(
                        widget.title,
                        style: AppText.title(19),
                        strokeWidth: 3.5,
                      ),
                    ),
                  ),
                  FrostIconButton(icon: Icons.refresh_rounded, onPressed: _reload),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  if (_error == null)
                    WebViewWidget(controller: _controller)
                  else
                    _ErrorView(message: _error!, onRetry: _reload),
                  if (_loading && _error == null)
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: FrostPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.ice),
              const SizedBox(height: 14),
              Text(
                'Could not load the page',
                textAlign: TextAlign.center,
                style: AppText.title(18).copyWith(color: AppColors.gold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.body(12).copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              FrostButton(label: 'TRY AGAIN', onPressed: onRetry, height: 46, fontSize: 15),
            ],
          ),
        ),
      ),
    );
  }
}
