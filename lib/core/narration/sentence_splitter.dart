/// Sentence terminators recognized across the four supported story languages.
///
/// The Arabic question mark is listed separately from the Latin one because
/// Arabic story prose never uses `?`.
const narrationSentenceTerminators = <String>{'.', '!', '?', '؟', '…'};

/// One sentence located inside the original, unmodified page text.
///
/// The offsets always refer to the string that was split, so a reader can
/// highlight the exact characters it already renders instead of re-joining
/// fragments and changing the child's story text.
class NarrationSentence {
  /// Creates a located sentence; [end] is exclusive, as in `String.substring`.
  const NarrationSentence({
    required this.text,
    required this.start,
    required this.end,
  });

  /// Sentence prose with its terminator kept and surrounding blanks removed.
  final String text;

  /// Index of the first character of [text] inside the split page text.
  final int start;

  /// Index just after the last character of [text] inside the page text.
  final int end;
}

/// Locates every spoken sentence of one page in reading order.
///
/// A sentence ends at a run of terminators (so `Wait...` stays one sentence)
/// or at a line break, and the terminator stays attached to the sentence that
/// owns it. Blank fragments are dropped, so empty text yields no sentences and
/// narration simply has nothing to say for that page.
List<NarrationSentence> locateNarrationSentences(String text) {
  final sentences = <NarrationSentence>[];
  var start = 0;
  var index = 0;
  while (index < text.length) {
    final character = text[index];
    if (character == '\n') {
      _addSentence(sentences, text, start, index);
      index++;
      start = index;
      continue;
    }
    if (narrationSentenceTerminators.contains(character)) {
      index++;
      while (index < text.length &&
          narrationSentenceTerminators.contains(text[index])) {
        index++;
      }
      _addSentence(sentences, text, start, index);
      start = index;
      continue;
    }
    index++;
  }
  _addSentence(sentences, text, start, text.length);
  return List<NarrationSentence>.unmodifiable(sentences);
}

/// Splits one page into the sentences narration speaks, in reading order.
List<String> splitIntoSentences(String text) {
  return locateNarrationSentences(
    text,
  ).map((sentence) => sentence.text).toList(growable: false);
}

/// Appends one trimmed fragment, ignoring whitespace-only ranges.
void _addSentence(
  List<NarrationSentence> sentences,
  String text,
  int start,
  int end,
) {
  final fragment = text.substring(start, end);
  final trimmedStart = start + (fragment.length - fragment.trimLeft().length);
  final trimmedEnd = end - (fragment.length - fragment.trimRight().length);
  if (trimmedEnd <= trimmedStart) return;
  sentences.add(
    NarrationSentence(
      text: text.substring(trimmedStart, trimmedEnd),
      start: trimmedStart,
      end: trimmedEnd,
    ),
  );
}
