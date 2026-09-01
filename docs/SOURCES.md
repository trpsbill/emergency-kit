# Reference documents

The embedding index (`python kit.py index`) expects these files in `./docs/`.
PDFs are not committed to the repo — download them to the exact filenames
below, then rebuild the index. The EPA text file *is* committed (small, plain
text, US-government public domain).

| Save as | Document | License | Download |
|---|---|---|---|
| `fm21-76-survival-manual.pdf` | FM 21-76, US Army Survival Manual (277 pp.) | Public domain (US federal government work) | https://archive.org/download/fm-21-76-us-army-survival-manual/FM%2021-76%20US%20ARMY%20SURVIVAL%20MANUAL.pdf |
| `fm4-25.11-first-aid.pdf` | FM 4-25.11, First Aid (Army/Navy/Air Force/Marine Corps joint publication, 227 pp.) | Public domain (US federal government work) | https://archive.org/download/FM4-25x11/FM4-25x11.pdf |
| `epa-emergency-disinfection-drinking-water.txt` | EPA, "Emergency Disinfection of Drinking Water" (saved as plain text) | Public domain (US federal government work) | https://www.epa.gov/ground-water-and-drinking-water/emergency-disinfection-drinking-water |

Rebuild from scratch:

```bash
cd docs
curl -L -o fm21-76-survival-manual.pdf "https://archive.org/download/fm-21-76-us-army-survival-manual/FM%2021-76%20US%20ARMY%20SURVIVAL%20MANUAL.pdf"
curl -L -o fm4-25.11-first-aid.pdf "https://archive.org/download/FM4-25x11/FM4-25x11.pdf"
cd .. && ./venv/bin/python kit.py index
```

Any additional PDF/MD/TXT dropped into `./docs/` is picked up by the next
`kit.py index` run — stick to public-domain or clearly licensed material.
