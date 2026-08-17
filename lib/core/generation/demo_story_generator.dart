import 'package:miko_hero/core/generation/story_generator.dart';
import 'package:miko_hero/core/models/app_language.dart';
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
    await Future<void>.delayed(latency);
    final script = _scriptFor(request);
    final pageTexts = script.pages.take(request.presentation.length.pageCount);
    final pages = _numberPages(pageTexts, request.theme);
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
  List<StoryPage> _numberPages(Iterable<String> texts, String theme) {
    return texts.indexed
        .map((entry) {
          final pageNumber = entry.$1 + 1;
          return StoryPage(
            number: pageNumber,
            text: entry.$2,
            sceneDescription: '$theme — illustrated scene $pageNumber',
          );
        })
        .toList(growable: false);
  }

  /// Creates the English demo script from parent-authored details.
  _DemoScript _englishScript(StoryRequest request) {
    final name = request.heroName;
    return _DemoScript('${request.theme}: $name\'s Adventure', <String>[
      '$name discovered a secret path leading toward ${request.theme}.',
      'She stepped forward with a curious heart and a very brave smile.',
      'A small new friend needed help finding the way through the unfamiliar world.',
      '$name listened carefully and remembered the importance of ${request.moral}.',
      'Together they solved a puzzle that neither of them could solve alone.',
      'The path glowed brighter each time $name made a kind choice.',
      'A sudden challenge tested her courage, but she did not give up.',
      '$name shared what she had learned, and the whole world began to shine.',
      'Her new friend thanked her for turning a difficult day into an adventure.',
      '$name returned home knowing that ${request.moral} can change any story.',
    ]);
  }

  /// Creates the Arabic demo script from parent-authored details.
  _DemoScript _arabicScript(StoryRequest request) {
    final name = request.heroName;
    return _DemoScript('${request.theme}: مغامرة $name', <String>[
      'اكتشفت $name طريقًا سريًا يقود إلى ${request.theme}.',
      'تقدمت بقلب فضولي وابتسامة مليئة بالشجاعة.',
      'وجدت صديقًا صغيرًا يحتاج إلى مساعدتها في هذا العالم الجديد.',
      'استمعت $name بعناية وتذكرت أهمية ${request.moral}.',
      'تعاونا معًا وحلا لغزًا لم يستطع أي منهما حله وحده.',
      'كان الطريق يزداد نورًا كلما اختارت $name فعلًا لطيفًا.',
      'ظهر تحدٍ مفاجئ اختبر شجاعتها، لكنها لم تستسلم.',
      'شاركت $name ما تعلمته، فبدأ العالم كله يتلألأ.',
      'شكرها صديقها لأنها حولت يومًا صعبًا إلى مغامرة جميلة.',
      'عادت $name إلى بيتها وهي تعرف أن ${request.moral} يغير أي قصة.',
    ]);
  }

  /// Creates the Swedish demo script from parent-authored details.
  _DemoScript _swedishScript(StoryRequest request) {
    final name = request.heroName;
    return _DemoScript('${request.theme}: ${name}s äventyr', <String>[
      '$name upptäckte en hemlig stig som ledde till ${request.theme}.',
      'Hon gick vidare med nyfiket hjärta och ett mycket modigt leende.',
      'En liten ny vän behövde hjälp att hitta genom den främmande världen.',
      '$name lyssnade noga och mindes vikten av ${request.moral}.',
      'Tillsammans löste de en gåta som ingen av dem klarade ensam.',
      'Stigen lyste starkare varje gång $name gjorde ett vänligt val.',
      'En plötslig utmaning prövade hennes mod, men hon gav inte upp.',
      '$name delade med sig av det hon lärt sig och hela världen började glittra.',
      'Hennes nya vän tackade henne för att hon förvandlat dagen till ett äventyr.',
      '$name kom hem och visste att ${request.moral} kan förändra varje berättelse.',
    ]);
  }

  /// Creates the Somali demo script from parent-authored details.
  _DemoScript _somaliScript(StoryRequest request) {
    final name = request.heroName;
    return _DemoScript('${request.theme}: Tacaburkii $name', <String>[
      '$name waxay heshay waddo qarsoon oo u socota ${request.theme}.',
      'Waxay hore ugu dhaqaaqday qalbi xiisaynaya iyo dhoolla-caddayn geesinimo leh.',
      'Saaxiib yar oo cusub ayaa u baahday caawimo si uu jidka u helo.',
      '$name si taxaddar leh ayay u dhagaysatay, waxayna xasuusatay ${request.moral}.',
      'Iyagoo wadajira ayay xalliyeen halxiraale uusan midkood keligiis xallin karin.',
      'Waddadu way sii iftiimaysay mar kasta oo $name ay dooratay fal wanaagsan.',
      'Caqabad lama filaan ah ayaa tijaabisay geesinimadeeda, laakiin ma quusan.',
      '$name waxay la wadaagtay wixii ay baratay, adduunkiina wuu iftiimay.',
      'Saaxiibkeed cusub ayaa uga mahadceliyay tacaburka quruxda badan.',
      '$name guriga ayay ku soo noqotay iyadoo og in ${request.moral} ay sheeko beddeli karto.',
    ]);
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
