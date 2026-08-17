import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Standard loading and recovery boundary for locally persisted application state.
class AppStateBoundary extends ConsumerWidget {
  /// Creates a boundary that renders feature content after state is available.
  const AppStateBoundary({
    required this.state,
    required this.builder,
    super.key,
  });

  /// Current asynchronous application state.
  final AsyncValue<AppState> state;

  /// Builds feature content from a successfully loaded immutable snapshot.
  final Widget Function(AppState state) builder;

  @override
  /// Avoids exposing corrupt local content while offering a safe reload action.
  Widget build(BuildContext context, WidgetRef ref) {
    return state.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        final text = AppLocalizations.of(context);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline_rounded, size: 42),
                const SizedBox(height: 12),
                Text(text.somethingWentWrong),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(appControllerProvider),
                  child: Text(text.retry),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
