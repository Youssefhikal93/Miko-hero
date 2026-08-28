# Illustration quality upgrade — instructions for the AI-PC agent

This document is a self-contained work order. It is written to be handed to a
coding agent running **on the AI PC** (the machine that runs Ollama, ComfyUI,
and the Iam-hero bridge). Follow it top to bottom. Ask the owner before
deviating from anything marked **decision**.

## Why this exists

The bridge currently renders every illustration with the **raw Stable
Diffusion 1.5 base checkpoint at 512×512** — see
`bridge/lib/src/illustration/illustration_workflow.dart`. The pipeline design
around it is good (two-stage photo stylization, face adapter, deterministic
seeds), but the base model produces crude art, 512px looks blurry on modern
screens, and small faces in wide scenes come out distorted. The owner confirmed
all three complaints, confirmed the GPU has **~4 GB VRAM**, and approved
downloading free model files.

The fix has two halves: **(A) code changes** in this repository and **(B) model
downloads + configuration** on this PC. Do A first, then B, then verify.

## Non-negotiable constraints (from the project owner)

- Everything stays 100% free and local. No paid APIs, no cloud, no uploads of
  photos, prompts, stories, or illustrations to any third-party service.
  (Downloading open model files from Hugging Face / Civitai / GitHub is fine.)
- Do not hardcode machine paths, IPs, tokens, or child data in the repo.
- Preserve every existing feature, migration, and test (the suite must stay
  green: `flutter test` at the repo root and `dart test` inside `bridge/`).
- `flutter analyze` (repo root, after `dart pub get` in `bridge/`) must report
  zero issues. Note: analyzing before resolving bridge deps yields ~1400 fake
  errors — run `dart pub get` in `bridge/` first.
- Every authored public API gets a `///` doc comment in the existing style
  (`public_member_api_docs` is enforced).
- An **unchanged `bridge_config.json` must behave exactly as today** — every
  new setting defaults to the current compiled-in value or to "off".
- Do not commit model files (`.safetensors`, `.pth`, `.ckpt`) or
  `bridge_config.json` to git.
- Read `docs/CODEBASE.md` and `bridge/README.md` before coding, and update
  both when done.

## Part A — code changes (in `bridge/`)

All rendering constants live in
`bridge/lib/src/illustration/illustration_workflow.dart` today. The work:

### A1. Make rendering configurable

Extend `BridgeConfig` (`bridge/lib/src/config/bridge_config.dart`) with an
`illustration` section. Every field optional; defaults = today's values:

```jsonc
{
  "illustration": {
    "checkpoint": "v1-5-pruned-emaonly-fp16.safetensors",
    "imageSize": 512,
    "samplerSteps": 24,
    "cfgScale": 7.0,
    "ipAdapterWeight": 0.65,
    "referenceDenoise": 0.62,
    "loras": [
      { "name": "some-style-lora.safetensors", "strength": 0.8 }
    ],
    "upscale": {
      "enabled": false,
      "model": "RealESRGAN_x4plus_anime_6B.pth",
      "targetSize": 1024
    },
    "faceDetail": {
      "enabled": false,
      "detector": "bbox/face_yolov8m.pt",
      "denoise": 0.45
    }
  }
}
```

Validate shapes and ranges the way the existing config code does (typed
errors, no silent coercion): `imageSize` one of 512/576/640, `samplerSteps`
1–60, `cfgScale` 1–15, LoRA strength 0–1.5, `targetSize` 512–2048. Reject
unknown keys inside `illustration` (catches typos).

### A2. LoRA chain

When `loras` is non-empty, insert one `LoraLoader` node per entry between the
checkpoint loader and everything that consumes the model/CLIP outputs (both
the page graph and the reference-stylization graph). Chain multiple LoRAs in
order. Both `strength_model` and `strength_clip` = the entry's `strength`.

### A3. Upscale pass

When `upscale.enabled`, after `VAEDecode` in the **page** graph (not the
reference portrait — it is only an adapter input), add:

- `UpscaleModelLoader` (`model_name` = config value) →
- `ImageUpscaleWithModel` →
- `ImageScale` down to `targetSize` × `targetSize` (lanczos) — the ESRGAN
  model multiplies by 4, so 512 → 2048 → resize to 1024.

`SaveImage` then consumes the scaled result. These are built-in ComfyUI nodes;
no custom-node install is needed for this step.

### A4. Face-detail pass (optional, off by default)

When `faceDetail.enabled`, insert the Impact-Pack `FaceDetailer` node between
decode and save (after upscaling if enabled), wired to the same model/CLIP/VAE
and both prompt encoders, `denoise` from config, detector from
`UltralyticsDetectorProvider` (`model_name` = `faceDetail.detector`). This
requires the ComfyUI-Impact-Pack custom nodes on the PC (Part B4) — the bridge
must fail with a **clear typed error** if the pass is enabled but ComfyUI
rejects the node, not hang or half-render.

### A5. Respect the size cap

`comfyui_client.dart` caps downloaded images at 16 MB — a 1024px PNG fits, but
verify the cap against `targetSize` at config-load time and refuse impossible
combinations with a clear error.

### A6. Tests and docs

- Unit tests: config parsing (defaults, ranges, unknown-key rejection), graph
  building with LoRAs / upscale / face-detail on and off (assert exact node
  wiring, like the existing workflow tests), impossible-size rejection.
- Update `bridge/README.md` (setup + every new config key with its default)
  and `docs/CODEBASE.md` (changed files).
- Gates before finishing: `dart pub get` + `dart analyze` + `dart test` in
  `bridge/`; `flutter analyze` + `flutter test` at the root. All green, then
  commit with a clear message and push to `main` **only if the owner has
  authorized push on this machine** — otherwise leave committed locally and
  tell the owner.

## Part B — downloads and configuration (on this PC)

Model files go into the **ComfyUI** folders, not this repo. Locate the ComfyUI
installation first (the owner knows where it is; the bridge config points at
its URL).

### B1. Better checkpoint (~2.1 GB) — the main quality jump

Download **DreamShaper 8** (SD 1.5 fine-tune, free):
`dreamshaper_8.safetensors` from its Civitai page (model "DreamShaper",
version 8) or its Hugging Face mirror (Lykon/DreamShaper). Verify it is the
**SD 1.5** version, not XL. Place in `ComfyUI/models/checkpoints/`.

**Decision:** if the owner prefers a different SD 1.5 checkpoint (e.g. a
dedicated storybook or anime model), any SD 1.5 fine-tune works — just use its
exact filename in the config.

### B2. Storybook style LoRA (~50–200 MB, optional but recommended)

On Civitai, filter LoRAs by base model **SD 1.5** and search for a children's
book / kids illustration style (the "COOL KIDS" kids-illustration LoRA is a
well-known example). Check the license allows personal use. Place the
`.safetensors` file in `ComfyUI/models/loras/`. Start with strength 0.7–0.9.

### B3. Upscaler (~18 MB)

Download `RealESRGAN_x4plus_anime_6B.pth` from the Real-ESRGAN GitHub
releases. Place in `ComfyUI/models/upscale_models/`.

### B4. Face detailing (optional, needs custom nodes)

Install **ComfyUI-Impact-Pack** (github.com/ltdrdata/ComfyUI-Impact-Pack) via
ComfyUI Manager, plus its Ultralytics detector models (it offers
`face_yolov8m.pt` during setup). Restart ComfyUI. Skip this step entirely if
the owner wants to keep the PC setup minimal — the config default is off.

### B5. Update `bridge_config.json`

Add the `illustration` section (see A1) with the real filenames, e.g.:

```jsonc
"illustration": {
  "checkpoint": "dreamshaper_8.safetensors",
  "loras": [{ "name": "<your-style-lora>.safetensors", "strength": 0.8 }],
  "upscale": { "enabled": true, "model": "RealESRGAN_x4plus_anime_6B.pth", "targetSize": 1024 },
  "faceDetail": { "enabled": false }
}
```

Enable `faceDetail` only after B4. Restart the bridge.

## Part C — verification (end to end, on this PC)

1. Bridge health endpoint reports ComfyUI reachable.
2. From a paired device (or the web app on this PC), generate a full story
   with illustrations for a test profile **using a non-real photo** (any
   cartoon face image) first.
3. Confirm: pages render in the chosen style, output files are ~1024×1024,
   the hero looks consistent across pages, nothing frightening or deformed.
4. Compare a few pages against the old settings (temporarily switch
   `checkpoint` back to `v1-5-pruned-emaonly-fp16.safetensors` if the owner
   wants a side-by-side) — then decide final settings together with the owner.
5. VRAM check: watch GPU memory during a run; if ComfyUI OOMs at 1024 target,
   drop `targetSize` to 768 — still a visible improvement over 512.
6. Tuning knobs, in order of usefulness: LoRA strength (style), then
   `ipAdapterWeight` 0.55–0.75 (likeness vs. drawn-ness), then
   `referenceDenoise` 0.55–0.70 (how hard the photo is cartoonified).

## What NOT to do

- Do not switch to SDXL/Flux models — they do not fit in 4 GB alongside the
  face adapter. (If this PC ever gets an 8 GB+ GPU, that becomes a config
  change thanks to Part A.)
- Do not remove or weaken `illustrationNegativePrompt` — it is the child-
  safety guard and is deliberately not configurable.
- Do not commit model files, `bridge_config.json`, or any generated
  image/story into git.
- Do not expose the bridge or ComfyUI beyond localhost / the private LAN.
