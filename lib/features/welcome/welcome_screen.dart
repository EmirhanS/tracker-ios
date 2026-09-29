import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../data/providers.dart';
import '../../domain/models/player.dart';
import '../session/current_player_provider.dart';

/// Picks the player using the app.
///
/// This stands in for sign-in. When Google or Apple sign-in arrives, the list
/// below is replaced by the provider buttons and nothing else changes.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  String? _selectedId;

  void _continue(List<Player> players) {
    final id = _selectedId;
    if (id == null) return;

    final player = players.firstWhere((player) => player.id == id);
    ref.read(currentPlayerProvider.notifier).signIn(player);
    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final players = ref.watch(playersProvider);

    return Scaffold(
      body: SafeArea(
        child: AsyncView<List<Player>>(
          value: players,
          builder: (context, players) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.sports_score,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        AppStrings.welcomeTitle,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppStrings.welcomeTagline,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        AppStrings.welcomeChoosePlayer,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      final isSelected = player.id == _selectedId;

                      return ListTile(
                        selected: isSelected,
                        onTap: () => setState(() => _selectedId = player.id),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(player.name),
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primaryContainer,
                          child: Text(
                            _initials(player.name),
                            style: TextStyle(
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                              )
                            : const Icon(Icons.circle_outlined),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: FilledButton(
                    onPressed:
                        _selectedId == null ? null : () => _continue(players),
                    child: const Text(AppStrings.welcomeContinue),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Mia Halvorsen" becomes "MH".
String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
