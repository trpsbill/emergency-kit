# Emergency Knowledge Kit

**Your own offline survival library with a built-in assistant — no internet required.**

The Emergency Knowledge Kit turns an ordinary computer into a self-contained
reference system for emergencies: it stores offline copies of Wikipedia,
survival and first-aid manuals, and maps, and puts a local AI assistant in
front of them that answers questions in plain language — citing exactly which
manual and page each answer came from, and saying so honestly when its
library doesn't cover something.

Everything runs on your own machine. Once it's set up, it works with the
network cable unplugged — during a power grid failure, a natural disaster, or
anywhere without connectivity.

**What it can help with:** first aid and field medicine, safe drinking water,
food storage and preservation, gardening, hunting and trapping, shelter
building, fire, cold-weather survival, navigation with offline street/topo/
aerial maps, nuclear fallout protection, and much more — see the full
[source list](docs/SOURCES.md).

> ⚠ **Important:** this tool is a reference, not a substitute for emergency
> services, professional medical care, or your own judgment. The AI assistant
> can make mistakes — it cites its sources so you can check them, and you
> should.

---

## What you need

**Hardware** (a used business laptop works great):

| | Minimum | Recommended |
|---|---|---|
| CPU | 64-bit x86, ~2015 or newer | Anything 4-core, ~2018+ |
| RAM | 8 GB | 16 GB |
| Disk | ~15 GB free | 30–60 GB free (room for maps) |
| GPU | not required | any — makes answers faster |

**Operating system:**

- **Linux** — fully supported (this is the primary target).
- **Windows** — fully supported through WSL2 (Microsoft's built-in Linux
  layer; one command to enable: `wsl --install`). LM Studio runs on the
  Windows side, everything else in WSL2.
- **macOS** — works with minor manual steps (install kiwix-tools yourself
  and point the kit at it; see [TECHNICAL.md](TECHNICAL.md)).

**Disk budget** — you choose what to install, roughly:

| Content | Size |
|---|---|
| AI models (chat + embedding) | ~3–4 GB |
| Survival/reference documents (25+ manuals and books) | ~25 MB |
| Offline medical Wikipedia (WikiMed, 362k articles) | ~2.1 GB |
| Street map per US state | ~0.5–2 GB |
| Topo map per US state | ~2–4 GB |
| Aerial imagery per US state | ~3–6 GB |

## Setup

You'll paste a handful of commands into a terminal. No programming knowledge
needed.

**1. Install LM Studio** (the AI engine) from
[lmstudio.ai](https://lmstudio.ai) — free, runs on Windows/Mac/Linux. In LM
Studio:
   - download the chat model `qwen3.5-4b` and the embedding model
     `nomic-embed-text-v1.5`
   - start the local server (Developer tab → Start Server, port 1234)
   - load the chat model with **16384 context length**

**2. Get this project** — download it from GitHub (green "Code" button → 
Download ZIP, then unzip) or:
```bash
git clone https://github.com/trpsbill/emergency-kit.git
cd emergency-kit
```

**3. Prepare Python** (already installed on Linux/WSL2):
```bash
python3 -m venv venv
./venv/bin/pip install -r requirements.txt
```

**4. Install kiwix-tools** (serves offline Wikipedia): download the Linux
x86_64 build from
[download.kiwix.org/release/kiwix-tools](https://download.kiwix.org/release/kiwix-tools/)
and extract it into the `kiwix/` folder.

**5. Download your library** — an interactive checklist lets you pick which
documents, Wikipedia archives, and state maps to install (everything
document-related is selected by default; maps are opt-in because of their
size):
```bash
./setup.sh
```

**6. Build the search index** (re-run whenever you add documents):
```bash
./venv/bin/python kit.py index
```

**7. Start it:**
```bash
./start.sh
```
Open **http://localhost:8000** in your browser. That's it.

To have it start automatically when the computer boots, add to your crontab:
`@reboot /path/to/emergency-kit/start.sh`

## Using it

- **Ask questions** in the chat — answers stream in with citations you can
  click to open the actual manual at the cited page, images from relevant
  Wikipedia articles (click to zoom), and suggested follow-up questions you
  can tap. The assistant asks clarifying questions when details matter
  ("urban or wilderness? how close are they?").
- **Chats save automatically** in the sidebar, get auto-named by topic, and
  survive restarts. ＋ New chat starts fresh.
- **Map** (navbar) — your downloaded offline street maps, USGS topo maps,
  and aerial imagery, switchable per region.
- **Sources** (navbar) — everything the kit knows, with descriptions. You
  can also just ask it: *"do you have anything on snakebites?"*
- **☾/☀** toggles dark/light theme.
- Command line, if you prefer:
  ```bash
  ./venv/bin/python kit.py ask "How do I treat a burn?"
  ```

## Adding your own content

Drop any PDF, text, or Markdown file into `docs/` and re-run
`./venv/bin/python kit.py index` — it becomes part of the assistant's
library immediately. Stick to material you have the right to use; see
[docs/SOURCES.md](docs/SOURCES.md) for what's included and where it came
from (all public domain or freely licensed).

More ZIM archives (other Wikipedia editions, WikiHow, Project Gutenberg…)
are at [download.kiwix.org/zim](https://download.kiwix.org/zim/) — drop them
in `kiwix/zims/`, restart, and add the book name to `KIWIX_BOOKS` in
`kit.py`.

## Troubleshooting

- **"The language model server is not reachable"** — LM Studio's server
  isn't running (Developer tab → Start Server), or you're on WSL2 and need
  the Windows host address in `.env` (see [TECHNICAL.md](TECHNICAL.md)).
- **Answers cut off mid-sentence** — reload the chat model with a larger
  context length (16384).
- **Slow answers on older hardware** — normal for CPU-only machines
  (~20–100 s). Disable suggested replies (`KIT_SUGGESTIONS=0` in `.env`) to
  save a little more.
- **Something else** — `./stop.sh && ./start.sh`, and check `app.log` /
  `kiwix-serve.log`.

## Learn more / contribute

- [TECHNICAL.md](TECHNICAL.md) — architecture, configuration, API, and how
  the pieces fit together
- [CONTRIBUTING.md](CONTRIBUTING.md) — how to help
- [docs/SOURCES.md](docs/SOURCES.md) — every source, with license and origin
- [LICENSE](LICENSE) — MIT; free to use, modify, and share
