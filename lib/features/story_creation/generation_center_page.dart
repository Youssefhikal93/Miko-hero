import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/models/generation_job.dart';
import 'package:miko_hero/features/story_creation/generation_queue_controller.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// Parent-only readiness summary and durable generation queue controls.
class GenerationCenterPage extends ConsumerStatefulWidget {
  /// Creates the routed local generation center.
  const GenerationCenterPage({super.key});

  @override
  /// Creates retry progress state for one job at a time.
  ConsumerState<GenerationCenterPage> createState() {
    return _GenerationCenterPageState();
  }
}

/// Coordinates queue retry and cancellation without owning persistence.
class _GenerationCenterPageState extends ConsumerState<GenerationCenterPage> {
  String? _activeJobId;

  @override
  /// Shows honest backend readiness followed by persisted pending requests.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final queue = ref.watch(generationQueueControllerProvider);
    return ScreenLayout(
      maxWidth: 860,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            title: text.generationCenterTitle,
            subtitle: text.generationCenterBody,
          ),
          const SizedBox(height: 20),
          const _AiReadinessCard(),
          const SizedBox(height: 20),
          Text(
            text.generationQueueTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          queue.when(
            data: _queueContent,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _QueueError(
              onRetry: () {
                ref.invalidate(generationQueueControllerProvider);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Renders an empty state or one command card per persisted request.
  Widget _queueContent(List<GenerationJob> jobs) {
    final text = AppLocalizations.of(context);
    if (jobs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text.generationQueueEmpty),
        ),
      );
    }
    return Column(
      children: jobs
          .map(
            (job) => _GenerationJobCard(
              job: job,
              isBusy: _activeJobId == job.id,
              onRetry: () => _retry(job),
              onCancel: () => _cancel(job),
            ),
          )
          .toList(growable: false),
    );
  }

  /// Retries one job and routes its successfully saved draft to review.
  Future<void> _retry(GenerationJob job) async {
    if (_activeJobId != null) return;
    setState(() => _activeJobId = job.id);
    try {
      final story = await ref
          .read(storyControllerProvider)
          .retryGeneration(job.id);
      if (mounted) context.go('/review/${story.id}');
    } on Exception {
      if (!mounted) return;
      _showError();
      setState(() => _activeJobId = null);
    }
  }

  /// Confirms removal of one pending request without deleting saved stories.
  Future<void> _cancel(GenerationJob job) async {
    final text = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.cancelGenerationTitle),
        content: Text(text.cancelGenerationBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: Text(text.removeFromQueue),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(storyControllerProvider).cancelGeneration(job.id);
    } on Exception {
      if (mounted) _showError();
    }
  }

  /// Shows safe recovery feedback without exposing request or family content.
  void _showError() {
    final text = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
  }
}

/// Honest current capability report for demo, Ollama, ComfyUI, and PC use.
class _AiReadinessCard extends StatelessWidget {
  /// Creates the static readiness card from implemented integration state.
  const _AiReadinessCard();

  @override
  /// Distinguishes the available demo from unimplemented local AI adapters.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            _ReadinessRow(
              icon: Icons.offline_bolt_rounded,
              title: text.demoGeneratorStatus,
              status: text.readyOffline,
              isReady: true,
            ),
            const Divider(),
            _ReadinessRow(
              icon: Icons.text_fields_rounded,
              title: text.ollamaStatus,
              status: text.notConnectedYet,
              isReady: false,
            ),
            const Divider(),
            _ReadinessRow(
              icon: Icons.image_rounded,
              title: text.comfyUiStatus,
              status: text.notConnectedYet,
              isReady: false,
            ),
            const SizedBox(height: 12),
            Text(text.pcRequirementStatus),
          ],
        ),
      ),
    );
  }
}

/// One backend status row with accessible icon and text state.
class _ReadinessRow extends StatelessWidget {
  /// Creates a row from one backend label and readiness result.
  const _ReadinessRow({
    required this.icon,
    required this.title,
    required this.status,
    required this.isReady,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool isReady;

  @override
  /// Uses color as reinforcement while keeping status available as text.
  Widget build(BuildContext context) {
    final statusColor = isReady ? Colors.greenAccent : Colors.orangeAccent;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      trailing: Text(status, style: TextStyle(color: statusColor)),
    );
  }
}

/// One durable request with status and safe retry or cancel controls.
class _GenerationJobCard extends StatelessWidget {
  /// Creates a queue card from the current persisted job snapshot.
  const _GenerationJobCard({
    required this.job,
    required this.isBusy,
    required this.onRetry,
    required this.onCancel,
  });

  final GenerationJob job;
  final bool isBusy;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  /// Shows hero and theme context without displaying private profile photos.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            const Icon(Icons.pending_actions_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    job.request.heroName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(job.request.theme),
                  Text(_statusName(text, job.status)),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: isBusy || job.status == GenerationJobStatus.running
                  ? null
                  : onRetry,
              tooltip: text.retryGeneration,
              icon: isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              onPressed: isBusy ? null : onCancel,
              tooltip: text.removeFromQueue,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }

  /// Localizes one persisted lifecycle state.
  String _statusName(AppLocalizations text, GenerationJobStatus status) {
    return switch (status) {
      GenerationJobStatus.queued => text.generationQueued,
      GenerationJobStatus.running => text.generationRunning,
      GenerationJobStatus.failed => text.generationFailed,
    };
  }
}

/// Retry surface for corrupt or unreadable local queue state.
class _QueueError extends StatelessWidget {
  /// Creates a queue error surface with a non-destructive reload command.
  const _QueueError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  /// Keeps malformed queue bytes intact while offering a retry.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline_rounded),
        title: Text(text.somethingWentWrong),
        trailing: TextButton(onPressed: onRetry, child: Text(text.retry)),
      ),
    );
  }
}
