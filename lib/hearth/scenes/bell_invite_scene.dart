import 'package:flutter/material.dart';

import '../lore/frost_config.dart';
import '../wireline/ember_vault.dart';
import '../wireline/warden_bell.dart';
import 'gray_actions.dart';
import 'great_gate_scene.dart';

// ============================================================
// BELL INVITE SCENE — push opt-in stage.
// ============================================================
// Shown once (per snooze window) before the WebView portal, only
// when [EmberVault.shouldOfferBell] is true.
//
// Uses the pre-rendered Vertical / Horizontal notifications art
// (the purple bell panel and copy are baked into the WebP) — the
// two buttons float over the artwork.
//
// Layout rule:
//   Portrait  — Accept and Skip stack vertically (Accept on top).
//   Landscape — Accept and Skip sit SIDE BY SIDE on the same y as
//               Skip used to sit alone, so both fit under the
//               baked panel and neither covers the joker's face.
// ============================================================

class BellInviteScene extends StatefulWidget {
  const BellInviteScene({
    super.key,
    required this.vault,
    required this.bell,
    required this.gatewayUrl,
  });

  final EmberVault vault;
  final WardenBell bell;
  final String gatewayUrl;

  @override
  State<BellInviteScene> createState() => _BellInviteSceneState();
}

class _BellInviteSceneState extends State<BellInviteScene> {
  bool _busy = false;
  late String _gatewayUrl;

  @override
  void initState() {
    super.initState();
    _gatewayUrl = widget.gatewayUrl;
    // A campaign tap during the invite must win over the URL the
    // orchestrator already handed us — otherwise Accept opens the
    // cached homepage instead of the promo.
    widget.bell.onWarmUrl = (String url) {
      _gatewayUrl = url;
    };
  }

  @override
  void dispose() {
    if (widget.bell.onWarmUrl != null) {
      widget.bell.onWarmUrl = null;
    }
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bool granted = await widget.bell.askForBell();
    if (!granted) {
      await widget.vault.writeBellHushUntil(_snoozeTarget());
    }
    if (mounted) _proceed();
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.vault.writeBellHushUntil(_snoozeTarget());
    if (mounted) _proceed();
  }

  int _snoozeTarget() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      FrostConfig.permissionSnoozeSeconds;

  void _proceed() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GreatGateScene(
          url: _gatewayUrl,
          vault: widget.vault,
          bell: widget.bell,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? 'assets/frost_boot_stage/alert_landscape.webp'
        : 'assets/frost_boot_stage/alert_portrait.webp';

    return Scaffold(
      backgroundColor: const Color(0xFF060B1C),
      // No SafeArea around the buttons — the target artwork bleeds
      // to the edge and we want the buttons to sit on the visible
      // bottom, not offset by the system inset.
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            bg,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
          ),
          // Bottom scrim so button labels stay legible over any
          // brighter part of the artwork's lower edge.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x00000000), Color(0x88000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: landscape ? size.height * 0.055 : size.height * 0.075,
            child: landscape
                ? _LandscapeButtons(
                    width: size.width,
                    onAccept: _accept,
                    onSkip: _skip,
                  )
                : _PortraitButtons(
                    width: size.width,
                    onAccept: _accept,
                    onSkip: _skip,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Landscape layout — Accept and Skip sit on the same y (single
/// Row) at equal width. The pair together occupies 60 % of the
/// screen width (each button = 30 %), so there is a 20 % gutter
/// on both sides matching the artwork's built-in margin.
class _LandscapeButtons extends StatelessWidget {
  const _LandscapeButtons({
    required this.width,
    required this.onAccept,
    required this.onSkip,
  });

  final double width;
  final VoidCallback onAccept;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    // Buttons are shortened by 20% on each side of the screen —
    // i.e. the button pair occupies the middle 60% of the width.
    final double pairWidth = width * 0.6;
    final double gap = 14;
    final double buttonWidth = (pairWidth - gap) / 2;

    return Center(
      child: SizedBox(
        width: pairWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            GrayPrimaryButton(
              label: 'ACCEPT',
              width: buttonWidth,
              height: 50,
              onTap: onAccept,
            ),
            GrayGhostButton(
              label: 'SKIP',
              width: buttonWidth,
              height: 50,
              onTap: onSkip,
            ),
          ],
        ),
      ),
    );
  }
}

/// Portrait layout — Accept on top, Skip below. Same width, same
/// height so nothing about the pair reads as "the small one is
/// less important".
class _PortraitButtons extends StatelessWidget {
  const _PortraitButtons({
    required this.width,
    required this.onAccept,
    required this.onSkip,
  });

  final double width;
  final VoidCallback onAccept;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final double buttonWidth = width * 0.68;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GrayPrimaryButton(
          label: 'ACCEPT',
          width: buttonWidth,
          height: 58,
          onTap: onAccept,
        ),
        const SizedBox(height: 14),
        GrayGhostButton(
          label: 'SKIP',
          width: buttonWidth,
          height: 58,
          onTap: onSkip,
        ),
      ],
    );
  }
}
