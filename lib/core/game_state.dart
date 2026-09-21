import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_service.dart';

/// Player profile and settings. All currency in this game is fun money: it has
/// no cash value and cannot be purchased or cashed out.
class GameState extends ChangeNotifier {
  static const List<int> betLevels = <int>[20, 40, 100, 200, 400, 1000, 2000, 4000];
  static const int startingCoins = 25000;
  static const int freeCoinsAmount = 5000;
  static const Duration freeCoinsCooldown = Duration(hours: 2);
  static const int lowBalanceThreshold = 2000;

  static const String _kCoins = 'coins';
  static const String _kBet = 'bet_index';
  static const String _kMusic = 'music_on';
  static const String _kSound = 'sound_on';
  static const String _kSpins = 'total_spins';
  static const String _kBest = 'best_win';
  static const String _kClaim = 'last_claim_ms';

  SharedPreferences? _prefs;

  int _coins = startingCoins;
  int _betIndex = 0;
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  int _totalSpins = 0;
  int _biggestWin = 0;
  int _lastClaimMs = 0;

  int get coins => _coins;
  int get betIndex => _betIndex;
  int get totalBet => betLevels[_betIndex];
  int get lineBet => totalBet ~/ 20;
  bool get musicEnabled => _musicEnabled;
  bool get soundEnabled => _soundEnabled;
  int get totalSpins => _totalSpins;
  int get biggestWin => _biggestWin;
  bool get canBetHigher => _betIndex < betLevels.length - 1;
  bool get canBetLower => _betIndex > 0;
  bool get canAffordSpin => _coins >= totalBet;

  bool get canClaimFreeCoins {
    if (_coins < lowBalanceThreshold) return true;
    final DateTime last = DateTime.fromMillisecondsSinceEpoch(_lastClaimMs);
    return DateTime.now().difference(last) >= freeCoinsCooldown;
  }

  Duration get freeCoinsRemaining {
    if (canClaimFreeCoins) return Duration.zero;
    final DateTime last = DateTime.fromMillisecondsSinceEpoch(_lastClaimMs);
    final Duration elapsed = DateTime.now().difference(last);
    final Duration left = freeCoinsCooldown - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final SharedPreferences prefs = _prefs!;
    _coins = prefs.getInt(_kCoins) ?? startingCoins;
    _betIndex = (prefs.getInt(_kBet) ?? 0).clamp(0, betLevels.length - 1);
    _musicEnabled = prefs.getBool(_kMusic) ?? true;
    _soundEnabled = prefs.getBool(_kSound) ?? true;
    _totalSpins = prefs.getInt(_kSpins) ?? 0;
    _biggestWin = prefs.getInt(_kBest) ?? 0;
    _lastClaimMs = prefs.getInt(_kClaim) ?? 0;
    AudioService.instance.musicEnabled = _musicEnabled;
    AudioService.instance.soundEnabled = _soundEnabled;
    notifyListeners();
  }

  void increaseBet() {
    if (!canBetHigher) return;
    _betIndex++;
    _prefs?.setInt(_kBet, _betIndex);
    notifyListeners();
  }

  void decreaseBet() {
    if (!canBetLower) return;
    _betIndex--;
    _prefs?.setInt(_kBet, _betIndex);
    notifyListeners();
  }

  void maxBet() {
    int index = betLevels.length - 1;
    while (index > 0 && betLevels[index] > _coins) {
      index--;
    }
    if (index == _betIndex) return;
    _betIndex = index;
    _prefs?.setInt(_kBet, _betIndex);
    notifyListeners();
  }

  /// Deducts the stake. Returns false when the player cannot cover the bet.
  bool placeBet() {
    if (_coins < totalBet) return false;
    _coins -= totalBet;
    _totalSpins++;
    _prefs?.setInt(_kCoins, _coins);
    _prefs?.setInt(_kSpins, _totalSpins);
    notifyListeners();
    return true;
  }

  void addWin(int amount) {
    if (amount <= 0) return;
    _coins += amount;
    if (amount > _biggestWin) {
      _biggestWin = amount;
      _prefs?.setInt(_kBest, _biggestWin);
    }
    _prefs?.setInt(_kCoins, _coins);
    notifyListeners();
  }

  bool claimFreeCoins() {
    if (!canClaimFreeCoins) return false;
    _coins += freeCoinsAmount;
    _lastClaimMs = DateTime.now().millisecondsSinceEpoch;
    _prefs?.setInt(_kCoins, _coins);
    _prefs?.setInt(_kClaim, _lastClaimMs);
    notifyListeners();
    return true;
  }

  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    await _prefs?.setBool(_kMusic, value);
    await AudioService.instance.setMusicEnabled(value);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    await _prefs?.setBool(_kSound, value);
    AudioService.instance.soundEnabled = value;
    notifyListeners();
  }

  Future<void> resetProgress() async {
    _coins = startingCoins;
    _betIndex = 0;
    _totalSpins = 0;
    _biggestWin = 0;
    _lastClaimMs = 0;
    await _prefs?.setInt(_kCoins, _coins);
    await _prefs?.setInt(_kBet, _betIndex);
    await _prefs?.setInt(_kSpins, _totalSpins);
    await _prefs?.setInt(_kBest, _biggestWin);
    await _prefs?.setInt(_kClaim, _lastClaimMs);
    notifyListeners();
  }
}

String formatCoins(int value) {
  final String digits = value.abs().toString();
  final StringBuffer buffer = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
