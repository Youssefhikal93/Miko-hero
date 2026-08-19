import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/narration/narration_options.dart';
import 'package:miko_hero/core/narration/narration_service.dart';
import 'package:miko_hero/features/reader/story_export_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/parent_access_gate.dart';

/// Full-screen illustrated reader with free device narration.
class StoryReaderPage extends ConsumerStatefulWidget {
  /// Creates a reader route for one locally persisted story identity.
  const StoryReaderPage({required this.storyId, super.key});

  /// Story identity resolved from the current local library.
  final String storyId;

  @override
  /// Creates page and narration state scoped to this reader session.
  ConsumerState<StoryReaderPage> createState() => _StoryReaderPageState();
}

/// Controls reader page position and active platform narration.
class _StoryReaderPageState extends ConsumerState<StoryReaderPage> {
  final _pageController = PageController();
  late final NarrationService _narration;
  int _pageIndex = 0;
  bool _speaking = false;
  bool _exporting = false;
  NarrationSpeed _narrationSpeed = NarrationSpeed.normal;
  NarrationScope _narrationScope = NarrationScope.currentPage;

  @override
  /// Retains the provider-owned speech service before disposal becomes unsafe.
  void initState() {
    super.initState();
    _narration = ref.read(narrationServiceProvider);
  }

  @override
  /// Stops speech before releasing the page controller and route state.
  void dispose() {
    unawaited(_narration.stop());
    _pageController.dispose();
    super.dispose();
  }

  @override
  /// Resolves the route identity from local state without accepting book payloads.
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      body: AppStateBoundary(
        state: state,
        builder: (snapshot) {
          final story = _storyFrom(snapshot);
          if (story == null) return const _MissingStory();
          return _reader(snapshot, story);
        },
      ),
    );
  }

  /// Finds the requested book while treating a deleted identity as absent.
  StoryBook? _storyFrom(AppState state) {
    for (final story in state.stories) {
      if (story.id == widget.storyId &&
          story.reviewStatus == StoryReviewStatus.approved) {
        return story;
      }
    }
    return null;
  }

  /// Composes page content and controls from one stable story snapshot.
  Widget _reader(AppState state, StoryBook story) {
    final pages = story.content.pages;
    return Column(
      children: <Widget>[
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: _changePage,
            itemBuilder: (context, index) {
              return _ReaderPage(
                story: story,
                page: pages[index],
                profile: state.profileById(story.content.request.profileId),
              );
            },
          ),
        ),
        _ReaderControls(
          status: _ReaderStatus(
            pageIndex: _pageIndex,
            pageCount: pages.length,
            speaking: _speaking,
            exporting: _exporting,
          ),
          actions: _ReaderActions(
            navigation: _ReaderNavigation(
              previous: _pageIndex == 0 ? null : _previousPage,
              next: _pageIndex == pages.length - 1 ? null : _nextPage,
            ),
            narration: () => _toggleNarration(story),
            narrationSettings: _changeNarrationSettings,
            export: () => _exportStory(story),
          ),
        ),
      ],
    );
  }

  /// Changes page state and stops speech so narration never overlaps pages.
  void _changePage(int pageIndex) {
    unawaited(_narration.stop());
    setState(() {
      _pageIndex = pageIndex;
      _speaking = false;
    });
  }

  /// Moves one page backward using the reader's semantic page order.
  Future<void> _previousPage() async {
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  /// Moves one page forward using the reader's semantic page order.
  Future<void> _nextPage() async {
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  /// Starts or stops narration with graceful unsupported-language recovery.
  Future<void> _toggleNarration(StoryBook story) async {
    if (_speaking) {
      await _narration.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    await _startNarration(story);
  }

  /// Speaks the selected scope after checking for an installed device voice.
  Future<void> _startNarration(StoryBook story) async {
    final language = story.content.request.presentation.language;
    try {
      final supported = await _narration.supports(language);
      if (!supported) {
        _showNarrationUnavailable();
        return;
      }
      setState(() => _speaking = true);
      await _narration.speak(
        NarrationRequest(
          text: _narrationText(story),
          language: language,
          speed: _narrationSpeed,
        ),
      );
      if (mounted) setState(() => _speaking = false);
    } on Exception {
      if (mounted) setState(() => _speaking = false);
      _showNarrationUnavailable();
    }
  }

  /// Chooses either the visible page or all remaining pages for speech.
  String _narrationText(StoryBook story) {
    if (_narrationScope == NarrationScope.currentPage) {
      return story.content.pages[_pageIndex].text;
    }
    return story.content.pages
        .skip(_pageIndex)
        .map((page) => page.text)
        .join('\n\n');
  }

  /// Opens session narration choices and stops stale playback after changes.
  Future<void> _changeNarrationSettings() async {
    final selected = await showDialog<_NarrationSelection>(
      context: context,
      builder: (_) => _NarrationSettingsDialog(selection: _selection),
    );
    if (selected == null || !mounted) return;
    await _narration.stop();
    if (!mounted) return;
    setState(() {
      _narrationSpeed = selected.speed;
      _narrationScope = selected.scope;
      _speaking = false;
    });
  }

  /// Returns the current session choices as one immutable dialog value.
  _NarrationSelection get _selection {
    return _NarrationSelection(speed: _narrationSpeed, scope: _narrationScope);
  }

  /// Requests parent access before copying a named child story to a file.
  Future<void> _exportStory(StoryBook story) async {
    if (_exporting || !await requestParentAccess(context, ref)) return;
    await _savePdf(story);
  }

  /// Renders and saves the PDF while keeping cancellation non-exceptional.
  Future<void> _savePdf(StoryBook story) async {
    final text = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final saved = await ref
          .read(storyExportControllerProvider)
          .export(story, text.exportPdfDialogTitle);
      if (mounted) {
        _showMessage(saved ? text.pdfSaved : text.pdfSaveCancelled);
      }
    } on Exception {
      if (mounted) _showMessage(text.pdfExportFailed);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Replaces any reader notice with the latest export outcome.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Explains a missing platform voice without blocking text-based reading.
  void _showNarrationUnavailable() {
    if (!mounted) return;
    final text = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.narrationUnavailable)));
  }
}

/// Story page with explicit direction independent of the application locale.
class _ReaderPage extends StatelessWidget {
  /// Creates one responsive page spread from local story and profile content.
  const _ReaderPage({
    required this.story,
    required this.page,
    required this.profile,
  });

  final StoryBook story;
  final StoryPage page;
  final ChildProfile? profile;

  @override
  /// Switches between stacked phone content and a desktop two-column spread.
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final illustration = _PageIllustration(
          story: story,
          page: page,
          profile: profile,
        );
        final prose = _StoryProse(story: story, page: page);
        if (constraints.maxWidth < 760) {
          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                Expanded(flex: 3, child: illustration),
                const SizedBox(height: 16),
                Expanded(flex: 2, child: prose),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: <Widget>[
              Expanded(child: illustration),
              const SizedBox(width: 24),
              Expanded(child: prose),
            ],
          ),
        );
      },
    );
  }
}

/// Honest placeholder composition for the future ComfyUI page illustration.
class _PageIllustration extends StatelessWidget {
  /// Creates placeholder art from story styling and optional private photo bytes.
  const _PageIllustration({
    required this.story,
    required this.page,
    required this.profile,
  });

  final StoryBook story;
  final StoryPage page;
  final ChildProfile? profile;

  @override
  /// Uses local photo bytes only and marks the surface as demo output.
  Widget build(BuildContext context) {
    final photo = profile?.photoBase64;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _pageGradient(),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: CircleAvatar(
              radius: 72,
              backgroundColor: Colors.white24,
              backgroundImage: photo == null
                  ? null
                  : MemoryImage(base64Decode(photo)),
              child: photo == null
                  ? const Icon(
                      Icons.face_rounded,
                      size: 74,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          PositionedDirectional(
            top: 18,
            start: 18,
            child: Chip(
              avatar: const Icon(Icons.science_outlined, size: 16),
              label: Text(AppLocalizations.of(context).demoBadge),
            ),
          ),
          PositionedDirectional(
            end: 18,
            bottom: 18,
            child: Text(
              '${page.number}',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  /// Keeps placeholder art stable for each selected illustration style.
  LinearGradient _pageGradient() {
    final primary = AppTheme.primaryFor(story.content.request.gender);
    final secondary = AppTheme.secondaryFor(story.content.request.gender);
    return switch (story.content.request.presentation.style) {
      IllustrationStyle.pictureBook => LinearGradient(
        colors: <Color>[primary, secondary],
      ),
      IllustrationStyle.watercolor => LinearGradient(
        colors: <Color>[secondary, primary.withValues(alpha: 0.78)],
      ),
      IllustrationStyle.colorful3d => LinearGradient(
        colors: <Color>[primary, secondary, const Color(0xFF8A31CB)],
      ),
    };
  }
}

/// Scrollable story prose with language-specific direction and alignment.
class _StoryProse extends StatelessWidget {
  /// Creates prose for one page without inheriting the interface direction.
  const _StoryProse({required this.story, required this.page});

  final StoryBook story;
  final StoryPage page;

  @override
  /// Applies right-to-left direction only when the story language is Arabic.
  Widget build(BuildContext context) {
    final language = story.content.request.presentation.language;
    final direction = language == AppLanguage.arabic
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: Card(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                story.content.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 22),
              Text(page.text, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reader actions kept outside story direction so controls follow app locale.
class _ReaderControls extends StatelessWidget {
  /// Creates controls for the current reader position and narration state.
  const _ReaderControls({required this.status, required this.actions});

  final _ReaderStatus status;
  final _ReaderActions actions;

  @override
  /// Keeps page progress and actions reachable above mobile system insets.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: const BoxDecoration(
          color: Color(0xFF11141D),
          border: Border(top: BorderSide(color: Color(0xFF2A2E3B))),
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: actions.navigation.previous,
              tooltip: text.previousPage,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                text.pageProgress(status.pageIndex + 1, status.pageCount),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: status.exporting ? null : actions.export,
              tooltip: status.exporting ? text.exportingPdf : text.exportPdf,
              icon: status.exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
            ),
            IconButton(
              onPressed: actions.narrationSettings,
              tooltip: text.narrationSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton.filledTonal(
              onPressed: actions.narration,
              tooltip: status.speaking
                  ? text.stopNarration
                  : text.playNarration,
              icon: Icon(
                status.speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: actions.navigation.next,
              tooltip: text.nextPage,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// Immutable values needed to render the reader control bar.
class _ReaderStatus {
  /// Groups page progress and narration state into one control input.
  const _ReaderStatus({
    required this.pageIndex,
    required this.pageCount,
    required this.speaking,
    required this.exporting,
  });

  final int pageIndex;
  final int pageCount;
  final bool speaking;
  final bool exporting;
}

/// User commands exposed by the reader control bar.
class _ReaderActions {
  /// Groups navigation and narration commands without boolean action flags.
  const _ReaderActions({
    required this.navigation,
    required this.narration,
    required this.narrationSettings,
    required this.export,
  });

  final _ReaderNavigation navigation;
  final VoidCallback narration;
  final VoidCallback narrationSettings;
  final VoidCallback export;
}

/// Optional page movement commands grouped for the reader control bar.
class _ReaderNavigation {
  /// Creates movement callbacks disabled at the beginning and end.
  const _ReaderNavigation({required this.previous, required this.next});

  final VoidCallback? previous;
  final VoidCallback? next;
}

/// Immutable narration choices returned only after dialog confirmation.
class _NarrationSelection {
  /// Groups speech pace and scope without exposing mutable dialog state.
  const _NarrationSelection({required this.speed, required this.scope});

  final NarrationSpeed speed;
  final NarrationScope scope;
}

/// Session-only narration controls that do not alter a child's saved profile.
class _NarrationSettingsDialog extends StatefulWidget {
  /// Creates settings from the reader's current narration choices.
  const _NarrationSettingsDialog({required this.selection});

  final _NarrationSelection selection;

  @override
  /// Creates a disposable edit buffer for pace and spoken scope.
  State<_NarrationSettingsDialog> createState() {
    return _NarrationSettingsDialogState();
  }
}

/// Holds uncommitted narration choices until the reader confirms them.
class _NarrationSettingsDialogState extends State<_NarrationSettingsDialog> {
  late NarrationSpeed _speed;
  late NarrationScope _scope;

  @override
  /// Copies reader values so dismissing the dialog changes nothing.
  void initState() {
    super.initState();
    _speed = widget.selection.speed;
    _scope = widget.selection.scope;
  }

  @override
  /// Composes localized choice chips and explicit cancel/apply actions.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(text.narrationSettings),
      content: _content(text),
      actions: _actions(text),
    );
  }

  /// Separates pace and spoken scope into two scannable sections.
  Widget _content(AppLocalizations text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(text.narrationSpeed),
        const SizedBox(height: 8),
        _speedChoices(text),
        const SizedBox(height: 20),
        Text(text.narrationScope),
        const SizedBox(height: 8),
        _scopeChoices(text),
      ],
    );
  }

  /// Builds pace choices from the bounded platform-safe enum values.
  Widget _speedChoices(AppLocalizations text) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: NarrationSpeed.values
          .map((speed) {
            return ChoiceChip(
              selected: _speed == speed,
              onSelected: (_) => setState(() => _speed = speed),
              label: Text(_speedLabel(text, speed)),
            );
          })
          .toList(growable: false),
    );
  }

  /// Builds visible-page and remaining-story speech scope choices.
  Widget _scopeChoices(AppLocalizations text) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: NarrationScope.values
          .map((scope) {
            return ChoiceChip(
              selected: _scope == scope,
              onSelected: (_) => setState(() => _scope = scope),
              label: Text(_scopeLabel(text, scope)),
            );
          })
          .toList(growable: false),
    );
  }

  /// Returns cancel and apply actions without saving dismissed changes.
  List<Widget> _actions(AppLocalizations text) {
    return <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(text.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(
          context,
        ).pop(_NarrationSelection(speed: _speed, scope: _scope)),
        child: Text(text.applyNarrationSettings),
      ),
    ];
  }

  /// Localizes one device narration pace.
  String _speedLabel(AppLocalizations text, NarrationSpeed speed) {
    return switch (speed) {
      NarrationSpeed.slow => text.slowSpeed,
      NarrationSpeed.normal => text.normalSpeed,
      NarrationSpeed.fast => text.fastSpeed,
    };
  }

  /// Localizes one reader narration scope.
  String _scopeLabel(AppLocalizations text, NarrationScope scope) {
    return switch (scope) {
      NarrationScope.currentPage => text.currentPage,
      NarrationScope.remainingStory => text.remainingStory,
    };
  }
}

/// Safe destination when a deep link targets a deleted local story.
class _MissingStory extends StatelessWidget {
  /// Creates a non-sensitive recovery view for an unresolved story identity.
  const _MissingStory();

  @override
  /// Offers a library exit without leaking the missing route identity.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Center(
      child: FilledButton.tonal(
        onPressed: () => context.go('/library'),
        child: Text(text.somethingWentWrong),
      ),
    );
  }
}
