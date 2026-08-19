import 'package:miko_hero/core/models/app_language.dart';

/// Safe device speech speeds offered by the story reader.
enum NarrationSpeed {
  /// Slower speech for younger readers.
  slow(0.35),

  /// Balanced default speech pace.
  normal(0.5),

  /// Faster speech for confident readers.
  fast(0.65);

  /// Associates the choice with the cross-platform TTS plugin rate.
  const NarrationSpeed(this.platformRate);

  /// Rate sent only to the current device speech engine.
  final double platformRate;
}

/// Amount of story text spoken by one play action.
enum NarrationScope {
  /// Speaks only the visible story page.
  currentPage,

  /// Speaks from the visible page through the end of the book.
  remainingStory,
}

/// Bounded bedtime limits after which narration stops on its own.
enum NarrationSleepTimer {
  /// Narration keeps going until the story or the listener ends it.
  off(null),

  /// Stops narration five minutes after playback started.
  fiveMinutes(Duration(minutes: 5)),

  /// Stops narration ten minutes after playback started.
  tenMinutes(Duration(minutes: 10)),

  /// Stops narration twenty minutes after playback started.
  twentyMinutes(Duration(minutes: 20));

  /// Associates the choice with the countdown it starts, or null when off.
  const NarrationSleepTimer(this.duration);

  /// Time narration may still run, or null when no limit is selected.
  final Duration? duration;

  /// Whether this choice actually limits how long narration continues.
  bool get isActive => duration != null;
}

/// One validated speech command passed to the platform boundary.
class NarrationRequest {
  /// Creates an immutable command from reader-owned choices.
  const NarrationRequest({
    required this.text,
    required this.language,
    required this.speed,
  });

  /// Story prose to speak without sending it across the network.
  final String text;

  /// Installed device voice locale requested for the prose.
  final AppLanguage language;

  /// Reader-selected platform speech pace.
  final NarrationSpeed speed;
}
