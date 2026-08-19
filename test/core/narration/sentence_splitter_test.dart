import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/narration/sentence_splitter.dart';

/// Verifies that a page is divided the way narration should read it aloud.
void main() {
  test('an English page is split on every terminator', () {
    const page = 'Miko woke up. Was the garden awake? Yes! Off she went.';

    expect(splitIntoSentences(page), <String>[
      'Miko woke up.',
      'Was the garden awake?',
      'Yes!',
      'Off she went.',
    ]);
  });

  test('an Arabic page is split on the Arabic question mark', () {
    const page = 'استيقظ عبّاس. هل الحديقة مستيقظة؟ نعم! ثم انطلق.';

    expect(splitIntoSentences(page), <String>[
      'استيقظ عبّاس.',
      'هل الحديقة مستيقظة؟',
      'نعم!',
      'ثم انطلق.',
    ]);
  });

  test('a run of terminators stays with the sentence that owns it', () {
    const page = 'Wait... the door opened!? Then it closed…';

    expect(splitIntoSentences(page), <String>[
      'Wait...',
      'the door opened!?',
      'Then it closed…',
    ]);
  });

  test('a line break ends a sentence even without a terminator', () {
    const page = 'A song for the night\nA whisper for the day.';

    expect(splitIntoSentences(page), <String>[
      'A song for the night',
      'A whisper for the day.',
    ]);
  });

  test('a page with one sentence stays one utterance', () {
    expect(splitIntoSentences('  The moon garden glowed.  '), <String>[
      'The moon garden glowed.',
    ]);
  });

  test('empty and blank pages produce nothing to speak', () {
    expect(splitIntoSentences(''), isEmpty);
    expect(splitIntoSentences('   \n  \n'), isEmpty);
    expect(splitIntoSentences('...'), <String>['...']);
  });

  test('located sentences point at the original characters', () {
    const page = 'One. Two.';
    final sentences = locateNarrationSentences(page);

    expect(sentences.length, 2);
    expect(page.substring(sentences[1].start, sentences[1].end), 'Two.');
    expect(sentences[0].start, 0);
    expect(sentences[0].end, 4);
  });
}
