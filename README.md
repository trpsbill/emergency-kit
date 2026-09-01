# Emergency Knowledge Kit

This is a self-contained reference system meant to live in a truck bag and work with zero connectivity. It serves offline Wikipedia and other ZIM archives through Kiwix, indexes a folder of curated PDFs and text (survival manuals, first-aid references, water disinfection guidance), and puts a small local language model in front of both. The model is a reading and summarizing layer, not a knowledge source: it answers only from retrieved text, cites where each claim came from, and says so when the archives don't cover a question. Target hardware is a used business laptop drawing 10–15W, charged from a portable power station.

## Architecture

```
                       question
                          │
                 ┌────────┴────────┐
                 │     kit.py      │
                 └──┬───────────┬──┘
        embedding   │           │   2-4 keywords
        similarity  ▼           ▼   (stopword strip)
      ┌──────────────────┐   ┌──────────────────────┐
      │ index.npz        │   │ kiwix-serve :8080    │
      │ (chunked ./docs, │   │ full-text search     │
      │ cosine ≥ 0.65)   │   │ over ZIM archives    │
      └────────┬─────────┘   └──────────┬───────────┘
               │  top chunks            │  top articles
               └───────────┬────────────┘  (keyword-filtered)
                           ▼
              one prompt, sources numbered
                           │
                           ▼
          OpenAI-compatible LLM server :1234
        (LM Studio on the PoC desktop; llama.cpp
         server on the laptop target)
                           │
                           ▼
        cited answer ── CLI (kit.py ask) or
                        web UI (app.py :8000)
```

Everything is local; the only network calls are to `localhost` (or wherever
`.env` points). No frameworks — retrieval, chunking, and prompting are plain
Python with numpy; HTTP is stdlib urllib.

## Requirements

- Python 3.10+ and the four packages in `requirements.txt` (numpy, pypdf for
  the CLI; fastapi, uvicorn only for the web UI)
- An OpenAI-compatible LLM server with a small chat model and an embedding
  model (PoC: LM Studio; target: llama.cpp `llama-server`)
- `kiwix-serve` (from kiwix-tools) plus at least one ZIM archive
- Disk: ~3 GB for the ZIMs listed below, a few MB for docs and index

## Setup (desktop PoC, LM Studio)

1. Python env:
   ```bash
   python3 -m venv venv
   ./venv/bin/pip install -r requirements.txt
   ```
2. LM Studio server on port 1234 with:
   - chat model `qwen3.5-4b`, loaded with 16k context: `lms load qwen3.5-4b -c 16384`
   - embedding model `text-embedding-nomic-embed-text-v1.5@f16`
   - Reasoning is suppressed per-request via the `reasoning_effort: "none"`
     API field (`REASONING_EFFORT` in kit.py); no model-side config needed.
3. kiwix-tools: download the Linux x86_64 build from
   https://download.kiwix.org/release/kiwix-tools/ and extract into `./kiwix/`
   (start.sh expects `./kiwix/kiwix-tools_linux-x86_64-<ver>/kiwix-serve`;
   override with `KIWIX_BIN` in `.env`).
4. Download the reference library:
   ```bash
   ./setup.sh          # interactive checklist (SPACE toggles, ENTER confirms)
   ./setup.sh --all    # non-interactive, fetch everything
   ```
   Presents every source — 17 documents (survival/SERE manuals, small-unit
   tactics, fieldworks, cold weather, hygiene, civil disturbance, nuclear
   fallout, first aid, water disinfection, canning, gardening, trapping,
   woodcraft/shelter-building classics) plus the two ZIM archives — all
   selected by default; uncheck what you don't want. Already-present files
   are skipped, Gutenberg boilerplate is stripped, and the EPA page is
   converted to plain text automatically. Provenance and licenses:
   `docs/SOURCES.md`.
5. Machine-specific config: `cp .env.example .env` and edit if anything is not
   on localhost (e.g. under WSL2 with LM Studio on the Windows host, add the
   gateway IP to `LMSTUDIO_EXTRA_URLS`). Update `KIWIX_BOOKS` in kit.py if
   your ZIM versions differ.
6. Build the index:
   ```bash
   ./venv/bin/python kit.py index
   ```
   Prints chunk counts per file and generates a one-line description of each
   document (one LLM call each), stored in the index for the Sources panel.

### Notes on the laptop target (llama.cpp on Linux)

The kit only needs an OpenAI-compatible `/v1` endpoint, so LM Studio swaps out
for llama.cpp without code changes:

```bash
llama-server -m qwen3.5-4b-Q4_K_M.gguf -c 16384 --port 1234 \
  --embeddings -m2 nomic-embed-text-v1.5.f16.gguf   # or run a second
                                                    # llama-server for embeddings
```

Set `CHAT_MODEL`/`EMBED_MODEL` in `.env` to whatever ids the server reports at
`/v1/models`. On CPU expect roughly 20–100 s per answer at 4B Q4 (see status
section); trim `TOP_K_WIKI`/`WIKI_EXCERPT_CHARS` in kit.py if that's too slow.

## ZIM archives

| Archive | Size | Download |
|---|---|---|
| `wikipedia_en_medicine_maxi_2026-04.zim` — WikiMed Medical Encyclopedia, ~362k articles | ~2.1 GB | https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2026-04.zim |
| `wikipedia_en_100_2026-08.zim` — top-100 Wikipedia articles (general ballast, optional) | ~320 MB | https://download.kiwix.org/zim/wikipedia/wikipedia_en_100_2026-08.zim |

Browse https://download.kiwix.org/zim/ for newer dates or more collections
(the full `wikipedia_en_all_nopic` is ~60 GB if disk allows). After adding or
updating a ZIM: drop it in `./kiwix/zims/`, restart kiwix-serve, and add its
book name (the `/content/<name>` path segment, visible on the kiwix landing
page) to `KIWIX_BOOKS` in kit.py, most-useful first.

## Adding documents

Drop PDF/MD/TXT files into `./docs/` and re-run `kit.py index`. Stick to
public-domain or clearly licensed material; record each addition in
`docs/SOURCES.md` so the folder can be rebuilt. Current contents are listed
there with download URLs and licenses.

## Running

CLI:
```bash
./venv/bin/python kit.py ask "How do I treat a snakebite?"
./venv/bin/python kit.py ask -v "..."   # also print retrieved chunks + scores
```

Web UI:
```bash
./start.sh          # kiwix-serve :8080 + web UI :8000 (APP_PORT/KIWIX_PORT in .env)
./stop.sh
```

Open http://localhost:8000. Streamed answers, last-6-turn conversation memory,
citation chips (kiwix citations link into the article, document citations show
file + page), a per-answer "Show retrieved context" toggle, and a Sources
panel showing every served ZIM and indexed document. `GET /api/sources`
returns the same manifest as JSON; the model gets it in its system prompt so
"do you have anything on X?" is answered from the manifest.

Both scripts are idempotent (pidfiles in `./run/`). For start-on-boot, either
`@reboot /path/to/emergency-kit/start.sh` in crontab, or a systemd oneshot
unit with `RemainAfterExit=yes` that execs `start.sh`.

## Current status / known limitations

From the PoC test run (`results/summary.md`; desktop, qwen3.5-4b Q4):

- Retrieval quality is good on the covered domains: water disinfection
  questions pull the EPA text verbatim, hypothermia pulls the right manual
  sections plus the WikiMed *Hypothermia* article. Answers stay faithful to
  retrieved text with per-claim citations.
- Out-of-scope questions send a near-empty source list (relevance floor:
  cosine ≥ 0.65 for docs, keyword-presence for kiwix articles). The model
  then answers from its own memory behind a mandatory bold disclaimer
  ("No sources cover this…"). A 4B model's unsourced answers deserve real
  skepticism — treat that mode as a hint, not a reference.
- CPU speed (desktop-class CPU, faster than the target laptop): ~21 s for a
  short sourced answer, ~99 s for a long one, ~1–2 s for refusals/manifest
  answers. Prompt processing of the ~3k-token source block dominates.
- Kiwix keyword extraction is a plain stopword strip — it works on direct
  questions but has no synonym/spelling tolerance.
- Wikipedia articles are truncated to the first ~2.5k characters of text, so
  a long article's relevant section can be missed.
- `qwen3.5-4b` under LM Studio ignores `chat_template_kwargs.enable_thinking`;
  reasoning is controlled via the `reasoning_effort` API field instead.
