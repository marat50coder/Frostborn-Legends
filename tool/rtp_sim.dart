// Stand-alone RTP simulator. Reimplements the slot engine + planned bonus
// wheel EV without any Flutter deps so it can run via `dart run tool/rtp_sim.dart`.

import 'dart:math';

// ---------------------------------------------------------------------------
// Symbol table (must stay in sync with lib/game/slot_symbols.dart).
// ---------------------------------------------------------------------------

class Sym {
  const Sym(this.id, this.kind, this.weight, [this.pays = const <int, int>{}, this.bonus]);
  final String id;
  final String kind; // 'regular', 'wild', 'bonus'
  final int weight;
  final Map<int, int> pays;
  final String? bonus; // wheel id if bonus
}

const List<Sym> symbols = <Sym>[
  Sym('cherry', 'regular', 40, <int, int>{2: 3, 3: 24, 4: 76, 5: 240}),
  Sym('banana', 'regular', 36, <int, int>{2: 3, 3: 24, 4: 76, 5: 240}),
  Sym('grapes', 'regular', 32, <int, int>{3: 32, 4: 96, 5: 310}),
  Sym('orange', 'regular', 29, <int, int>{3: 32, 4: 96, 5: 310}),
  Sym('apple', 'regular', 24, <int, int>{3: 44, 4: 128, 5: 430}),
  Sym('watermelon', 'regular', 21, <int, int>{3: 48, 4: 150, 5: 520}),
  Sym('strawberry', 'regular', 18, <int, int>{3: 48, 4: 150, 5: 520}),
  Sym('pineapple', 'regular', 15, <int, int>{3: 70, 4: 210, 5: 700}),
  Sym('bells', 'regular', 11, <int, int>{3: 100, 4: 290, 5: 950}),
  Sym('lollipop', 'regular', 5, <int, int>{3: 230, 4: 760, 5: 2300}),
  Sym('gem', 'regular', 3, <int, int>{3: 440, 4: 1550, 5: 5400}),
  Sym('bonus_fish', 'regular', 12, <int, int>{3: 54, 4: 160, 5: 550}),
  Sym('bonus_zeus', 'regular', 9, <int, int>{3: 74, 4: 210, 5: 740}),
  Sym('bonus_joker', 'regular', 9, <int, int>{3: 74, 4: 210, 5: 740}),
  Sym('bonus_winter', 'regular', 12, <int, int>{3: 54, 4: 160, 5: 550}),
  Sym('bar', 'wild', 8, <int, int>{3: 140, 4: 400, 5: 1250}),
  Sym('wild', 'regular', 10, <int, int>{3: 70, 4: 200, 5: 660}),
  Sym('bonus_wheel_snow', 'bonus', 12, <int, int>{}, 'snow'),
  Sym('bonus_wheel_emerald', 'bonus', 10, <int, int>{}, 'emerald'),
  Sym('bonus_wheel_amethyst', 'bonus', 8, <int, int>{}, 'amethyst'),
  Sym('bonus_wheel_fire', 'bonus', 6, <int, int>{}, 'fire'),
  Sym('bonus_wheel_frost', 'bonus', 5, <int, int>{}, 'frost'),
];

final Map<String, Sym> byId = <String, Sym>{
  for (final Sym s in symbols) s.id: s,
};

// 20 paylines.
const List<List<int>> paylines = <List<int>>[
  <int>[1, 1, 1, 1, 1],
  <int>[0, 0, 0, 0, 0],
  <int>[2, 2, 2, 2, 2],
  <int>[0, 1, 2, 1, 0],
  <int>[2, 1, 0, 1, 2],
  <int>[1, 0, 0, 0, 1],
  <int>[1, 2, 2, 2, 1],
  <int>[0, 0, 1, 2, 2],
  <int>[2, 2, 1, 0, 0],
  <int>[1, 0, 1, 2, 1],
  <int>[1, 2, 1, 0, 1],
  <int>[0, 1, 1, 1, 0],
  <int>[2, 1, 1, 1, 2],
  <int>[1, 1, 0, 1, 1],
  <int>[1, 1, 2, 1, 1],
  <int>[0, 1, 0, 1, 0],
  <int>[2, 1, 2, 1, 2],
  <int>[1, 0, 2, 0, 1],
  <int>[1, 2, 0, 2, 1],
  <int>[0, 2, 0, 2, 0],
];

// ---------------------------------------------------------------------------
// Bonus wheel EV, planned 3-tier design.
//
// Every scatter now leads to the same 3-tier wheel game. Each tier is a
// 12-cell wheel; three cells sitting 120° apart send the round to the next
// tier. Tier 3 is the top: only prizes and jackpots.
// ---------------------------------------------------------------------------

class WheelSegment {
  const WheelSegment.coins(this.mult)
    : type = 'coins',
      jackpotMult = 0,
      upgrade = false;
  const WheelSegment.jackpot(this.jackpotMult)
    : type = 'jackpot',
      mult = 0,
      upgrade = false;
  const WheelSegment.upgrade()
    : type = 'upgrade',
      mult = 0,
      jackpotMult = 0,
      upgrade = true;

  final String type;
  final int mult;
  final int jackpotMult;
  final bool upgrade;
}

// Prize multipliers are of totalBet.
const List<WheelSegment> tier1 = <WheelSegment>[
  WheelSegment.upgrade(),          // 0
  WheelSegment.coins(3),           // 1
  WheelSegment.coins(4),           // 2
  WheelSegment.coins(2),           // 3
  WheelSegment.upgrade(),          // 4
  WheelSegment.coins(5),           // 5
  WheelSegment.coins(3),           // 6
  WheelSegment.coins(4),           // 7
  WheelSegment.upgrade(),          // 8
  WheelSegment.coins(2),           // 9
  WheelSegment.coins(6),           // 10
  WheelSegment.coins(4),           // 11
];

const List<WheelSegment> tier2 = <WheelSegment>[
  WheelSegment.upgrade(),
  WheelSegment.coins(7),
  WheelSegment.coins(9),
  WheelSegment.coins(11),
  WheelSegment.upgrade(),
  WheelSegment.coins(9),
  WheelSegment.coins(7),
  WheelSegment.coins(14),
  WheelSegment.upgrade(),
  WheelSegment.coins(7),
  WheelSegment.coins(18),
  WheelSegment.coins(11),
];

const List<WheelSegment> tier3 = <WheelSegment>[
  WheelSegment.coins(20),
  WheelSegment.coins(28),
  WheelSegment.coins(15),
  WheelSegment.jackpot(10),   // MINI
  WheelSegment.coins(32),
  WheelSegment.coins(22),
  WheelSegment.coins(40),
  WheelSegment.jackpot(50),   // MINOR
  WheelSegment.coins(24),
  WheelSegment.coins(60),
  WheelSegment.jackpot(500),  // GRAND
  WheelSegment.coins(32),
];

/// Expected multiplier of totalBet paid per wheel round when it starts at
/// [startingTier]. Uses closed-form recursion over the 3 tiers.
double wheelEv(int startingTier) {
  final List<List<WheelSegment>> tiers = <List<WheelSegment>>[tier1, tier2, tier3];
  final List<double> tierEv = List<double>.filled(3, 0);
  // Tier 3 is terminal: expected prize = average of its segments.
  double sum = 0;
  for (final WheelSegment seg in tier3) {
    sum += seg.mult + seg.jackpotMult.toDouble();
  }
  tierEv[2] = sum / tier3.length;
  // Tiers 1 and 2: with probability p_upgrade advance and take the next
  // tier's EV; otherwise take the prize on this tier.
  for (int t = 1; t >= 0; t--) {
    final List<WheelSegment> segs = tiers[t];
    int upgrades = 0;
    double prizes = 0;
    for (final WheelSegment seg in segs) {
      if (seg.upgrade) {
        upgrades++;
      } else {
        prizes += seg.mult + seg.jackpotMult.toDouble();
      }
    }
    final double n = segs.length.toDouble();
    tierEv[t] = prizes / n + upgrades / n * tierEv[t + 1];
  }
  return tierEv[startingTier];
}

// Which tier does each scatter open the wheel on.
int startingTierFor(String bonusId) => switch (bonusId) {
  'snow' => 0,
  'emerald' => 0,
  'amethyst' => 1,
  'fire' => 1,
  'frost' => 2,
  _ => 0,
};

// How many spins does the round get depending on how many scatters landed
// (3, 4, or 5).
int spinsFor(int scatterCount) => switch (scatterCount) {
  <= 3 => 1,
  4 => 2,
  _ => 3,
};

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

late final List<List<String>> pools;

void buildPools() {
  pools = List<List<String>>.generate(5, (_) {
    final List<String> pool = <String>[];
    for (final Sym s in symbols) {
      for (int i = 0; i < s.weight; i++) {
        pool.add(s.id);
      }
    }
    return pool;
  });
}

List<List<String>> spinGrid(Random rng) {
  return List<List<String>>.generate(5, (int reel) {
    final List<String> pool = pools[reel];
    final List<String> column = <String>[];
    final Set<String> seenBonus = <String>{};
    while (column.length < 3) {
      final String id = pool[rng.nextInt(pool.length)];
      if (byId[id]!.kind == 'bonus') {
        if (!seenBonus.add(id)) continue;
      }
      column.add(id);
    }
    return column;
  });
}

int evaluateLines(List<List<String>> grid) {
  int total = 0;
  for (final List<int> line in paylines) {
    final List<String> seq = <String>[for (int r = 0; r < 5; r++) grid[r][line[r]]];
    String? base;
    for (final String id in seq) {
      final Sym s = byId[id]!;
      if (s.kind == 'regular') {
        base = id;
        break;
      }
      if (s.kind != 'wild') break;
    }
    int count = 0;
    if (base == null) {
      for (final String id in seq) {
        if (byId[id]!.kind == 'wild') {
          count++;
        } else {
          break;
        }
      }
      base = 'bar';
    } else {
      for (final String id in seq) {
        if (id == base || byId[id]!.kind == 'wild') {
          count++;
        } else {
          break;
        }
      }
    }
    final int? pay = byId[base]!.pays[count];
    if (pay != null) total += pay; // pay is in lineBet units
  }
  return total; // multiplied by lineBet outside
}

class BonusHit {
  const BonusHit(this.bonusId, this.count);
  final String bonusId;
  final int count;
}

BonusHit? detectBonus(List<List<String>> grid) {
  String? best;
  int bestCount = 0;
  for (final Sym s in symbols) {
    if (s.kind != 'bonus') continue;
    int c = 0;
    for (int r = 0; r < 5; r++) {
      for (int row = 0; row < 3; row++) {
        if (grid[r][row] == s.id) c++;
      }
    }
    if (c >= 3 && c > bestCount) {
      best = s.bonus;
      bestCount = c;
    }
  }
  if (best == null) return null;
  return BonusHit(best, bestCount);
}

// ---------------------------------------------------------------------------
// Main sim
// ---------------------------------------------------------------------------

void main(List<String> args) {
  final int spins = args.isNotEmpty ? int.parse(args[0]) : 100000;
  final int seed = args.length > 1
      ? int.parse(args[1])
      : DateTime.now().microsecondsSinceEpoch;
  buildPools();
  final Random rng = Random(seed);

  const int lineBet = 1;
  const int totalBet = 20;

  double lineWinTotal = 0;
  double bonusWinTotal = 0;
  int bonusHits = 0;
  int lineHits = 0;

  for (int i = 0; i < spins; i++) {
    final List<List<String>> grid = spinGrid(rng);
    final int lineCoins = evaluateLines(grid) * lineBet;
    lineWinTotal += lineCoins;
    if (lineCoins > 0) lineHits++;

    final BonusHit? bonus = detectBonus(grid);
    if (bonus != null) {
      bonusHits++;
      final int startTier = startingTierFor(bonus.bonusId);
      final int spins = spinsFor(bonus.count);
      final double evPerSpin = wheelEv(startTier);
      bonusWinTotal += evPerSpin * spins * totalBet;
    }
  }

  final double staked = spins * totalBet.toDouble();
  final double rtpLines = lineWinTotal / staked * 100;
  final double rtpBonus = bonusWinTotal / staked * 100;
  final double rtp = rtpLines + rtpBonus;

  print('Spins:                $spins');
  print('Total bet:            ${staked.toStringAsFixed(0)}');
  print('Line wins:            ${lineWinTotal.toStringAsFixed(0)}   ($lineHits hits, hit rate ${(lineHits / spins * 100).toStringAsFixed(2)}%)');
  print('Bonus wins (EV):      ${bonusWinTotal.toStringAsFixed(0)}   ($bonusHits triggers, ${(bonusHits / spins * 100).toStringAsFixed(3)}% freq)');
  print('RTP lines:            ${rtpLines.toStringAsFixed(2)}%');
  print('RTP bonus:            ${rtpBonus.toStringAsFixed(2)}%');
  print('RTP total:            ${rtp.toStringAsFixed(2)}%');
  print('Wheel EV tier 0/1/2:  ${wheelEv(0).toStringAsFixed(3)}  ${wheelEv(1).toStringAsFixed(3)}  ${wheelEv(2).toStringAsFixed(3)}');
}
