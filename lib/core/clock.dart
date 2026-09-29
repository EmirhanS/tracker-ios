import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the app reads "now".
///
/// Going through a provider means tests can fix the date, so "this week" and
/// "Today" never depend on when the test runs.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The instant the screens are currently drawing.
///
/// Watch this rather than calling [clockProvider] inline. Two reasons:
///
/// * Everything on a frame agrees on one "now", so a list cannot label a row
///   "Today" while the total beside it has already moved on to tomorrow.
/// * It gives [ClockTicker] something to invalidate. [clockProvider] holds a
///   *function*, and the same function is identical across a rebuild —
///   `DateTime.now` is a canonicalised tearoff, and a test's override is one
///   captured closure — so invalidating it changes no value and Riverpod
///   rightly tells nobody. Invalidating this recomputes the instant, and
///   dependents wake only when the instant has really moved. A test that pins
///   [clockProvider] therefore stays pinned through any number of ticks.
///
/// Use `ref.read(clockProvider)()` instead where the live wall clock is what
/// is wanted — validating a typed date on submit, say.
final nowProvider = Provider<DateTime>((ref) => ref.watch(clockProvider)());

/// Rereads the clock when the day turns over, and again on every resume.
///
/// Everything derived from "now" — "Today", "Yesterday", the Monday-to-Sunday
/// week on the dashboard — hangs off [nowProvider], which is a plain `Provider`
/// and so only recomputes when something it watches changes. Left to itself an
/// app open across midnight keeps counting the old week until the next log or
/// delete happens to rebuild it.
///
/// Two triggers, because neither covers the other: the timer catches an app
/// sitting in the foreground over midnight, the resume catches one that was
/// backgrounded — where timers are not dependable — and came back days later.
class ClockTicker extends ConsumerStatefulWidget {
  const ClockTicker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ClockTicker> createState() => _ClockTickerState();
}

class _ClockTickerState extends ConsumerState<ClockTicker> {
  Timer? _midnight;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _tick);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  void _tick() {
    ref.invalidate(nowProvider);
    _scheduleMidnight();
  }

  /// Arms the timer for just after the next local midnight.
  ///
  /// Measured from the clock to the next calendar day rather than by adding a
  /// flat 24 hours, so it stays on the day boundary across a DST change, where
  /// two adjacent local midnights are 23 or 25 hours apart. The second of slack
  /// keeps it from firing a hair early and reading the old day straight back;
  /// the one-second floor keeps a clock pinned in the past — a test's — from
  /// turning a zero-length timer into a spin.
  void _scheduleMidnight() {
    _midnight?.cancel();

    final now = ref.read(clockProvider)();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    final untilMidnight = nextDay.difference(now) + const Duration(seconds: 1);

    _midnight = Timer(
      untilMidnight < const Duration(seconds: 1)
          ? const Duration(seconds: 1)
          : untilMidnight,
      _tick,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
