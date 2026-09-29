import 'dart:math';

/// The short code that lets a player into a challenge.
///
/// A code gets read out loud, written on a whiteboard and typed back in, so the
/// rules here are all about what survives that trip.
abstract final class JoinCode {
  /// The characters a code is built from.
  ///
  /// O, 0, I and 1 are left out. They look alike in most fonts and sound alike
  /// when somebody reads a code across a room, so keeping them out removes a
  /// whole class of "it says the code is wrong" support.
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// How many characters a code has.
  static const int length = 6;

  static final RegExp _separators = RegExp(r'[\s-]');

  /// Turns what a player typed into the form the store holds.
  ///
  /// Spaces and dashes go, because people break a code up to read it, and the
  /// rest is uppercased. `'  a-bc def '` and `'AbCdEf'` both give `ABCDEF`.
  static String normalize(String input) =>
      input.replaceAll(_separators, '').toUpperCase();

  /// True when [code] is exactly [length] characters, all from [alphabet].
  ///
  /// Nothing is normalised first, on purpose: this asks whether a code *is* a
  /// code, so `'abcdef'` is not one. Callers taking input from a player run it
  /// through [normalize] first.
  static bool isValid(String code) {
    if (code.length != length) return false;
    for (var i = 0; i < code.length; i++) {
      if (!alphabet.contains(code[i])) return false;
    }
    return true;
  }
}

/// Hands out join codes.
///
/// An interface rather than a `Random()` call inside the repository, so a test
/// can script exactly which codes come out — including the same code twice, to
/// prove the repository retries on a collision.
abstract interface class JoinCodeGenerator {
  /// A code, which the caller still has to check for a collision.
  String next();
}

/// Picks [JoinCode.length] characters out of [JoinCode.alphabet] at random.
class RandomJoinCodeGenerator implements JoinCodeGenerator {
  RandomJoinCodeGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  String next() {
    final buffer = StringBuffer();
    for (var i = 0; i < JoinCode.length; i++) {
      buffer.write(
        JoinCode.alphabet[_random.nextInt(JoinCode.alphabet.length)],
      );
    }
    return buffer.toString();
  }
}
