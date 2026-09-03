# Contributing

Thanks for wanting to improve the Emergency Knowledge Kit. The project's goal
is a reliable, fully-offline emergency reference that a non-technical person
can set up and trust. Contributions are judged against that goal.

## Ground rules

- **Offline-first is non-negotiable.** No cloud APIs, no telemetry, no
  CDN-loaded assets. Anything fetched at setup time must be vendored or
  reproducible from `setup.sh`.
- **Keep dependencies minimal.** Core retrieval stays plain Python + numpy +
  pypdf; the web layer stays FastAPI + vanilla JS in a single HTML file. No
  LLM frameworks, no JS build step. If a feature seems to need a new
  dependency, open an issue first.
- **Grounding over cleverness.** Changes to prompts or retrieval must not
  weaken citation faithfulness or the memory-mode disclaimer. If you touch
  them, include before/after transcripts for at least: one well-covered
  question, one uncovered question (must still disclaim), and one
  conversational follow-up.

## Adding reference sources

The most valuable non-code contribution. Requirements:

1. **License must be clean**: public domain (US government works, pre-1929
   publications) or an explicit free license. "It's on the internet" is not
   a license. Distribution-restricted military documents are excluded even
   when copyright-free.
2. Prefer plain-text versions (archive.org `_djvu.txt`, Project Gutenberg
   `.txt`) over scanned PDFs — smaller and better retrieval.
3. Add the source to **both** `setup.sh` (the `SOURCES` manifest) and
   `docs/SOURCES.md` (with title, license, and download URL).
 4. Documents themselves are never committed — `docs/` is gitignored except
    `SOURCES.md`. (Personal, user-owned documents go in `personal/`, which
    is gitignored except its `README.md` — they're not redistributable
    library content, so they don't need a provenance entry.)
5. Sanity-check retrieval: `./venv/bin/python kit.py ask -v "<question your
   source should answer>"` and confirm the right chunks surface.

## Code contributions

- Fork, branch, and open a PR with a focused change and a clear description
  of what it does and how you verified it.
- Match the existing style: config constants at the top of `kit.py`,
  comments explain *why* not *what*, user-visible errors say what to do
  next.
- Test the paths you touched: `kit.py index`, `kit.py ask -v`, the web UI
  (stream, citations, images, chats), and `./setup.sh` if you changed it.
  There is no automated test suite yet — a PR adding one (stdlib `unittest`,
  mocked HTTP) would be very welcome.
- Keep `README.md` layperson-friendly; technical detail belongs in
  `TECHNICAL.md`.

## Ideas that would help

- Wiki article chunking (score sections, not lead excerpts)
- Better keyword extraction for kiwix search (synonyms, spelling tolerance)
- An automated eval set of question → expected-source pairs
- llama.cpp setup automation for the Linux laptop target
- Non-US map presets (bounding boxes + regional ZIM suggestions)
- Accessibility pass on the web UI

## Reporting problems

Open a GitHub issue with: what you asked, what it answered, what you
expected, and the `-v` retrieval output (or the "Show retrieved context"
contents) if it's a retrieval-quality issue. For setup problems, include
your OS and the tail of `app.log` / `kiwix-serve.log`.

## License

By contributing you agree your contributions are licensed under the
project's [MIT License](LICENSE).
