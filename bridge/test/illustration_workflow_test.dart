import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_workflow.dart';
import 'package:test/test.dart';

/// Class type of one node in a built workflow.
String? _classType(Map<String, Object?> workflow, String nodeId) {
  final node = workflow[nodeId];
  return node is Map<String, Object?> ? node['class_type'] as String? : null;
}

/// Inputs of one node in a built workflow.
Map<String, Object?> _inputs(Map<String, Object?> workflow, String nodeId) {
  final node = workflow[nodeId]! as Map<String, Object?>;
  return node['inputs']! as Map<String, Object?>;
}

/// Text of the positive prompt node.
String _positivePrompt(Map<String, Object?> workflow) {
  return _inputs(workflow, positivePromptNodeId)['text']! as String;
}

Map<String, Object?> _build({
  String illustrationId = 'illustration-1',
  String sceneDescription = 'A harbour at dusk with paper lanterns',
  StoryIllustrationStyle style = StoryIllustrationStyle.pictureBook,
  StoryGenderContext? gender = StoryGenderContext.girl,
  String? referenceImageName,
}) {
  return buildIllustrationWorkflow(
    illustrationId: illustrationId,
    sceneDescription: sceneDescription,
    style: style,
    gender: gender,
    referenceImageName: referenceImageName,
  );
}

Map<String, Object?> _stylize({
  String storyId = 'story-1',
  String photoImageName = 'profile-1.jpg',
  StoryIllustrationStyle style = StoryIllustrationStyle.pictureBook,
  StoryGenderContext? gender = StoryGenderContext.girl,
}) {
  return buildReferenceStylizeWorkflow(
    storyId: storyId,
    photoImageName: photoImageName,
    style: style,
    gender: gender,
  );
}

void main() {
  test('without a photo the graph is plain text-to-image', () {
    final workflow = _build();

    expect(_classType(workflow, checkpointNodeId), 'CheckpointLoaderSimple');
    expect(
      _inputs(workflow, checkpointNodeId)['ckpt_name'],
      illustrationCheckpointName,
    );
    expect(_classType(workflow, samplerNodeId), 'KSampler');
    expect(_classType(workflow, saveImageNodeId), 'SaveImage');
    expect(
      _inputs(workflow, samplerNodeId)['model'],
      <Object?>[checkpointNodeId, 0],
      reason: 'the sampler reads the checkpoint model directly',
    );

    for (final nodeId in <String>[
      referenceImageNodeId,
      ipAdapterModelNodeId,
      clipVisionNodeId,
      ipAdapterApplyNodeId,
    ]) {
      expect(
        workflow.containsKey(nodeId),
        isFalse,
        reason: 'no photo means no IPAdapter node $nodeId',
      );
    }

    final latent = _inputs(workflow, latentNodeId);
    expect(latent['width'], illustrationImageSize);
    expect(latent['height'], illustrationImageSize);
    expect(latent['batch_size'], 1);
    final sampler = _inputs(workflow, samplerNodeId);
    expect(sampler['steps'], inInclusiveRange(20, 28));
  });

  test('with a photo the IPAdapter-plus-face chain is wired in', () {
    final workflow = _build(referenceImageName: 'profile-1.jpg');

    expect(_classType(workflow, referenceImageNodeId), 'LoadImage');
    expect(_inputs(workflow, referenceImageNodeId)['image'], 'profile-1.jpg');
    expect(_classType(workflow, ipAdapterModelNodeId), 'IPAdapterModelLoader');
    expect(
      _inputs(workflow, ipAdapterModelNodeId)['ipadapter_file'],
      illustrationIpAdapterName,
      reason: 'the face variant is what makes the child recognizable',
    );
    expect(_classType(workflow, clipVisionNodeId), 'CLIPVisionLoader');
    expect(
      _inputs(workflow, clipVisionNodeId)['clip_name'],
      illustrationClipVisionName,
    );

    final adapter = _inputs(workflow, ipAdapterApplyNodeId);
    expect(_classType(workflow, ipAdapterApplyNodeId), 'IPAdapterAdvanced');
    expect(adapter['model'], <Object?>[checkpointNodeId, 0]);
    expect(adapter['ipadapter'], <Object?>[ipAdapterModelNodeId, 0]);
    expect(adapter['image'], <Object?>[referenceImageNodeId, 0]);
    expect(adapter['clip_vision'], <Object?>[clipVisionNodeId, 0]);
    expect(adapter['weight'], illustrationIpAdapterWeight);
    expect(
      illustrationIpAdapterWeight,
      inExclusiveRange(0.0, 1.0),
      reason: 'a full-weight face adapter stops the page looking drawn',
    );

    expect(
      _inputs(workflow, samplerNodeId)['model'],
      <Object?>[ipAdapterApplyNodeId, 0],
      reason: 'the adapted model, not the raw checkpoint, must be sampled',
    );
  });

  test('an empty reference name falls back to the plain graph', () {
    final workflow = _build(referenceImageName: '   ');
    expect(workflow.containsKey(ipAdapterApplyNodeId), isFalse);
    expect(_inputs(workflow, samplerNodeId)['model'], <Object?>[
      checkpointNodeId,
      0,
    ]);
  });

  test('every style gets its own prompt prefix', () {
    final prompts = <StoryIllustrationStyle, String>{
      for (final style in StoryIllustrationStyle.values)
        style: _positivePrompt(_build(style: style)),
    };

    expect(
      prompts.values.toSet(),
      hasLength(StoryIllustrationStyle.values.length),
    );
    expect(
      prompts[StoryIllustrationStyle.pictureBook],
      contains('picture book'),
    );
    expect(prompts[StoryIllustrationStyle.watercolor], contains('watercolor'));
    expect(prompts[StoryIllustrationStyle.colorful3d], contains('3d'));
    for (final prompt in prompts.values) {
      expect(
        prompt,
        contains('A harbour at dusk with paper lanterns'),
        reason: 'the scene must survive the style prefix',
      );
    }
  });

  test('the gender context reaches the prompt', () {
    expect(
      _positivePrompt(_build(gender: StoryGenderContext.girl)),
      contains('a young girl'),
    );
    expect(
      _positivePrompt(_build(gender: StoryGenderContext.boy)),
      contains('a young boy'),
    );
    expect(
      _positivePrompt(_build(gender: null)),
      contains('a young child'),
      reason: 'an unknown context must not invent one',
    );
  });

  test('the negative prompt is present and unconditional', () {
    for (final style in StoryIllustrationStyle.values) {
      for (final reference in <String?>[null, 'profile-1.png']) {
        final workflow = _build(style: style, referenceImageName: reference);
        final negative =
            _inputs(workflow, negativePromptNodeId)['text']! as String;
        expect(negative, illustrationNegativePrompt);
        for (final guard in <String>[
          'scary',
          'nsfw',
          'deformed',
          'text',
          'watermark',
        ]) {
          expect(negative, contains(guard));
        }
        expect(_inputs(workflow, samplerNodeId)['negative'], <Object?>[
          negativePromptNodeId,
          0,
        ]);
      }
    }
  });

  test('the seed is derived from the illustration id and is stable', () {
    final first = _build(illustrationId: 'page-a');
    final again = _build(
      illustrationId: 'page-a',
      // A re-render with a different style still reproduces the same noise.
      style: StoryIllustrationStyle.colorful3d,
    );
    final other = _build(illustrationId: 'page-b');

    final seed = _inputs(first, samplerNodeId)['seed'];
    expect(seed, _inputs(again, samplerNodeId)['seed']);
    expect(seed, illustrationSeed('page-a'));
    expect(seed, isNot(_inputs(other, samplerNodeId)['seed']));
    expect(seed! as int, isNonNegative);
  });

  test('a blank scene description still produces a usable prompt', () {
    final prompt = _positivePrompt(_build(sceneDescription: '   '));
    expect(prompt, isNotEmpty);
    expect(prompt, contains('a quiet friendly moment'));
  });

  group('reference stylization pass', () {
    test('the graph is an img2img redraw of the photo', () {
      final workflow = _stylize();

      expect(
        _classType(workflow, referenceCheckpointNodeId),
        'CheckpointLoaderSimple',
      );
      expect(
        _inputs(workflow, referenceCheckpointNodeId)['ckpt_name'],
        illustrationCheckpointName,
        reason: 'the portrait must come out of the checkpoint the pages use',
      );

      expect(_classType(workflow, referencePhotoNodeId), 'LoadImage');
      expect(_inputs(workflow, referencePhotoNodeId)['image'], 'profile-1.jpg');

      expect(_classType(workflow, referenceScaleNodeId), 'ImageScale');
      final scale = _inputs(workflow, referenceScaleNodeId);
      expect(scale['upscale_method'], illustrationReferenceScaleMethod);
      expect(scale['width'], illustrationImageSize);
      expect(scale['height'], illustrationImageSize);
      expect(scale['crop'], illustrationReferenceCropMode);
      expect(scale['image'], <Object?>[referencePhotoNodeId, 0]);

      expect(_classType(workflow, referenceEncodeNodeId), 'VAEEncode');
      final encode = _inputs(workflow, referenceEncodeNodeId);
      expect(encode['pixels'], <Object?>[referenceScaleNodeId, 0]);
      expect(encode['vae'], <Object?>[referenceCheckpointNodeId, 2]);

      expect(_classType(workflow, referenceSamplerNodeId), 'KSampler');
      final sampler = _inputs(workflow, referenceSamplerNodeId);
      expect(
        sampler['latent_image'],
        <Object?>[referenceEncodeNodeId, 0],
        reason: 'the pass paints over the photo, not over empty noise',
      );
      expect(sampler['model'], <Object?>[referenceCheckpointNodeId, 0]);
      expect(sampler['positive'], <Object?>[referencePositivePromptNodeId, 0]);
      expect(sampler['negative'], <Object?>[referenceNegativePromptNodeId, 0]);
      expect(sampler['steps'], illustrationSamplerSteps);
      expect(sampler['cfg'], illustrationCfgScale);
      expect(sampler['sampler_name'], illustrationSamplerName);
      expect(sampler['scheduler'], illustrationScheduler);

      expect(_classType(workflow, referenceDecodeNodeId), 'VAEDecode');
      final decode = _inputs(workflow, referenceDecodeNodeId);
      expect(decode['samples'], <Object?>[referenceSamplerNodeId, 0]);
      expect(decode['vae'], <Object?>[referenceCheckpointNodeId, 2]);

      expect(_classType(workflow, referenceSaveImageNodeId), 'SaveImage');
      final save = _inputs(workflow, referenceSaveImageNodeId);
      expect(save['filename_prefix'], 'iam_hero_ref');
      expect(save['images'], <Object?>[referenceDecodeNodeId, 0]);

      expect(
        workflow.containsKey(ipAdapterApplyNodeId),
        isFalse,
        reason: 'stage one draws the reference, it does not use one',
      );
    });

    test('the denoise keeps the child while dropping the photograph', () {
      final denoise =
          _inputs(_stylize(), referenceSamplerNodeId)['denoise']! as double;
      expect(denoise, illustrationReferenceDenoise);
      expect(denoise, 0.62);
      expect(
        denoise,
        inExclusiveRange(0.0, 1.0),
        reason: 'a full redraw invents a different child, none keeps the photo',
      );
    });

    test('the portrait prompt carries the style and the hero phrase', () {
      for (final style in StoryIllustrationStyle.values) {
        for (final gender in <StoryGenderContext?>[
          StoryGenderContext.girl,
          StoryGenderContext.boy,
          null,
        ]) {
          final prompt = buildReferencePortraitPrompt(
            style: style,
            gender: gender,
          );
          expect(prompt, startsWith(illustrationPortraitStylePrefix(style)));
          expect(
            prompt,
            isNot(startsWith(illustrationStylePrefix(style))),
            reason:
                'a page prefix over a photo reads as cinema and produces '
                'a color-graded photo, so the portrait has its own wording',
          );
          expect(
            prompt,
            contains('cartoon'),
            reason: 'the one job of this pass is an unmistakably drawn face',
          );
          expect(prompt, contains(illustrationHeroPhrase(gender)));
          expect(
            prompt,
            contains('cheerful'),
            reason: "the photo's own expression must not travel into the book",
          );
        }
      }
      final text =
          _inputs(
                _stylize(
                  style: StoryIllustrationStyle.colorful3d,
                  gender: StoryGenderContext.boy,
                ),
                referencePositivePromptNodeId,
              )['text']!
              as String;
      expect(text, contains('3d'));
      expect(text, contains('a young boy'));
      expect(
        text,
        isNot(contains('harbour')),
        reason: 'the portrait is not a scene',
      );
    });

    test('only the stylization negative fights photographs', () {
      final stylizeNegative =
          _inputs(_stylize(), referenceNegativePromptNodeId)['text']! as String;
      expect(stylizeNegative, illustrationReferenceNegativePrompt);
      for (final term in <String>[
        'photorealistic',
        'real person',
        'film grain',
        'dslr',
        'skin pores',
      ]) {
        expect(stylizeNegative, contains(term));
      }
      expect(
        stylizeNegative,
        contains(illustrationNegativePrompt),
        reason: 'the children-book guards still apply to the portrait',
      );

      final pageNegative =
          _inputs(
                _build(referenceImageName: 'iam-hero-ref-story-1.png'),
                negativePromptNodeId,
              )['text']!
              as String;
      expect(pageNegative, illustrationNegativePrompt);
      for (final term in <String>['photorealistic', 'dslr', 'skin pores']) {
        expect(
          pageNegative,
          isNot(contains(term)),
          reason: 'a page must not be told to avoid what its style may need',
        );
      }
    });

    test('the seed is stable per story and never a page seed', () {
      final seed = _inputs(
        _stylize(storyId: 'story-a'),
        referenceSamplerNodeId,
      )['seed'];
      expect(
        seed,
        _inputs(
          _stylize(
            storyId: 'story-a',
            style: StoryIllustrationStyle.watercolor,
          ),
          referenceSamplerNodeId,
        )['seed'],
        reason: 'a re-run must reproduce the same portrait',
      );
      expect(seed, illustrationReferenceSeed('story-a'));
      expect(
        seed,
        isNot(
          _inputs(_stylize(storyId: 'story-b'), referenceSamplerNodeId)['seed'],
        ),
      );
      expect(
        illustrationReferenceSeed('story-a'),
        isNot(illustrationSeed('story-a')),
        reason: 'the portrait and a page of the same id are different rolls',
      );
      expect(seed! as int, isNonNegative);
    });

    test('the portrait file name is per story and carries no name', () {
      expect(referencePortraitFileName('story-a'), 'iam-hero-ref-story-a.png');
      expect(
        referencePortraitFileName('story-a'),
        referencePortraitFileName('story-a'),
      );
      expect(
        referencePortraitFileName('story-a'),
        isNot(referencePortraitFileName('story-b')),
      );
    });
  });
}
