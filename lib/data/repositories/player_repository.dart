import '../../domain/models/player.dart';

/// Reads the team roster.
///
/// v1 has a fixed seeded roster. A Supabase implementation replaces this class
/// without any change above it.
abstract interface class PlayerRepository {
  Future<List<Player>> getAll();

  Future<Player?> getById(String id);

  /// Emits the current roster, then again after every change.
  Stream<List<Player>> watchAll();
}
