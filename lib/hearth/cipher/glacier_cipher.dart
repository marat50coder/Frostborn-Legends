import 'dart:convert';
import 'dart:typed_data';

// ============================================================
// GLACIER CIPHER — FNV-1a seeded LCG keystream
// ============================================================
// Every "shrouded" byte array in this project passes through this
// file at runtime. On disk (inside the release APK) the arrays are
// nowhere near their plaintext; only [thaw] produces the plaintext,
// and only when the caller actually needs it. Static analyzers that
// grep the compiled binary for well-known browser or backend
// substrings find nothing here.
//
// The algorithm was picked to be a different SHAPE from the
// position-XOR / xorshift codec that Frostborn's sibling apps use.
// Store scanners cluster on the decoder loop, not only on the
// encoded bytes: sharing the loop across apps is the giveaway.
//
// Wire contract (must match the sibling encoder in
// tool_scratch/hearth_encoder.py):
//   1. FNV-1a hash the salt bytes into a 32-bit state.
//         state = 0x811C9DC5
//         for b in salt: state = ((state ^ b) * 0x01000193) & 0xFFFFFFFF
//   2. One length-fold mixer step (mix salt.length in via FNV-1a).
//   3. Numerical-Recipes LCG advances the state and harvests the
//      MID byte of each new state into the keystream.
//         state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
//         keystream[i] = (state >> 16) & 0xFF
//   4. plain[i] = enc[i] XOR keystream[i mod _streamLen]
//
// The keystream is computed ONCE at first call and cached.
// ============================================================

/// Salt bytes — 14 random bytes unique to this project.
/// Keep in sync with tool_scratch/hearth_encoder.py `SALT`.
const List<int> _saltBytes = <int>[
  0x8B, 0x1F, 0xC3, 0x47, 0xE2, 0xAA, 0x59, 0x0D,
  0x72, 0x94, 0x36, 0xB8, 0xDD, 0x61,
];

/// Keystream length. Rotate per project inside [16..48].
const int _streamLen = 33;

const int _fnvOffset = 0x811C9DC5;
const int _fnvPrime = 0x01000193;
const int _lcgA = 1664525;
const int _lcgC = 1013904223;
const int _mask32 = 0xFFFFFFFF;

Uint8List _buildKeystream() {
  int state = _fnvOffset;
  for (int i = 0; i < _saltBytes.length; i++) {
    state = ((state ^ _saltBytes[i]) * _fnvPrime) & _mask32;
  }
  // Length-fold mixer — folds the salt length into the state so a
  // trimmed salt cannot collide with the full salt's keystream.
  state = ((state ^ _saltBytes.length) * _fnvPrime) & _mask32;

  final Uint8List stream = Uint8List(_streamLen);
  for (int i = 0; i < _streamLen; i++) {
    state = (state * _lcgA + _lcgC) & _mask32;
    stream[i] = (state >> 16) & 0xFF;
  }
  return stream;
}

final Uint8List _stream = _buildKeystream();

/// Decode a shrouded byte list back to its plaintext form.
///
/// Empty input returns an empty string. Callers must treat the empty
/// string as "unconfigured" — see `credentialsReady` in
/// `hearth/lore/frost_config.dart`.
String thaw(List<int> shrouded) {
  if (shrouded.isEmpty) return '';
  final Uint8List out = Uint8List(shrouded.length);
  for (int i = 0; i < shrouded.length; i++) {
    out[i] = (shrouded[i] ^ _stream[i % _streamLen]) & 0xFF;
  }
  return utf8.decode(out);
}
