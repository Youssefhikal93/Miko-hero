# Illustration quality upgrade — steps for the AI PC

> **Status: completed on the AI PC, September 2026** (issues #5, #6, #24).
> Live configuration: `dreamshaper_8` checkpoint, `coolkids-v2` LoRA,
> RealESRGAN upscale to 1024², peak VRAM about 3.4 GB; a six-page book renders
> in roughly 72 s. The bridge now unloads the Ollama model before rendering.
> The steps below are kept as the record of that setup.

This document is a self-contained work order for an agent (or a person) on
the **AI PC** — the machine that runs Ollama, ComfyUI, and the Iam-hero
bridge. Everything that could be done in code is **already implemented and
pushed**; what remains is downloading free model files, editing the bridge's
settings file, and verifying a real render. No programming is required here.

## What the code already does (for context)

The bridge's rendering pipeline is now fully configurable through an
`illustration` section in `bridge_config.json` (every key documented with its
default in `bridge/README.md`). It supports, in this order:

1. Any **SD 1.5 checkpoint** (`checkpoint`) — no longer hardwired to the raw
   base model.
2. A chain of up to 8 **style LoRAs** (`loras`, each `{name, strength}`),
   applied to pages and to the stylized reference portrait alike.
3. An **upscale pass** (`upscale`) — RealESRGAN 4× then resize down to
   `targetSize` (default 1024) — pages only, off by default.
4. An optional **face-detail pass** (`faceDetail`) via the ComfyUI Impact
   Pack — off by default; the bridge checks ComfyUI for the node before any
   render and fails with a clear `missing_custom_node` error if the pack is
   not installed, without touching any page.

An unchanged `bridge_config.json` behaves exactly as before this change. The
guard rails (child-safety negative prompt, size caps, localhost/LAN only) are
not configurable and must stay that way.

## The hero looks the same in every story (issue #62)

Landed after the setup above, and it needs **no new model file and no config
change** — but it is worth knowing about before comparing books.

The child's drawn face used to be reinvented per book. The portrait seed came
from the story id, so each story produced a different cartoon of the same
child, and the story planner invented a fresh appearance line every time. Two
things now come from the child instead:

- **The portrait seed** is `reference:<profileId>:<sha256 of the photo>`. One
  photo, one drawn face, in every book. Replacing the photo is the one thing
  that deliberately redraws it.
- **A per-child character sheet** in the master library (schema v4, table
  `hero_character_sheets`): `hair`, `skinTone` and `eyeColor` read from the
  photo once, plus one recurring `outfit` and `prop` that survive a new photo.
  Its one English line is what the story planner is told to copy verbatim, and
  it lands in every page's scene description as before.

The three colours come from one Ollama call with the photo attached, on the new
optional `visionModel` key (default `gemma3:4b`, documented in
`bridge/README.md`). The prompt describes a **drawn cartoon character** and is
forbidden to mention a photo or a real person, or any identifying detail. The
outfit and prop are **not** asked of the model — a vision model asked about
clothes describes the jumper in the photograph — but picked from two small
curated wardrobes, hashed per profile.

It runs when the photo is uploaded (behind the response, skipped if the GPU is
busy) and again, lazily, before a story if it is missing or the photo changed.
The pass is an Ollama tenant at the one-GPU gate, so its model is unloaded
before ComfyUI renders.

**If `visionModel` cannot see** — a text-only tag, or Ollama down — nothing
breaks: no sheet is stored and the planner invents an appearance line exactly
as it did before. If the PC's `ollamaModel` has been upgraded to a text-only
writer, leave `visionModel` at `gemma3:4b` (or point it at another vision tag
that is already pulled).

**Still to do with the owner, by eye:** render two books for one test profile
and confirm the hero is recognizably the same child in both; then decide
whether the derived colours and the chosen outfit look right, and whether
`referenceDenoise` needs re-tuning now that the face no longer changes between
books. That comparison is Step 5 territory and is not something a test can
answer.

## Non-negotiables

- Everything stays free and local. Downloading open model files from
  Civitai / Hugging Face / GitHub is fine; nothing private is ever uploaded.
- Do not commit model files or `bridge_config.json` to git.
- Do not weaken or remove the built-in negative prompt (child safety).
- Do not expose the bridge or ComfyUI beyond localhost / the private LAN.
- Ask the owner before deviating from anything marked **decision**.

## Step 1 — pull the latest code and rebuild the bridge

```
git fetch origin
git checkout dev   # this work lives on dev, never main
git pull
cd bridge && dart pub get
```

Restart the bridge the way it is normally started on this PC (see
`bridge/README.md`).

## Step 2 — download the model files

Place each file in the stated **ComfyUI** folder (find the ComfyUI install
first; the owner knows where it is).

| File | Where to get it | Put it in | Size |
| --- | --- | --- | --- |
| `dreamshaper_8.safetensors` (SD 1.5 fine-tune — the main quality jump) | Civitai model "DreamShaper", version 8, or the Hugging Face mirror (Lykon/DreamShaper). Verify it is the **SD 1.5** version, not XL. | `ComfyUI/models/checkpoints/` | ~2.1 GB |
| A children's-book style LoRA (**decision**: pick one with the owner) | Civitai → filter LoRA + base model **SD 1.5** → search "kids illustration" / "storybook" (the "COOL KIDS" kids-illustration LoRA is a well-known example). Check the license allows personal use. | `ComfyUI/models/loras/` | 50–200 MB |
| `RealESRGAN_x4plus_anime_6B.pth` (sharpness) | Real-ESRGAN GitHub releases | `ComfyUI/models/upscale_models/` | ~18 MB |
| ComfyUI-Impact-Pack (optional — face fixing) | Install via ComfyUI Manager (github.com/ltdrdata/ComfyUI-Impact-Pack); accept its `face_yolov8m.pt` detector during setup; restart ComfyUI | managed by ComfyUI Manager | small |

**Decision:** any other SD 1.5 fine-tune is equally valid as the checkpoint —
use its exact filename in Step 3. Do **not** use SDXL/Flux models: they do not
fit in this PC's 4 GB of VRAM alongside the face adapter.

## Step 3 — edit `bridge_config.json`

Add (or extend) the `illustration` section. Start with:

```jsonc
"illustration": {
  "checkpoint": "dreamshaper_8.safetensors",
  "loras": [
    { "name": "<your-style-lora>.safetensors", "strength": 0.8 }
  ],
  "upscale": { "enabled": true, "targetSize": 1024 },
  "faceDetail": { "enabled": false }
}
```

Enable `faceDetail` only after the Impact Pack is installed (Step 2, last
row). Restart the bridge after saving. A typo in any filename or key is
refused at startup with a clear message — fix and restart.

## Step 4 — verify end to end

1. The bridge health endpoint must report ComfyUI reachable.
2. From a paired device (or the web app on this PC), generate a full story
   with illustrations for a **test profile with a non-real photo** (any
   cartoon face image) first.
3. Confirm: pages come out in the chosen style, files are ~1024×1024, the
   hero looks consistent across pages, nothing frightening or deformed.
3a. Generate a **second** story for the same test profile and confirm the hero
   is the same drawn child in both books — same face, same coat, same prop.
   That is what issue #62 added; see the section above.
4. Optional side-by-side: temporarily set `checkpoint` back to
   `v1-5-pruned-emaonly-fp16.safetensors`, render the same story again
   (seeds are deterministic), and compare with the owner.
5. Watch GPU memory during a run. If ComfyUI runs out of memory with
   `targetSize` 1024, drop it to 768 — still far better than 512. The bridge
   unloads its Ollama model before ComfyUI starts, so no manual unload is
   needed.
6. If `faceDetail` was enabled: confirm the first render actually completes —
   the FaceDetailer wiring follows the Impact Pack's documented inputs but
   was never run against a real install; a `missing_custom_node` error means
   the pack is absent or ComfyUI was not restarted.
7. Only after the test profile looks right, render for the real profiles.

## Step 5 — tune (with the owner)

Knobs in `bridge_config.json`, in order of usefulness:

1. `loras[].strength` (0–1.5): the style push. 0.7–0.9 is the sweet spot;
   above ~1.2 the style overwhelms the checkpoint.
2. `ipAdapterWeight` (default 0.65): likeness vs. drawn-ness. Raise toward
   0.75 if the hero is not recognizable enough; lower toward 0.55 if pages
   look too photographic.
3. `referenceDenoise` (default 0.62): how strongly the child's photo is
   redrawn into a cartoon portrait before it steers the pages. Raise if
   pages inherit photo-like faces; lower if the hero stops resembling the
   child.
4. `samplerSteps` (default 24) and `cfgScale` (default 7): usually fine as
   they are.

Settings live on this PC only. When the owner is happy, note the final values
somewhere safe (they are part of the "how my library looks" recipe and are
not in git).
