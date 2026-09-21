import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio_service.dart';
import '../core/game_assets.dart';
import '../core/game_state.dart';
import '../game/slot_symbols.dart';
import '../widgets/frost_ui.dart';
import 'paytable_screen.dart';
import 'settings_screen.dart';
import 'slot_screen.dart';
import 'web_page_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Future<void> _claim(BuildContext context) async {
    final GameState state = context.read<GameState>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (state.claimFreeCoins()) {
      AudioService.instance.reward();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.deepNavy,
          content: Text(
            '+${formatCoins(GameState.freeCoinsAmount)} fun coins added!',
            style: AppText.body(14).copyWith(color: AppColors.gold),
          ),
        ),
      );
    } else {
      AudioService.instance.error();
      final Duration left = state.freeCoinsRemaining;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.deepNavy,
          content: Text(
            'Next free coins in ${left.inHours}h ${left.inMinutes % 60}m',
            style: AppText.body(14).copyWith(color: AppColors.ice),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameState state = context.watch<GameState>();

    return Scaffold(
      body: _MenuBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 26),
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          CoinChip(coins: state.coins),
                          FrostIconButton(
                            icon: Icons.settings_rounded,
                            tooltip: 'Settings',
                            onPressed: () => _open(context, const SettingsScreen()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Image.asset(
                        GameAssets.logo,
                        height: constraints.maxHeight * 0.2,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 2),
                      StrokeText(
                        'FUN COIN SLOTS',
                        style: AppText.title(13).copyWith(letterSpacing: 4),
                        gradient: AppColors.iceGradient,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 18),
                      FrostButton(
                        label: 'PLAY',
                        icon: Icons.play_arrow_rounded,
                        width: double.infinity,
                        height: 64,
                        fontSize: 18,
                        onPressed: () => _open(context, const SlotScreen()),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: FrostButton(
                              label: 'PAYTABLE',
                              style: FrostButtonStyle.ice,
                              height: 50,
                              fontSize: 18,
                              onPressed: () => _open(context, const PaytableScreen()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FrostButton(
                              label: 'FREE COINS',
                              style: state.canClaimFreeCoins
                                  ? FrostButtonStyle.crimson
                                  : FrostButtonStyle.ghost,
                              height: 50,
                              fontSize: 18,
                              onPressed: () => _claim(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _BonusShowcase(),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: FrostButton(
                              label: 'PRIVACY POLICY',
                              style: FrostButtonStyle.ghost,
                              height: 50,
                              fontSize: 18,
                              onPressed: () => _open(
                                context,
                                const WebPageScreen(
                                  title: 'Privacy Policy',
                                  url: WebPageScreen.privacyPolicyUrl,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FrostButton(
                              label: 'SUPPORT',
                              style: FrostButtonStyle.ghost,
                              height: 50,
                              fontSize: 18,
                              onPressed: () => _open(
                                context,
                                const WebPageScreen(
                                  title: 'Support',
                                  url: WebPageScreen.supportUrl,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This game is intended for an adult audience and does not\n'
                        'offer real money gambling or any opportunity to win real money.',
                        textAlign: TextAlign.center,
                        style: AppText.body(10, weight: FontWeight.w500).copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Crystal hall backdrop flanked by the two headline characters. The loading
/// artwork is deliberately not reused here because it already carries the game
/// logo baked in.
class _MenuBackground extends StatelessWidget {
  const _MenuBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.sizeOf(context).height;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(GameAssets.bgCrystal, fit: BoxFit.cover),
        Positioned(
          left: -height * 0.06,
          bottom: -height * 0.02,
          height: height * 0.46,
          child: Opacity(opacity: 0.42, child: Image.asset(GameAssets.zeus, fit: BoxFit.fitHeight)),
        ),
        Positioned(
          right: -height * 0.05,
          bottom: -height * 0.02,
          height: height * 0.44,
          child: Opacity(opacity: 0.42, child: Image.asset(GameAssets.joker, fit: BoxFit.fitHeight)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xB3030817), Color(0x66030817), Color(0xD9030817)],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Advertises the five wheel bonus rounds.
class _BonusShowcase extends StatelessWidget {
  const _BonusShowcase();

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StrokeText(
            '5 WHEEL BONUSES',
            style: AppText.title(14).copyWith(letterSpacing: 2),
            strokeWidth: 3,
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 4),
          Text(
            'Land 3 matching wheels to spin that bonus. Rarer wheel, bigger jackpot.',
            style: AppText.body(11).copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          const _BonusRow(bonuses: BonusGame.values),
        ],
      ),
    );
  }
}

class _BonusRow extends StatelessWidget {
  const _BonusRow({required this.bonuses});

  final List<BonusGame> bonuses;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final BonusGame bonus in bonuses)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0xFF26194D), Color(0xFF0C0A1E)],
                        ),
                        border: Border.all(
                          color: bonus.accent.withValues(alpha: 0.75),
                          width: 1.4,
                        ),
                      ),
                      child: Image.asset(
                        GameAssets.symbol(bonus.symbolId),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    child: Text(
                      bonus.shortTitle,
                      maxLines: 1,
                      style: AppText.body(8, weight: FontWeight.w800).copyWith(
                        color: AppColors.ice,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
