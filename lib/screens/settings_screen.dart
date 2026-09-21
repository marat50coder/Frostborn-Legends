import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio_service.dart';
import '../core/game_assets.dart';
import '../core/game_state.dart';
import '../widgets/frost_ui.dart';
import 'web_page_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final GameState state = context.read<GameState>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.deepNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.7), width: 2),
        ),
        title: Text('Reset progress?', style: AppText.title(18).copyWith(color: AppColors.gold)),
        content: Text(
          'Your balance will be restored to '
          '${formatCoins(GameState.startingCoins)} fun coins and all statistics cleared.',
          style: AppText.body(13).copyWith(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCEL', style: AppText.body(13).copyWith(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('RESET', style: AppText.body(13).copyWith(color: AppColors.crimsonLight)),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await state.resetProgress();
      AudioService.instance.select();
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameState state = context.watch<GameState>();

    return Scaffold(
      body: GameBackground(
        asset: GameAssets.bgVortex,
        scrim: 0.62,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: <Widget>[
                    FrostIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: StrokeText('SETTINGS', style: AppText.title(22)),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
                  children: <Widget>[
                    FrostPanel(
                      child: Column(
                        children: <Widget>[
                          _ToggleRow(
                            icon: Icons.music_note_rounded,
                            label: 'Music',
                            value: state.musicEnabled,
                            onChanged: state.setMusicEnabled,
                          ),
                          const Divider(color: Colors.white12, height: 22),
                          _ToggleRow(
                            icon: Icons.volume_up_rounded,
                            label: 'Sound effects',
                            value: state.soundEnabled,
                            onChanged: state.setSoundEnabled,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FrostPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          StrokeText(
                            'STATISTICS',
                            style: AppText.title(14).copyWith(letterSpacing: 2),
                            strokeWidth: 3,
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 12),
                          _StatRow(label: 'Balance', value: formatCoins(state.coins)),
                          _StatRow(label: 'Total spins', value: formatCoins(state.totalSpins)),
                          _StatRow(label: 'Biggest win', value: formatCoins(state.biggestWin)),
                          _StatRow(label: 'Current bet', value: formatCoins(state.totalBet)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FrostButton(
                      label: 'PRIVACY POLICY',
                      style: FrostButtonStyle.ice,
                      height: 50,
                      fontSize: 15,
                      width: double.infinity,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WebPageScreen(
                            title: 'Privacy Policy',
                            url: WebPageScreen.privacyPolicyUrl,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FrostButton(
                      label: 'SUPPORT',
                      style: FrostButtonStyle.ice,
                      height: 50,
                      fontSize: 15,
                      width: double.infinity,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WebPageScreen(
                            title: 'Support',
                            url: WebPageScreen.supportUrl,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FrostButton(
                      label: 'RESET PROGRESS',
                      style: FrostButtonStyle.ghost,
                      height: 50,
                      fontSize: 15,
                      width: double.infinity,
                      onPressed: () => _confirmReset(context),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Frostborn Legends v1.0.0\n'
                      'All coins in this game are virtual and have no real world value. '
                      'Playing this game does not offer any opportunity to win real money '
                      'or prizes, and practice or success at social casino gaming does not '
                      'imply future success at real money gambling.',
                      textAlign: TextAlign.center,
                      style: AppText.body(10, weight: FontWeight.w500).copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: AppColors.ice, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AppText.body(15, weight: FontWeight.w700)),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.gold,
          activeTrackColor: AppColors.goldDark,
          inactiveThumbColor: Colors.white54,
          onChanged: (bool next) {
            AudioService.instance.click();
            onChanged(next);
          },
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: AppText.body(13).copyWith(color: Colors.white70)),
          Text(value, style: AppText.numeric(14).copyWith(color: AppColors.gold)),
        ],
      ),
    );
  }
}
