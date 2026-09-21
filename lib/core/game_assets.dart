/// Central registry of every bundled art and audio file.
class GameAssets {
  const GameAssets._();

  // UI ------------------------------------------------------------------
  static const String logo = 'assets/game/ui/logo.webp';
  static const String loadingPortrait = 'assets/game/ui/loading_portrait.webp';
  static const String loadingLandscape = 'assets/game/ui/loading_landscape.webp';
  static const String notifyPortrait = 'assets/game/ui/notify_portrait.webp';
  static const String notifyLandscape = 'assets/game/ui/notify_landscape.webp';

  // Backgrounds ---------------------------------------------------------
  static const String bgCrystal = 'assets/game/bg/bg_crystal.webp';
  static const String bgHall = 'assets/game/bg/bg_hall.webp';
  static const String bgVortex = 'assets/game/bg/bg_vortex.webp';

  // Characters ----------------------------------------------------------
  static const String zeus = 'assets/game/chars/zeus.webp';
  static const String joker = 'assets/game/chars/joker.webp';
  static const String boyWinter = 'assets/game/chars/boy_winter.webp';
  static const String fishermanFront = 'assets/game/chars/fisherman_front.webp';
  static const String fishermanSide = 'assets/game/chars/fisherman_side.webp';
  static const String rod = 'assets/game/chars/rod.webp';

  // Wheels --------------------------------------------------------------
  static const String wheelSnow = 'assets/game/wheels/wheel_snow.webp';
  static const String wheelEmerald = 'assets/game/wheels/wheel_emerald.webp';
  static const String wheelAmethyst = 'assets/game/wheels/wheel_amethyst.webp';
  static const String wheelFire = 'assets/game/wheels/wheel_fire.webp';
  static const String wheelGold = 'assets/game/wheels/wheel_gold.webp';

  // Jackpot badges ------------------------------------------------------
  static const String badgeGrand = 'assets/game/badges/grand.webp';
  static const String badgeMajor = 'assets/game/badges/major.webp';
  static const String badgeMinor = 'assets/game/badges/minor.webp';
  static const String badgeMini = 'assets/game/badges/mini.webp';

  // Items ---------------------------------------------------------------
  static const String fishGold = 'assets/game/items/fish_gold.webp';
  static const String fishBlue = 'assets/game/items/fish_blue.webp';
  static const String fishRed = 'assets/game/items/fish_red.webp';
  static const String crown = 'assets/game/items/crown.webp';
  static const String hourglass = 'assets/game/items/hourglass.webp';
  static const String ring = 'assets/game/items/ring.webp';
  static const String chalice = 'assets/game/items/chalice.webp';
  static const String magicBell = 'assets/game/items/magic_bell.webp';
  static const String gemBlue = 'assets/game/items/gem_blue.webp';
  static const String gemRed = 'assets/game/items/gem_red.webp';
  static const String gemGreen = 'assets/game/items/gem_green.webp';
  static const String gemAmber = 'assets/game/items/gem_amber.webp';
  static const String gemPurple = 'assets/game/items/gem_purple.webp';
  static const String gemCyan = 'assets/game/items/gem_cyan.webp';
  static const String gemGold = 'assets/game/items/gem_gold.webp';
  static const String gemRainbow = 'assets/game/items/gem_rainbow.webp';
  static const String candyHeart = 'assets/game/items/candy_heart.webp';
  static const String candyPurple = 'assets/game/items/candy_purple.webp';
  static const String candyGreen = 'assets/game/items/candy_green.webp';
  static const String candyBlue = 'assets/game/items/candy_blue.webp';

  static String symbol(String id) => 'assets/game/symbols/$id.webp';

  /// Everything worth warming up before the first frame of the menu.
  static const List<String> preload = <String>[
    logo,
    loadingPortrait,
    loadingLandscape,
    bgCrystal,
    bgHall,
    bgVortex,
    zeus,
    joker,
    boyWinter,
    fishermanFront,
    fishermanSide,
    rod,
    wheelSnow,
    wheelEmerald,
    wheelAmethyst,
    wheelFire,
    wheelGold,
    badgeGrand,
    badgeMajor,
    badgeMinor,
    badgeMini,
    fishGold,
    fishBlue,
    fishRed,
    crown,
    hourglass,
    ring,
    chalice,
    magicBell,
    gemBlue,
    gemRed,
    gemGreen,
    gemAmber,
    gemPurple,
    gemCyan,
    gemGold,
    gemRainbow,
    candyHeart,
    candyPurple,
    candyGreen,
    candyBlue,
  ];
}

/// Sound effects. Paths are relative to `assets/` as required by AssetSource.
class GameSounds {
  const GameSounds._();

  static const String menuMusic = 'game/audio/main_menu.mp3';
  static const String click = 'game/audio/button_click.mp3';
  static const String selection = 'game/audio/selection.mp3';
  static const String reward = 'game/audio/reward.mp3';
  static const String victory = 'game/audio/victory.mp3';
  static const String defeat = 'game/audio/defeat.mp3';
  static const String error = 'game/audio/error.mp3';
  static const String majorBonus = 'game/audio/major_bonus.mp3';
}
