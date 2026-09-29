import 'dart:async';

/// A list held in memory that tells listeners when it changes.
///
/// Every in-memory repository is built on this, so they all behave the same:
/// a new listener gets the current list at once, then every later change.
class InMemoryStore<T> {
  InMemoryStore([Iterable<T> initial = const []])
      : _items = List<T>.of(initial);

  final List<T> _items;
  final StreamController<List<T>> _changes =
      StreamController<List<T>>.broadcast();

  /// A copy of the current list. Callers cannot change the store through it.
  List<T> get items => List<T>.unmodifiable(_items);

  /// The current list first, then a new list after every change.
  ///
  /// Built with `Stream.multi` so the subscription to [_changes] exists by the
  /// time `listen` returns. An `async*` body only subscribes on the next
  /// event-loop turn, so a write landing between the snapshot and that turn
  /// reached a broadcast controller with no listener and was dropped for good.
  Stream<List<T>> watch() {
    return Stream<List<T>>.multi((controller) {
      controller.add(items);
      controller.addStream(_changes.stream).then((_) => controller.close());
    });
  }

  void add(T item) {
    _items.add(item);
    _notify();
  }

  void replaceAt(int index, T item) {
    _items[index] = item;
    _notify();
  }

  void replaceAll(Iterable<T> items) {
    _items
      ..clear()
      ..addAll(items);
    _notify();
  }

  /// Removes the first item matching [test]. Returns true when one went.
  bool removeWhere(bool Function(T) test) {
    final index = _items.indexWhere(test);
    if (index < 0) return false;
    _items.removeAt(index);
    _notify();
    return true;
  }

  int indexWhere(bool Function(T) test) => _items.indexWhere(test);

  T? firstWhereOrNull(bool Function(T) test) {
    final index = _items.indexWhere(test);
    return index < 0 ? null : _items[index];
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(items);
  }

  /// Stops the change stream.
  ///
  /// Closing is not awaited: a broadcast controller with a listener that has
  /// not cancelled yet would otherwise hold the caller up.
  void dispose() => unawaited(_changes.close());
}
