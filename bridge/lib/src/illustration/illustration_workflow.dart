import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:iam_hero_bridge/src/config/illustration_settings.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';

/// IPAdapter-plus **face** model used when the child has a reference photo.
const String illustrationIpAdapterName =
    'ip-adapter-plus-face_sd15.safetensors';

/// CLIP vision encoder the face adapter reads the reference photo through.
const String illustrationClipVisionName =
    'CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors';

/// Sampler and scheduler pair used for every render.
const String illustrationSamplerName = 'dpmpp_2m';

/// Noise schedule paired with [illustrationSamplerName].
const String illustrationScheduler = 'karras';

/// Resampling filter the upscale pass is brought back down with.
///
/// The ESRGAN models multiply by a fixed factor of four, so a 512 render
/// lands at 2048 and has to be resized to the configured target. Lanczos is
/// the filter that keeps the recovered detail instead of blurring it away
/// again on the way down.
const String illustrationUpscaleScaleMethod = 'lanczos';

/// ComfyUI class type of the Impact-Pack face detailer.
///
/// Named as a constant because the bridge also asks ComfyUI whether it knows
/// this node before it enables the pass; a typo would turn "not installed"
/// into a mystery instead of a clear error.
const String illustrationFaceDetailerClassType = 'FaceDetailer';

/// ComfyUI class type of the Impact-Pack detector loader.
const String illustrationFaceDetectorClassType = 'UltralyticsDetectorProvider';

/// Prefix of the file name ComfyUI saves each render under.
const String illustrationOutputPrefix = 'iam_hero_page';

/// Prefix of the file name ComfyUI saves the stylized reference portrait under.
///
/// Kept distinct from [illustrationOutputPrefix] so a reference portrait can
/// never be mistaken for a page — nothing but the face adapter is ever meant
/// to see it, and it must never end up written into the library.
const String illustrationReferenceOutputPrefix = 'iam_hero_ref';

/// Resampling filter used to bring the photo to the render size.
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

/// Deterministic seed of the face-detail pass of one page.
///
/// Namespaced like [illustrationReferenceSeed] and for the same reason: the
/// detailer runs a second, differently shaped diffusion over the face, and
/// two passes of one page should not be handed the same roll. Re-rendering
/// the page still reproduces both.
int illustrationFaceDetailSeed(String illustrationId) {
  final digest = sha256Hex('face:$illustrationId');
  return int.parse(digest.substring(0, 12), radix: 16);
}

/// Builds the complete ComfyUI node graph for one page.
///
/// Without [referenceImageName] this is a plain SD 1.5 text-to-image graph.
/// With one, the model output is routed through the IPAdapter-plus-face
/// chain — load the portrait, encode it with CLIP vision, apply the face
/// adapter — before it reaches the sampler, which is what makes the hero look
/// like the same child on every page.
///
/// [settings] is what the PC's configuration file said; its defaults are the
/// values the bridge shipped with, so an untouched file builds exactly the
/// graph it always built. Three optional stages hang off it: a LoRA chain
/// between the checkpoint and everything that reads a model or a CLIP, an
/// upscale pass after the decode, and an Impact-Pack face-detail pass after
/// that. The order is deliberate — detailing a face after the enlargement
/// means the detailer works at the size the page will actually be read at.
Map<String, Object?> buildIllustrationWorkflow({
  required String illustrationId,
  required String sceneDescription,
  required StoryIllustrationStyle style,
  required StoryGenderContext? gender,
  String? referenceImageName,
  IllustrationSettings settings = IllustrationSettings.defaults,
}) {
  final hasReference =
      referenceImageName != null && referenceImageName.trim().isNotEmpty;
  final workflow = <String, Object?>{
    checkpointNodeId: _node('CheckpointLoaderSimple', <String, Object?>{
      'ckpt_name': settings.checkpoint,
    }),
  };
  // Everything that consumes a model or a CLIP reads the end of the chain,
  // not the checkpoint: a LoRA that only half the graph sees is a LoRA that
  // styles the picture while the prompt is still encoded without it.
  final String source = _appendLoraChain(
    workflow,
    checkpointId: checkpointNodeId,
    loras: settings.loras,
    nodeIdOf: illustrationLoraNodeId,
  );
  final List<Object?> pageModel = <Object?>[
    hasReference ? ipAdapterApplyNodeId : source,
    0,
  ];

  workflow[positivePromptNodeId] = _node('CLIPTextEncode', <String, Object?>{
    'text': buildIllustrationPrompt(
      sceneDescription: sceneDescription,
      style: style,
      gender: gender,
    ),
    'clip': <Object?>[source, 1],
  });
  workflow[negativePromptNodeId] = _node('CLIPTextEncode', <String, Object?>{
    'text': illustrationNegativePrompt,
    'clip': <Object?>[source, 1],
  });
  workflow[latentNodeId] = _node('EmptyLatentImage', <String, Object?>{
    'width': settings.imageSize,
    'height': settings.imageSize,
    'batch_size': 1,
  });
  workflow[samplerNodeId] = _node('KSampler', <String, Object?>{
    'seed': illustrationSeed(illustrationId),
    'steps': settings.samplerSteps,
    'cfg': settings.cfgScale,
    'sampler_name': illustrationSamplerName,
    'scheduler': illustrationScheduler,
    'denoise': 1.0,
    'model': pageModel,
    'positive': <Object?>[positivePromptNodeId, 0],
    'negative': <Object?>[negativePromptNodeId, 0],
    'latent_image': <Object?>[latentNodeId, 0],
  });
  workflow[decodeNodeId] = _node('VAEDecode', <String, Object?>{
    'samples': <Object?>[samplerNodeId, 0],
    // A LoRA loader has no VAE output, so the decoder always reads the
    // checkpoint's third slot however long the chain in front of it is.
    'vae': <Object?>[checkpointNodeId, 2],
  });

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
        'weight': settings.ipAdapterWeight,
        'weight_type': 'linear',
        'combine_embeds': 'concat',
        'start_at': 0.0,
        'end_at': 1.0,
        'embeds_scaling': 'V only',
        'model': <Object?>[source, 0],
        'ipadapter': <Object?>[ipAdapterModelNodeId, 0],
        'image': <Object?>[referenceImageNodeId, 0],
        'clip_vision': <Object?>[clipVisionNodeId, 0],
      },
    );
  }

  var image = decodeNodeId;
  if (settings.upscale.enabled) {
    workflow[upscaleModelNodeId] = _node(
      'UpscaleModelLoader',
      <String, Object?>{'model_name': settings.upscale.model},
    );
    workflow[upscaleImageNodeId] = _node(
      'ImageUpscaleWithModel',
      <String, Object?>{
        'upscale_model': <Object?>[upscaleModelNodeId, 0],
        'image': <Object?>[image, 0],
      },
    );
    workflow[upscaleResizeNodeId] = _node('ImageScale', <String, Object?>{
      'upscale_method': illustrationUpscaleScaleMethod,
      'width': settings.upscale.targetSize,
      'height': settings.upscale.targetSize,
      // The page is already square, so there is nothing to crop away.
      'crop': 'disabled',
      'image': <Object?>[upscaleImageNodeId, 0],
    });
    image = upscaleResizeNodeId;
  }

  if (settings.faceDetail.enabled) {
    workflow[faceDetectorNodeId] = _node(
      illustrationFaceDetectorClassType,
      <String, Object?>{'model_name': settings.faceDetail.detector},
    );
    workflow[faceDetailerNodeId] = _node(
      illustrationFaceDetailerClassType,
      _faceDetailerInputs(
        illustrationId: illustrationId,
        settings: settings,
        image: image,
        model: pageModel,
        clip: <Object?>[source, 1],
      ),
    );
    image = faceDetailerNodeId;
  }

  workflow[saveImageNodeId] = _node('SaveImage', <String, Object?>{
    'filename_prefix': illustrationOutputPrefix,
    'images': <Object?>[image, 0],
  });
  return workflow;
}

/// Inputs of the Impact-Pack `FaceDetailer` node of one page.
///
/// The detailer re-diffuses each detected face on its own, so it needs the
/// whole rendering context again: the same model the page was sampled with
/// (adapter chain included, or the refined face would stop looking like the
/// child), the same CLIP, the same VAE, and both prompt encoders — including
/// the negative one, because the child-safety guard applies to a re-rendered
/// face exactly as it applies to the page.
///
/// The remaining values are the node's own documented defaults, spelled out
/// rather than omitted: ComfyUI rejects a node whose required inputs are
/// missing, and a graph that says what it asks for is a graph that can be
/// read off the wire.
Map<String, Object?> _faceDetailerInputs({
  required String illustrationId,
  required IllustrationSettings settings,
  required String image,
  required List<Object?> model,
  required List<Object?> clip,
}) {
  return <String, Object?>{
    'image': <Object?>[image, 0],
    'model': model,
    'clip': clip,
    'vae': <Object?>[checkpointNodeId, 2],
    'positive': <Object?>[positivePromptNodeId, 0],
    'negative': <Object?>[negativePromptNodeId, 0],
    'bbox_detector': <Object?>[faceDetectorNodeId, 0],
    // A detected face is scaled to this before it is repainted, and never
    // past the size the finished page is: the point is a face rendered at
    // the resolution the page is read at, not a bigger one pasted in.
    'guide_size': settings.imageSize.toDouble(),
    'guide_size_for': true,
    'max_size': settings.outputImageSize.toDouble(),
    'seed': illustrationFaceDetailSeed(illustrationId),
    'steps': settings.samplerSteps,
    'cfg': settings.cfgScale,
    'sampler_name': illustrationSamplerName,
    'scheduler': illustrationScheduler,
    'denoise': settings.faceDetail.denoise,
    'feather': 5,
    'noise_mask': true,
    'force_inpaint': true,
    'bbox_threshold': 0.5,
    'bbox_dilation': 10,
    'bbox_crop_factor': 3.0,
    'sam_detection_hint': 'center-1',
    'sam_dilation': 0,
    'sam_threshold': 0.93,
    'sam_bbox_expansion': 0,
    'sam_mask_hint_threshold': 0.7,
    'sam_mask_hint_use_negative': 'False',
    'drop_size': 10,
    'wildcard': '',
    'cycle': 1,
  };
}

/// Chains [loras] onto [checkpointId] and returns the id of the node that
/// now produces the model (slot 0) and the CLIP (slot 1).
///
/// With an empty list that is the checkpoint itself, which is why an
/// untouched configuration produces byte-for-byte the previous graph.
String _appendLoraChain(
  Map<String, Object?> workflow, {
  required String checkpointId,
  required List<IllustrationLora> loras,
  required String Function(int index) nodeIdOf,
}) {
  var source = checkpointId;
  for (var index = 0; index < loras.length; index++) {
    final lora = loras[index];
    final nodeId = nodeIdOf(index);
    workflow[nodeId] = _node('LoraLoader', <String, Object?>{
      'lora_name': lora.name,
      // One number for both: a style LoRA whose CLIP side is weighted
      // differently from its model side pulls the prompt and the picture
      // apart, which is a knob nobody asked for.
      'strength_model': lora.strength,
      'strength_clip': lora.strength,
      'model': <Object?>[source, 0],
      'clip': <Object?>[source, 1],
    });
    source = nodeId;
  }
  return source;
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
///
/// [settings] contributes the checkpoint, the size, the sampler numbers and
/// the LoRA chain, so the portrait comes out of the same model the pages do —
/// a face drawn by a different model than the one that draws the book is a
/// face the book cannot reproduce. It deliberately gets **neither** the
/// upscale nor the face-detail pass: this image is never read by anyone, only
/// by the face adapter, and both passes would spend GPU minutes and VRAM on
/// pixels that are downsampled again the moment they are used.
Map<String, Object?> buildReferenceStylizeWorkflow({
  required String storyId,
  required String photoImageName,
  required StoryIllustrationStyle style,
  required StoryGenderContext? gender,
  IllustrationSettings settings = IllustrationSettings.defaults,
}) {
  final workflow = <String, Object?>{
    referenceCheckpointNodeId: _node(
      'CheckpointLoaderSimple',
      <String, Object?>{'ckpt_name': settings.checkpoint},
    ),
  };
  final String source = _appendLoraChain(
    workflow,
    checkpointId: referenceCheckpointNodeId,
    loras: settings.loras,
    nodeIdOf: referenceLoraNodeId,
  );

  workflow.addAll(<String, Object?>{
    referencePhotoNodeId: _node('LoadImage', <String, Object?>{
      'image': photoImageName.trim(),
      'upload': 'image',
    }),
    referenceScaleNodeId: _node('ImageScale', <String, Object?>{
      'upscale_method': illustrationReferenceScaleMethod,
      'width': settings.imageSize,
      'height': settings.imageSize,
      'crop': illustrationReferenceCropMode,
      'image': <Object?>[referencePhotoNodeId, 0],
    }),
    referenceEncodeNodeId: _node('VAEEncode', <String, Object?>{
      'pixels': <Object?>[referenceScaleNodeId, 0],
      'vae': <Object?>[referenceCheckpointNodeId, 2],
    }),
    referencePositivePromptNodeId: _node('CLIPTextEncode', <String, Object?>{
      'text': buildReferencePortraitPrompt(style: style, gender: gender),
      'clip': <Object?>[source, 1],
    }),
    referenceNegativePromptNodeId: _node('CLIPTextEncode', <String, Object?>{
      'text': illustrationReferenceNegativePrompt,
      'clip': <Object?>[source, 1],
    }),
    referenceSamplerNodeId: _node('KSampler', <String, Object?>{
      'seed': illustrationReferenceSeed(storyId),
      'steps': settings.samplerSteps,
      'cfg': settings.cfgScale,
      'sampler_name': illustrationSamplerName,
      'scheduler': illustrationScheduler,
      // The one value that differs from a page: a page paints from noise,
      // this pass paints over a photo.
      'denoise': settings.referenceDenoise,
      'model': <Object?>[source, 0],
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
  });
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

/// Node id of the upscale model loader; present only when upscaling.
const String upscaleModelNodeId = '12';

/// Node id of the 4x model upscale; present only when upscaling.
const String upscaleImageNodeId = '13';

/// Node id of the resize back to the configured target size.
const String upscaleResizeNodeId = '14';

/// Node id of the Ultralytics detector loader; only with face detailing.
const String faceDetectorNodeId = '15';

/// Node id of the Impact-Pack face detailer; only with face detailing.
const String faceDetailerNodeId = '16';

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

// LoRA chains are the only part of either graph whose node count is not
// known in advance, so each gets a reserved band far from the fixed ids
// above. `maximumIllustrationLoraCount` keeps a chain inside its band, which
// is why the config refuses a ninth LoRA rather than silently colliding.

/// Node id of the [index]th LoRA loader of the page graph.
String illustrationLoraNodeId(int index) => '${100 + index}';

/// Node id of the [index]th LoRA loader of the stylization graph.
String referenceLoraNodeId(int index) => '${200 + index}';

Map<String, Object?> _node(String classType, Map<String, Object?> inputs) {
  return <String, Object?>{'class_type': classType, 'inputs': inputs};
}
