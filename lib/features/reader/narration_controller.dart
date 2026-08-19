import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/narration/narration_options.dart';
import 'package:miko_hero/core/narration/narration_service.dart';
import 'package:miko_hero/core/narration/sentence_splitter.dart';

/// Countdown factory injected so tests expire a sleep timer deterministically.
typedef NarrationTimerFactory =
    Timer Function(Duration delay, void Function() onExpire);

/// Whether the reader is silent, speaking, or holding a remembered position.
enum NarrationPlayback {
  /// Nothing is queued and no sentence is highlighted.
  idle,

  /// A sentence is being spoken by the device voice.
  playing,

  /// Playback stopped but the paused sentence is still remembered.
  paused,
}

/// One queued sentence together with the story page that contains it.
class NarrationCue {
  /// Creates a cue that locates a sentence inside the open book.
  const NarrationCue({
    required this.pageIndex,
    required this.sentenceIndex,
    required this.text,
  });

  /// Zero-based page the sentence belongs to.
  final int pageIndex;

  /// Zero-based position of the sentence inside its page.
  final int sentenceIndex;

  /// Sentence prose handed to the device voice unchanged.
  final String text;
}

/// Speaks a story one sentence at a time and owns the reader's queue position.
///
/// Splitting the page into sentences and driving the queue here — above the
/// [NarrationService] platform boundary — keeps sentence progress, pause,
/// resume, and the sleep timer identical on every platform, because only
/// speak-completion is required from the device engine. It also makes the whole
/// behavior unit-testable without a real voice.
class NarrationController extends ChangeNotifier {
  /// Creates a controller around one device speech boundary.
  ///
  /// [scheduleSleepTimer] and [clock] are injected together so a test can both
  /// fire the countdown and read the remaining time it reports.
  NarrationController(
    this._service, {
    NarrationTimerFactory? scheduleSleepTimer,
    DateTime Function()? clock,
  }) : _scheduleSleepTimer = scheduleSleepTimer ?? Timer.new,
       _clock = clock ?? DateTime.now;

  final NarrationService _service;
  final NarrationTimerFactory _scheduleSleepTimer;
  final DateTime Function() _clock;

  List<NarrationCue> _cues = const <NarrationCue>[];
  NarrationPlayback _playback = NarrationPlayback.idle;
  NarrationSpeed _speed = NarrationSpeed.normal;
  NarrationScope _scope = NarrationScope.currentPage;
  NarrationSleepTimer _sleepTimer = NarrationSleepTimer.off;
  AppLanguage _language = AppLanguage.english;
  Timer? _sleepCountdown;
  DateTime? _sleepDeadline;
  int _position = 0;
  int _announcedPage = 0;
  int _generation = 0;
  bool _disposed = false;

  /// Called with the page the queue moved to so the reader can turn the page.
  ValueChanged<int>? onPageChanged;

  /// Called when the device has no usable voice, so the reader can explain it.
  VoidCallback? onUnavailable;

  /// Current playback lifecycle observed by the reader controls.
  NarrationPlayback get playback => _playback;

  /// Whether narration is either speaking or paused on a remembered sentence.
  bool get isActive => _playback != NarrationPlayback.idle;

  /// Sentence currently spoken or paused on, or null while nothing is queued.
  NarrationCue? get currentCue {
    if (_playback == NarrationPlayback.idle || _position >= _cues.length) {
      return null;
    }
    return _cues[_position];
  }

  /// Reader-selected device speech pace.
  NarrationSpeed get speed => _speed;

  /// Amount of the book one play action speaks.
  NarrationScope get scope => _scope;

  /// Selected bedtime limit, which is off until a parent chooses one.
  NarrationSleepTimer get sleepTimer => _sleepTimer;

  /// Time left before the sleep timer stops narration, or null when inactive.
  Duration? get remainingSleep {
    final deadline = _sleepDeadline;
    if (deadline == null) return null;
    final remaining = deadline.difference(_clock());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Sentence to highlight on [pageIndex], or null when that page is silent.
  int? highlightedSentence(int pageIndex) {
    final cue = currentCue;
    return cue != null && cue.pageIndex == pageIndex ? cue.sentenceIndex : null;
  }

  /// Speaks the selected scope from [pageIndex], one sentence at a time.
  ///
  /// Any earlier queue is dropped first. A page without spoken sentences and a
  /// device without a voice for [language] both leave narration idle; the
  /// missing voice additionally reports through [onUnavailable].
  Future<void> start({
    required List<String> pageTexts,
    required int pageIndex,
    required AppLanguage language,
  }) async {
    await stop();
    final cues = _buildQueue(pageTexts, pageIndex);
    if (cues.isEmpty) return;
    final token = _generation;
    if (!await _hasVoice(language)) {
      if (token == _generation) onUnavailable?.call();
      return;
    }
    if (token != _generation) return;
    _language = language;
    _cues = cues;
    _position = 0;
    _announcedPage = pageIndex;
    _playback = NarrationPlayback.playing;
    _startSleepCountdown();
    _notify();
    await _speakQueue();
  }

  /// Stops the current utterance while remembering the sentence it reached.
  ///
  /// Deliberately independent of platform pause support: resuming re-speaks the
  /// paused sentence from its beginning.
  Future<void> pause() async {
    if (_playback != NarrationPlayback.playing) return;
    _generation++;
    _playback = NarrationPlayback.paused;
    _notify();
    await _service.stop();
  }

  /// Continues the queue by speaking the paused sentence again from its start.
  Future<void> resume() async {
    if (_playback != NarrationPlayback.paused) return;
    _generation++;
    _playback = NarrationPlayback.playing;
    _notify();
    await _speakQueue();
  }

  /// Ends narration, clears the queue and highlight, and resets the countdown.
  Future<void> stop() async {
    _generation++;
    final wasActive = isActive;
    _cues = const <NarrationCue>[];
    _position = 0;
    _playback = NarrationPlayback.idle;
    _cancelSleepCountdown();
    if (wasActive) _notify();
    await _service.stop();
  }

  /// Ends narration when the reader shows a page the queue did not ask for.
  ///
  /// A page turn the queue itself requested is kept, so rest-of-story narration
  /// continues across pages instead of silencing itself.
  Future<void> handlePageChange(int pageIndex) async {
    if (currentCue?.pageIndex == pageIndex) return;
    await stop();
  }

  /// Applies a new device pace, which the next spoken sentence already uses.
  void setSpeed(NarrationSpeed selectedSpeed) {
    if (_speed == selectedSpeed) return;
    _speed = selectedSpeed;
    _notify();
  }

  /// Applies a new spoken scope, which the next play action queues.
  void setScope(NarrationScope selectedScope) {
    if (_scope == selectedScope) return;
    _scope = selectedScope;
    _notify();
  }

  /// Applies a bedtime limit and restarts the countdown when already speaking.
  void setSleepTimer(NarrationSleepTimer selectedTimer) {
    if (_sleepTimer == selectedTimer) return;
    _sleepTimer = selectedTimer;
    if (isActive) {
      _startSleepCountdown();
    } else {
      _cancelSleepCountdown();
    }
    _notify();
  }

  @override
  /// Silences the device and drops the countdown before listeners disappear.
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelSleepCountdown();
    unawaited(_service.stop());
    super.dispose();
  }

  /// Speaks queued sentences until the queue ends or the position is replaced.
  Future<void> _speakQueue() async {
    final token = _generation;
    while (_position < _cues.length) {
      final cue = _cues[_position];
      _announce(cue);
      try {
        await _service.speak(
          NarrationRequest(text: cue.text, language: _language, speed: _speed),
        );
      } on Exception {
        if (token != _generation) return;
        await stop();
        onUnavailable?.call();
        return;
      }
      if (token != _generation) return;
      _position++;
    }
    await stop();
  }

  /// Publishes the active sentence and asks the reader to follow a page turn.
  void _announce(NarrationCue cue) {
    if (cue.pageIndex != _announcedPage) {
      _announcedPage = cue.pageIndex;
      onPageChanged?.call(cue.pageIndex);
    }
    _notify();
  }

  /// Builds the sentence queue for the selected scope in reading order.
  List<NarrationCue> _buildQueue(List<String> pageTexts, int pageIndex) {
    if (pageIndex < 0 || pageIndex >= pageTexts.length) {
      return const <NarrationCue>[];
    }
    final lastPage = _scope == NarrationScope.currentPage
        ? pageIndex
        : pageTexts.length - 1;
    final cues = <NarrationCue>[];
    for (var page = pageIndex; page <= lastPage; page++) {
      final sentences = splitIntoSentences(pageTexts[page]);
      for (var index = 0; index < sentences.length; index++) {
        cues.add(
          NarrationCue(
            pageIndex: page,
            sentenceIndex: index,
            text: sentences[index],
          ),
        );
      }
    }
    return List<NarrationCue>.unmodifiable(cues);
  }

  /// Treats a failing availability check as a device without a usable voice.
  Future<bool> _hasVoice(AppLanguage language) async {
    try {
      return await _service.supports(language);
    } on Exception {
      return false;
    }
  }

  /// Restarts the bedtime countdown from now, or clears it when off.
  void _startSleepCountdown() {
    _cancelSleepCountdown();
    final duration = _sleepTimer.duration;
    if (duration == null) return;
    _sleepDeadline = _clock().add(duration);
    _sleepCountdown = _scheduleSleepTimer(duration, _expireSleepCountdown);
  }

  /// Drops any pending countdown so a stopped story never stops itself later.
  void _cancelSleepCountdown() {
    _sleepCountdown?.cancel();
    _sleepCountdown = null;
    _sleepDeadline = null;
  }

  /// Ends narration at the bedtime limit without any fade-out.
  void _expireSleepCountdown() {
    unawaited(stop());
  }

  /// Notifies listeners only while the reader session is still mounted.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }
}
