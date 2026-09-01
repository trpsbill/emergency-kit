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

## Reference library

Everything `setup.sh` installs (licenses and exact filenames in
[docs/SOURCES.md](docs/SOURCES.md)):

**Survival, SERE, fieldcraft**
- [FM 21-76 — Survival](https://archive.org/download/fm-21-76-us-army-survival-manual/FM%2021-76%20US%20ARMY%20SURVIVAL%20MANUAL.pdf) — shelter, water, fire, food, plants, traps
- [FM 21-76-1 — Survival, Evasion, and Recovery](https://archive.org/download/Fm21-76-1/Fm21-76-1_djvu.txt) — multiservice SERE quick reference
- [FM 21-75 — Combat Skills of the Soldier](https://archive.org/download/milmanual-fm-21-75-combat-skills-of-the-soldier/fm_21-75_combat_skills_of_the_soldier_djvu.txt) — cover, concealment, movement, observation
- [FM 7-8 — Infantry Rifle Platoon and Squad](https://archive.org/download/fm-7-8-infantry-rifle-platoon-and-sqaud-1992/FM%207-8%20Infantry%20Rifle%20Platoon%20And%20Sqaud%20%201992_djvu.txt) — small-unit tactics, patrolling, defense
- [FM 5-103 — Survivability](https://archive.org/download/fm-5-103-survivability-1985/FM%205-103%20Survivability%20%201985_djvu.txt) — protective positions and field fortification
- [FM 31-70 — Basic Cold Weather Manual](https://archive.org/download/fm-31-70-basic-cold-weather-manual-1968/FM%2031-70%20Basic%20Cold%20Weather%20Manual%20%201968_djvu.txt) — clothing, shelters, cold injuries

**Health, sanitation, long-duration emergencies**
- [FM 4-25.11 — First Aid](https://archive.org/download/FM4-25x11/FM4-25x11.pdf) — joint-services first aid
- [FM 21-10 — Field Hygiene and Sanitation](https://archive.org/download/milmanual-fm-21-10-mcrp-4-11.1d-field-hygiene-and-sanitation/fm_21-10_mcrp_4-11.1d_field_hygiene_and_sanitation_djvu.txt) — camp sanitation, waste, disease prevention
- [EPA — Emergency Disinfection of Drinking Water](https://www.epa.gov/ground-water-and-drinking-water/emergency-disinfection-drinking-water)
- [Kearny — Nuclear War Survival Skills](https://archive.org/download/nuclear-war-survival-skills-by-cresson-h.-kearny/Nuclear%20War%20Survival%20Skills%2C%20by%20Cresson%20H.%20Kearny_djvu.txt) — fallout shelters, expedient meters, post-fallout water and food
- [FM 3-19.15 — Civil Disturbance Operations](https://archive.org/download/fm-3-19.15-civil-disturbance-operations-2005/FM%203-19.15%20Civil%20Disturbance%20Operations%20%202005_djvu.txt) — crowd dynamics, riot-control doctrine

**Food: growing, preserving, trapping**
- [USDA — Complete Guide to Home Canning (2015)](https://archive.org/download/usda-complete-guide-to-home-canning-2015-revision/USDA-Complete-Guide-to-Home-Canning-2015-revision_djvu.txt)
- [Watts — Vegetable Gardening (1912)](https://archive.org/download/vegetablegardeni00wattrich/vegetablegardeni00wattrich_djvu.txt)
- [Gibson — Camp Life in the Woods and the Tricks of Trapping (1881)](https://archive.org/download/william-hamilton-gibson-camp-life-in-the-woods-the-tricks-of-trapping/William_Hamilton_Gibson_Camp_Life_in_the_Woods_%26_the_Tricks_of_Trapping_djvu.txt)

**Woodcraft, camping, primitive building**
- [Beard — Shelters, Shacks and Shanties (1914)](https://www.gutenberg.org/ebooks/28255) — structures built with axe and hand tools
- [Nessmuk — Woodcraft and Camping](https://www.gutenberg.org/ebooks/34607)
- [Boy Scouts Handbook, 1st ed. (1911)](https://www.gutenberg.org/ebooks/29558) — firecraft, knots, camping, signaling

**Offline maps** (per-state, via `setup.sh`)
- [OpenStreetMap street maps](https://protomaps.com/) — vector extracts from the Protomaps daily planet build (ODbL, ~0.5–2 GB per state)
- [USGS US Topo](https://basemap.nationalmap.gov/arcgis/rest/services/USGSTopo/MapServer) — raster topo tiles from The National Map (public domain, ~2–4 GB per state at the default zoom)

**Offline Wikipedia (ZIM)**
- [WikiMed Medical Encyclopedia](https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2026-04.zim) — ~362k medical articles
- [Wikipedia top-100 articles](https://download.kiwix.org/zim/wikipedia/wikipedia_en_100_2026-08.zim)

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

Open http://localhost:8000, and http://localhost:8000/map for offline maps.
`setup.sh` offers two per-state map downloads (also non-interactive:
`./setup.sh --maps texas --topo texas`): OpenStreetMap street/trail vector
maps extracted from the Protomaps daily build, and USGS US Topo raster tiles
fetched from The National Map (set `TOPO_MAX_ZOOM=15` before running for full
1:24k contour detail — roughly 16× the size and time of the default 13). The
map page auto-zooms to each extract and shows a region dropdown when several
are downloaded.

The chat UI streams answers with last-6-turn conversation memory,
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
