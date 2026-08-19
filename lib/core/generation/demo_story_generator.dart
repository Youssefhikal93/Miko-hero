import 'package:miko_hero/core/generation/story_generator.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Local sample generator used only until Ollama and ComfyUI are connected.
class DemoStoryGenerator implements StoryGenerator {
  /// Creates a demo generator with visible latency and an injectable clock.
  const DemoStoryGenerator({required this.latency, required this.currentTime});

  /// Delay that keeps generation progress perceivable in the real app.
  final Duration latency;

  /// Clock used to create stable story identifiers and timestamps.
  final DateTime Function() currentTime;

  @override
  /// Builds an explicitly marked sample without pretending to call local AI.
  Future<StoryBook> generate(StoryRequest request) async {
    if (!request.gender.isSpecified) {
      throw ArgumentError.value(request.gender, 'request.gender');
    }
    await Future<void>.delayed(latency);
    final script = _scriptFor(request);
    final pageTexts = script.pages.take(request.presentation.length.pageCount);
    final pages = _numberPages(pageTexts, request);
    final createdAt = currentTime().toUtc();
    return StoryBook(
      id: createdAt.microsecondsSinceEpoch.toString(),
      createdAt: createdAt,
      content: StoryContent(
        title: script.title,
        request: request,
        pages: pages,
      ),
    );
  }

  /// Chooses a script that never crosses the requested language boundary.
  _DemoScript _scriptFor(StoryRequest request) {
    return switch (request.presentation.language) {
      AppLanguage.english => _englishScript(request),
      AppLanguage.arabic => _arabicScript(request),
      AppLanguage.swedish => _swedishScript(request),
      AppLanguage.somali => _somaliScript(request),
    };
  }

  /// Adds stable page numbers and future illustration directions.
  List<StoryPage> _numberPages(Iterable<String> texts, StoryRequest request) {
    final setting = _storySetting(request);
    final favoriteThings = request.prompt.preferences.favoriteThings;
    final inspiration = favoriteThings.isEmpty
        ? ''
        : ' — favorite things: $favoriteThings';
    return texts.indexed
        .map((entry) {
          final pageNumber = entry.$1 + 1;
          return StoryPage(
            number: pageNumber,
            text: entry.$2,
            sceneDescription:
                '$setting$inspiration — ${request.gender.name} hero — illustrated scene $pageNumber',
          );
        })
        .toList(growable: false);
  }

  /// Creates the English demo script from parent-authored details.
  _DemoScript _englishScript(StoryRequest request) {
    final name = request.heroName;
    final setting = _storySetting(request);
    final favoriteThings = request.prompt.preferences.favoriteThings;
    final voice = request.gender == ChildGender.girl
        ? (
            subject: 'She',
            subjectLower: 'she',
            possessive: 'her',
            possessiveUpper: 'Her',
          )
        : (
            subject: 'He',
            subjectLower: 'he',
            possessive: 'his',
            possessiveUpper: 'His',
          );
    return _DemoScript('$setting: $name\'s Adventure', <String>[
      '$name discovered a secret path leading toward $setting.',
      '${voice.subject} stepped forward with a curious heart and a very brave smile.',
      favoriteThings.isEmpty
          ? 'A small new friend needed help finding the way through the unfamiliar world.'
          : '$name found a helpful clue among $favoriteThings and shared it with a new friend.',
      '$name listened carefully and remembered the importance of ${request.moral}.',
      'Together they solved a puzzle that neither of them could solve alone.',
      'The path glowed brighter each time $name made a kind choice.',
      'A sudden challenge tested ${voice.possessive} courage, but ${voice.subjectLower} did not give up.',
      '$name shared what ${voice.subjectLower} had learned, and the whole world began to shine.',
      '${voice.possessiveUpper} new friend gave thanks for turning a difficult day into an adventure.',
      '$name returned home knowing that ${request.moral} can change any story.',
    ]);
  }

  /// Creates the Arabic demo script from parent-authored details.
  _DemoScript _arabicScript(StoryRequest request) {
    final name = request.heroName;
    final setting = _storySetting(request);
    final favoriteThings = request.prompt.preferences.favoriteThings;
    final voice = request.gender == ChildGender.girl
        ? (
            discovered: 'اكتشفت',
            advanced: 'تقدمت',
            found: 'وجدت',
            help: 'مساعدتها',
            listened: 'استمعت',
            remembered: 'وتذكرت',
            chose: 'اختارت',
            courage: 'شجاعتها',
            resisted: 'لكنها لم تستسلم',
            shared: 'شاركت',
            learned: 'تعلمته',
            thanked: 'شكرها صديقها',
            changed: 'حولت',
            returned: 'عادت',
            knows: 'وهي تعرف',
          )
        : (
            discovered: 'اكتشف',
            advanced: 'تقدم',
            found: 'وجد',
            help: 'مساعدته',
            listened: 'استمع',
            remembered: 'وتذكر',
            chose: 'اختار',
            courage: 'شجاعته',
            resisted: 'لكنه لم يستسلم',
            shared: 'شارك',
            learned: 'تعلمه',
            thanked: 'شكره صديقه',
            changed: 'حول',
            returned: 'عاد',
            knows: 'وهو يعرف',
          );
    return _DemoScript('$setting: مغامرة $name', <String>[
      '${voice.discovered} $name طريقًا سريًا يقود إلى $setting.',
      '${voice.advanced} بقلب فضولي وابتسامة مليئة بالشجاعة.',
      favoriteThings.isEmpty
          ? '${voice.found} صديقًا صغيرًا يحتاج إلى ${voice.help} في هذا العالم الجديد.'
          : '${voice.found} $name دليلاً مفيدًا بين $favoriteThings وساعد ذلك في العثور على الطريق.',
      '${voice.listened} $name بعناية ${voice.remembered} أهمية ${request.moral}.',
      'تعاونا معًا وحلا لغزًا لم يستطع أي منهما حله وحده.',
      'كان الطريق يزداد نورًا كلما ${voice.chose} $name فعلًا لطيفًا.',
      'ظهر تحدٍ مفاجئ اختبر ${voice.courage}، ${voice.resisted}.',
      '${voice.shared} $name ما ${voice.learned}، فبدأ العالم كله يتلألأ.',
      '${voice.thanked} لأن $name ${voice.changed} يومًا صعبًا إلى مغامرة جميلة.',
      '${voice.returned} $name إلى البيت ${voice.knows} أن ${request.moral} يغير أي قصة.',
    ]);
  }

  /// Creates the Swedish demo script from parent-authored details.
  _DemoScript _swedishScript(StoryRequest request) {
    final name = request.heroName;
    final setting = _storySetting(request);
    final favoriteThings = request.prompt.preferences.favoriteThings;
    final voice = request.gender == ChildGender.girl
        ? (
            subject: 'Hon',
            subjectLower: 'hon',
            possessive: 'hennes',
            object: 'henne',
          )
        : (
            subject: 'Han',
            subjectLower: 'han',
            possessive: 'hans',
            object: 'honom',
          );
    return _DemoScript('$setting: ${name}s äventyr', <String>[
      '$name upptäckte en hemlig stig som ledde till $setting.',
      '${voice.subject} gick vidare med nyfiket hjärta och ett mycket modigt leende.',
      favoriteThings.isEmpty
          ? 'En liten ny vän behövde hjälp att hitta genom den främmande världen.'
          : '$name hittade en ledtråd bland $favoriteThings och delade den med en ny vän.',
      '$name lyssnade noga och mindes vikten av ${request.moral}.',
      'Tillsammans löste de en gåta som ingen av dem klarade ensam.',
      'Stigen lyste starkare varje gång $name gjorde ett vänligt val.',
      'En plötslig utmaning prövade ${voice.possessive} mod, men ${voice.subjectLower} gav inte upp.',
      '$name delade med sig av det ${voice.subjectLower} lärt sig och hela världen började glittra.',
      '${voice.possessive} nya vän tackade ${voice.object} för att dagen blivit ett äventyr.',
      '$name kom hem och visste att ${request.moral} kan förändra varje berättelse.',
    ]);
  }

  /// Creates the Somali demo script from parent-authored details.
  _DemoScript _somaliScript(StoryRequest request) {
    final name = request.heroName;
    final setting = _storySetting(request);
    final favoriteThings = request.prompt.preferences.favoriteThings;
    final voice = request.gender == ChildGender.girl
        ? (
            found: 'waxay heshay',
            advanced: 'Waxay hore ugu dhaqaaqday',
            listened: 'si taxaddar leh ayay u dhagaysatay',
            remembered: 'waxayna xasuusatay',
            chose: 'ay dooratay',
            courage: 'geesinimadeeda',
            shared: 'waxay la wadaagtay wixii ay baratay',
            friend: 'Saaxiibkeed',
            returning: 'iyadoo',
            returned: 'guriga ayay ku soo noqotay',
          )
        : (
            found: 'wuxuu helay',
            advanced: 'Wuxuu hore ugu dhaqaaqay',
            listened: 'si taxaddar leh ayuu u dhagaystay',
            remembered: 'wuxuuna xasuustay',
            chose: 'uu doortay',
            courage: 'geesinimadiisa',
            shared: 'wuxuu la wadaagay wixii uu bartay',
            friend: 'Saaxiibkiis',
            returning: 'isagoo',
            returned: 'guriga ayuu ku soo noqday',
          );
    return _DemoScript('$setting: Tacaburkii $name', <String>[
      '$name ${voice.found} waddo qarsoon oo u socota $setting.',
      '${voice.advanced} qalbi xiisaynaya iyo dhoolla-caddayn geesinimo leh.',
      favoriteThings.isEmpty
          ? 'Saaxiib yar oo cusub ayaa u baahday caawimo si uu jidka u helo.'
          : '$name wuxuu tilmaam waxtar leh ka dhex helay $favoriteThings oo la wadaagay saaxiib cusub.',
      '$name ${voice.listened}, ${voice.remembered} ${request.moral}.',
      'Iyagoo wadajira ayay xalliyeen halxiraale uusan midkood keligiis xallin karin.',
      'Waddadu way sii iftiimaysay mar kasta oo $name ${voice.chose} fal wanaagsan.',
      'Caqabad lama filaan ah ayaa tijaabisay ${voice.courage}, laakiin ma quusan.',
      '$name ${voice.shared}, adduunkiina wuu iftiimay.',
      '${voice.friend} cusub ayaa uga mahadceliyay tacaburka quruxda badan.',
      '$name ${voice.returned} ${voice.returning} og in ${request.moral} ay sheeko beddeli karto.',
    ]);
  }

  /// Combines the current idea with a child's optional recurring world.
  String _storySetting(StoryRequest request) {
    final world = request.prompt.preferences.recurringWorld;
    return world.isEmpty ? request.theme : '${request.theme} · $world';
  }
}

/// Title and ordered prose used by the temporary demo generator.
class _DemoScript {
  /// Creates one language-specific script with enough pages for every length.
  const _DemoScript(this.title, this.pages);

  /// Cover title.
  final String title;

  /// Ten available page texts, truncated by the selected story length.
  final List<String> pages;
}
