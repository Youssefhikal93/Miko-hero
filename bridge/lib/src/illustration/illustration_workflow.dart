import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';

/// Stable Diffusion 1.5 checkpoint every illustration is rendered with.
///
/// SD 1.5 is not a style choice, it is the only family that fits: 4 GB of
/// VRAM cannot hold an SDXL checkpoint plus a face adapter.
const String illustrationCheckpointName =
    'v1-5-pruned-emaonly-fp16.safetensors';

/// IPAdapter-plus **face** model used when the child has a reference photo.
const String illustrationIpAdapterName =
    'ip-adapter-plus-face_sd15.safetensors';

/// CLIP vision encoder the face adapter reads the reference photo through.
const String illustrationClipVisionName =
    'CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors';

/// Square edge of every rendered illustration, in pixels.
///
/// SD 1.5 was trained at 512x512 and a 4 GB card has no headroom above it.
const int illustrationImageSize = 512;

/// Sampling steps per image: enough for clean line work, few enough to keep
/// a ten-page book inside a bedtime-sized wait.
const int illustrationSamplerSteps = 24;

/// Classifier-free guidance scale.
const double illustrationCfgScale = 7.0;

/// Sampler and scheduler pair used for every render.
const String illustrationSamplerName = 'dpmpp_2m';

/// Noise schedule paired with [illustrationSamplerName].
const String illustrationScheduler = 'karras';

/// How strongly the reference face steers the image.
///
/// Deliberately below 1.0: at full weight the adapter drags every page
/// towards the photo's pose and lighting and the illustration stops looking
/// drawn. Around two thirds keeps the face recognizable while the picture
/// stays a picture-book picture.
const double illustrationIpAdapterWeight = 0.65;

/// Prefix of the file name ComfyUI saves each render under.
const String illustrationOutputPrefix = 'iam_hero_page';

/// The negative prompt applied to every illustration, without exception.
///
/// This is a children's book generator: the guard against frightening,
/// adult, deformed or text-covered output is not a per-request option, so it
/// is a constant rather than anything a caller can influence.
const String illustrationNegativePrompt =
    'scary, frightening, horror, creepy, nightmare, gore, blood, injury, '
    'violence, weapon, nsfw, nude, nudity, sexual, suggestive, adult content, '
    'deformed, disfigured, mutated, malformed, extra limbs, extra fingers, '
    'missing fingers, bad hands, bad anatomy, ugly, grotesque, '
    'text, words, letters, caption, subtitles, watermark, signature, logo, '
    'lowres, blurry, jpeg artifacts';

/// Art-direction prefix that gives each style its own look.
///
/// The three prefixes are deliberately disjoint — a watercolor page and a 3D
/// page must not converge on the same image just because the scene matches.
String illustrationStylePrefix(StoryIllustrationStyle style) {
  switch (style) {
    case StoryIllustrationStyle.pictureBook:
      return "gentle children's picture book illustration, soft rounded "
          'shapes, warm friendly storybook art, clean flat colors, thick '
          'confident outlines';
    case StoryIllustrationStyle.watercolor:
      return 'traditional watercolor storybook painting, soft translucent '
          'washes, visible cold-pressed paper texture, delicate wet-on-wet '
          'brush strokes, muted natural palette';
    case StoryIllustrationStyle.colorful3d:
      return 'bright colorful 3d animated film illustration, glossy '
          'dimensional characters, soft global illumination, cinematic '
          'depth of field, vivid saturated palette';
  }
}

/// How the hero is described to the model.
///
/// A reference photo carries the face, never the wording, so the Girl/Boy
/// context the parent confirmed still has to be said out loud. When no
/// context is known the hero stays simply a child.
String illustrationHeroPhrase(StoryGenderContext? gender) {
  switch (gender) {
    case StoryGenderContext.girl:
      return 'a young girl';
    case StoryGenderContext.boy:
      return 'a young boy';
    case null:
      return 'a young child';
  }
}

/// The full positive prompt for one page.
String buildIllustrationPrompt({
  required String sceneDescription,
  required StoryIllustrationStyle style,
  required StoryGenderContext? gender,
}) {
  final scene = sceneDescription.trim();
  return '${illustrationStylePrefix(style)}, '
      '${illustrationHeroPhrase(gender)} as the main character, '
      '${scene.isEmpty ? 'a quiet friendly moment from the story' : scene}, '
      'wholesome, cheerful, age-appropriate, full scene, centered composition';
}

/// Deterministic sampler seed derived from an illustration id.
///
/// Re-rendering a page must reproduce it: the parent who asks for the same
/// picture again should get the same picture, not a lottery ticket. The id
/// is a uuid, so hashing it spreads pages of one story across the seed space
/// instead of clustering them.
int illustrationSeed(String illustrationId) {
  final digest = sha256Hex(illustrationId);
  // 48 bits keeps the value comfortably inside every JSON number consumer
  // while staying far larger than the number of pages a family will render.
  return int.parse(digest.substring(0, 12), radix: 16);
}

/// Builds the complete ComfyUI node graph for one page.
///
/// Without [referenceImageName] this is a plain SD 1.5 text-to-image graph.
/// With one, the checkpoint's model output is routed through the
/// IPAdapter-plus-face chain — load the photo, encode it with CLIP vision,
/// apply the face adapter — before it reaches the sampler, which is what
/// makes the hero look like the same child on every page.
Map<String, Object?> buildIllustrationWorkflow({
  required String illustrationId,
  required String sceneDescription,
  required StoryIllustrationStyle style,
  required StoryGenderContext? gender,
  String? referenceImageName,
}) {
  final hasReference =
      referenceImageName != null && referenceImageName.trim().isNotEmpty;
  final workflow = <String, Object?>{
    checkpointNodeId: _node('CheckpointLoaderSimple', <String, Object?>{
      'ckpt_name': illustrationCheckpointName,
    }),
    positivePromptNodeId: _node('CLIPTextEncode', <String, Object?>{
      'text': buildIllustrationPrompt(
        sceneDescription: sceneDescription,
        style: style,
        gender: gender,
      ),
      'clip': <Object?>[checkpointNodeId, 1],
    }),
    negativePromptNodeId: _node('CLIPTextEncode', <String, Object?>{
      'text': illustrationNegativePrompt,
      'clip': <Object?>[checkpointNodeId, 1],
    }),
    latentNodeId: _node('EmptyLatentImage', <String, Object?>{
      'width': illustrationImageSize,
      'height': illustrationImageSize,
      'batch_size': 1,
    }),
    samplerNodeId: _node('KSampler', <String, Object?>{
      'seed': illustrationSeed(illustrationId),
      'steps': illustrationSamplerSteps,
      'cfg': illustrationCfgScale,
      'sampler_name': illustrationSamplerName,
      'scheduler': illustrationScheduler,
      'denoise': 1.0,
      'model': <Object?>[
        hasReference ? ipAdapterApplyNodeId : checkpointNodeId,
        0,
      ],
      'positive': <Object?>[positivePromptNodeId, 0],
      'negative': <Object?>[negativePromptNodeId, 0],
      'latent_image': <Object?>[latentNodeId, 0],
    }),
    decodeNodeId: _node('VAEDecode', <String, Object?>{
      'samples': <Object?>[samplerNodeId, 0],
      'vae': <Object?>[checkpointNodeId, 2],
    }),
    saveImageNodeId: _node('SaveImage', <String, Object?>{
      'filename_prefix': illustrationOutputPrefix,
      'images': <Object?>[decodeNodeId, 0],
    }),
  };

  if (hasReference) {
    workflow[referenceImageNodeId] = _node('LoadImage', <String, Object?>{
      'image': referenceImageName.trim(),
      'upload': 'image',
    });
    workflow[ipAdapterModelNodeId] = _node(
      'IPAdapterModelLoader',
      <String, Object?>{'ipadapter_file': illustrationIpAdapterName},
    );
    workflow[clipVisionNodeId] = _node('CLIPVisionLoader', <String, Object?>{
      'clip_name': illustrationClipVisionName,
    });
    workflow[ipAdapterApplyNodeId] = _node(
      'IPAdapterAdvanced',
      <String, Object?>{
        'weight': illustrationIpAdapterWeight,
        'weight_type': 'linear',
        'combine_embeds': 'concat',
        'start_at': 0.0,
        'end_at': 1.0,
        'embeds_scaling': 'V only',
        'model': <Object?>[checkpointNodeId, 0],
        'ipadapter': <Object?>[ipAdapterModelNodeId, 0],
        'image': <Object?>[referenceImageNodeId, 0],
        'clip_vision': <Object?>[clipVisionNodeId, 0],
      },
    );
  }
  return workflow;
}

/// Node id of the SD 1.5 checkpoint loader.
const String checkpointNodeId = '1';

/// Node id of the positive prompt encoder.
const String positivePromptNodeId = '2';

/// Node id of the negative prompt encoder.
const String negativePromptNodeId = '3';

/// Node id of the empty 512x512 latent.
const String latentNodeId = '4';

/// Node id of the sampler.
const String samplerNodeId = '5';

/// Node id of the VAE decoder.
const String decodeNodeId = '6';

/// Node id of the image writer; its output is what the bridge downloads.
const String saveImageNodeId = '7';

/// Node id of the reference photo loader; present only with a photo.
const String referenceImageNodeId = '8';

/// Node id of the IPAdapter model loader; present only with a photo.
const String ipAdapterModelNodeId = '9';

/// Node id of the CLIP vision loader; present only with a photo.
const String clipVisionNodeId = '10';

/// Node id of the face adapter application; present only with a photo.
const String ipAdapterApplyNodeId = '11';

Map<String, Object?> _node(String classType, Map<String, Object?> inputs) {
  return <String, Object?>{'class_type': classType, 'inputs': inputs};
}
