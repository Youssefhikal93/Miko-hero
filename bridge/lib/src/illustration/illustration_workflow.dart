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

/// Prefix of the file name ComfyUI saves the stylized reference portrait under.
///
/// Kept distinct from [illustrationOutputPrefix] so a reference portrait can
/// never be mistaken for a page — nothing but the face adapter is ever meant
/// to see it, and it must never end up written into the library.
const String illustrationReferenceOutputPrefix = 'iam_hero_ref';

/// How much of the reference photo the stylization pass repaints.
///
/// This is the whole tradeoff of stage one in one number. Lower values keep
/// more of the real child — and more of the photograph: its lighting, its
/// texture, its expression, which is exactly what dragged pages towards
/// distorted photorealism when the raw photo was used as the reference.
/// Higher values cartoonify harder and start inventing a different child.
/// 0.62 is the value that was validated on real photos: unmistakably drawn,
/// still recognizably the same face.
const double illustrationReferenceDenoise = 0.62;

/// Resampling filter used to bring the photo to [illustrationImageSize].
///
/// Lanczos keeps the eyes and mouth crisp through the downscale; a softer
/// filter hands the sampler a blurred face and gets a blurred face back.
const String illustrationReferenceScaleMethod = 'lanczos';

/// How the photo is fitted to a square: centre crop, keeping the face.
///
/// Phone photos are portrait, and a centre crop of a head-and-shoulders
/// photo is the face. Letterboxing instead would feed the adapter a picture
/// that is mostly empty border.
const String illustrationReferenceCropMode = 'center';

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

/// Terms that push the reference portrait away from being a photograph.
///
/// Only the stylization pass uses these. A page must stay free to be whatever
/// its style demands — a watercolor page has no business fighting the word
/// "film grain" — so this never reaches [illustrationNegativePrompt].
const String illustrationAntiPhotoNegativePrefix =
    'photo, photograph, photorealistic, realistic photo, real person, '
    'film grain, dslr, 35mm, skin pores, ';

/// The negative prompt of the reference stylization pass.
///
/// The page guards still apply — the portrait is an input to a children's
/// book — with the anti-photo terms in front of them, because the one thing
/// this pass must not produce is another photograph.
const String illustrationReferenceNegativePrompt =
    illustrationAntiPhotoNegativePrefix + illustrationNegativePrompt;

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

/// Portrait-specific art direction of the reference stylization pass.
///
/// Deliberately NOT [illustrationStylePrefix]. The page prefixes describe a
/// finished scene, and over a photo they read as cinema: "3d animated film
/// illustration" painted onto a photograph produces a color-graded photo of
/// the child, which the pages then faithfully copy. A portrait needs blunter
/// words — "cartoon child", "stylized features" — that leave the sampler no
/// photographic reading. These are the phrasings that were validated to turn
/// a real photo into an unmistakably drawn portrait.
String illustrationPortraitStylePrefix(StoryIllustrationStyle style) {
  switch (style) {
    case StoryIllustrationStyle.pictureBook:
      return "cute children's picture book character portrait, cartoon "
          'child drawing, soft rounded shapes, warm flat colors, thick '
          'confident outlines';
    case StoryIllustrationStyle.watercolor:
      return 'traditional watercolor storybook character portrait, cartoon '
          'child painting, soft translucent washes, visible paper texture, '
          'muted natural palette';
    case StoryIllustrationStyle.colorful3d:
      return 'cute 3d animated movie character portrait, pixar style cartoon '
          'child, big expressive eyes, smooth stylized features, glossy '
          'render, soft studio lighting';
  }
}

/// The positive prompt of the reference stylization pass.
///
/// Deliberately not a scene: this pass draws one plain portrait whose only
/// job is to be a good reference, in a drawn dialect of the book's own style
/// (see [illustrationPortraitStylePrefix]) so the face the adapter hands to
/// every page arrives as a drawing instead of a photograph. The smile is
/// asked for on purpose — a photo's expression otherwise travels into every
/// page, and a crying child is not what a bedtime book should look like.
String buildReferencePortraitPrompt({
  required StoryIllustrationStyle style,
  required StoryGenderContext? gender,
}) {
  return '${illustrationPortraitStylePrefix(style)}, '
      'a cheerful ${illustrationHeroPhrase(gender)}, gentle smile, '
      'head and shoulders, plain light background';
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

/// Deterministic seed of the reference portrait of one story.
///
/// Namespaced with a `reference:` prefix rather than hashing the bare id, so
/// the portrait can never accidentally draw the same noise as a page of the
/// same story: the two are different pictures and must stay different rolls.
/// Re-running a job reproduces the portrait, which is what makes a re-render
/// of one failed page match the pages that already landed.
int illustrationReferenceSeed(String storyId) {
  final digest = sha256Hex('reference:$storyId');
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

/// Name the stylized portrait of [storyId] is stored under in ComfyUI.
///
/// Deterministic and per story, so a second run of the same job overwrites
/// the previous portrait instead of littering ComfyUI's input folder with a
/// copy of the child's face for every attempt. It carries no name, only the
/// story's uuid.
String referencePortraitFileName(String storyId) => 'iam-hero-ref-$storyId.png';

/// Builds the ComfyUI node graph of the reference stylization pass.
///
/// This is stage one of rendering a book, run once per job and only when the
/// child has a photo: an img2img pass that redraws [photoImageName] as a
/// cheerful storybook portrait in the book's own [style]. The result is what
/// stage two hands to the face adapter.
///
/// The pass exists because a photograph is the wrong kind of reference. The
/// face adapter reads an image, not a description, so a photographic
/// embedding pulls every page towards photorealism — and towards whatever
/// mood the photo happened to catch — no matter what the style prompt asks
/// for. A drawn reference asks for a drawing and gets one.
///
/// The portrait is derived from the child's photo and is therefore private
/// content: it lives only inside ComfyUI's folders, exactly as the photo
/// already does, and is never written to the library, logged or echoed.
Map<String, Object?> buildReferenceStylizeWorkflow({
  required String storyId,
  required String photoImageName,
  required StoryIllustrationStyle style,
  required StoryGenderContext? gender,
}) {
  return <String, Object?>{
    referenceCheckpointNodeId: _node(
      'CheckpointLoaderSimple',
      <String, Object?>{'ckpt_name': illustrationCheckpointName},
    ),
    referencePhotoNodeId: _node('LoadImage', <String, Object?>{
      'image': photoImageName.trim(),
      'upload': 'image',
    }),
    referenceScaleNodeId: _node('ImageScale', <String, Object?>{
      'upscale_method': illustrationReferenceScaleMethod,
      'width': illustrationImageSize,
      'height': illustrationImageSize,
      'crop': illustrationReferenceCropMode,
      'image': <Object?>[referencePhotoNodeId, 0],
    }),
    referenceEncodeNodeId: _node('VAEEncode', <String, Object?>{
      'pixels': <Object?>[referenceScaleNodeId, 0],
      'vae': <Object?>[referenceCheckpointNodeId, 2],
    }),
    referencePositivePromptNodeId: _node('CLIPTextEncode', <String, Object?>{
      'text': buildReferencePortraitPrompt(style: style, gender: gender),
      'clip': <Object?>[referenceCheckpointNodeId, 1],
    }),
    referenceNegativePromptNodeId: _node('CLIPTextEncode', <String, Object?>{
      'text': illustrationReferenceNegativePrompt,
      'clip': <Object?>[referenceCheckpointNodeId, 1],
    }),
    referenceSamplerNodeId: _node('KSampler', <String, Object?>{
      'seed': illustrationReferenceSeed(storyId),
      'steps': illustrationSamplerSteps,
      'cfg': illustrationCfgScale,
      'sampler_name': illustrationSamplerName,
      'scheduler': illustrationScheduler,
      // The one value that differs from a page: a page paints from noise,
      // this pass paints over a photo.
      'denoise': illustrationReferenceDenoise,
      'model': <Object?>[referenceCheckpointNodeId, 0],
      'positive': <Object?>[referencePositivePromptNodeId, 0],
      'negative': <Object?>[referenceNegativePromptNodeId, 0],
      'latent_image': <Object?>[referenceEncodeNodeId, 0],
    }),
    referenceDecodeNodeId: _node('VAEDecode', <String, Object?>{
      'samples': <Object?>[referenceSamplerNodeId, 0],
      'vae': <Object?>[referenceCheckpointNodeId, 2],
    }),
    referenceSaveImageNodeId: _node('SaveImage', <String, Object?>{
      'filename_prefix': illustrationReferenceOutputPrefix,
      'images': <Object?>[referenceDecodeNodeId, 0],
    }),
  };
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

// The stylization graph is submitted on its own, so its ids only have to be
// unique within it. They are numbered away from the page ids anyway: a graph
// captured in a test or read off the wire should be identifiable as one pass
// or the other at a glance.

/// Node id of the checkpoint loader in the stylization graph.
const String referenceCheckpointNodeId = '20';

/// Node id of the raw-photo loader in the stylization graph.
const String referencePhotoNodeId = '21';

/// Node id of the square downscale of the photo.
const String referenceScaleNodeId = '22';

/// Node id of the VAE encode that turns the photo into a latent to paint on.
const String referenceEncodeNodeId = '23';

/// Node id of the portrait prompt encoder.
const String referencePositivePromptNodeId = '24';

/// Node id of the anti-photo negative prompt encoder.
const String referenceNegativePromptNodeId = '25';

/// Node id of the img2img sampler that does the redrawing.
const String referenceSamplerNodeId = '26';

/// Node id of the VAE decoder of the stylization graph.
const String referenceDecodeNodeId = '27';

/// Node id of the portrait writer; its output is downloaded and re-uploaded.
const String referenceSaveImageNodeId = '28';

Map<String, Object?> _node(String classType, Map<String, Object?> inputs) {
  return <String, Object?>{'class_type': classType, 'inputs': inputs};
}
