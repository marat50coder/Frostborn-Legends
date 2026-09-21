import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/game_assets.dart';
import '../core/game_state.dart';
import '../game/jackpots.dart';
import '../game/slot_engine.dart';
import '../game/slot_symbols.dart';
import '../widgets/frost_ui.dart';

class PaytableScreen extends StatelessWidget {
  const PaytableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final GameState state = context.watch<GameState>();
    final int lineBet = state.lineBet;

    return Scaffold(
      body: GameBackground(
        asset: GameAssets.bgHall,
        scrim: 0.68,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: <Widget>[
                    FrostIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(child: StrokeText('PAYTABLE', style: AppText.title(22))),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Text(
                  'Payouts shown for a line bet of ${formatCoins(lineBet)} '
                  '(total bet ${formatCoins(state.totalBet)} across ${kPaylines.length} lines).',
                  textAlign: TextAlign.center,
                  style: AppText.body(11).copyWith(color: AppColors.ice),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
                  children: <Widget>[
                    FrostPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        children: <Widget>[
                          const _TableHeader(),
                          for (final SlotSymbol symbol in SlotSymbols.all)
                            if (symbol.pays.isNotEmpty)
                              _PayRow(symbol: symbol, lineBet: lineBet),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'BAR WILD',
                      asset: GameAssets.symbol('bar'),
                      body: 'The only substituting symbol. It replaces any regular '
                          'symbol to complete a payline — two watermelons and a Bar '
                          'pay as three watermelons. It never replaces a wheel. '
                          'Three or more Bars in a row pay the Bar awards shown above.',
                    ),
                    const SizedBox(height: 12),
                    for (final BonusGame bonus in BonusGame.values) ...<Widget>[
                      _SectionCard(
                        title: bonus.title.toUpperCase(),
                        asset: GameAssets.symbol(bonus.symbolId),
                        body: '${bonus.tagline}.\nTrigger with 3 or more '
                            '${bonus.title} symbols anywhere on the reels. '
                            '4 or 5 symbols start the round with a stronger boost.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    FrostPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          StrokeText(
                            'JACKPOTS',
                            style: AppText.title(15).copyWith(letterSpacing: 2),
                            strokeWidth: 3,
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Jackpots are won inside the bonus rounds and scale with '
                            'your current bet.',
                            style: AppText.body(11).copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          for (final JackpotTier tier in JackpotTier.values.reversed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: <Widget>[
                                  Image.asset(tier.badge, height: 40),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${tier.label}  •  ${tier.multiplier}x total bet',
                                      style: AppText.body(13, weight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    formatCoins(tier.valueFor(state.totalBet)),
                                    style: AppText.numeric(15).copyWith(color: AppColors.gold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FrostPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          StrokeText(
                            'RULES',
                            style: AppText.title(15).copyWith(letterSpacing: 2),
                            strokeWidth: 3,
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 10),
                          ...<String>[
                            '5 reels, 3 rows and ${kPaylines.length} fixed paylines.',
                            'Wins pay from the leftmost reel on adjacent reels only.',
                            'The Bar is the only wild: it substitutes for any regular symbol.',
                            'Only the highest win is paid per payline.',
                            'All wins are multiplied by the line bet.',
                            'Malfunction voids all plays and pays.',
                          ].map(
                            (String rule) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text('•  ', style: TextStyle(color: AppColors.gold)),
                                  Expanded(
                                    child: Text(
                                      rule,
                                      style: AppText.body(12).copyWith(color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final TextStyle style = AppText.body(10, weight: FontWeight.w800).copyWith(
      color: AppColors.ice,
      letterSpacing: 1.2,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 56),
      child: Row(
        children: <Widget>[
          Expanded(child: Text('SYMBOL', style: style)),
          SizedBox(width: 56, child: Text('3x', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 62, child: Text('4x', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 70, child: Text('5x', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({required this.symbol, required this.lineBet});

  final SlotSymbol symbol;
  final int lineBet;

  @override
  Widget build(BuildContext context) {
    final TextStyle value = AppText.numeric(12).copyWith(color: AppColors.gold);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(width: 44, height: 40, child: Image.asset(symbol.asset, fit: BoxFit.contain)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              symbol.name,
              style: AppText.body(12, weight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              formatCoins((symbol.pays[3] ?? 0) * lineBet),
              style: value,
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              formatCoins((symbol.pays[4] ?? 0) * lineBet),
              style: value,
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              formatCoins((symbol.pays[5] ?? 0) * lineBet),
              style: value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.asset, required this.body});

  final String title;
  final String asset;
  final String body;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 58, height: 58, child: Image.asset(asset, fit: BoxFit.contain)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                StrokeText(
                  title,
                  style: AppText.title(14).copyWith(letterSpacing: 1.4),
                  strokeWidth: 3,
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: AppText.body(11.5).copyWith(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
