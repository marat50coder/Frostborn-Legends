import '../core/game_assets.dart';

enum JackpotTier { mini, minor, major, grand }

extension JackpotTierInfo on JackpotTier {
  String get label => switch (this) {
    JackpotTier.mini => 'MINI',
    JackpotTier.minor => 'MINOR',
    JackpotTier.major => 'MAJOR',
    JackpotTier.grand => 'GRAND',
  };

  String get badge => switch (this) {
    JackpotTier.mini => GameAssets.badgeMini,
    JackpotTier.minor => GameAssets.badgeMinor,
    JackpotTier.major => GameAssets.badgeMajor,
    JackpotTier.grand => GameAssets.badgeGrand,
  };

  /// Jackpots scale with the current stake, which keeps the payout curve sane
  /// at every bet level.
  int get multiplier => switch (this) {
    JackpotTier.mini => 10,
    JackpotTier.minor => 50,
    JackpotTier.major => 100,
    JackpotTier.grand => 500,
  };

  int valueFor(int totalBet) => multiplier * totalBet;
}
