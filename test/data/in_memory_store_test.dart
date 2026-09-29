import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/data/in_memory/in_memory_store.dart';

void main() {
  group('InMemoryStore.watch', () {
    test('a new listener gets the current list at once', () async {
      final store = InMemoryStore<int>([1, 2]);
      addTearDown(store.dispose);

      await expectLater(store.watch().first, completion([1, 2]));
    });

    test('a write in the same turn as listen is not dropped', () async {
      final store = InMemoryStore<int>([1]);
      addTearDown(store.dispose);

      final seen = <List<int>>[];
      final subscription = store.watch().listen(seen.add);
      addTearDown(subscription.cancel);

      // Deliberately no await before the write. With the old `async*` body the
      // subscription to the broadcast controller was only established on the
      // next event-loop turn, so this change reached a controller with no
      // listener and was lost for good - the listener stayed on [1] until some
      // later write happened to bring it back in sync.
      store.add(2);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [
        [1],
        [1, 2],
      ]);
    });

    test('every later change is emitted, in order', () async {
      final store = InMemoryStore<int>();
      addTearDown(store.dispose);

      final seen = <List<int>>[];
      final subscription = store.watch().listen(seen.add);
      addTearDown(subscription.cancel);

      store.add(1);
      store.add(2);
      store.removeWhere((item) => item == 1);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [
        <int>[],
        [1],
        [1, 2],
        [2],
      ]);
    });

    test('two listeners both see the same changes', () async {
      final store = InMemoryStore<int>();
      addTearDown(store.dispose);

      final first = <List<int>>[];
      final second = <List<int>>[];
      final a = store.watch().listen(first.add);
      final b = store.watch().listen(second.add);
      addTearDown(a.cancel);
      addTearDown(b.cancel);

      store.add(7);
      await Future<void>.delayed(Duration.zero);

      expect(first, second);
      expect(first.last, [7]);
    });

    test('the list handed out cannot change the store', () {
      final store = InMemoryStore<int>([1]);
      addTearDown(store.dispose);

      expect(() => store.items.add(2), throwsUnsupportedError);
      expect(store.items, [1]);
    });
  });
}
