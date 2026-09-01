# Technical Documentation

Architecture, configuration, and internals. For setup and everyday use, see
the [README](README.md).

## Design principles

- **Offline-first**: after setup, every request goes to `localhost`. No
  cloud APIs, no telemetry, no CDN assets.
- **Dependency-light**: retrieval, chunking, and prompting are plain Python
  with numpy; HTTP is stdlib urllib. No LangChain/LlamaIndex/vector-DB
  frameworks. The web layer is FastAPI + one hand-written HTML file with
  vanilla JS (no build step).
- **Grounded answers**: the model is a reading/summarizing layer over
  retrieved text, instructed to cite sources and flag memory-based answers.

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
               │  top chunks            │  articles, re-scored with
               │                        │  embeddings (cosine ≥ 0.66)
               └───────────┬────────────┘
                           ▼
              one prompt, sources numbered
                           │
                           ▼
          OpenAI-compatible LLM server :1234
          (LM Studio; llama.cpp also works)
                           │
                           ▼
        cited answer ── CLI (kit.py ask) or
                        web UI (app.py :8000)
```

## Components

| File | Role |
|---|---|
| `kit.py` | All retrieval/prompting logic + CLI. Config at the top. |
| `app.py` | FastAPI wrapper: SSE streaming chat, sources manifest, map listing, static/doc serving. |
| `static/index.html` | Entire chat UI (vanilla JS): markdown renderer, SSE client, chat persistence (localStorage), citation dialogs, lightbox, themes. |
| `static/map.html` | MapLibre GL viewer for vector (Protomaps) and raster (USGS) PMTiles. |
| `setup.sh` | Interactive downloader: documents, ZIMs, per-state maps (street/topo/imagery), viewer libraries, pmtiles CLI. |
| `scripts/fetch_usgs.py` | Throttled, resumable USGS tile scraper → MBTiles (topo or imagery). |
| `start.sh` / `stop.sh` | Pidfile-managed start/stop of kiwix-serve + uvicorn. |

## Retrieval pipeline

1. **Local documents** — `kit.py index` extracts text (pypdf for PDFs, with
   per-page tracking so citations carry page numbers), chunks to ~1600 chars
   with 200 overlap at paragraph/sentence boundaries, embeds via the
   `nomic-embed-text-v1.5` task prefixes (`search_document:` /
   `search_query:`), and stores everything in a single `index.npz` (float32
   embeddings + chunk text + metadata + one LLM-generated description per
   document). Query time: cosine against the whole matrix, top-4 above 0.65.
2. **Kiwix** — the question is stopword-stripped to 2–4 keywords for
   kiwix-serve's Xapian full-text search (`/search?pattern=…&format=xml&
   books.name=…`), each book in `KIWIX_BOOKS` in order. Retrieved articles
   are HTML-stripped to a 2.5k-char excerpt, then **re-scored with the same
   embeddings** against the question; anything under 0.66 cosine is dropped
   (plain keyword search OR-matches common words and returns junk
   otherwise). Surviving articles contribute text, a citation link, and up
   to 4 images.
3. **Prompting** — sources are numbered into one user message. The system
   prompt makes the model an *advisor*: prioritize by the user's stated
   situation, lead with time-critical actions, ask up to three clarifying
   questions, cite inline, never fake citations. If **zero** sources
   survive, the server (not the model) prepends a bold "answering from model
   memory" disclaimer — this is deterministic so it can never contradict the
   citations.
4. **Post-answer calls** — chat title (first exchange only) and 3–4
   suggested replies, each one small LLM call streamed as extra SSE events.

## LLM server

Any OpenAI-compatible `/v1` endpoint. Development uses LM Studio; the
laptop target is llama.cpp `llama-server`. Notes:

- `qwen3.5-4b` reasons by default; the kit suppresses it per-request with
  `reasoning_effort: "none"` (config `REASONING_EFFORT`; ~10–50× faster
  with no observed quality loss on this workload).
- Load the chat model with ≥16k context — prompts run ~3–6k tokens.
- The embedding server is the same LM Studio instance (`EMBED_MODEL`).
- `kit.check_llm()` probes `/models` before every ask and re-discovers the
  base URL, so an LM Studio restart recovers without restarting the kit.

## Configuration

All tunables sit at the top of `kit.py` (models, book names, chunk size,
top-k, score floors, token budget). Machine-specific values go in a
gitignored `.env` (see `.env.example`):

| Key | Purpose |
|---|---|
| `LMSTUDIO_EXTRA_URLS` | extra base URLs tried after localhost — needed under WSL2 where LM Studio runs on the Windows host (use the gateway IP from `ip route show default`) |
| `KIWIX_EXTRA_URLS` / `KIWIX_PUBLIC_URL` | kiwix reachable elsewhere / as seen from the browser |
| `CHAT_MODEL` / `EMBED_MODEL` | model ids as served by `/v1/models` |
| `APP_PORT` / `KIWIX_PORT` / `KIWIX_BIN` | ports and kiwix binary path (`start.sh`) |
| `KIT_DEBUG=1` | token counts + tokens/s in stats lines (also `./start.sh --debug`, CLI `--stats`) |
| `KIT_SUGGESTIONS=0` | disable suggested replies (saves one LLM call per answer) |

## Web API

- `GET /` chat UI · `GET /map` map viewer
- `POST /api/ask` `{question, history}` → SSE: `meta` (retrieved chunks,
  scores, images), `token` deltas, `done` (timings), `title`,
  `suggestions`, `error`
- `GET /api/sources` — manifest (docs with descriptions + kiwix OPDS
  catalog); also injected into the system prompt so the model can answer
  "what do you know?"
- `GET /api/maps` — available `.pmtiles` with type (vector/raster)
- `/docs/*`, `/maps/*`, `/static/*` — static mounts (maps served with byte
  ranges, which PMTiles clients require)

## Maps

- **Street (vector)**: `pmtiles extract` pulls a state bounding box from the
  Protomaps daily planet build (~120 GB remote; extract downloads only the
  needed tiles via HTTP range requests). Rendered client-side by MapLibre
  with the Protomaps basemap theme; fonts/sprites vendored for offline use.
- **Topo / imagery (raster)**: `scripts/fetch_usgs.py` scrapes The National
  Map's `USGSTopo` / `USGSImageryOnly` tile services (public domain) into
  MBTiles (stdlib sqlite3, TMS row order), 8 connections, resumable;
  `pmtiles convert` produces the final archive. Zoom caps:
  `TOPO_MAX_ZOOM` (13 default ≈ 1:70k; 15 = full 1:24k at ~16× cost),
  `IMAGERY_MAX_ZOOM` (13 ≈ 16 m/px; 16–17 = building-level, only sane for
  small bounding boxes — see the AOI recipe in `scripts/fetch_usgs.py`).
- State bounding boxes live in `setup.sh` (`STATES`).

## macOS notes

Everything is POSIX shell + Python; the gaps are binaries: install
kiwix-tools via Homebrew (`brew install kiwix-tools`) and set
`KIWIX_BIN=$(which kiwix-serve)` in `.env`; download the macOS `pmtiles`
CLI from the go-pmtiles releases into `maps/`. LM Studio has a native macOS
build.

## Known limitations

- Kiwix keyword extraction is a plain stopword strip — no synonyms or
  spelling tolerance; article excerpts are lead-only (2.5k chars), so a
  relevant deep section can be missed. Chunking wiki articles like docs is
  the known fix.
- A 4B model's unsourced (memory-mode) answers deserve real skepticism; the
  disclaimer exists for a reason. Its "situational reasoning" is
  pattern-matching, not judgment.
- Chat history is per-browser localStorage (single machine by design).
- CPU-only hardware answers in ~20–100 s; prompt processing of the ~3k-token
  source block dominates.
