# Personal documents

Drop your **own** documents here — PDF, Markdown, or plain text — and the kit
will index them alongside the public library. Place files in this folder (or
subfolders); every `*.pdf`, `*.md`, and `*.txt` file is picked up, and file
names are used as-is for citations.

- This is a **manual drop-in**: nothing is downloaded for this folder by
  `setup.sh`. Add files yourself.
- After adding or removing files, rebuild the index:
  `./venv/bin/python kit.py index`
- Personal files are served locally at `/personal/...` and can be opened from
  their citation links.
- This folder is **gitignored** (except this README), so personal documents
  never leave your machine.

Use this for material you own or have rights to, such as your own notes,
equipment manuals, local water/treatment SOPs, or self-authored reference
material. The public library in `docs/` stays for cleanly-licensed,
public-domain sources.
