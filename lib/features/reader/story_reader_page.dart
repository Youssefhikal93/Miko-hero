import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/narration/narration_options.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/features/reader/narration_controller.dart';
import 'package:miko_hero/features/reader/reader_controls.dart';
import 'package:miko_hero/features/reader/reader_dialogs.dart';
import 'package:miko_hero/features/reader/reader_spread.dart';
import 'package:miko_hero/features/reader/story_export_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/parent_gated_action.dart';
import 'package:miko_hero/shared/reading_badge_view.dart';

/// Full-screen illustrated reader with free device narration.
///
/// The page itself only orchestrates: it resolves the route's story, owns the
/// narration session and the page position, answers the reader's three modal
/// questions, and records a finished reading. What a page looks like lives in
/// `reader_spread.dart`, and the chrome around it in `reader_controls.dart`.
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
  late final NarrationController _narration;
  int _pageIndex = 0;
  bool _exporting = false;
  bool _bedtime = false;
  bool _sleepTimerChosen = false;
  bool _finishRecorded = false;

  @override
  /// Builds the sentence queue around the provider-owned speech service.
  void initState() {
    super.initState();
    _narration = NarrationController(ref.read(narrationServiceProvider))
      ..onPageChanged = _followNarratedPage
      ..onUnavailable = _showNarrationUnavailable
      ..addListener(_narrationChanged);
  }

  @override
  /// Stops speech before releasing the page controller and route state.
  void dispose() {
    _narration
      ..removeListener(_narrationChanged)
      ..dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Repaints controls and the sentence highlight as the queue advances.
  void _narrationChanged() {
    if (mounted) setState(() {});
  }

  @override
  /// Resolves the route identity from local state without accepting book payloads.
  ///
  /// A deleted story and one a parent has not approved are the same answer
  /// here: the reader opens neither and offers the shelf instead.
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      body: AppStateBoundary(
        state: state,
        builder: (snapshot) {
          final story = snapshot.storyById(widget.storyId);
          if (story == null ||
              story.reviewStatus != StoryReviewStatus.approved) {
            return const _MissingStory();
          }
          return _reader(snapshot, story);
        },
      ),
    );
  }

  /// Composes page content and controls from one stable story snapshot.
  Widget _reader(AppState state, StoryBook story) {
    final pages = story.content.pages;
    final lastPage = pages.length - 1;
    final profile = state.profileById(story.content.request.profileId);
    final readingSettings =
        profile?.readingSettings ?? const ChildReadingSettings();
    _scheduleFinishCheck(story);
    return Column(
      children: <Widget>[
        ReaderTopRow(
          profile: profile,
          bedtime: _bedtime,
          onClose: () => context.go('/library'),
          onBedtime: _toggleBedtime,
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (index) => _changePage(index, story),
            itemBuilder: (context, index) {
              return ReaderSpread(
                pageContext: ReaderPageContext(
                  story: story,
                  page: pages[index],
                  profile: profile,
                  readingSettings: readingSettings,
                  bedtime: _bedtime,
                  highlightedSentence: _narration.highlightedSentence(index),
                ),
              );
            },
          ),
        ),
        ReaderControls(
          status: ReaderStatus(
            pageIndex: _pageIndex,
            pageCount: pages.length,
            playback: _narration.playback,
            exporting: _exporting,
          ),
          actions: ReaderActions(
            navigation: ReaderNavigation(
              previous: _pageIndex == 0 ? null : () => _turnTo(_pageIndex - 1),
              next: _pageIndex == lastPage
                  ? null
                  : () => _turnTo(_pageIndex + 1),
            ),
            narration: () => _toggleNarration(story),
            stopNarration: () => unawaited(_narration.stop()),
            narrationSettings: _changeNarrationSettings,
            textSize: profile == null ? null : () => _changeTextSize(profile),
            export: () => _exportStory(story, profile),
          ),
        ),
      ],
    );
  }

  /// Records the visible page and lets narration decide whether to continue.
  ///
  /// A page turn the sentence queue itself requested keeps narrating; a swipe
  /// or arrow tap by the reader stops it and clears the highlight.
  void _changePage(int pageIndex, StoryBook story) {
    unawaited(_narration.handlePageChange(pageIndex));
    setState(() => _pageIndex = pageIndex);
    _noteFinishedStory(story, pageIndex);
  }

  /// Counts a story a child opened directly on its last page, once per session.
  void _scheduleFinishCheck(StoryBook story) {
    if (_finishRecorded || _pageIndex != story.content.pages.length - 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _noteFinishedStory(story, _pageIndex);
    });
  }

  /// Records one finished reading when the last page of a story is reached.
  ///
  /// Guarded per reader session so paging back and forth never celebrates
  /// twice; the profile itself keeps distinct identities, so a story read again
  /// tomorrow still counts only once.
  void _noteFinishedStory(StoryBook story, int pageIndex) {
    if (_finishRecorded || pageIndex != story.content.pages.length - 1) return;
    _finishRecorded = true;
    unawaited(_recordFinishedStory(story));
  }

  /// Persists the finished story and celebrates a badge the moment it is earned.
  Future<void> _recordFinishedStory(StoryBook story) async {
    try {
      final badge = await ref
          .read(profileControllerProvider)
          .recordFinishedStory(story.content.request.profileId, story.id);
      if (badge == null || !mounted) return;
      final text = AppLocalizations.of(context);
      reportActionOutcome(
        ScaffoldMessenger.of(context),
        text.badgeEarned(readingBadgeName(text, badge)),
      );
    } on Exception {
      // A profile deleted while its story is open must not break reading.
    }
  }

  /// Dims and warms the reader for one bedtime session without persisting it.
  void _toggleBedtime() {
    setState(() => _bedtime = !_bedtime);
    if (_bedtime && _narration.isActive) _applyBedtimeSleepTimer();
  }

  /// Selects the ten-minute limit unless a timer was already chosen this session.
  void _applyBedtimeSleepTimer() {
    if (_sleepTimerChosen || _narration.sleepTimer.isActive) return;
    _narration.setSleepTimer(NarrationSleepTimer.tenMinutes);
    final duration = NarrationSleepTimer.tenMinutes.duration!;
    reportActionOutcome(
      ScaffoldMessenger.of(context),
      AppLocalizations.of(context).bedtimeSleepTimerApplied(duration.inMinutes),
    );
  }

  /// Follows the sentence queue into the next page of a rest-of-story reading.
  void _followNarratedPage(int pageIndex) => unawaited(_turnTo(pageIndex));

  /// Turns the book to one page, the single animation every page turn uses.
  Future<void> _turnTo(int pageIndex) async {
    if (!mounted || !_pageController.hasClients) return;
    await _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  /// Plays, pauses, or resumes sentence-by-sentence narration.
  Future<void> _toggleNarration(StoryBook story) async {
    switch (_narration.playback) {
      case NarrationPlayback.playing:
        await _narration.pause();
      case NarrationPlayback.paused:
        await _narration.resume();
      case NarrationPlayback.idle:
        if (_bedtime) _applyBedtimeSleepTimer();
        await _narration.start(
          pageTexts: story.content.pages
              .map((page) => page.text)
              .toList(growable: false),
          pageIndex: _pageIndex,
          language: story.content.request.presentation.language,
        );
    }
  }

  /// Opens session narration choices and requeues only when the scope changes.
  ///
  /// Pace and sleep timer apply to playback that is already running, so a
  /// bedtime limit never costs the listener their place in the story.
  Future<void> _changeNarrationSettings() async {
    final selected = await showNarrationSettingsDialog(
      context,
      current: _selection,
    );
    if (selected == null || !mounted) return;
    final requeue = selected.scope != _narration.scope;
    _sleepTimerChosen = _sleepTimerChosen || selected.sleepTimerChosen;
    _narration
      ..setSpeed(selected.speed)
      ..setScope(selected.scope)
      ..setSleepTimer(selected.sleepTimer);
    if (requeue) await _narration.stop();
  }

  /// Returns the current session choices as one immutable dialog value.
  NarrationSelection get _selection {
    return NarrationSelection(
      speed: _narration.speed,
      scope: _narration.scope,
      sleepTimer: _narration.sleepTimer,
      remainingSleep: _narration.remainingSleep,
    );
  }

  /// Opens the hero's saved prose size without closing the book.
  ///
  /// The choice is the same reading comfort My Kingdom edits, so a size picked
  /// mid-story is the size this child keeps in every later book.
  Future<void> _changeTextSize(ChildProfile profile) async {
    final settings = profile.readingSettings;
    final size = await showTextSizeDialog(context, current: settings.textSize);
    if (size == null || size == settings.textSize || !mounted) return;
    try {
      await ref
          .read(profileControllerProvider)
          .setReadingSettings(profile.id, settings.withTextSize(size));
    } on Exception {
      if (mounted) {
        reportActionOutcome(
          ScaffoldMessenger.of(context),
          AppLocalizations.of(context).somethingWentWrong,
        );
      }
    }
  }

  /// Requests parent access and the cover choice before writing a story file.
  ///
  /// The photo question is only asked when the hero still has a saved photo;
  /// otherwise the photo-free cover is the only possible result.
  Future<void> _exportStory(StoryBook story, ChildProfile? profile) async {
    if (_exporting) return;
    await runParentGatedAction<bool, bool>(
      context,
      ref,
      confirm: (context) => _chooseCover(context, profile),
      run: (context, includePhoto) =>
          _savePdf(story, includePhoto: includePhoto),
      report: (text, saved) => saved ? text.pdfSaved : text.pdfSaveCancelled,
      onFailure: (text, failure) => text.pdfExportFailed,
    );
  }

  /// Asks about the cover photo only while the hero still has one.
  ///
  /// Parents expect the hero's face, so the question starts already answered
  /// yes and only a deliberate change leaves it off the cover.
  Future<bool?> _chooseCover(
    BuildContext context,
    ChildProfile? profile,
  ) async {
    if (profile == null || profile.photoBase64.isEmpty) return false;
    return showExportOptionsDialog(
      context,
      current: true,
      childName: profile.name,
    );
  }

  /// Renders and saves the PDF while keeping cancellation non-exceptional.
  Future<bool> _savePdf(StoryBook story, {required bool includePhoto}) async {
    final text = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      return await ref
          .read(storyExportControllerProvider)
          .export(story, text.exportPdfDialogTitle, includePhoto: includePhoto);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
