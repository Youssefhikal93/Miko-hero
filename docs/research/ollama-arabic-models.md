# Arabic-capable Ollama models per RAM band

Research note for issue #8. Checked on **2026-09-03** against the Ollama
model library, the model authors' own model cards and release posts, and
four independent evaluations. Everything *recommended* here is a free
download from a public library or the Hugging Face hub: no account, no
key, no per-token cost, nothing leaves the machine after the download.
Where a model fails that test it is named and ruled out, not quietly
dropped.

This note re-checks the model table in `docs/STORY_QUALITY_UPGRADE.md`,
which was written on 2026-08-31 and recommends the Qwen family.

## Bottom line

**Qwen still holds at 8 GB and 16 GB. It does not hold at 32 GB, and
the tags in the work order are wrong everywhere.**

Three things to carry away:

1. `qwen3:*` has been superseded by `qwen3.5:*` (February 2026) and the
   size ladder changed: 4B / 9B / 27B, not 4B / 8B / 14B. The upgrade is
   not optional — **Qwen3-8B scores 39.38 on the QIMMA Arabic suite and
   Qwen3.5-9B scores 56.28.** The old recommendation was pointing at a
   model that is bad at Arabic.
2. At the top band there is now a direct measurement, and it goes the
   other way: **`gemma3:27b` scores 60.75 on QIMMA Arabic against
   `qwen3.5:27b`'s 59.70, at the same 17 GB download.** That margin is
   within noise on its own, but Gemma also wins Somali by a wide and
   well-measured margin, so the 32 GB pick changes family.
3. **Somali is the reason this is not a pure Arabic decision.** On
   Belebele Somali, the whole Qwen3 lineage sits at chance (Qwen3-8B
   33.78, chance ≈ 25) while Gemma3-12B reaches 69.33. Qwen3.5 clearly
   improved it — Qwen3.5-4B jumps to 53.82 — but Gemma remains far
   ahead.

Nothing else about the work order changes: it is still one line in
`bridge_config.json`, and the native-speaker read-aloud in step 5 is
still the only test that decides whether the upgrade worked. The table
in step 3 should be replaced with the one below.

## Recommendation per RAM band

Sizes are the Ollama download. Resident RAM is the download plus the
runtime overhead Ollama adds; on a machine with 4 GB of VRAM, Ollama
defaults to a 4k context window, so the KV cache is small and the
download size dominates.

| System RAM | `ollama pull` | Params | Quant | Download | Approx. resident | QIMMA Arabic | Why |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ~8 GB | `qwen3.5:4b` | 4.66B | Q4_K_M | 3.4 GB | ~5 GB | not measured | Beats `gemma3:4b` on both Somali measures and is a generation newer. Still a 4B model: expect the Arabic read-aloud test to fail. |
| ~16 GB | **`qwen3.5:9b`** | 9.65B | Q4_K_M | 6.6 GB | ~8–9 GB | **56.28** | The pick. Only model in this size class with a measured Arabic score, and the best Arabic-per-gigabyte on offer. |
| ~32 GB | **`gemma3:27b`** | 27B | Q4_K_M | 17 GB | ~19–20 GB | **60.75** | The pick, and a change from the work order. Best measured Arabic of anything that fits, and much stronger Somali. |

Close alternatives, all one config line away:

| Band | Alternative | Download | Trade |
| --- | --- | --- | --- |
| ~16 GB | `gemma3:12b` | 8.1 GB | 1.5 GB larger and no measured Arabic score at this size, but **the best Somali of any stock model measured anywhere** (Belebele 69.33). Pick this instead if Somali is the complaint. |
| ~16 GB | `gemma4:12b-it-qat` | 7.2 GB | Newer, Apache 2.0, 256k context, better aggregate scores. But Google publishes **no** Arabic, Swedish or Somali evidence for Gemma 4 at all. A bet, not a measurement. |
| ~32 GB | `qwen3.5:27b` | 17 GB | 1.05 points behind on QIMMA Arabic, ahead on Arabic *dialect* translation, well behind on Somali. Apache 2.0 and 256k context where Gemma 3 is 128k and a custom licence. |
| ~32 GB | `gemma4:31b-it-qat` | 19 GB | Same unmeasured-newer bet as `gemma4:12b`, one size up. |

Two tag-level details worth knowing:

- **For Gemma, prefer the `-it-qat` tags where they exist.** Google
  ships quantisation-aware-trained weights, which give better quality
  at the same or smaller size: `gemma4:12b-it-qat` is 7.2 GB against
  `gemma4:12b`'s 7.6 GB. (`gemma3:12b-it-qat` is 8.9 GB, larger than
  the plain 8.1 GB tag, so there the trade is size for quality.)
- **Never point the bridge at a `-cloud` tag.** Ollama's own docs say
  structured outputs are not supported on Ollama Cloud, and the bridge
  depends entirely on `format` holding a JSON schema. `qwen3.5:cloud`
  and `gemma4:cloud` exist and would break generation.

Do **not** pick from the "newest" list on the Ollama library front page
without checking what the model was tuned for. `qwen3.6` (April 2026)
and `qwen3.8` (August 2026) are newer than `qwen3.5` and both describe
themselves in terms of agentic coding and long-horizon tasks. Neither
has any published Arabic, Swedish or Somali evidence.

## What changed since the work order was written

The work order's table is roughly a year behind the library, not eight
days. Four things moved:

1. **Qwen3.5 replaced Qwen3**, released 2026-02-16 with the small dense
   models following on 2026-03-02. Alibaba claims 201 languages and
   dialects, up from 119, with 262,144 native context. Apache 2.0.
2. **The size ladder shifted.** There is no `qwen3.5:8b` or
   `qwen3.5:14b`. The dense sizes are 0.8B, 2B, 4B, 9B and 27B, plus
   MoE 35B-A3B and 122B-A10B.
3. **Gemma 4 arrived** (late March / early April 2026) and is Apache
   2.0, removing the licence objection to the Gemma family — but it
   arrived with no per-language evaluation published at all, which is
   why this note still recommends Gemma **3** at 32 GB.
4. **QIMMA was published** (TII, April 2026) and it is the first Arabic
   evaluation with usable numbers for models this size. Most of the
   revision in this note comes from it.

The `gemma3:4b` floor still exists in the library and the bridge default
is unchanged, so nothing breaks by doing nothing.

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

These are its scores for the models that matter here, read out of the
paper's own results table. "Poetry" is QIMMA's Poetry and Literature
domain — the closest thing in the suite to writing children's prose.
"Cultural" is the ArabCulture and ArabicMMLU-style knowledge domain.

| Model | Avg | Cultural | Poetry | Note |
| --- | --- | --- | --- | --- |
| Jais-2-70B-Chat | 65.81 | 81.95 | 56.13 | Far too large; gated |
| Qwen2.5-72B-Instruct | 65.75 | 72.94 | 57.51 | Far too large |
| Llama-3.3-70B-Instruct | 63.96 | 77.74 | 24.43 | Far too large |
| AceGPT-v2-32B-Chat | 61.14 | 76.97 | 15.56 | Arabic/English only |
| **gemma-3-27b-it** | **60.75** | 58.84 | **59.74** | `gemma3:27b`, 17 GB |
| **Qwen3.5-27B** | **59.70** | 60.61 | 47.03 | `qwen3.5:27b`, 17 GB |
| Jais-2-8B-Chat | 57.89 | 71.18 | 51.94 | Best at 8B, but gated |
| Fanar-1-9B-Instruct | 56.78 | 72.78 | 0.02 | Arabic/English; 4k context |
| ALLaM-7B-Instruct | 56.51 | 63.86 | 48.48 | Arabic/English only |
| **Qwen3.5-9B** | **56.28** | 59.39 | **59.57** | `qwen3.5:9b`, 6.6 GB |
| Qwen3-8B | 39.38 | 35.37 | 57.47 | **the old recommendation** |
| gpt-oss-20b | 32.10 | 28.35 | 15.34 | last of 14 |

TII's own leaderboard post is a useful cross-check on that table: its
published top ten ends at AceGPT-v2-32B-Chat on 61.14, and the two
models this note cares about sit immediately below that cutoff, in the
order shown. Across the 46 models on the live leaderboard the overall
leader is Qwen3.5-397B-A17B at 68.06 — a Qwen, but four hundred billion
parameters of one.

What to take from the table:

- **The generational jump is the headline.** Qwen3-8B at 39.38 is bad at
  Arabic; Qwen3.5-9B at 56.28 is respectable. Whatever else this note
  concludes, moving off `qwen3:*` is the right call.
- **`gemma3:27b` is the best Arabic model that fits this PC.** It beats
  `qwen3.5:27b` at the same download size, and it ranks first in the
  whole suite on Poetry and Literature. Treat the 1.05-point average
  gap as a tie and the Poetry result as suggestive rather than proven —
  that benchmark is clearly format-sensitive, since Fanar-1-9B scored
  0.02 on it, which is a JSON-shaped failure and not a language one.
- **Gemma's weakness is culture, not language.** `gemma-3-27b-it` scores
  58.84 on Cultural against 68.64 on STEM. For a storybook about a
  child's own day this matters much less than it would for a model
  answering questions about Arab history.
- **`qwen3.5:9b` punches above its size on the one domain closest to our
  use case**, scoring 59.57 on Poetry — level with the 27B models. Again,
  suggestive, not proven.
- Two secondary confirmations of the ceiling at small sizes:
  `command-r7b-arabic`'s own card reports ArabicMMLU 60.9 at about 8B
  and loses that benchmark to Gemma 2 9B (62.4); and Jais-2-8B-Chat,
  the best 8B-class model in QIMMA, is only 1.6 points ahead of
  `qwen3.5:9b`.

Two other evaluations back the same picture from a different direction:

- **OALL v2**, the Open Arabic LLM Leaderboard maintained by OALL, 2A2I,
  TII and Hugging Face, has Llama-3.3-70B-Instruct leading every
  category, ahead of the Arabic specialists. A general multilingual
  model at the top of an Arabic leaderboard is the same conclusion this
  note reaches, arrived at independently.
- **BALSAM** (ACL ArabicNLP 2025) evaluated 22 models over 78 Arabic
  tasks and 52,000 examples with blind test sets. Under LLM-as-judge
  scoring the Arabic-centric models land in a tight, unimpressive band:
  Fanar 1.62, SILMA-9B 1.55, Jais-13B-chat 1.53, AceGPT-v2-8B 1.39,
  against GPT-4o at 2.05.

BALSAM also carries the most useful methodological warning for this
ticket: **SILMA-9B ranked first on automatic metrics (ROUGE/BLEU) and
fell to the lower third under LLM-as-judge**, because terse output games
n-gram scoring. Every "top-ranked Arabic model" claim on a vendor card
should be read with that in mind. It is another reason the read-aloud
test is the only acceptance test that counts.

## Why not one of the Arabic-specialist models

This is the part worth reading, because the obvious answer is wrong.

There is a real and growing set of Arabic-first open models, and several
of them do beat general models of the same size on Arabic —
Jais-2-8B-Chat at 57.89 is the best 8B-class model in QIMMA, and
**Fanar-2-27B-Instruct** (Apache 2.0, ArabicMMLU 74.67) is the strongest
Arabic model that would physically fit a 32 GB machine.

They are the wrong choice here for one structural reason: **the bridge
has one model for all four languages.** `bridge_config.json` has a
single `ollamaModel` field and the bridge uses it for `en`, `ar`, `sv`
and `so` alike. Every one of these models is Arabic and English only.
`command-r7b-arabic`'s own 23-language list omits both Swedish and
Somali. Some are actively worse than a general model would be on the
other three, because they spent their vocabulary on Arabic: Jais-2
carries a 150,272-token Arabic-centric vocabulary, ALLaM only 64,000
tokens in total. Adopting one fixes Arabic and breaks Swedish and
Somali.

There is also a striking piece of evidence that the specialists have
less headroom than they look like they do. **Fanar-2-27B was built by
continuing to pretrain `gemma-3-27b-pt` on roughly 120–166 billion
Arabic-heavy tokens.** For all that work it moved ArabicMMLU by about
2.5 points over `gemma-3-27b-it` (74.67 against 72.21) and it *loses* on
OALL v2 (69.40 against 70.95). A dedicated Arabic team spending that
much compute on Gemma 3 27B barely improved it — which is a strong
argument that Gemma 3 27B is already a good Arabic model, and the
reason this note is comfortable recommending it.

The other problem is distribution. `ollama.com/library/fanar`, `/allam`,
`/jais`, `/silma` and `/acegpt` are all 404. Only Cohere's
`command-r7b-arabic` (5.1 GB) has an official library page, it has not
been updated in about a year, its licence is CC-BY-NC with an
acceptable-use policy, and Ollama's packaging caps its context at 16k
where the card advertises 128k. Everything else is either
community-uploaded under a personal namespace — `iKhalid/ALLaM`,
`salmatrafi/acegpt`, `emr/silma-9b-instruct`, `jwnder/jais-adaptive`,
with unstated quantisation and no upstream maintenance — or needs a GGUF
pulled from Hugging Face by hand.

Community GGUF conversions of Fanar are pullable with no account —
`ollama pull hf.co/mradermacher/Fanar-2-27B-Instruct-GGUF` (Q4_K_M
15.4 GiB) or `hf.co/mradermacher/Fanar-1-9B-Instruct-GGUF` (Q4_K_M
5.0 GiB, and note Fanar-1 has only a 4k context). QCRI's own card claims
GGUF quantisations exist for Ollama, but its repository holds
safetensors, so the working route is a third-party quant.

Two traps in this area are worth writing down, because a web search will
walk you straight into both:

- **Jais-2 is gated.** Inception's Jais-2-8B and 70B are Apache 2.0 and
  ship official GGUF repos, but every Jais repo sits behind Hugging
  Face's "share your contact information" gate and an anonymous fetch
  of the GGUF returns HTTP 401. No community mirror of Jais-2 exists.
  It fails the project's no-accounts rule outright.
- **Falcon-H1-Arabic's weights do not appear to be public.** TII
  announced 3B/7B/34B Arabic models in January 2026 with the best OALL
  numbers of anything in this note (71.7% at 7B), and several blog posts
  hand you `ollama run hf.co/tiiuae/Falcon-H1-Arabic-7B-Instruct-GGUF`.
  That repository does not exist; nor does any Arabic-named model
  anywhere in TII's Hugging Face org, enumerated in full through the
  hub API. Falcon-Arabic is likewise absent from the Ollama library. If
  you see that recommendation elsewhere, it is invented.

**If Arabic is still unacceptable on `gemma3:27b`, the next move is a
code change, not a bigger download:** teach the bridge to pick a model
per language, run Fanar-2 for `ar` and keep a multilingual model for the
other three. That is a separate ticket and a fair amount of work — the
config schema, the health check and the two-pass generator all assume
one model — and it is worth doing only after the read-aloud test has
actually failed.

## Also ruled out

- **Llama.** Arabic is not an officially supported language before Llama
  4 — Llama 3.1, 3.2 and 3.3 all list eight languages and Arabic is not
  among them, with the card naming other languages as out of scope.
  Llama 4 Scout does list Arabic, but the smallest Llama 4 on Ollama is
  67 GB. There is no small Llama with official Arabic support.
- **`gpt-oss:20b`.** Last of fourteen models on QIMMA at 32.10, last on
  eleven of its fourteen benchmarks, and OpenAI publishes no supported
  language list of any kind. The paper's own note is that thinking
  cannot compensate for limited Arabic. Its 76.3 on multilingual MMLU
  is multiple choice, not generation, and misleads.
- **Cohere Aya Expanse, Aya 23, Command A.** All CC-BY-NC, and Aya's
  23-language list excludes both Swedish and Somali. Aya-101 is the only
  Cohere model that declares Somali, and it is a 2024 mT5 sequence model
  with no modern chat template and no Ollama presence.
- **Mistral Small 3.2 (15 GB)** is the interesting near-miss: it declares
  both Arabic and Swedish, it is Apache 2.0, and Mistral makes the
  strongest structured-output commitment of any vendor. But Mistral
  publishes no Arabic benchmark numbers anywhere, and Somali is not in
  its list. Worth a try only as a curiosity.
- **IBM `granite4.2:8b` (5.3 GB)** declares Arabic but not Swedish or
  Somali, and publishes no Arabic numbers.

## Somali

Somali is the weakest of the four languages in every model considered,
and no option here fixes it. It is also the language that most firmly
rules out the Arabic specialists: Somali appears in none of their
language lists — not Fanar's paper, not ALLaM's, SILMA's, Jais's or
AceGPT's cards, and not in `command-r7b-arabic`'s 23 languages.

**Somali is absent from every published Qwen language table.** The Qwen3
release post enumerates all 119 supported languages and dialects and
Somali is not among them, while Swedish is; the only sub-Saharan African
language on the whole list is Swahili. The Qwen3 technical report's
Belebele language table has `arb_Arab` and `swe_Latn` but no `som_Latn`.
Qwen3.5 claims 201 languages, but that list is not published anywhere —
its own Omni technical report gives the count and then defers to a page
that has no list. So the expansion is uncheckable from documentation.

Google publishes no enumerated language list for Gemma 3 or Gemma 4 at
all, only counts ("over 140 languages" and "35+ out of the box"). The one
Google document that does enumerate is the **TranslateGemma** paper, and
its Appendix C lists Somali as a bidirectional English pair alongside six
Arabic varieties, with Swedish as a from-English pair. So Google trains
on Somali deliberately, and publishes no Somali quality number.

The measurements are better than the documentation. **AfriqueLLM**
(arXiv 2601.06395, accepted to ACL 2026) covers Somali as one of its 20
African languages and, usefully for us, publishes per-language numbers
for the stock base models it compares against. Belebele Somali is a
four-way multiple choice task, so chance is about 25:

| Model | Belebele Somali (5-shot) | FLORES en→so (chrF++) |
| --- | --- | --- |
| **Gemma3-12B** | **69.33** | 20.58 |
| Qwen3.5-4B | 53.82 | **22.19** |
| Gemma3-4B | 41.93 | 15.91 |
| Qwen3-14B | 35.13 | 15.17 |
| Qwen3-8B | 33.78 | 11.19 |
| Qwen3-4B | 33.47 | 9.63 |
| Llama3.1-8B | 32.71 | 17.38 |

Three reads, in order of confidence:

1. **The entire Qwen3 lineage is at or barely above chance on Somali
   comprehension**, exactly as its language list implies. The current
   bridge default `gemma3:4b` (41.93) is meaningfully better at Somali
   than `qwen3:8b` (33.78) ever was.
2. **Qwen3.5 genuinely fixed some of this.** Qwen3.5-4B at 53.82 is 20
   points above Qwen3-4B and has the best en→Somali generation score in
   the table. This is the only concrete evidence that the unpublished
   201-language expansion is real, and it is why `qwen3.5:4b` is the
   8 GB pick rather than staying on `gemma3:4b`.
3. **Gemma3-12B at 69.33 is the standout**, nearly matching a
   purpose-tuned Somali model. If Somali is what the family complains
   about, `gemma3:12b` is the answer at 16 GB and `gemma3:27b` at 32 GB.

But note the second column. **Somali *generation* is poor for everything
untuned** — the best stock score is 22.19 chrF++ against 42.14 for a
purpose-built Somali model. Comprehension improving does not mean the
model can write a Somali story well. Expect Somali to stay the weakest
of the four whatever is chosen.

There is one narrower confirmation. *SomaliBench Eval* (arXiv 2605.25420,
single author, August 2026) is a safety study, not a quality benchmark,
but its failure taxonomy is exactly our failure mode. Of 100 Somali
prompts, responses classified as unclear output — "wrong-language,
incoherent, or off-topic generations" — numbered 30 for Gemma-2-9B,
71 for Qwen-2.5-7B, 81 for Llama-3.1-8B and 91 for Aya-23-8B, and the
author reports Qwen produced no on-topic responses at all to *benign*
Somali prompts. That is the same class of defect the bridge's
language-purity check exists to catch, and it independently reproduces
the Gemma-over-Qwen ordering. Take it as directional only: 100 prompts,
one annotator, and it tests Gemma 2 and Qwen 2.5, a generation behind
everything recommended here.

Finally, worth knowing but not recommending: **`translategemma:12b`
(8.1 GB) is in the official Ollama library** and is the only model there
with primary-source proof that Somali was deliberately trained. It is a
translation model, not a chat model, so it cannot generate stories — but
if Somali stays broken it is the obvious component for a translate-after
approach.

## Swedish

No serious weakness found, and the evidence is thin but real. Swedish is
explicitly in Qwen3's published 119-language table, in Mistral Small
3.2's declared list, and in Falcon-H1's 18 — it is a high-resource
European language that every model here will have seen a great deal of.
It is absent from Cohere Aya's 23 and from Ministral 3 8B's list.

The only per-language Swedish quality numbers anyone publishes for a
model in this note are in the TranslateGemma paper, as MetricX on
en→sv_SE, where lower is better: Gemma 3 27B **2.73**, 12B **3.06**,
4B **4.14**. The same table gives en→ar_SA at 3.19 / 3.64 / 4.49. So for
both Arabic and Swedish, Gemma 3's quality degrades sharply below 12B —
which is the clearest size-versus-quality signal in this whole note, and
it applies to Swedish as much as to Arabic.

Otherwise: no Swedish-specific open-model evaluation surfaced, and I
could not retrieve current ScandEval results for any of these models.
Treat Swedish as low risk and largely unmeasured. The work order's
"serviceable but plain" assessment is probably still accurate and should
improve with size like everything else.

## Two operational notes before pulling anything

These are not model-choice questions, but they will affect whether the
upgrade looks like a success.

**Every recommended model is a thinking model.** `qwen3.5`, `gemma3` and
`gemma4` all carry the `thinking` capability badge on Ollama, and Qwen's
own card says Qwen3.5 "operate[s] in thinking mode by default,
generating thinking content signified by `<think>\n...</think>`". Ollama's
API documents a `think` parameter on `/api/generate` that accepts `false`
or a level. The bridge does not send it:
`OllamaGenerateRequest.toJson()` sends `model`, `prompt`, `stream` and
`format` only. Best case the thinking tokens are wasted time on both of
the two calls per story; worst case they interact badly with the JSON
schema in `format`. If generation gets strangely slow or starts
returning invalid output after the model swap, look here first.

The good news on the other side: **Ollama enforces structured output at
the runtime level**, not in the model, so the `format` schema the bridge
sends works with essentially any local model. The one exception is
Ollama Cloud, which its docs say does not support structured outputs —
hence the warning above about `-cloud` tags.

**The default context window will be 4k.** Ollama's documentation states
it picks context length from available VRAM: under 24 GiB it uses 4k.
This PC has 4 GB, so 4k it is, regardless of the 128k or 256k the model
supports. A six-page story prompt with the outline embedded, plus six
pages of output, plus Arabic's poor tokenisation ratio, is not obviously
under 4k. If pages come back truncated, raise it at the server:

```
OLLAMA_CONTEXT_LENGTH=16000 ollama serve
```

More context costs more memory, so add it to the resident-RAM figures in
the table above if you do.

## What I could not verify

Listed plainly, because parts of the recommendation rest on inference:

- **No Arabic, Swedish or Somali evaluation exists for Gemma 4, Qwen3.6
  or Qwen3.8.** The newest models are the least documented for exactly
  the languages this app cares about. That is why the 32 GB pick is
  Gemma **3**.
- **No Arabic score exists for `gemma3:12b` or `gemma4:12b`.** QIMMA
  measured `gemma-3-27b-it` but not the 12B. The 16 GB recommendation
  therefore compares a measured Qwen number against an unmeasured Gemma
  one, which is part of why `qwen3.5:9b` keeps that slot.
- **No Somali evaluation covers any current-generation model.** The
  Belebele numbers are Gemma 3 and Qwen3/3.5-4B; nobody has run Somali
  against `gemma4:12b` or `qwen3.5:9b`. Running full Global MMLU would
  settle Arabic, Swedish and Somali in one pass, since all three are in
  its 42 languages — that is a real, cheap piece of novel work if the
  question ever needs a firmer answer.
- **Whether Somali is in Qwen3.5's 201 languages.** The list is not
  published and the technical report defers to a page that lacks it.
- **Whether an official Fanar-2 GGUF exists.** The card says yes; the
  repository holds safetensors. Community quants pull anonymously,
  which is enough for the fallback plan.
- **Whether Falcon-H1-Arabic's weights are published anywhere.** TII
  announced the models and the numbers; no repository exists in their
  org, which was enumerated in full.
- Anything about how these models handle simple Modern Standard Arabic
  specifically, as opposed to Arabic knowledge and comprehension
  benchmarks. Only the read-aloud test can answer that.

## Sources

Ollama library and docs (primary, all read on 2026-09-03):

- [Ollama library, sorted by newest](https://ollama.com/library?sort=newest)
- [`qwen3.5`](https://ollama.com/library/qwen3.5) ·
  [tags](https://ollama.com/library/qwen3.5/tags) ·
  [`qwen3.5:4b`](https://ollama.com/library/qwen3.5:4b) ·
  [`qwen3.5:9b`](https://ollama.com/library/qwen3.5:9b) ·
  [`qwen3.5:27b`](https://ollama.com/library/qwen3.5:27b)
- [`gemma3`](https://ollama.com/library/gemma3/tags) ·
  [`gemma4`](https://ollama.com/library/gemma4) ·
  [`gemma4:12b`](https://ollama.com/library/gemma4:12b) ·
  [`translategemma`](https://ollama.com/library/translategemma/tags)
- [`qwen3.6`](https://ollama.com/library/qwen3.6) ·
  [`qwen3.8`](https://ollama.com/library/qwen3.8)
- [`command-r7b-arabic`](https://ollama.com/library/command-r7b-arabic)
- [Ollama library search: "arabic"](https://ollama.com/search?q=arabic) ·
  [search: "falcon"](https://ollama.com/search?q=falcon)
- [Ollama docs — context length defaults](https://github.com/ollama/ollama/blob/main/docs/context-length.mdx)
- [Ollama docs — API, `think` and `format`](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Ollama docs — structured outputs](https://docs.ollama.com/capabilities/structured-outputs)
- [Hugging Face docs — using Ollama with any GGUF on the hub](https://huggingface.co/docs/hub/ollama)
  — the `hf.co/{user}/{repo}` syntax, the Q4_K_M default, and the fact
  that no route is documented for gated repositories

Model cards and releases (primary):

- [Qwen/Qwen3.5-9B](https://huggingface.co/Qwen/Qwen3.5-9B) and
  [Qwen3.5-27B](https://huggingface.co/Qwen/Qwen3.5-27B) — Apache 2.0,
  ungated per the hub API, 201 languages, thinking by default
- [Qwen3 release post](https://qwenlm.github.io/blog/qwen3/) — the
  enumerated 119-language table: eight Arabic varieties, Swedish
  present, Somali absent
- [Qwen3 technical report](https://arxiv.org/abs/2505.09388) — Arabic
  per-language benchmarks, and the Belebele language table
- [Qwen3.5-Omni technical report](https://arxiv.org/abs/2604.15804) —
  counts the 201 text languages without listing them
- [Gemma 3 model card](https://ai.google.dev/gemma/docs/core/model_card_3)
  and [Gemma 4 model card](https://ai.google.dev/gemma/docs/core/model_card_4)
  — "over 140 languages" and "35+ out of the box", neither enumerated
- [Gemma releases page](https://ai.google.dev/gemma/docs/releases)
- [google/gemma-4-12B-it](https://huggingface.co/google/gemma-4-12B-it) —
  Apache 2.0 and ungated per the hub API, 11.95B, 256k context
- [TranslateGemma](https://arxiv.org/abs/2601.09012) — Appendix C, the
  only Google-published language list; names Somali and Swedish, and
  gives per-language MetricX for Gemma 3 4B/12B/27B on Arabic and
  Swedish
- [QCRI/Fanar-2-27B-Instruct](https://huggingface.co/QCRI/Fanar-2-27B-Instruct)
  and [Fanar-1-9B-Instruct](https://huggingface.co/QCRI/Fanar-1-9B-Instruct)
- [CohereLabs/c4ai-command-r7b-arabic-02-2025](https://huggingface.co/CohereLabs/c4ai-command-r7b-arabic-02-2025) —
  CC-BY-NC, 23 languages excluding Swedish and Somali, ArabicMMLU 60.9
- [inception42/Jais-2-8B-Chat](https://huggingface.co/inception42/Jais-2-8B-Chat) —
  Apache 2.0 but gated; anonymous GGUF fetch returns 401
- [meta-llama/Llama-3.1-8B-Instruct](https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct)
  and [Llama-4-Scout-17B-16E-Instruct](https://huggingface.co/meta-llama/Llama-4-Scout-17B-16E-Instruct)
  — the official language lists, Arabic absent before Llama 4
- [Falcon-H1-Arabic announcement](https://falconllm.tii.ae/falcon-h1-arabic.html)
  and [its Hugging Face blog post](https://huggingface.co/blog/tiiuae/falcon-h1-arabic)
  — the numbers everyone quotes; neither links to weights

Evaluations:

- [QIMMA قِمّة: A Quality-First Arabic LLM Leaderboard](https://huggingface.co/blog/tiiuae/qimma-arabic-leaderboard)
  (TII, 2026-04-21) and
  [the paper](https://arxiv.org/abs/2604.03395) (arXiv 2604.03395) —
  the per-model table above comes from Table 3 of the paper
- [AfriqueLLM](https://arxiv.org/abs/2601.06395) (arXiv 2601.06395) —
  Belebele Somali and FLORES en→Somali for stock Gemma 3 and Qwen models
- [BALSAM](https://arxiv.org/abs/2507.22603) (arXiv 2507.22603, ACL
  ArabicNLP 2025) — 22 models, 78 Arabic tasks, LLM-as-judge versus
  automatic metrics
- [Open Arabic LLM Leaderboard v2](https://huggingface.co/blog/leaderboard-arabic-v2)
  (OALL, 2A2I, TII, Hugging Face)
- [SomaliBench Eval](https://arxiv.org/abs/2605.25420) (arXiv 2605.25420)
  — single-author safety study; the Somali failure taxonomy
- [Global MMLU](https://huggingface.co/datasets/CohereLabs/Global-MMLU) —
  42 languages including Arabic, Swedish and Somali; the vehicle for
  settling all three at once
- [OALL leaderboard space](https://huggingface.co/spaces/OALL/Open-Arabic-LLM-Leaderboard)
  and [SILMA's Arabic Broad Leaderboard](https://huggingface.co/spaces/silma-ai/Arabic-LLM-Leaderboard)
  — both live Spaces; neither served data to a plain fetch, so nothing
  here depends on their current rankings

Weaker evidence, and two active pieces of misinformation:

- [Best Arabic Local LLMs 2026](https://www.promptquorum.com/local-llms/best-arabic-local-llms-2026)
  (2026-08-28) and [Qwen 3.6 for Arabic NLP](https://hosn.om/blog/qwen-3-6-arabic-nlp-benchmarks.html)
  (2026-05-03) — roundups with no primary citations. Both quote
  Falcon-H1-Arabic scores, disagreeing with each other, and the first
  publishes a pull command for a repository that does not exist.
- A widely syndicated "Llama 5, released 8 April 2026" story is
  contradicted by Meta's own developer site, the `meta-llama` hub org
  and the Ollama library. There is no Llama 5, and there was never a
  Gemma 3.1, 3.2 or 3.5.
