import 'package:sporttracker/data/in_memory/in_memory_challenge_repository.dart';
import 'package:sporttracker/domain/models/challenge.dart';

/// An in-memory challenge store whose member writes always fail.
///
/// It exists for one thing: proving that a row leaves the member list because
/// the write landed, not because the screen guessed it would. Everything else
/// behaves exactly as the real one does.
class RefusingChallengeRepository extends InMemoryChallengeRepository {
  RefusingChallengeRepository({
    super.challenges,
    super.idGenerator,
    super.joinCodeGenerator,
  });

  @override
  Future<Challenge> removeMember({
    required String challengeId,
    required String ownerId,
    required String playerId,
  }) async {
    throw StateError('The store refused to remove $playerId.');
  }

  @override
  Future<Challenge> leaveChallenge({
    required String challengeId,
    required String playerId,
  }) async {
    throw StateError('The store refused to let $playerId leave.');
  }
}
