import 'package:flutter/material.dart';

import 'gray_actions.dart';

// ============================================================
// BLIZZARD SCENE — no-connectivity screen.
// ============================================================
// No background artwork — an inline gradient and a two-line
// message. This keeps the scene mount-instant (there is no
// Image.asset to decode) which is what makes the offline branch
// feel immediate.
//
// Landscape uses a side-by-side rail so the icon + copy + retry
// all stay on one short axis and never overflow a 16:9 frame.
// ============================================================

class BlizzardScene extends StatefulWidget {
  const BlizzardScene({super.key, required this.rebuild});

  final WidgetBuilder rebuild;

  @override
  State<BlizzardScene> createState() => _BlizzardSceneState();
}

class _BlizzardSceneState extends State<BlizzardScene> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.rebuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF0B1B3F),
              Color(0xFF060B1C),
              Color(0xFF000000),
            ],
            stops: <double>[0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: landscape ? 36 : 28,
              vertical: landscape ? 16 : 20,
            ),
            child: landscape
                ? _LandscapeBody(
                    screenWidth: size.width,
                    busy: _busy,
                    onRetry: _retry,
                  )
                : _PortraitBody(
                    screenWidth: size.width,
                    busy: _busy,
                    onRetry: _retry,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PortraitBody extends StatelessWidget {
  const _PortraitBody({
    required this.screenWidth,
    required this.busy,
    required this.onRetry,
  });

  final double screenWidth;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Spacer(),
        const _OfflineCopy(iconSize: 72, titleSize: 22, bodySize: 15),
        const Spacer(),
        _RetrySlot(
          busy: busy,
          width: screenWidth * 0.72,
          onRetry: onRetry,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Landscape: copy on the left, retry on the right — everything
/// fits the short axis without stacking three blocks vertically.
class _LandscapeBody extends StatelessWidget {
  const _LandscapeBody({
    required this.screenWidth,
    required this.busy,
    required this.onRetry,
  });

  final double screenWidth;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const Expanded(
          flex: 11,
          child: _OfflineCopy(iconSize: 48, titleSize: 18, bodySize: 13),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 9,
          child: Align(
            alignment: Alignment.centerRight,
            child: _RetrySlot(
              busy: busy,
              width: screenWidth * 0.32,
              onRetry: onRetry,
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineCopy extends StatelessWidget {
  const _OfflineCopy({
    required this.iconSize,
    required this.titleSize,
    required this.bodySize,
  });

  final double iconSize;
  final double titleSize;
  final double bodySize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.signal_wifi_off_rounded,
          color: const Color(0xFFEAF9FF),
          size: iconSize,
        ),
        SizedBox(height: iconSize > 60 ? 22 : 12),
        Text(
          'NO INTERNET CONNECTION',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFEAF9FF),
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Check your connection and try again',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: bodySize,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _RetrySlot extends StatelessWidget {
  const _RetrySlot({
    required this.busy,
    required this.width,
    required this.onRetry,
  });

  final bool busy;
  final double width;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF67E7FF)),
        ),
      );
    }
    return GrayPrimaryButton(
      label: 'TRY AGAIN',
      width: width,
      onTap: onRetry,
      iconRight: Icons.refresh_rounded,
    );
  }
}
