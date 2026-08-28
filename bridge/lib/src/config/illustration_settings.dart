import 'package:iam_hero_bridge/src/illustration/comfyui_client.dart';

/// Square edges an illustration may be rendered at.
///
/// SD 1.5 was trained at 512x512 and drifts into duplicated limbs and second
/// heads well before 704; a 4 GB card has little headroom above it either.
/// The three accepted values are the ones that stay inside both limits.
const List<int> supportedIllustrationImageSizes = <int>[512, 576, 640];

/// Largest number of LoRAs one chain may hold.
///
/// Not a VRAM limit — LoRAs are small — but a bookkeeping one: the workflow
/// builder reserves a fixed band of node ids per chain, and eight stacked
/// style LoRAs already fight each other into mud.
const int maximumIllustrationLoraCount = 8;

/// Bytes one pixel of a rendered page contributes to its PNG, worst case.
///
/// ComfyUI saves a decoded image as an 8-bit RGB PNG, so three channels is
/// the whole picture; there is no alpha channel on a page.
const int _pngBytesPerPixel = 3;

/// Fixed byte allowance for PNG headers, chunk framing and CRCs.
const int _pngOverheadBytes = 4096;

/// Worst-case encoded size of a square [edge]-pixel RGB PNG.
///
/// A PNG row is one filter byte plus its pixels, and deflate on
/// incompressible data expands rather than shrinks — by well under one
/// percent, which is the margin added here. Real illustrations compress far
/// below this; the point of the number is that nothing can exceed it.
int worstCaseSquarePngBytes(int edge) {
  final raw = edge * (1 + edge * _pngBytesPerPixel);
  return raw + raw ~/ 100 + _pngOverheadBytes;
}

/// Largest square edge whose PNG is guaranteed to fit inside [maxBytes].
int largestSquarePngEdgeWithin(int maxBytes) {
  var low = 0;
  // Far above anything SD 1.5 plus a 4x upscaler can produce, so the search
  // is always bounded by the byte budget rather than by this ceiling.
  var high = 8192;
  while (low < high) {
    final middle = (low + high + 1) ~/ 2;
    if (worstCaseSquarePngBytes(middle) <= maxBytes) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  return low;
}

/// Largest square image the bridge can actually download from ComfyUI.
///
/// Derived from [maxComfyUiImageBytes] rather than written down beside it, so
/// lowering that cap automatically starts refusing the configurations it can
/// no longer carry instead of failing every page at download time.
final int maximumDownloadableIllustrationSize = largestSquarePngEdgeWithin(
  maxComfyUiImageBytes,
);

/// One LoRA in the illustration model chain.
class IllustrationLora {
  /// Creates a LoRA entry from validated values.
  const IllustrationLora({required this.name, required this.strength});

  /// Smallest accepted LoRA strength: zero, which applies nothing.
  static const double minimumStrength = 0.0;

  /// Largest accepted LoRA strength.
  ///
  /// Above roughly 1.5 a style LoRA stops decorating the checkpoint and
  /// starts overwriting it, which produces artefacts rather than a style.
  static const double maximumStrength = 1.5;

  /// File name of the LoRA inside ComfyUI's `models/loras` folder.
  final String name;

  /// How strongly the LoRA is applied, to the model and the CLIP alike.
  final double strength;

  /// Serializes this entry into the JSON shape the config file holds.
  Map<String, Object> toJson() {
    return <String, Object>{'name': name, 'strength': strength};
  }
}

/// Whether and how a rendered page is enlarged after decoding.
class IllustrationUpscaleSettings {
  /// Creates upscale settings from validated values.
  const IllustrationUpscaleSettings({
    this.enabled = false,
    this.model = defaultModel,
    this.targetSize = defaultTargetSize,
  });

  /// Default upscale model file name.
  ///
  /// Only ever used when [enabled] is set; the file has to exist in
  /// ComfyUI's `models/upscale_models` folder before it means anything.
  static const String defaultModel = 'RealESRGAN_x4plus_anime_6B.pth';

  /// Default square edge the enlarged page is resized back down to.
  static const int defaultTargetSize = 1024;

  /// Smallest accepted target size, in pixels.
  static const int minimumTargetSize = 512;

  /// Largest accepted target size, in pixels.
  ///
  /// The upscale pass is bounded by policy as well as by the download cap:
  /// beyond 2048 a page costs more time and disk than a picture book page
  /// is worth on any screen this app is read on.
  static const int maximumTargetSize = 2048;

  /// Whether the upscale pass runs at all. Off by default.
  final bool enabled;

  /// Upscale model file name passed to `UpscaleModelLoader`.
  final String model;

  /// Square edge the upscaled page is resized to before it is saved.
  ///
  /// The ESRGAN models multiply by four, so a 512 render becomes 2048 and is
  /// then scaled to this value — 1024 by default.
  final int targetSize;

  /// Serializes these settings into the JSON shape the config file holds.
  Map<String, Object> toJson() {
    return <String, Object>{
      'enabled': enabled,
      'model': model,
      'targetSize': targetSize,
    };
  }
}

/// Whether and how faces are re-rendered at full resolution after the page.
class IllustrationFaceDetailSettings {
  /// Creates face-detail settings from validated values.
  const IllustrationFaceDetailSettings({
    this.enabled = false,
    this.detector = defaultDetector,
    this.denoise = defaultDenoise,
  });

  /// Default Ultralytics detector model, as `UltralyticsDetectorProvider`
  /// names it inside ComfyUI's `models/ultralytics` folder.
  static const String defaultDetector = 'bbox/face_yolov8m.pt';

  /// Default share of the detected face the pass repaints.
  static const double defaultDenoise = 0.45;

  /// Whether the face-detail pass runs at all. Off by default.
  ///
  /// It needs the ComfyUI-Impact-Pack custom nodes, which are not part of a
  /// stock ComfyUI install, so "off" is the only honest default.
  final bool enabled;

  /// Detector model name passed to `UltralyticsDetectorProvider`.
  final String detector;

  /// How much of the detected face the detailer repaints.
  ///
  /// Low values sharpen the face that is already there; high values invent a
  /// new one that no longer matches the rest of the page. Zero is refused
  /// because a pass that repaints nothing is a pass that should be off.
  final double denoise;

  /// Serializes these settings into the JSON shape the config file holds.
  Map<String, Object> toJson() {
    return <String, Object>{
      'enabled': enabled,
      'detector': detector,
      'denoise': denoise,
    };
  }
}

/// Everything about rendering that the parent's PC may configure.
///
/// Every field is optional in the file and defaults to the value the bridge
/// shipped with, so a configuration written before this section existed keeps
/// rendering exactly what it rendered before.
class IllustrationSettings {
  /// Creates illustration settings from validated values.
  const IllustrationSettings({
    this.checkpoint = defaultCheckpoint,
    this.imageSize = defaultImageSize,
    this.samplerSteps = defaultSamplerSteps,
    this.cfgScale = defaultCfgScale,
    this.ipAdapterWeight = defaultIpAdapterWeight,
    this.referenceDenoise = defaultReferenceDenoise,
    this.loras = const <IllustrationLora>[],
    this.upscale = const IllustrationUpscaleSettings(),
    this.faceDetail = const IllustrationFaceDetailSettings(),
  });

  /// The settings an untouched configuration file resolves to.
  static const IllustrationSettings defaults = IllustrationSettings();

  /// Default Stable Diffusion 1.5 checkpoint every illustration comes from.
  ///
  /// SD 1.5 is not a style choice, it is the only family that fits: 4 GB of
  /// VRAM cannot hold an SDXL checkpoint plus a face adapter. Any SD 1.5
  /// fine-tune can be named here instead; the architecture is what is fixed.
  static const String defaultCheckpoint =
      'v1-5-pruned-emaonly-fp16.safetensors';

  /// Default square edge of every rendered illustration, in pixels.
  static const int defaultImageSize = 512;

  /// Default sampling steps per image: enough for clean line work, few
  /// enough to keep a ten-page book inside a bedtime-sized wait.
  static const int defaultSamplerSteps = 24;

  /// Smallest accepted number of sampling steps.
  static const int minimumSamplerSteps = 1;

  /// Largest accepted number of sampling steps.
  ///
  /// Past sixty an SD 1.5 sampler has long since converged and the extra
  /// minutes buy nothing but a longer wait for the page.
  static const int maximumSamplerSteps = 60;

  /// Default classifier-free guidance scale.
  static const double defaultCfgScale = 7.0;

  /// Smallest accepted guidance scale.
  static const double minimumCfgScale = 1.0;

  /// Largest accepted guidance scale; beyond this SD 1.5 burns colours out.
  static const double maximumCfgScale = 15.0;

  /// Default strength of the reference face adapter.
  ///
  /// Deliberately below 1.0: at full weight the adapter drags every page
  /// towards the photo's pose and lighting and the illustration stops looking
  /// drawn. Around two thirds keeps the face recognizable while the picture
  /// stays a picture-book picture.
  static const double defaultIpAdapterWeight = 0.65;

  /// Largest accepted face-adapter weight.
  static const double maximumIpAdapterWeight = 1.5;

  /// Default share of the reference photo the stylization pass repaints.
  ///
  /// This is the whole tradeoff of stage one in one number. Lower values keep
  /// more of the real child — and more of the photograph: its lighting, its
  /// texture, its expression, which is exactly what dragged pages towards
  /// distorted photorealism when the raw photo was used as the reference.
  /// Higher values cartoonify harder and start inventing a different child.
  /// 0.62 is the value that was validated on real photos: unmistakably drawn,
  /// still recognizably the same face.
  static const double defaultReferenceDenoise = 0.62;

  /// Checkpoint file name loaded by `CheckpointLoaderSimple`.
  final String checkpoint;

  /// Square edge every page and every reference portrait is rendered at.
  final int imageSize;

  /// Sampling steps per image.
  final int samplerSteps;

  /// Classifier-free guidance scale of every sampler in both graphs.
  final double cfgScale;

  /// How strongly the reference face steers a page.
  final double ipAdapterWeight;

  /// How much of the reference photo the stylization pass repaints.
  final double referenceDenoise;

  /// LoRAs applied on top of [checkpoint], in the order they are chained.
  ///
  /// Empty by default, which is what makes an untouched configuration render
  /// the plain checkpoint exactly as before.
  final List<IllustrationLora> loras;

  /// Whether and how a page is enlarged after decoding.
  final IllustrationUpscaleSettings upscale;

  /// Whether and how faces are re-rendered after the page.
  final IllustrationFaceDetailSettings faceDetail;

  /// Square edge of the image that actually reaches the library.
  ///
  /// The upscale pass is the only thing that changes it; without it a page
  /// leaves ComfyUI at the size it was sampled at.
  int get outputImageSize => upscale.enabled ? upscale.targetSize : imageSize;

  /// Serializes these settings into the JSON shape the config file holds.
  Map<String, Object> toJson() {
    return <String, Object>{
      'checkpoint': checkpoint,
      'imageSize': imageSize,
      'samplerSteps': samplerSteps,
      'cfgScale': cfgScale,
      'ipAdapterWeight': ipAdapterWeight,
      'referenceDenoise': referenceDenoise,
      'loras': <Object>[for (final lora in loras) lora.toJson()],
      'upscale': upscale.toJson(),
      'faceDetail': faceDetail.toJson(),
    };
  }

  /// Validates and parses the optional `illustration` section of a config.
  ///
  /// A missing section, and every missing field inside one, resolves to the
  /// value the bridge shipped with. Anything present but wrong — an unknown
  /// key, a wrong type, a value outside its documented range, or a size the
  /// image download cap could not carry — throws a [FormatException] naming
  /// the exact field, because a rendering setting that was silently ignored
  /// is a book that quietly came out wrong.
  ///
  /// [maxDownloadBytes] is the ceiling the finished page has to fit inside;
  /// it defaults to the one the ComfyUI client enforces and is a parameter
  /// only so a test can prove the refusal without a 16 MB image.
  factory IllustrationSettings.fromJson(
    Map<String, Object?> json, {
    int maxDownloadBytes = maxComfyUiImageBytes,
  }) {
    _rejectUnknownKeys(json, const <String>{
      'checkpoint',
      'imageSize',
      'samplerSteps',
      'cfgScale',
      'ipAdapterWeight',
      'referenceDenoise',
      'loras',
      'upscale',
      'faceDetail',
    }, 'illustration');

    final settings = IllustrationSettings(
      checkpoint:
          _readNonEmptyString(json, 'checkpoint', 'illustration.checkpoint') ??
          defaultCheckpoint,
      imageSize: _readChoice(
        json,
        'imageSize',
        'illustration.imageSize',
        supportedIllustrationImageSizes,
        defaultImageSize,
      ),
      samplerSteps: _readBoundedInt(
        json,
        'samplerSteps',
        'illustration.samplerSteps',
        minimum: minimumSamplerSteps,
        maximum: maximumSamplerSteps,
        fallback: defaultSamplerSteps,
      ),
      cfgScale: _readBoundedDouble(
        json,
        'cfgScale',
        'illustration.cfgScale',
        minimum: minimumCfgScale,
        maximum: maximumCfgScale,
        fallback: defaultCfgScale,
      ),
      ipAdapterWeight: _readBoundedDouble(
        json,
        'ipAdapterWeight',
        'illustration.ipAdapterWeight',
        minimum: 0.0,
        maximum: maximumIpAdapterWeight,
        fallback: defaultIpAdapterWeight,
      ),
      referenceDenoise: _readBoundedDouble(
        json,
        'referenceDenoise',
        'illustration.referenceDenoise',
        // A denoise of zero repaints nothing and hands the face adapter the
        // photograph itself, which is the one output this pass exists to
        // prevent, so the lower bound is exclusive.
        minimum: 0.0,
        minimumIsExclusive: true,
        maximum: 1.0,
        fallback: defaultReferenceDenoise,
      ),
      loras: _readLoras(json),
      upscale: _readUpscale(json),
      faceDetail: _readFaceDetail(json),
    );

    final int output = settings.outputImageSize;
    final int largest = largestSquarePngEdgeWithin(maxDownloadBytes);
    if (output > largest) {
      throw FormatException(
        'Bridge config section "illustration" asks for ${output}x$output '
        'pages, which can exceed the ${maxDownloadBytes ~/ 1024} KB limit on '
        'a downloaded image; at most ${largest}x$largest fits.',
      );
    }
    return settings;
  }

  static List<IllustrationLora> _readLoras(Map<String, Object?> json) {
    final value = json['loras'];
    if (value == null) {
      return const <IllustrationLora>[];
    }
    if (value is! List<Object?>) {
      throw const FormatException(
        'Bridge config field "illustration.loras" must be a list of '
        '{"name": …, "strength": …} objects.',
      );
    }
    if (value.length > maximumIllustrationLoraCount) {
      throw FormatException(
        'Bridge config field "illustration.loras" holds ${value.length} '
        'entries; at most $maximumIllustrationLoraCount are supported.',
      );
    }
    final loras = <IllustrationLora>[];
    for (var index = 0; index < value.length; index++) {
      final path = 'illustration.loras[$index]';
      final entry = value[index];
      if (entry is! Map<String, Object?>) {
        throw FormatException(
          'Bridge config field "$path" must be a JSON object with "name" '
          'and "strength".',
        );
      }
      _rejectUnknownKeys(entry, const <String>{'name', 'strength'}, path);
      final name = _readNonEmptyString(entry, 'name', '$path.name');
      if (name == null) {
        throw FormatException('Bridge config field "$path.name" is required.');
      }
      loras.add(
        IllustrationLora(
          name: name,
          strength: _readBoundedDouble(
            entry,
            'strength',
            '$path.strength',
            minimum: IllustrationLora.minimumStrength,
            maximum: IllustrationLora.maximumStrength,
          ),
        ),
      );
    }
    return List<IllustrationLora>.unmodifiable(loras);
  }

  static IllustrationUpscaleSettings _readUpscale(Map<String, Object?> json) {
    final section = _readSection(json, 'upscale', 'illustration.upscale');
    if (section == null) {
      return const IllustrationUpscaleSettings();
    }
    _rejectUnknownKeys(section, const <String>{
      'enabled',
      'model',
      'targetSize',
    }, 'illustration.upscale');
    return IllustrationUpscaleSettings(
      enabled: _readBool(
        section,
        'enabled',
        'illustration.upscale.enabled',
        fallback: false,
      ),
      model:
          _readNonEmptyString(section, 'model', 'illustration.upscale.model') ??
          IllustrationUpscaleSettings.defaultModel,
      targetSize: _readBoundedInt(
        section,
        'targetSize',
        'illustration.upscale.targetSize',
        minimum: IllustrationUpscaleSettings.minimumTargetSize,
        maximum: IllustrationUpscaleSettings.maximumTargetSize,
        fallback: IllustrationUpscaleSettings.defaultTargetSize,
      ),
    );
  }

  static IllustrationFaceDetailSettings _readFaceDetail(
    Map<String, Object?> json,
  ) {
    final section = _readSection(json, 'faceDetail', 'illustration.faceDetail');
    if (section == null) {
      return const IllustrationFaceDetailSettings();
    }
    _rejectUnknownKeys(section, const <String>{
      'enabled',
      'detector',
      'denoise',
    }, 'illustration.faceDetail');
    return IllustrationFaceDetailSettings(
      enabled: _readBool(
        section,
        'enabled',
        'illustration.faceDetail.enabled',
        fallback: false,
      ),
      detector:
          _readNonEmptyString(
            section,
            'detector',
            'illustration.faceDetail.detector',
          ) ??
          IllustrationFaceDetailSettings.defaultDetector,
      denoise: _readBoundedDouble(
        section,
        'denoise',
        'illustration.faceDetail.denoise',
        minimum: 0.0,
        minimumIsExclusive: true,
        maximum: 1.0,
        fallback: IllustrationFaceDetailSettings.defaultDenoise,
      ),
    );
  }

  static void _rejectUnknownKeys(
    Map<String, Object?> json,
    Set<String> known,
    String path,
  ) {
    for (final key in json.keys) {
      if (!known.contains(key)) {
        throw FormatException(
          'Bridge config section "$path" has no setting named "$key". '
          'Known settings: ${(known.toList()..sort()).join(', ')}.',
        );
      }
    }
  }

  static Map<String, Object?>? _readSection(
    Map<String, Object?> json,
    String key,
    String path,
  ) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! Map<String, Object?>) {
      throw FormatException('Bridge config field "$path" must be an object.');
    }
    return value;
  }

  static String? _readNonEmptyString(
    Map<String, Object?> json,
    String key,
    String path,
  ) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'Bridge config field "$path" must be a non-empty string.',
      );
    }
    return value.trim();
  }

  static bool _readBool(
    Map<String, Object?> json,
    String key,
    String path, {
    required bool fallback,
  }) {
    final value = json[key];
    if (value == null) {
      return fallback;
    }
    if (value is! bool) {
      throw FormatException(
        'Bridge config field "$path" must be true or false.',
      );
    }
    return value;
  }

  static int _readChoice(
    Map<String, Object?> json,
    String key,
    String path,
    List<int> allowed,
    int fallback,
  ) {
    final value = json[key];
    if (value == null) {
      return fallback;
    }
    if (value is! int || !allowed.contains(value)) {
      throw FormatException(
        'Bridge config field "$path" must be one of ${allowed.join(', ')}.',
      );
    }
    return value;
  }

  static int _readBoundedInt(
    Map<String, Object?> json,
    String key,
    String path, {
    required int minimum,
    required int maximum,
    required int fallback,
  }) {
    final value = json[key];
    if (value == null) {
      return fallback;
    }
    if (value is! int || value < minimum || value > maximum) {
      throw FormatException(
        'Bridge config field "$path" must be an integer between $minimum '
        'and $maximum.',
      );
    }
    return value;
  }

  /// Reads one bounded number, accepting the JSON integer spelling of it.
  ///
  /// `7` and `7.0` are the same number in a configuration file, so an integer
  /// is widened; anything that is not a number at all is refused rather than
  /// parsed out of a string. A null [fallback] marks the field as required.
  static double _readBoundedDouble(
    Map<String, Object?> json,
    String key,
    String path, {
    required double minimum,
    required double maximum,
    double? fallback,
    bool minimumIsExclusive = false,
  }) {
    final value = json[key];
    if (value == null) {
      if (fallback == null) {
        throw FormatException('Bridge config field "$path" is required.');
      }
      return fallback;
    }
    final double? number = value is int
        ? value.toDouble()
        : (value is double ? value : null);
    if (number == null ||
        number > maximum ||
        (minimumIsExclusive ? number <= minimum : number < minimum)) {
      throw FormatException(
        'Bridge config field "$path" must be a number '
        '${minimumIsExclusive ? 'above' : 'between'} $minimum '
        '${minimumIsExclusive ? 'and up to' : 'and'} $maximum.',
      );
    }
    return number;
  }
}
