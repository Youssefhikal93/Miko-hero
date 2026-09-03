# Arabic-capable Ollama models per RAM band

Research note for issue #8. Checked on **2026-09-03** against the Ollama
model library, the model authors' own model cards and release posts, and
three Arabic evaluation efforts. Everything *recommended* here is a free
download from a public library or the Hugging Face hub: no account, no
key, no per-token cost, nothing leaves the machine after the download.
Where a model fails that test it is named and ruled out, not quietly
dropped.

This note re-checks the model table in `docs/STORY_QUALITY_UPGRADE.md`,
which was written on 2026-08-31 and recommends the Qwen family.

## Bottom line

**The Qwen recommendation still holds. The tags in the work order do
not.** `qwen3:*` has been superseded by `qwen3.5:*`, released February
2026, and the size ladder is different: 4B / 9B / 27B rather than 4B /
8B / 14B. Same family, same reasoning, newer and larger models for the
same memory.

Nothing else about the work order changes: it is still one line in
`bridge_config.json`, and the native-speaker read-aloud in step 5 is
still the only test that decides whether the upgrade worked. The table
in step 3 of `STORY_QUALITY_UPGRADE.md` should be replaced with the one
below.

## Recommendation per RAM band

Sizes are the Ollama download. Resident RAM is the download plus the
runtime overhead Ollama adds; on a machine with 4 GB of VRAM, Ollama
defaults to a 4k context window, so the KV cache is small and the
download size dominates.

| System RAM | `ollama pull` | Params | Quant | Download | Approx. resident | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| ~8 GB | `qwen3.5:4b` | 4.66B | Q4_K_M | 3.4 GB | ~5 GB | A real step up from `gemma3:4b`, but still a 4B model. Expect the Arabic read-aloud test to fail. |
| ~16 GB | **`qwen3.5:9b`** | 9.65B | Q4_K_M | 6.6 GB | ~8–9 GB | The pick. Best Arabic per gigabyte available today, and it still covers en/sv/so. |
| ~32 GB | **`qwen3.5:27b`** | 27.8B | Q4_K_M | 17 GB | ~19–20 GB | The pick. Largest model that fits 32 GB without swapping. |

Second choices, if the first choice disappoints:

| Band | Also worth trying | Download | Why |
| --- | --- | --- | --- |
| ~16 GB | `gemma4:12b` | 7.6 GB | Apache 2.0, 140+ languages, likely the better of the two for Somali (see below). Probably weaker in Arabic. |
| ~32 GB | `gemma4:26b` or `gemma4:31b` | 19–20 GB | Same trade as above, one size up. |
| ~32 GB | `qwen3.6:27b` | 18 GB | Newer than 3.5 but tuned for agentic coding, not prose. No reason to prefer it here. |

Do **not** pick from the "newest" list on the Ollama library front page
without checking what the model was tuned for. `qwen3.6` and `qwen3.8`
are newer than `qwen3.5` and both describe themselves in terms of
coding and long-horizon agentic work. `qwen3.5` is the one whose release
notes are about language coverage.

## What changed since the work order was written

The work order's table is eight months behind the library, not eight
days. Three things moved:

1. **Qwen3.5 replaced Qwen3.** Released 2026-02-16, with the smaller
   dense models following on 2026-02-24. Alibaba's claim is support for
   **201 languages and dialects**, up from 119 in Qwen3, with a 256k
   native context. It is Apache 2.0.
2. **The size ladder shifted.** There is no `qwen3.5:8b` or
   `qwen3.5:14b`. The dense sizes are 0.8B, 2B, 4B, 9B and 27B, plus
   MoE 35B-A3B and 122B-A10B. So the 16 GB pick becomes 9B (slightly
   larger than the old 8B recommendation) and the 32 GB pick becomes
   27B (much larger than the old 14B recommendation, and still a
   comfortable fit).
3. **Gemma 4 replaced Gemma 3, and is now Apache 2.0.** Released
   2026-04-02, sizes 12B / 26B / 31B plus the E2B/E4B edge variants,
   256k context, "over 140 languages". The licence change removes the
   Gemma Terms of Use objection, so Gemma is a cleaner fallback than it
   was.

The `gemma3:4b` floor still exists in the library and the bridge default
is unchanged, so nothing breaks by doing nothing.

## Why Qwen and not one of the Arabic-specialist models

This is the part worth reading, because the obvious answer is wrong.

There is a real and growing set of Arabic-first open models, and on
Arabic benchmarks they beat general multilingual models of the same
size. The strongest current example is **Fanar-2-27B-Instruct** from
QCRI: Apache 2.0, 27B, built by continuing to pretrain Gemma 3 27B on
about 166 billion Arabic and English tokens, and it reports ArabicMMLU
74.67, Belebele 86.81 and ACVA 82.70 — beating `gemma-3-27b-it`, its own
base model, and holding its own against Qwen3-32B.

They are still the wrong choice for this app, for one structural
reason: **the bridge has one model for all four languages.**
`bridge_config.json` has a single `ollamaModel` field, and the bridge
uses it for `en`, `ar`, `sv` and `so` alike. Fanar-2 is documented as an
Arabic-English model; the card names no other natural language. The same
is true of the rest of the family — Jais, ALLaM, AceGPT and
`command-r7b-arabic` are all bilingual Arabic/English by design, and
`command-r7b-arabic`'s own 23-language list omits both Swedish and
Somali. Some of them are actively worse than a general model would be
on the other languages, because they spent their vocabulary on Arabic:
Jais-2 carries a 150k Arabic-centric vocabulary and ALLaM only 64k
tokens in total. Adopting one would fix Arabic and break Swedish and
Somali.

The other problem is distribution. Of the Arabic-first models, only
Cohere's `command-r7b-arabic` (5.1 GB) is in the official Ollama
library, and it has not been updated in about a year. It is also the one
Arabic-specialist with published numbers small enough to be relevant
here — its own card reports ArabicMMLU 60.9 and Arabic IFEval 69.0 at
about 8B parameters, which puts the ceiling for a 7–8B Arabic
specialist well below Fanar-2's 74.67 at 27B. Its licence is CC-BY-NC
with an acceptable-use policy attached; free for a family's own use, but
worth knowing. Its Hugging Face repo is gated behind a contact-details
form, though the Ollama library copy pulls without an account, which
keeps it inside the project's no-accounts rule. Everything else is
either community-uploaded under a personal namespace — the Ollama search
for "arabic" returns `iKhalid/ALLaM`, `ahmgam/acegpt-v2`,
`emr/silma-9b-instruct`, `jwnder/jais-adaptive` and similar, with
unstated quantisation and no upstream maintenance — or needs a GGUF
pulled from Hugging Face by hand. `ollama.com/library/fanar`,
`/allam`, `/jais`, `/silma` and `/acegpt` are all 404.

The Hugging Face route does work for some of them. Community GGUF
conversions of Fanar are pullable with no account —
`ollama pull hf.co/mradermacher/Fanar-2-27B-Instruct-GGUF` (Q4_K_M
15.4 GiB) or `hf.co/mradermacher/Fanar-1-9B-Instruct-GGUF` (Q4_K_M
5.0 GiB, and note Fanar-1 has only a 4k context). QCRI's own card
claims GGUF quantisations exist for Ollama and LM Studio, but its
repository holds safetensors only, so the working route is a
third-party quant rather than a first-party one.

Two traps in this area are worth writing down, because a web search
will walk you straight into both:

- **Jais-2 is gated.** Inception's Jais-2-8B and 70B are Apache 2.0
  and ship official GGUF repos, but every Jais repo is behind Hugging
  Face's "share your contact information" gate, and an anonymous fetch
  of the GGUF returns HTTP 401. No community mirror of Jais-2 exists.
  It therefore fails the project's no-accounts rule outright. (The
  older `jais-adapted-7b-chat` has ungated community mirrors.)
- **Falcon-H1-Arabic's weights do not appear to be public.** TII
  announced 3B/7B/34B Arabic models in January 2026 with the best OALL
  numbers of anything in this note, and several blog posts cheerfully
  hand you `ollama run hf.co/tiiuae/Falcon-H1-Arabic-7B-Instruct-GGUF`.
  That repository does not exist; nor does any Arabic-named model
  anywhere in TII's 137-model Hugging Face org. The announcement links
  to no weights. Falcon-Arabic is likewise absent from the Ollama
  library, whose "falcon" search returns `falcon`, `falcon2` and
  `falcon3` only. If you see this recommendation elsewhere, it is
  invented.

**If Arabic stays unacceptable at 27B, the right next move is a code
change, not a bigger download:** teach the bridge to pick a model per
language, then run Fanar-2 for `ar` — via
`ollama pull hf.co/mradermacher/Fanar-2-27B-Instruct-GGUF`, about
15.4 GiB at Q4_K_M — and keep a multilingual model for the other three.
That is a separate ticket and a fair amount of work: the config schema,
the health check and the two-pass generator all assume one model. It is
worth doing only if the read-aloud test fails on `qwen3.5:27b`.

## The Arabic evidence

Honest framing first: there is no benchmark that measures "writes a
grammatically correct six-page children's story in simple Modern
Standard Arabic". Everything below is a proxy, and the work order is
right that the native-speaker read-aloud is the real acceptance test.

The best current Arabic evaluation is **QIMMA** (قِمّة), published by TII
in April 2026. It is worth trusting more than the older Arabic
leaderboards because its whole point is benchmark hygiene: 14 source
benchmarks over 109 subsets and 52,000+ samples, more than 99% of it
natively Arabic rather than translated, with an explicit pipeline for
finding and fixing broken items in the benchmarks it inherited.

Its top ten as published:

| Rank | Model | Avg |
| --- | --- | --- |
| 1 | Qwen/Qwen3.5-397B-A17B-FP8 | 68.06 |
| 2 | Applied-Innovation-Center/Karnak | 66.20 |
| 3 | inceptionai/Jais-2-70B-Chat | 65.81 |
| 4 | Qwen/Qwen2.5-72B-Instruct | 65.75 |
| 5 | Applied-Innovation-Center/AIC-1 | 65.37 |
| 6 | Qwen/Qwen3.5-122B-A10B | 64.84 |
| 7 | Sakalti/Ultiima-72B | 64.49 |
| 8 | meta-llama/Llama-3.3-70B-Instruct | 63.96 |
| 9 | Qwen/Qwen2.5-32B-Instruct | 63.26 |
| 10 | FreedomIntelligence/AceGPT-v2-32B-Chat | 61.14 |

Two things to take from it. Qwen is the general-purpose family that
shows up repeatedly, including at the top; and everything in the list is
far too large for this PC, so the ranking transfers to our size band
only by family reputation, not directly. That is the main weakness in
this note: **I could not obtain per-model Arabic scores at the 4B, 9B
and 27B sizes.** The QIMMA leaderboard space and its results dataset
are dynamic and did not render or serve rows to a plain fetch, and the
published blog post shows only the top ten.

The indirect evidence that Qwen beats Gemma on Arabic at comparable size
is the Fanar-2 card: QCRI took Gemma 3 27B, spent ~166B tokens of
Arabic-heavy continued pretraining on it, and the result only reaches
parity with Qwen3-32B. Qwen3-32B got there without the Arabic-specific
training. That is a reasonable, if second-hand, argument for Qwen.

Two older evaluations back this up from a different direction, and both
argue against the intuition that an Arabic specialist must win:

- **OALL v2**, the Open Arabic LLM Leaderboard maintained jointly by
  OALL, 2A2I, TII and Hugging Face, has **Llama-3.3-70B-Instruct
  leading every category**, ahead of the Arabic-specialist models. A
  general multilingual model at the top of an Arabic leaderboard is
  the same conclusion this note reaches, arrived at independently.
- **BALSAM** (ACL ArabicNLP 2025) evaluated 22 models over 78 Arabic
  tasks and 52,000 examples with blind test sets. Under LLM-as-judge
  scoring, the Arabic-centric models land in a tight, unimpressive
  band: Fanar 1.62, SILMA-9B 1.55, Jais-13B-chat 1.53,
  AceGPT-v2-8B 1.39, against GPT-4o at 2.05. Being Arabic-specialised
  bought them very little.

BALSAM also carries the single most useful methodological warning for
this ticket: **SILMA-9B ranked first on automatic metrics (ROUGE/BLEU)
and fell to the lower third under LLM-as-judge**, because terse output
games n-gram scoring. Every "top-ranked Arabic model" claim on a vendor
model card — including the ArabicMMLU numbers quoted above — should be
read with that in mind. It is another reason the read-aloud test in
`STORY_QUALITY_UPGRADE.md` step 5 is the only acceptance test that
counts.

Secondary sources — a local-LLM roundup dated 2026-08-28 and an
Arabic-NLP blog post dated 2026-05-03 — both independently land on
"Qwen for the best multilingual option with strong Arabic, an
Arabic-specialist if Arabic is all you need". Neither cites primary
data. Both are also unreliable in a specific way: they quote
Falcon-H1-Arabic scores (71.47% and 75.36%, for the same model) and the
first hands out a `hf.co/tiiuae/Falcon-H1-Arabic-7B-Instruct-GGUF` pull
command for a repository that does not exist. Treat them as evidence
that the consensus points at Qwen, and as evidence of nothing else.

## Somali

Somali is the weakest of the four languages in every model considered,
and no model here fixes it. It is also the language that most firmly
rules out the Arabic specialists: Somali appears in none of their
language lists — not Fanar's paper, not ALLaM's, SILMA's, Jais's or
AceGPT's cards, and not in `command-r7b-arabic`'s 23 languages.

Concretely: **Somali is absent from every published Qwen language
table I could find.** The Qwen3 release post lists all 119 supported
languages and dialects; Somali is not among them, while Swedish is. The
Qwen3.5-Omni technical report is the only Qwen3.5 document with a
language table at all, and it does not enumerate the 201 text languages
either — it gives a count for text and enumerates only the speech
lists, whose 29 speech-output languages include Swedish and not Somali.
So whether Somali was added in the jump from 119 to 201 is
**unverified**. Gemma 4's card claims "over 140 languages" and likewise
does not enumerate them.

The only direct evidence on Somali generation quality is *SomaliBench
Eval* (arXiv 2605.25420, Khalid Yusuf Dahir, May 2026). It is a small,
single-author safety study, not a quality benchmark, but its failure
taxonomy is exactly our failure mode. Of 100 Somali prompts, the counts
of responses classified as unclear output — "wrong-language, incoherent,
or off-topic generations" — were:

| Model | Unclear Somali responses (of 100) |
| --- | --- |
| Gemma-2-9B-Instruct | 30 |
| Qwen-2.5-7B-Instruct | 71 |
| Llama-3.1-8B-Instruct | 81 |
| Aya-23-8B | 91 |

The paper's own categories are "answers in English or another unrelated
language rather than Somali" and "repeats generic Somali fragments or
malformed phrases". That is the same class of defect the bridge's
language-purity check exists to catch.

Take this as directional only: it is 100 prompts, one annotator, older
model generations, and a harmful-prompt set rather than storybook prose.
But it is the one signal available, and it points the other way from
Arabic — **Gemma handled Somali markedly better than Qwen at comparable
size.** So if Somali turns out to be the loudest complaint after the
upgrade, `gemma4:12b` is the model to try, and the per-language-model
change described above becomes more attractive.

## Swedish

No specific weakness found, and no specific evidence either. Swedish is
explicitly in Qwen3's published 119-language table and in the
Qwen3.5-Omni speech-output list, and it is a high-resource European
language that every model in this note will have seen a great deal of. I
looked for a current Swedish generation leaderboard (ScandEval is the
obvious one) and could not retrieve 2026 results for these models. Treat
Swedish as low risk but unmeasured. The work order's "serviceable but
plain" assessment is probably still accurate and should improve with
size like everything else.

## Two operational notes before pulling anything

These are not model-choice questions, but they will affect whether the
upgrade looks like a success, so they are worth knowing now.

**Every recommended model is a thinking model.** `qwen3.5` and `gemma4`
both carry the `thinking` capability badge on Ollama, and Qwen's own
card says Qwen3.5 "operate[s] in thinking mode by default, generating
thinking content signified by `<think>\n...</think>`". Ollama's API
documents a `think` parameter on `/api/generate` that accepts `false` or
a level. The bridge does not send it: `OllamaGenerateRequest.toJson()`
sends `model`, `prompt`, `stream` and `format` only. Best case the
thinking tokens are simply wasted time on every one of the two calls per
story; worst case they interact badly with the JSON schema in `format`.
If generation gets strangely slow or starts returning invalid output
after the model swap, this is the first thing to look at.

**The default context window will be 4k.** Ollama's documentation states
it picks the context length from available VRAM: under 24 GiB of VRAM it
uses 4k. This PC has 4 GB, so 4k it is, regardless of the 256k the model
supports. A six-page story prompt with the outline embedded, plus six
pages of output, plus Arabic's poor tokenisation ratio, is not obviously
under 4k. If pages come back truncated, raise it at the server:

```
OLLAMA_CONTEXT_LENGTH=16000 ollama serve
```

More context costs more memory, so add it to the resident-RAM figures in
the table above if you do.

## What I could not verify

Listed plainly, because the recommendation rests partly on inference:

- Per-model Arabic scores at 4B / 9B / 27B. The claim that
  `qwen3.5:9b` is the best Arabic writer in its size class is an
  extrapolation from family-level results, not a measurement.
- Whether Somali is in Qwen3.5's 201 languages. The list is not
  published.
- Whether an *official* Fanar-2 GGUF exists. The model card says yes;
  the repository holds safetensors. Community quants do exist and pull
  anonymously, which is enough for the fallback plan.
- Whether Falcon-H1-Arabic's weights are published anywhere at all. TII
  announced the models and the numbers; I could find no repository, and
  absence of evidence here is close to evidence of absence, since the
  whole 137-model org was enumerated.
- Anything about how these models handle simple Modern Standard Arabic
  specifically, as opposed to Arabic knowledge benchmarks. Only the
  read-aloud test in `STORY_QUALITY_UPGRADE.md` step 5 can answer that.

## Sources

Ollama library (primary):

- [Ollama library, sorted by newest](https://ollama.com/library?sort=newest)
- [`qwen3.5`](https://ollama.com/library/qwen3.5) ·
  [all tags and sizes](https://ollama.com/library/qwen3.5/tags) ·
  [`qwen3.5:9b` details](https://ollama.com/library/qwen3.5:9b)
- [`qwen3.6`](https://ollama.com/library/qwen3.6) ·
  [`qwen3.8`](https://ollama.com/library/qwen3.8)
- [`gemma4`](https://ollama.com/library/gemma4) ·
  [`gemma4:12b` details](https://ollama.com/library/gemma4:12b)
- [`command-r7b-arabic`](https://ollama.com/library/command-r7b-arabic)
- [Ollama library search: "arabic"](https://ollama.com/search?q=arabic) ·
  [search: "falcon"](https://ollama.com/search?q=falcon)
- [Ollama docs — context length defaults](https://github.com/ollama/ollama/blob/main/docs/context-length.mdx)
- [Ollama docs — API, `think` and `format`](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Hugging Face docs — using Ollama with any GGUF on the hub](https://huggingface.co/docs/hub/ollama)
  — the `hf.co/{user}/{repo}` pull syntax, and the fact that it
  documents no route for gated repositories

Model cards and releases (primary):

- [Qwen/Qwen3.5-9B](https://huggingface.co/Qwen/Qwen3.5-9B) — Apache 2.0
  and ungated per the hub API, 9B, 201 languages, thinking by default
- [Qwen3 release post](https://qwenlm.github.io/blog/qwen3/) — the
  published 119-language table
- [Qwen3.5-Omni technical report](https://arxiv.org/abs/2604.15804) —
  Table 3, the only Qwen3.5 language table; counts text languages
  without listing them, enumerates the speech lists
- [google/gemma-4-12B-it](https://huggingface.co/google/gemma-4-12B-it) —
  Apache 2.0 and ungated per the hub API, 11.95B, 140+ languages,
  256k context
- [Gemma 4: Expanding the Gemmaverse with Apache 2.0](https://opensource.googleblog.com/2026/03/gemma-4-expanding-the-gemmaverse-with-apache-20.html)
- [QCRI/Fanar-2-27B-Instruct](https://huggingface.co/QCRI/Fanar-2-27B-Instruct) —
  Apache 2.0, Arabic/English, ArabicMMLU 74.67
- [Fanar 2.0 collection](https://huggingface.co/collections/QCRI/fanar-20)
- [CohereLabs/c4ai-command-r7b-arabic-02-2025](https://huggingface.co/CohereLabs/c4ai-command-r7b-arabic-02-2025) —
  CC-BY-NC, ~8B, 23 languages excluding Swedish and Somali,
  ArabicMMLU 60.9
- [QCRI/Fanar-1-9B-Instruct](https://huggingface.co/QCRI/Fanar-1-9B-Instruct) —
  Apache 2.0, 4k context, ArabicMMLU 67.69
- [inception42/Jais-2-8B-Chat](https://huggingface.co/inception42/Jais-2-8B-Chat) —
  Apache 2.0 but gated; anonymous GGUF fetch returns 401
- [Falcon-H1-Arabic announcement](https://falconllm.tii.ae/falcon-h1-arabic.html)
  and [its Hugging Face blog post](https://huggingface.co/blog/tiiuae/falcon-h1-arabic)
  — the numbers everyone quotes; neither links to weights

Evaluations:

- [QIMMA قِمّة: A Quality-First Arabic LLM Leaderboard](https://huggingface.co/blog/tiiuae/qimma-arabic-leaderboard)
  (TII, 2026-04-21) — the top-ten table above
- [Are Arabic Benchmarks Reliable? QIMMA's Quality-First Approach to LLM
  Evaluation](https://arxiv.org/abs/2604.03395) (arXiv 2604.03395,
  2026-04-03) — the methodology
- [SomaliBench Eval](https://arxiv.org/abs/2605.25420) (arXiv 2605.25420,
  2026-05) — the Somali failure counts
- [BALSAM](https://arxiv.org/abs/2507.22603) (arXiv 2507.22603, ACL
  ArabicNLP 2025) — 22 models, 78 Arabic tasks, LLM-as-judge versus
  automatic metrics
- [Open Arabic LLM Leaderboard v2](https://huggingface.co/blog/leaderboard-arabic-v2)
  (OALL, 2A2I, TII, Hugging Face) — Llama-3.3-70B-Instruct leads all
  categories
- [Open Arabic LLM Leaderboard space](https://huggingface.co/spaces/OALL/Open-Arabic-LLM-Leaderboard)
  and [SILMA's Arabic Broad Leaderboard](https://huggingface.co/spaces/silma-ai/Arabic-LLM-Leaderboard)
  — both are live Spaces; neither served data to a plain fetch, so
  nothing in this note depends on their current rankings

Weaker evidence, flagged as such where used:

- [Best Arabic Local LLMs 2026](https://www.promptquorum.com/local-llms/best-arabic-local-llms-2026)
  (2026-08-28) — roundup, no primary citations for its numbers, and it
  publishes a pull command for a Hugging Face repository that does not
  exist; do not act on it
- [Qwen 3.6 for Arabic NLP](https://hosn.om/blog/qwen-3-6-arabic-nlp-benchmarks.html)
  (2026-05-03, updated 2026-08-21) — explicitly cites no sources
