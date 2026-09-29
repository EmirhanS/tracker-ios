/// A member of the team.
///
/// v1 has no accounts: players come from the seed data and the welcome screen
/// picks one. When sign-in arrives, [id] becomes the account id.
class Player {
  const Player({required this.id, required this.name});

  final String id;
  final String name;

  Player copyWith({String? id, String? name}) {
    return Player(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Player(id: $id, name: $name)';
}
