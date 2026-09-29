import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/domain/codes/join_code.dart';

void main() {
  group('the alphabet', () {
    test('holds nothing a player can misread', () {
      // O against 0 and I against 1 are the pairs people get wrong reading a
      // code out, so none of the four is in the alphabet at all.
      expect(JoinCode.alphabet, isNot(contains('O')));
      expect(JoinCode.alphabet, isNot(contains('0')));
      expect(JoinCode.alphabet, isNot(contains('I')));
      expect(JoinCode.alphabet, isNot(contains('1')));
    });

    test('is uppercase letters and digits only, with no repeats', () {
      expect(JoinCode.alphabet, matches(RegExp(r'^[A-Z2-9]+$')));
      expect(JoinCode.alphabet.split('').toSet(), hasLength(32));
    });

    test('a code is six characters long', () {
      expect(JoinCode.length, 6);
    });
  });

  group('normalize', () {
    test('uppercases', () {
      expect(JoinCode.normalize('abcdef'), 'ABCDEF');
      expect(JoinCode.normalize('AbCdEf'), 'ABCDEF');
    });

    test('drops the spaces and dashes people read a code out with', () {
      expect(JoinCode.normalize('  a-bc def '), 'ABCDEF');
      expect(JoinCode.normalize('ABC-DEF'), 'ABCDEF');
      expect(JoinCode.normalize('A B C D E F'), 'ABCDEF');
    });

    test('leaves a clean code alone', () {
      expect(JoinCode.normalize('ABCDEF'), 'ABCDEF');
    });

    test('an empty string stays empty', () {
      expect(JoinCode.normalize('   '), '');
    });

    test('does not repair a character that is not in the alphabet', () {
      // Normalising is about whitespace and case only. Swapping 0 for O would
      // be a guess, and a guess that matches somebody else's code is worse
      // than a "no such code" message.
      expect(JoinCode.normalize('abcd0f'), 'ABCD0F');
      expect(JoinCode.isValid(JoinCode.normalize('abcd0f')), isFalse);
    });
  });

  group('isValid', () {
    test('accepts a six character code from the alphabet', () {
      expect(JoinCode.isValid('ABCDEF'), isTrue);
      expect(JoinCode.isValid('23456789'.substring(0, 6)), isTrue);
      expect(JoinCode.isValid('A2B3C4'), isTrue);
    });

    test('rejects the wrong length', () {
      expect(JoinCode.isValid(''), isFalse);
      expect(JoinCode.isValid('ABCDE'), isFalse);
      expect(JoinCode.isValid('ABCDEFG'), isFalse);
    });

    test('rejects the characters that are not in the alphabet', () {
      expect(JoinCode.isValid('ABCDEO'), isFalse);
      expect(JoinCode.isValid('ABCDE0'), isFalse);
      expect(JoinCode.isValid('ABCDEI'), isFalse);
      expect(JoinCode.isValid('ABCDE1'), isFalse);
    });

    test('rejects lowercase, spaces and dashes', () {
      expect(JoinCode.isValid('abcdef'), isFalse);
      expect(JoinCode.isValid('ABC DE'), isFalse);
      expect(JoinCode.isValid('ABC-DE'), isFalse);
    });
  });

  group('RandomJoinCodeGenerator', () {
    test('every code it makes is a valid one', () {
      final generator = RandomJoinCodeGenerator(random: Random(7));

      for (var i = 0; i < 200; i++) {
        final code = generator.next();
        expect(JoinCode.isValid(code), isTrue, reason: code);
      }
    });

    test('the same seed gives the same codes', () {
      final first = RandomJoinCodeGenerator(random: Random(7));
      final second = RandomJoinCodeGenerator(random: Random(7));

      expect(
        [for (var i = 0; i < 5; i++) first.next()],
        [for (var i = 0; i < 5; i++) second.next()],
      );
    });

    test('it does not hand the same code out over and over', () {
      final generator = RandomJoinCodeGenerator(random: Random(7));
      final codes = {for (var i = 0; i < 100; i++) generator.next()};

      // 32^6 codes, so 100 draws colliding more than a couple of times would
      // mean the generator is not using the whole alphabet.
      expect(codes, hasLength(greaterThan(95)));
    });
  });
}
