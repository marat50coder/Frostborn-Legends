import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/audio_service.dart';
import '../../core/game_assets.dart';
import '../../game/jackpots.dart';
import 'bonus_common.dart';

class _Tile {
  _Tile({required this.asset, required this.multiplier, required this.jackpot, required this.isEnd});

  final String asset;
  final int multiplier;
  final JackpotTier? jackpot;
  final bool isEnd;
  bool revealed = false;
}

/// Crack frozen tiles to collect treasures. Three hourglasses end the round.
class FrozenTreasuresBonus extends StatefulWidget {
  const FrozenTreasuresBonus({super.key, required this.totalBet, required this.scatterCount});

  final int totalBet;
  final int scatterCount;

  @override
  State<FrozenTreasuresBonus> createState() => _FrozenTreasuresBonusState();
}

class _FrozenTreasuresBonusState extends State<FrozenTreasuresBonus> {
  static const int _endsRound = 3;

  final Random _random = Random();
  late final List<_Tile> _tiles = _buildTiles();

  int _collected = 0;
  int _strikes = 0;
  bool _busy = false;
  bool _finished = false;

  List<_Tile> _buildTiles() {
    // Four hourglasses sit in the pool; the third one revealed stops the round.
    final List<_Tile> tiles = <_Tile>[
      for (int i = 0; i < 4; i++)
        _Tile(asset: GameAssets.hourglass, multiplier: 0, jackpot: null, isEnd: true),
    ];

    const List<(String, int)> prizes = <(String, int)>[
      (GameAssets.candyHeart, 1),
      (GameAssets.candyBlue, 1),
      (GameAssets.candyGreen, 2),
      (GameAssets.candyPurple, 2),
      (GameAssets.gemCyan, 3),
      (GameAssets.gemRed, 3),
      (GameAssets.ring, 4),
      (GameAssets.chalice, 6),
    ];
    for (final (String asset, int multiplier) in prizes) {
      tiles.add(_Tile(asset: asset, multiplier: multiplier, jackpot: null, isEnd: false));
    }

    // Extra scatters upgrade the top prize into a jackpot pick.
    final int jackpotChance = 10 + (widget.scatterCount - 3) * 20;
    if (_random.nextInt(100) < jackpotChance) {
      tiles[tiles.length - 1] = _Tile(
        asset: GameAssets.crown,
        multiplier: 0,
        jackpot: JackpotTier.mini,
        isEnd: false,
      );
    }

    tiles.shuffle(_random);
    return tiles;
  }

  Future<void> _pick(int index) async {
    if (_busy || _finished) return;
    final _Tile tile = _tiles[index];
    if (tile.revealed) return;

    setState(() {
      _busy = true;
      tile.revealed = true;
    });

    if (tile.isEnd) {
      AudioService.instance.defeat();
      setState(() => _strikes++);
    } else {
      AudioService.instance.reward();
      final int coins = tile.jackpot != null
          ? tile.jackpot!.valueFor(widget.totalBet)
          : tile.multiplier * widget.totalBet;
      setState(() => _collected += coins);
    }

    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    setState(() => _busy = false);

    if (_strikes >= _endsRound) {
      _finished = true;
      for (final _Tile other in _tiles) {
        other.revealed = true;
      }
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      await showBonusResult(
        context,
        coins: _collected,
        title: 'Time is frozen',
        subtitle: 'Three hourglasses ended the hunt.',
        artwork: GameAssets.boyWinter,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BonusScaffold(
      title: 'Frozen Treasures',
      subtitle: 'Hourglasses: $_strikes of $_endsRound',
      background: GameAssets.bgCrystal,
      collected: _collected,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tiles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (BuildContext context, int index) => _IceTile(
                  tile: _tiles[index],
                  totalBet: widget.totalBet,
                  onTap: () => _pick(index),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 20),
            child: Text(
              'Tap the frozen tiles to collect treasures.\n'
              'Three hourglasses end the round.',
              textAlign: TextAlign.center,
              style: AppText.body(12).copyWith(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _IceTile extends StatelessWidget {
  const _IceTile({required this.tile, required this.totalBet, required this.onTap});

  final _Tile tile;
  final int totalBet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tile.revealed ? null : onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (Widget child, Animation<double> animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: tile.revealed
            ? _RevealedFace(key: const ValueKey<String>('open'), tile: tile, totalBet: totalBet)
            : const _FrozenFace(key: ValueKey<String>('closed')),
      ),
    );
  }
}

class _FrozenFace extends StatelessWidget {
  const _FrozenFace({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF8FD8F5), Color(0xFF2C6FA8), Color(0xFF123354)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x88000000), blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.ac_unit_rounded,
          color: Colors.white.withValues(alpha: 0.85),
          size: 34,
          shadows: const <Shadow>[Shadow(color: Colors.black38, blurRadius: 6)],
        ),
      ),
    );
  }
}

class _RevealedFace extends StatelessWidget {
  const _RevealedFace({super.key, required this.tile, required this.totalBet});

  final _Tile tile;
  final int totalBet;

  @override
  Widget build(BuildContext context) {
    final bool bad = tile.isEnd;
    final int coins = tile.jackpot != null
        ? tile.jackpot!.valueFor(totalBet)
        : tile.multiplier * totalBet;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bad
              ? <Color>[const Color(0xFF4A1620), const Color(0xFF16060A)]
              : <Color>[const Color(0xFF1C2E5E), const Color(0xFF080F26)],
        ),
        border: Border.all(
          color: bad ? AppColors.crimsonLight : AppColors.gold.withValues(alpha: 0.9),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(child: Image.asset(tile.asset, fit: BoxFit.contain)),
          const SizedBox(height: 4),
          if (bad)
            Text(
              'TIME',
              style: AppText.body(11, weight: FontWeight.w800).copyWith(
                color: AppColors.crimsonLight,
              ),
            )
          else
            PrizeTag(
              coins: coins,
              label: tile.jackpot?.label,
              color: tile.jackpot != null ? AppColors.ice : AppColors.gold,
            ),
        ],
      ),
    );
  }
}
