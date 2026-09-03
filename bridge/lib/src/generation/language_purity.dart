import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';

/// Smallest share of a story's letters that must belong to its own script.
///
/// Not 1.0 on purpose: a proper name, a made-up creature's name, or a single
/// borrowed word is not a language failure. A model that answered in the wrong
/// language, or mixed two languages sentence by sentence, lands far below this.
const double minimumScriptPurity = 0.95;

/// Verdict of one language-purity check.
///
/// Produced by [checkLanguagePurity], which is pure: it reads only the text it
/// is given and never throws, so the caller decides what a violation costs.
class LanguagePurityVerdict {
  /// Creates a verdict.
  const LanguagePurityVerdict({
    required this.isPure,
    required this.arabicLetters,
    required this.latinLetters,
    required this.otherLetters,
    this.failure,
  });

  /// Whether the text is written in the requested language's script.
  final bool isPure;

  /// Number of Arabic-script letters counted across every inspected string.
  final int arabicLetters;

  /// Number of Latin-script letters counted across every inspected string.
  final int latinLetters;

  /// Letters belonging to neither script (Cyrillic, Greek, CJK, and so on).
  final int otherLetters;

  /// Why the text was refused, or `null` when [isPure] is true.
  ///
  /// Deliberately statistical: it names counts and the expected script, never
  /// a word or a sentence of the story, so it is safe to attach to a job.
  final String? failure;

  /// Total number of letters counted, ignoring digits, marks and punctuation.
  int get letters => arabicLetters + latinLetters + otherLetters;
}

/// Checks that [texts] are written in the script [language] is written in.
///
/// Defense in depth behind the prompt, not a spellchecker: it works at the
/// script level, which is exactly the failure a small model actually produces —
/// answering an Arabic request in English, sprinkling Latin words through
/// Arabic prose, or transliterating Arabic into Latin letters.
///
/// Digits (ASCII, Arabic-Indic and Eastern Arabic-Indic), whitespace,
/// punctuation and combining marks are ignored, because a page number or a
/// question mark belongs to every language equally.
///
/// For Arabic the letters must be at least [minimumScriptPurity] Arabic. For
/// English, Swedish and Somali no Arabic-script letter is accepted at all and
/// the remaining letters must be at least [minimumScriptPurity] Latin.
LanguagePurityVerdict checkLanguagePurity({
  required StoryLanguage language,
  required Iterable<String> texts,
}) {
  var arabic = 0;
  var latin = 0;
  var other = 0;
  for (final text in texts) {
    for (final rune in text.runes) {
      switch (_classify(rune)) {
        case _Script.arabic:
          arabic++;
        case _Script.latin:
          latin++;
        case _Script.other:
          other++;
        case _Script.neutral:
          break;
      }
    }
  }
  final letters = arabic + latin + other;
  if (letters == 0) {
    return LanguagePurityVerdict(
      isPure: false,
      arabicLetters: arabic,
      latinLetters: latin,
      otherLetters: other,
      failure:
          'The model answer contained no letters at all, so it cannot be '
          '${language.englishName}.',
    );
  }
  final expectsArabic = language == StoryLanguage.arabic;
  if (!expectsArabic && arabic > 0) {
    return LanguagePurityVerdict(
      isPure: false,
      arabicLetters: arabic,
      latinLetters: latin,
      otherLetters: other,
      failure:
          'The model answer mixed $arabic Arabic-script letters into '
          '${language.englishName} text.',
    );
  }
  final ownScript = expectsArabic ? arabic : latin;
  final purity = ownScript / letters;
  if (purity < minimumScriptPurity) {
    return LanguagePurityVerdict(
      isPure: false,
      arabicLetters: arabic,
      latinLetters: latin,
      otherLetters: other,
      failure:
          'Only ${(purity * 100).round()}% of the answer\'s letters are '
          '${expectsArabic ? 'Arabic' : 'Latin'} script, but the story was '
          'requested in ${language.englishName}.',
    );
  }
  return LanguagePurityVerdict(
    isPure: true,
    arabicLetters: arabic,
    latinLetters: latin,
    otherLetters: other,
  );
}

/// Script buckets one character can fall into.
enum _Script { arabic, latin, other, neutral }

/// Sorts one code point into a script bucket.
///
/// Ranges rather than Unicode tables: the bridge has no character-database
/// dependency, and the four supported languages need only "Arabic letter",
/// "Latin letter", and "something else entirely".
_Script _classify(int rune) {
  if (_isNeutral(rune)) {
    return _Script.neutral;
  }
  if (_isArabicLetter(rune)) {
    return _Script.arabic;
  }
  if (_isLatinLetter(rune)) {
    return _Script.latin;
  }
  return _Script.other;
}

/// Whether [rune] belongs to every language equally.
bool _isNeutral(int rune) {
  // Whitespace, ASCII digits, and ASCII punctuation and symbols.
  if (rune <= 0x40) {
    return true;
  }
  if (rune >= 0x5B && rune <= 0x60) {
    return true;
  }
  if (rune >= 0x7B && rune <= 0xBF) {
    return true;
  }
  // Combining diacritical marks used by Latin text.
  if (rune >= 0x0300 && rune <= 0x036F) {
    return true;
  }
  // Arabic punctuation, digits and vowel marks.
  const arabicNeutrals = <int>[0x060C, 0x061B, 0x061F, 0x0640, 0x06D4];
  if (arabicNeutrals.contains(rune)) {
    return true;
  }
  if (rune >= 0x064B && rune <= 0x065F) {
    return true;
  }
  if (rune >= 0x0660 && rune <= 0x0669) {
    return true;
  }
  if (rune == 0x0670) {
    return true;
  }
  if (rune >= 0x06D6 && rune <= 0x06ED) {
    return true;
  }
  if (rune >= 0x06F0 && rune <= 0x06F9) {
    return true;
  }
  // General punctuation, currency symbols, arrows, and emoji-ish ranges.
  if (rune >= 0x2000 && rune <= 0x2BFF) {
    return true;
  }
  if (rune >= 0xFE00 && rune <= 0xFE0F) {
    return true;
  }
  if (rune >= 0x1F000) {
    return true;
  }
  return false;
}

/// Whether [rune] is an Arabic-script letter.
bool _isArabicLetter(int rune) {
  if (rune >= 0x0620 && rune <= 0x064A) {
    return true;
  }
  if (rune >= 0x066E && rune <= 0x06D5) {
    return true;
  }
  if (rune >= 0x06EE && rune <= 0x06FF) {
    return true;
  }
  // Arabic Supplement and Extended-A.
  if (rune >= 0x0750 && rune <= 0x08FF) {
    return true;
  }
  // Presentation Forms-A and Forms-B, which shaped text is made of.
  if (rune >= 0xFB50 && rune <= 0xFDFF) {
    return true;
  }
  if (rune >= 0xFE70 && rune <= 0xFEFC) {
    return true;
  }
  return false;
}

/// Whether [rune] is a Latin-script letter.
bool _isLatinLetter(int rune) {
  if (rune >= 0x41 && rune <= 0x5A) {
    return true;
  }
  if (rune >= 0x61 && rune <= 0x7A) {
    return true;
  }
  // Latin-1 Supplement letters, Latin Extended-A and Extended-B, minus the
  // multiplication and division signs already treated as neutral.
  if (rune >= 0x00C0 && rune <= 0x024F) {
    return rune != 0x00D7 && rune != 0x00F7;
  }
  // Latin Extended Additional, which carries the rest of the accented forms.
  if (rune >= 0x1E00 && rune <= 0x1EFF) {
    return true;
  }
  return false;
}
