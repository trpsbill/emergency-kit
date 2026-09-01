# Test Summary — updated 2026-09-01 (steps 1–5)

Full per-step transcripts: `results/step1/` … `results/step5/` (q1–q3 each).
Canonical `results/q1.txt`–`q3.txt` are the step-4 runs (final quality config,
GPU). Baseline numbers are the original PoC runs (reasoning on, 8192 context,
whole-question kiwix pattern, no relevance floor).

## Before/after table (LLM wall-clock s / completion tokens / prompt tokens)

| Stage | q1 bleach | q2 hypothermia | q3 ECU (refusal) |
|---|---|---|---|
| Baseline (GPU) | 38.6 / 4144 / 1658 | 53.8 / 5635 / 2557 ⚠ truncated | 11.7 / 1136 / 1842 |
| 1. reasoning off | 2.4 / 245 / 1660 | 8.2 / 892 / 2559 | 0.2 / 9 / 1842 |
| 2. 16384 context | 3.7 / 306 / 1660 | 9.0 / 807 / 2559 ✓ completes | 1.0 / 9 / 1842 |
| 3. kiwix keywords + medicine ZIM | 2.7 / 338 / 3204 | 10.9 / 972 / 3118 | 0.2 / 9 / 1842 |
| 4. relevance floor | 3.1 / 310 / 3204 | 10.2 / 1042 / 3118 | 0.2 / 9 / **160** |
| 5. CPU offload 0 (desktop CPU) | 20.7 / 168 / 3204 | 99.3 / 921 / 3118 | 1.4 / 9 / 160 |

Retrieval time is ~0.1 s throughout.

## Step notes

1. **Reasoning off.** Neither `chat_template_kwargs.enable_thinking` nor an
   `lms` toggle worked, but LM Studio honors the OpenAI **`reasoning_effort:
   "none"`** field — content arrives with zero reasoning tokens. No Gemma
   download needed; `REASONING_EFFORT` is config in kit.py (set `None` to
   restore default thinking). 10–50× speedup with no observed quality loss:
   q1 stayed verbatim-correct with citations, q3 still refused.
2. **16k context.** Reloaded via `lms load qwen3.5-4b -c 16384`. q2 now ends
   with a proper closing bullet instead of cutting off mid-sentence.
3. **Kiwix keywords + WikiMed.** Stopword-strip keyword extraction (no LLM
   call needed) plus `wikipedia_en_medicine_maxi_2026-04` (2.1 GB, 362,501
   articles). Wikipedia went from noise to signal: q1 now pulls *Sodium
   hypochlorite* and *Chlorine-releasing compounds*; **q2 pulls the actual
   *Hypothermia* article plus *Frostbite*** (baseline had pulled *Myocardial
   infarction*). Prompt grows ~600 tokens from the richer wiki excerpts.
4. **Relevance floor.** Doc chunks need cosine ≥ 0.65; kiwix articles must
   contain ≥ 1 search keyword. q1/q2 keep all six sources. **q3 sends zero
   sources — prompt drops 1842 → 160 tokens** — and still refuses ("The
   provided sources do not cover this."). Refusal is now structural, not just
   model discipline.
5. **CPU simulation.** Desktop CPU (Ryzen-class, faster than the Latitude's
   i7-1185G7 — treat these as optimistic): q1 ~21 s, q2 ~99 s, q3 ~1.4 s.
   Prompt processing dominates (~3.1k-token prompts); q2's longer answer adds
   ~900 generated tokens on top. Usable for an emergency reference; trimming
   `WIKI_EXCERPT_CHARS`/`TOP_K` is the lever if the Latitude needs faster
   answers. GPU offload restored afterward.

## Faithfulness spot-checks after the changes

- q1 unchanged and correct (8 drops of 6% / 6 drops of 8.25% per gallon,
  30 minutes, double if cloudy), all claims cited.
- q2 complete, per-claim citations to both FM manuals; the model now also has
  the WikiMed Hypothermia article available and stays consistent with it.
- q3 refuses with an empty source list at every stage.
