# Story quality upgrade — steps for the AI PC

This document is a self-contained work order for an agent (or a person) on
the **AI PC** — the machine that runs Ollama, ComfyUI, and the Iam-hero
bridge. Everything that could be done in code is **already implemented and
pushed**; what remains is pulling a free model, changing **one line** in the
bridge's settings file, and reading one story per language out loud. No
programming is required here.

Its sibling document, `ILLUSTRATION_QUALITY_UPGRADE.md`, does the same job for
the pictures. This one is about the words.

## Why (the honest version)

The bridge's default model is **`gemma3:4b`** — a 4-billion-parameter model
chosen because it fits in this PC's 4 GB of VRAM alongside everything else. It
works, and it is the reason there are stories at all. It is also the weakest
part of the pipeline:

- **Arabic is not fully correct.** This is the loudest problem. A 4B model
  writes Arabic that a native speaker recognizes as *almost* right: grammatical
  endings slip, dialect words drift into what should be Modern Standard Arabic,
  and the occasional English word appears mid-sentence. The bridge now refuses
  the worst of that automatically (see *What the code already does*), but no
  amount of validation can make a small model write good Arabic. Only a bigger
  model can.
- Plots are thin. Six pages that each describe a nice moment, rather than one
  story with a beginning, a middle and an end.
- The moral gets announced on the last page instead of being shown.
- Swedish and Somali are serviceable but plain.

`gemma3:4b` is now the documented **floor**, not a recommendation.

## What the code already does (for context)

You do not need to change any of this; it is here so you know what is already
handled and what is genuinely the model's job.

1. **Two-pass generation.** The bridge now asks the model for a compact
   outline first — a working title, one beat per page, and a one-line
   description of how the hero looks — validates it, and only then asks for the
   finished pages with that outline embedded in the prompt. That is what buys a
   real story arc instead of six unrelated scenes.
2. **Story-arc and age-aware prompting.** The page prompt demands a warm
   opening, a challenge or discovery in the middle, an ending the child's own
   action earns, and the lesson shown rather than stated. Sentence length and
   vocabulary follow the child's age. Since 2026-09-03 (#25) it also demands
   three to five sentences per page, a concrete sensory detail and a line of
   spoken dialogue on each page, feelings shown through the body, and an
   outline whose hero wants something on page 1 and pays a cost in the middle.
   The first `qwen3.5:9b` books were correct but flat; this is the fix.
3. **Arabic rules in the prompt.** For `ar` the prompt explicitly requires
   simple Modern Standard Arabic (فصحى مبسطة), forbids dialect mixing, and
   forbids Latin letters anywhere in the story text. Every other language gets
   the matching "this language only" rule.
4. **Language-purity validation.** After the model answers, the bridge checks
   the script of the title and pages. Arabic that is mostly Latin letters, or
   English with Arabic words dropped in, is rejected as invalid output and
   retried. This catches gross failures; it cannot catch bad grammar.
5. **A consistent hero.** The outline's appearance line is appended to every
   page's scene description, so ComfyUI draws the same child in the same
   clothes on every page.
6. **Everything is configurable.** The model is one line in
   `bridge_config.json`. Nothing about the model is hardcoded.

## Non-negotiables

- **Everything stays free and local.** Ollama is free and open source. Every
  model below is a free download with no account, no key, and no per-token
  cost. Nothing is ever sent off this machine.
- Do not commit model files or `bridge_config.json` to git.
- Do not weaken the language rules, the child-safety instructions, or the
  validation. If a model needs those relaxed to produce output, it is the
  wrong model.
- Do not expose the bridge or Ollama beyond localhost / the private LAN.
- Ask the owner before deviating from anything marked **decision**.

## Step 1 — pull the latest code and restart the bridge

```
git fetch origin
git checkout dev   # this work lives on dev, never main
git pull
cd bridge && dart pub get
```

Restart the bridge the way it is normally started on this PC (see
`bridge/README.md`).

## Step 2 — check how much RAM this PC has

The limit here is **system RAM**, not the 4 GB of VRAM. Ollama will happily
run a model larger than the graphics card by keeping part of it in system
memory; it just gets slower. So the question to answer first is:

```powershell
Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory
```

Divide by 1073741824 to get gigabytes. Write the number down — it decides the
next step.

## Step 3 — choose a model

All of these are **free**. Sizes are the download size; a model needs roughly
its own size in memory plus about 2 GB of headroom.

Corrected on 2026-09-03 against the live Ollama library and published
per-language evaluations. The evidence is in
`docs/research/ollama-arabic-models.md` on the `research/ollama-arabic-models`
branch.

| System RAM | Recommended | Download | Approx. resident | Notes |
| --- | --- | --- | --- | --- |
| 8 GB | `qwen3.5:4b` | 3.4 GB | ~5 GB | A genuine upgrade on the `gemma3:4b` floor: Qwen 3.5 repaired much of the Somali weakness and posts the best en-to-Somali generation score in its class. Arabic at this size stays limited. |
| 16 GB | **`qwen3.5:9b`** | 6.6 GB | ~8-9 GB | The sweet spot, and the strongest Arabic per gigabyte: 56.28 on QIMMA Arabic. |
| 32 GB or more | **`gemma3:27b`** | 17 GB | ~19-20 GB | Best Arabic measured at this size (60.75), and first in the entire QIMMA suite on Poetry and Literature, the domain closest to children's prose. It also wins Somali outright. Expect several minutes per story. |

**Do not use the `qwen3:*` tags.** They are the previous generation, and the
ladder is different: 4B/9B/27B, not 4B/8B/14B. The tag this document used to
recommend at 16 GB, `qwen3:8b`, scores **39.38** on QIMMA Arabic against
**56.28** for `qwen3.5:9b`. The old advice pointed at a model that is weak in
the one language this upgrade exists to fix.

**Qwen at 8 and 16 GB, Gemma at 32 GB.** Somali settles the top band: the
whole Qwen3 lineage sits at chance on Belebele Somali, while Gemma3-12B
reaches 69.33. Arabic-specialist models (Fanar-2, Jais-2, ALLaM, SILMA,
AceGPT) are ruled out structurally — the bridge has a single `ollamaModel`
serving all four languages, and every one of those models is Arabic/English
only. Jais-2 also sits behind a contact form, which fails the no-accounts
rule.

**A warning about search results.** Several blog posts recommend
`hf.co/tiiuae/Falcon-H1-Arabic-7B-Instruct-GGUF` and quote it as an OALL
leader at 71.7%. That repository does not exist. Ignore it.

**Decision:** any other freely downloadable Ollama model is a valid choice,
but check its Arabic before adopting it. The one requirement the bridge
places on a model is that it can follow a JSON schema (`format`), which every
model listed here does. Reasoning models (every `qwen3.5:*` tag) are covered:
the bridge sends `think: false`, because with thinking on Ollama returns the
JSON in its `thinking` field and an empty `response`, which the bridge can
only read as `invalid_model_output`.

Pull the chosen model:

```
ollama pull qwen3.5:9b
```

Replace `qwen3.5:9b` with whatever the table pointed at. The download is one
file over HTTPS from Ollama's public library; there is nothing to sign up for
and nothing to pay. Confirm it landed:

```
ollama list
```

## Step 4 — change one line in `bridge_config.json`

Find the file (its path is printed when the bridge starts) and change exactly
one line:

```jsonc
"ollamaModel": "qwen3.5:9b"
```

That is the whole change. Nothing else in the file needs touching.

If generation starts timing out on a slower model, the neighbouring line is
the budget **per model call** — a story makes two calls — and it may be raised
up to 3600:

```jsonc
"generationTimeoutSeconds": 900
```

Restart the bridge after saving. The bridge validates the file at startup and
refuses it with a clear message if anything is wrong.

## Step 5 — verify

1. `GET /health` on the bridge must report `ollama` **available** and name the
   new model. If it says the model is missing, `ollama list` and check the tag
   matches the config line character for character (`qwen3.5:9b`, not
   `qwen3.5-9b`).
2. Generate **one story per language** — `en`, `ar`, `sv`, `so` — for a test
   profile, six pages each. Use the same theme and moral for all four so the
   comparison is fair.
3. **Read the Arabic story out loud with a native speaker.** This is the
   acceptance test and it cannot be skipped or delegated to a checker. Ask
   specifically:
   - Is it Modern Standard Arabic, or does it slip into dialect?
   - Are the grammatical endings right?
   - Are there any Latin letters or English words?
   - Would a child this age understand it?
4. Read the other three. Check the story actually has an arc: does something
   change in the middle, and does the ending come from something the hero did?
   Is the moral shown rather than announced on the last page?
5. **Check the time.** Note how long one six-page story takes end to end. Up
   to a few minutes is normal and fine — the parent reviews the draft later
   anyway. If it takes longer than the owner is willing to wait, drop one size
   (`gemma3:27b` → `qwen3.5:9b` → `qwen3.5:4b`).
6. Watch memory during a run (Task Manager → Performance → Memory). If the
   machine starts swapping to disk, the model is too big for this PC; drop one
   size.
7. Only once all four languages read well, use the new model for the family's
   real profiles.

## Step 6 — record the outcome

Note in a safe place (not git): the model chosen, the observed time for a
six-page story, and the native speaker's verdict on the Arabic. If the owner
later wonders whether it was worth it, that note is the answer.

## The cost

**Slower generation is the only cost.** Everything here — Ollama, every model
in the table, the download, the bridge — is free and stays on this machine. A
bigger model uses more RAM and more seconds per story; it does not use money,
an account, or the internet after the download finishes. If the wait becomes
annoying, the fix is to pull a smaller model and change the same one line
back.
