import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/in_memory/seed_data.dart';
import 'data/providers.dart';

/// Starts the app with the in-memory repositories.
///
/// This is the one place that decides where the data comes from. A Supabase
/// build swaps the three overrides below for Supabase repositories, and no
/// screen changes.
void main() {
  final repositories = SeedData.build();

  runApp(
    ProviderScope(
      overrides: [
        playerRepositoryProvider.overrideWithValue(repositories.players),
        seasonRepositoryProvider.overrideWithValue(repositories.seasons),
        activityRepositoryProvider.overrideWithValue(repositories.activities),
      ],
      child: const SportTrackerApp(),
    ),
  );
}
