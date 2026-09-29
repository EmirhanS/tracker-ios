import '../../domain/models/player.dart';
import '../repositories/player_repository.dart';
import 'in_memory_store.dart';

/// The team roster, held in memory.
class InMemoryPlayerRepository implements PlayerRepository {
  InMemoryPlayerRepository(Iterable<Player> players)
      : _store = InMemoryStore<Player>(players);

  final InMemoryStore<Player> _store;

  @override
  Future<List<Player>> getAll() async => _store.items;

  @override
  Future<Player?> getById(String id) async =>
      _store.firstWhereOrNull((player) => player.id == id);

  @override
  Stream<List<Player>> watchAll() => _store.watch();

  void dispose() => _store.dispose();
}
