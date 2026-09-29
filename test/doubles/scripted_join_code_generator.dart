import 'package:sporttracker/domain/codes/join_code.dart';

/// A [JoinCodeGenerator] that hands out the codes a test wrote for it.
///
/// Real codes are random, which is no good for asserting on one. Scripting them
/// also lets a test hand the same code out twice and prove the repository keeps
/// looking rather than storing a duplicate.
class ScriptedJoinCodeGenerator implements JoinCodeGenerator {
  ScriptedJoinCodeGenerator(this.codes);

  final List<String> codes;

  int _used = 0;

  /// How many codes have been taken so far, for counting retries.
  int get used => _used;

  @override
  String next() {
    if (_used >= codes.length) {
      // Running out is a failed test, not a fallback: a repository that asks for
      // more codes than the script holds is not doing what the test says.
      throw StateError(
        'The script only holds ${codes.length} join codes and they are all used.',
      );
    }
    return codes[_used++];
  }
}
