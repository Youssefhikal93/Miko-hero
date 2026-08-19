/// Decorative castle drawn as the header of one child's My Kingdom page.
enum CastleStyle {
  /// Square keeps with crenellated battlements.
  classicTowers,

  /// Rounded palace domes on wide towers.
  roundDomes,

  /// Tall, faceted crystal spires.
  crystalSpires,

  /// Wooden hut nestled between forest canopies.
  forestTreehouse,
}

/// Decoration drawn around a child's reference photo.
enum AvatarFrameStyle {
  /// The plain circle used before frames existed.
  none,

  /// Small stars orbiting the photo.
  stars,

  /// Small hearts orbiting the photo.
  hearts,

  /// A laurel wreath along both sides of the photo.
  laurel,
}

/// Ambient backdrop painted behind one child's My Kingdom page.
enum KingdomBackdrop {
  /// The deep night palette the application already uses everywhere.
  nightSky,

  /// Soft green meadow light.
  meadow,

  /// Cool blue-green ocean light.
  ocean,

  /// Warm orange sunset light.
  sunset,
}

/// Small kid-friendly badge shown beside a child's hero name.
enum KingdomSymbol {
  /// A bright star.
  star,

  /// A launching rocket.
  rocket,

  /// A royal crown.
  crown,

  /// A butterfly.
  butterfly,

  /// A friendly dragon-sized creature.
  dragon,

  /// A flower in bloom.
  flower,

  /// A football.
  football,

  /// A music note.
  music,

  /// An open book.
  book,

  /// An animal paw.
  paw,

  /// A rainbow arc.
  rainbow,

  /// Sparkles of magic.
  sparkles,
}

/// One child's personalized kingdom decoration, drawn entirely in Flutter.
///
/// Every field is optional: the defaults reproduce the appearance the app had
/// before personalization existed as closely as a bounded choice set allows,
/// so a profile stored without a `kingdomTheme` never looks broken.
class KingdomTheme {
  /// Creates a decoration set, defaulting to the first choice of each group.
  const KingdomTheme({
    this.castle = CastleStyle.classicTowers,
    this.frame = AvatarFrameStyle.none,
    this.backdrop = KingdomBackdrop.nightSky,
    this.symbol = KingdomSymbol.star,
  });

  /// Castle silhouette painted at the top of My Kingdom.
  final CastleStyle castle;

  /// Decoration drawn around the child's reference photo.
  final AvatarFrameStyle frame;

  /// Ambient gradient painted behind the My Kingdom page.
  final KingdomBackdrop backdrop;

  /// Badge shown beside the hero name on My Kingdom and the library tab.
  final KingdomSymbol symbol;

  /// Converts the decoration into a JSON-compatible profile field.
  Map<String, Object> toJson() {
    return <String, Object>{
      'castle': castle.name,
      'frame': frame.name,
      'backdrop': backdrop.name,
      'symbol': symbol.name,
    };
  }

  /// Restores a decoration, defaulting each choice the payload omits.
  ///
  /// A stored name this build does not know is refused with a
  /// [FormatException] instead of silently falling back, because that value
  /// belongs to a newer schema and would be lost on the next save.
  factory KingdomTheme.fromJson(Map<String, Object?> json) {
    return KingdomTheme(
      castle: _decodeChoice(
        json['castle'],
        CastleStyle.values,
        CastleStyle.classicTowers,
        'castle style',
      ),
      frame: _decodeChoice(
        json['frame'],
        AvatarFrameStyle.values,
        AvatarFrameStyle.none,
        'avatar frame',
      ),
      backdrop: _decodeChoice(
        json['backdrop'],
        KingdomBackdrop.values,
        KingdomBackdrop.nightSky,
        'kingdom backdrop',
      ),
      symbol: _decodeChoice(
        json['symbol'],
        KingdomSymbol.values,
        KingdomSymbol.star,
        'kingdom symbol',
      ),
    );
  }

  /// Returns the same decoration with one newly chosen castle.
  KingdomTheme withCastle(CastleStyle selected) {
    return KingdomTheme(
      castle: selected,
      frame: frame,
      backdrop: backdrop,
      symbol: symbol,
    );
  }

  /// Returns the same decoration with one newly chosen photo frame.
  KingdomTheme withFrame(AvatarFrameStyle selected) {
    return KingdomTheme(
      castle: castle,
      frame: selected,
      backdrop: backdrop,
      symbol: symbol,
    );
  }

  /// Returns the same decoration with one newly chosen backdrop.
  KingdomTheme withBackdrop(KingdomBackdrop selected) {
    return KingdomTheme(
      castle: castle,
      frame: frame,
      backdrop: selected,
      symbol: symbol,
    );
  }

  /// Returns the same decoration with one newly chosen favourite symbol.
  KingdomTheme withSymbol(KingdomSymbol selected) {
    return KingdomTheme(
      castle: castle,
      frame: frame,
      backdrop: backdrop,
      symbol: selected,
    );
  }
}

/// Resolves one stored enum name, defaulting only when the field is absent.
T _decodeChoice<T extends Enum>(
  Object? encodedChoice,
  List<T> choices,
  T missingChoice,
  String label,
) {
  if (encodedChoice == null) return missingChoice;
  if (encodedChoice is! String) {
    throw FormatException('Malformed $label.');
  }
  for (final choice in choices) {
    if (choice.name == encodedChoice) return choice;
  }
  throw FormatException('Unsupported $label.');
}
