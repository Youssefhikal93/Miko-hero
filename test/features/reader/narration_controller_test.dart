import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/narration/narration_options.dart';
import 'package:miko_hero/core/narration/narration_service.dart';
import 'package:miko_hero/features/reader/narration_controller.dart';

/// Verifies sentence-by-sentence narration without a real device voice.
void main() {
  test('play speaks the sentences of a page in reading order', () async {
    final voice = _FakeVoice();
    final controller = NarrationController(voice);

    unawaited(_startPage(controller, 'One. Two. Three.'));
    await _settle();

    expect(voice.spokenText, <String>['One.']);
    expect(controller.playback, NarrationPlayback.playing);
    expect(controller.currentCue!.sentenceIndex, 0);

    await voice.finishUtterance();
    expect(voice.spokenText, <String>['One.', 'Two.']);
    expect(controller.currentCue!.sentenceIndex, 1);

    await voice.finishUtterance();
    await voice.finishUtterance();
    expect(voice.spokenText, <String>['One.', 'Two.', 'Three.']);
    expect(controller.playback, NarrationPlayback.idle);
    expect(controller.currentCue, isNull);
  });

  test('pause freezes the position and resume repeats that sentence', () async {
    final voice = _FakeVoice();
    final controller = NarrationController(voice);

    unawaited(_startPage(controller, 'One. Two.'));
    await _settle();
    await controller.pause();

    expect(controller.playback, NarrationPlayback.paused);
    expect(controller.currentCue!.text, 'One.');

    await voice.finishUtterance();
    expect(voice.spokenText, <String>['One.'], reason: 'paused queue advanced');

    unawaited(controller.resume());
    await _settle();

    expect(controller.playback, NarrationPlayback.playing);
    expect(voice.spokenText, <String>['One.', 'One.']);
  });

  test('stop clears the queue and the highlighted sentence', () async {
    final voice = _FakeVoice();
    final controller = NarrationController(voice);

    unawaited(_startPage(controller, 'One. Two.'));
    await _settle();
    await controller.stop();

    expect(controller.playback, NarrationPlayback.idle);
    expect(controller.currentCue, isNull);
    expect(voice.stopCount, greaterThan(0));

    await voice.finishUtterance();
    expect(voice.spokenText, <String>['One.']);
  });

  test('turning to another page stops narration', () async {
    final voice = _FakeVoice();
    final controller = NarrationController(voice);

    unawaited(_startPage(controller, 'One. Two.'));
    await _settle();

    await controller.handlePageChange(0);
    expect(controller.playback, NarrationPlayback.playing);

    await controller.handlePageChange(1);
    expect(controller.playback, NarrationPlayback.idle);
    expect(controller.currentCue, isNull);
  });

  test('rest of story continues onto the next page', () async {
    final voice = _FakeVoice();
    final controller = NarrationController(voice);
    final followedPages = <int>[];
    controller
      ..onPageChanged = followedPages.add
      ..setScope(NarrationScope.remainingStory);

    unawaited(
      controller.start(
        pageTexts: const <String>['One.', 'Two.'],
        pageIndex: 0,
        language: AppLanguage.english,
      ),
    );
    await _settle();
    expect(followedPages, isEmpty);

    await voice.finishUtterance();

    expect(followedPages, <int>[1]);
    expect(voice.spokenText, <String>['One.', 'Two.']);
    expect(controller.currentCue!.pageIndex, 1);
  });

  test('the sleep timer stops narration when it expires', () async {
    final voice = _FakeVoice();
    var now = DateTime.utc(2026, 8, 19, 20);
    Duration? scheduled;
    void Function()? expire;
    final controller = NarrationController(
      voice,
      clock: () => now,
      scheduleSleepTimer: (delay, onExpire) {
        scheduled = delay;
        expire = onExpire;
        return Timer(const Duration(hours: 1), () {});
      },
    );
    controller.setSleepTimer(NarrationSleepTimer.fiveMinutes);

    unawaited(_startPage(controller, 'One. Two.'));
    await _settle();

    expect(scheduled, const Duration(minutes: 5));
    expect(controller.remainingSleep, const Duration(minutes: 5));

    now = now.add(const Duration(minutes: 3));
    expect(controller.remainingSleep, const Duration(minutes: 2));

    expire!();
    await _settle();

    expect(controller.playback, NarrationPlayback.idle);
    expect(controller.remainingSleep, isNull);
    expect(voice.stopCount, greaterThan(0));
  });

  test('the selected speed reaches the device boundary', () async {
    final voice = _FakeVoice();
    final controller = NarrationController(voice)
      ..setSpeed(NarrationSpeed.fast);

    unawaited(_startPage(controller, 'One.'));
    await _settle();

    expect(voice.spoken.single.speed, NarrationSpeed.fast);
    expect(voice.spoken.single.language, AppLanguage.english);
  });

  test(
    'a device without a voice reports instead of pretending to read',
    () async {
      final voice = _FakeVoice()..hasVoice = false;
      var reported = 0;
      final controller = NarrationController(voice)
        ..onUnavailable = () => reported++;

      await _startPage(controller, 'One.');

      expect(reported, 1);
      expect(voice.spoken, isEmpty);
      expect(controller.playback, NarrationPlayback.idle);
    },
  );
}

/// Starts narration of one page in the reader's default current-page scope.
Future<void> _startPage(NarrationController controller, String text) {
  return controller.start(
    pageTexts: <String>[text],
    pageIndex: 0,
    language: AppLanguage.english,
  );
}

/// Lets the controller's pending microtasks run before the next assertion.
Future<void> _settle() async {
  for (var pass = 0; pass < 4; pass++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Device voice that completes utterances only when the test asks it to.
class _FakeVoice implements NarrationService {
  /// Requests handed to the platform boundary, in the order they arrived.
  final spoken = <NarrationRequest>[];

  /// Number of times the reader asked the engine to fall silent.
  int stopCount = 0;

  /// Whether the simulated device has a voice for the requested language.
  bool hasVoice = true;

  Completer<void>? _utterance;

  /// Text of every request, which is what sentence order is asserted on.
  List<String> get spokenText {
    return spoken.map((request) => request.text).toList(growable: false);
  }

  @override
  /// Answers the availability probe without touching a platform plugin.
  Future<bool> supports(AppLanguage language) async => hasVoice;

  @override
  /// Holds the utterance open until [finishUtterance] reports completion.
  Future<void> speak(NarrationRequest request) {
    spoken.add(request);
    final utterance = Completer<void>();
    _utterance = utterance;
    return utterance.future;
  }

  @override
  /// Counts cancellations without completing the outstanding utterance.
  Future<void> stop() async => stopCount++;

  /// Completes the pending utterance the way a real engine reports it.
  Future<void> finishUtterance() async {
    final utterance = _utterance;
    _utterance = null;
    utterance?.complete();
    await _settle();
  }
}
