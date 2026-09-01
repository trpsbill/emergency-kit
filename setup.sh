#!/usr/bin/env bash
# Download the reference library (docs + ZIM archives) with an interactive
# selection screen (whiptail checklist, everything selected by default —
# uncheck with SPACE, confirm with ENTER).
#
#   ./setup.sh          interactive selection
#   ./setup.sh --all    non-interactive: fetch everything
#
# Already-downloaded files are skipped; delete a file to re-fetch it.
# Sources, licenses, and provenance: docs/SOURCES.md
set -u
cd "$(dirname "$0")"
mkdir -p docs kiwix/zims

# tag|filename|kind|description|url
# kind: txt (as-is), pdf (as-is), gutenberg (strip PG boilerplate),
#       epa (HTML -> plain text), zim (into kiwix/zims/)
SOURCES=$(cat <<'EOF'
fm21-76|fm21-76-survival-manual.pdf|pdf|FM 21-76 Survival manual (shelter/water/fire/food, 3 MB)|https://archive.org/download/fm-21-76-us-army-survival-manual/FM%2021-76%20US%20ARMY%20SURVIVAL%20MANUAL.pdf
fm21-76-1|fm21-76-1-survival-evasion-recovery.txt|txt|FM 21-76-1 Survival, Evasion, Recovery (SERE quick ref)|https://archive.org/download/Fm21-76-1/Fm21-76-1_djvu.txt
fm21-75|fm21-75-combat-skills.txt|txt|FM 21-75 Combat Skills (cover, concealment, movement)|https://archive.org/download/milmanual-fm-21-75-combat-skills-of-the-soldier/fm_21-75_combat_skills_of_the_soldier_djvu.txt
fm7-8|fm7-8-infantry-platoon-squad.txt|txt|FM 7-8 Infantry Platoon and Squad (small-unit tactics)|https://archive.org/download/fm-7-8-infantry-rifle-platoon-and-sqaud-1992/FM%207-8%20Infantry%20Rifle%20Platoon%20And%20Sqaud%20%201992_djvu.txt
fm5-103|fm5-103-survivability-fieldworks.txt|txt|FM 5-103 Survivability (protective positions, fieldworks)|https://archive.org/download/fm-5-103-survivability-1985/FM%205-103%20Survivability%20%201985_djvu.txt
fm21-10|fm21-10-field-hygiene-sanitation.txt|txt|FM 21-10 Field Hygiene and Sanitation|https://archive.org/download/milmanual-fm-21-10-mcrp-4-11.1d-field-hygiene-and-sanitation/fm_21-10_mcrp_4-11.1d_field_hygiene_and_sanitation_djvu.txt
fm31-70|fm31-70-cold-weather.txt|txt|FM 31-70 Basic Cold Weather Manual|https://archive.org/download/fm-31-70-basic-cold-weather-manual-1968/FM%2031-70%20Basic%20Cold%20Weather%20Manual%20%201968_djvu.txt
fm3-19.15|fm3-19.15-civil-disturbance.txt|txt|FM 3-19.15 Civil Disturbance Operations (crowd/riot doctrine)|https://archive.org/download/fm-3-19.15-civil-disturbance-operations-2005/FM%203-19.15%20Civil%20Disturbance%20Operations%20%202005_djvu.txt
fm4-25.11|fm4-25.11-first-aid.pdf|pdf|FM 4-25.11 First Aid (joint services, 2.6 MB)|https://archive.org/download/FM4-25x11/FM4-25x11.pdf
epa-water|epa-emergency-disinfection-drinking-water.txt|epa|EPA Emergency Disinfection of Drinking Water|https://www.epa.gov/ground-water-and-drinking-water/emergency-disinfection-drinking-water
kearny|nuclear-war-survival-skills-kearny.txt|txt|Kearny, Nuclear War Survival Skills (fallout, expedient shelters)|https://archive.org/download/nuclear-war-survival-skills-by-cresson-h.-kearny/Nuclear%20War%20Survival%20Skills%2C%20by%20Cresson%20H.%20Kearny_djvu.txt
usda-canning|usda-complete-guide-home-canning.txt|txt|USDA Complete Guide to Home Canning (2015)|https://archive.org/download/usda-complete-guide-to-home-canning-2015-revision/USDA-Complete-Guide-to-Home-Canning-2015-revision_djvu.txt
gardening|vegetable-gardening-watts.txt|txt|Watts, Vegetable Gardening (1912)|https://archive.org/download/vegetablegardeni00wattrich/vegetablegardeni00wattrich_djvu.txt
trapping|camp-life-woods-tricks-of-trapping.txt|txt|Gibson, Camp Life in the Woods / Tricks of Trapping (1881)|https://archive.org/download/william-hamilton-gibson-camp-life-in-the-woods-the-tricks-of-trapping/William_Hamilton_Gibson_Camp_Life_in_the_Woods_%26_the_Tricks_of_Trapping_djvu.txt
shelters|shelters-shacks-and-shanties-beard.txt|gutenberg|Beard, Shelters Shacks and Shanties (axe-built structures)|https://www.gutenberg.org/cache/epub/28255/pg28255.txt
woodcraft|woodcraft-and-camping-nessmuk.txt|gutenberg|Nessmuk, Woodcraft and Camping|https://www.gutenberg.org/cache/epub/34607/pg34607.txt
scouts-1911|boy-scouts-handbook-1911.txt|gutenberg|Boy Scouts Handbook 1911 (firecraft, knots, camping)|https://www.gutenberg.org/cache/epub/29558/pg29558.txt
zim-medicine|wikipedia_en_medicine_maxi_2026-04.zim|zim|ZIM: WikiMed Medical Encyclopedia (~2.1 GB)|https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2026-04.zim
zim-wiki100|wikipedia_en_100_2026-08.zim|zim|ZIM: Wikipedia top-100 articles (~320 MB)|https://download.kiwix.org/zim/wikipedia/wikipedia_en_100_2026-08.zim
EOF
)

# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------
ALL_TAGS=$(echo "$SOURCES" | cut -d'|' -f1)

if [ "${1:-}" = "--all" ]; then
  SELECTED="$ALL_TAGS"
elif command -v whiptail >/dev/null 2>&1 && [ -t 0 ]; then
  ARGS=()
  while IFS='|' read -r tag file kind desc url; do
    ARGS+=("$tag" "$desc" ON)
  done <<< "$SOURCES"
  CHOICES=$(whiptail --title "Emergency Knowledge Kit — source selection" \
    --checklist "Select sources to download. SPACE toggles, ENTER confirms.\nAlready-downloaded files are skipped." \
    24 100 16 "${ARGS[@]}" 3>&1 1>&2 2>&3) || { echo "cancelled"; exit 1; }
  SELECTED=$(echo "$CHOICES" | tr -d '"' | tr ' ' '\n')
else
  echo "whiptail not available (or no TTY) — downloading everything."
  echo "Use './setup.sh --all' to skip this message, or install whiptail for selection."
  SELECTED="$ALL_TAGS"
fi

[ -z "$SELECTED" ] && { echo "nothing selected"; exit 0; }

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------
strip_gutenberg() {
  python3 - "$1" <<'PYEOF'
import re, sys
p = sys.argv[1]
t = open(p, encoding='utf-8', errors='replace').read()
m = re.search(r'\*\*\* START OF TH.*?\*\*\*(.*)\*\*\* END OF TH', t, re.S)
if m: open(p, 'w').write(m.group(1).strip())
PYEOF
}

epa_to_text() {
  python3 - "$1" "$2" <<'PYEOF'
import re, sys
from html.parser import HTMLParser
src, dst = sys.argv[1], sys.argv[2]
html = open(src, encoding='utf-8', errors='replace').read()
m = re.search(r'<main[^>]*>(.*?)</main>', html, re.S | re.I)
if m: html = m.group(1)
class T(HTMLParser):
    def __init__(self):
        super().__init__(); self.out = []; self.skip = 0
    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style', 'nav', 'footer'): self.skip += 1
        if tag in ('p', 'li', 'h1', 'h2', 'h3', 'h4', 'tr', 'br', 'div'):
            self.out.append('\n')
    def handle_endtag(self, tag):
        if tag in ('script', 'style', 'nav', 'footer') and self.skip: self.skip -= 1
    def handle_data(self, d):
        if not self.skip: self.out.append(d)
t = T(); t.feed(html)
text = re.sub(r'\n{3,}', '\n\n', ''.join(t.out))
text = '\n'.join(l.strip() for l in text.split('\n'))
text = re.sub(r'\n{3,}', '\n\n', text).strip()
hdr = ("Emergency Disinfection of Drinking Water\n"
       "Source: US EPA, https://www.epa.gov/ground-water-and-drinking-water/"
       "emergency-disinfection-drinking-water\n\n")
open(dst, 'w').write(hdr + text)
PYEOF
}

ok=0; skipped=0; failed=0
while IFS='|' read -r tag file kind desc url; do
  echo "$SELECTED" | grep -qx "$tag" || continue
  case "$kind" in zim) dest="kiwix/zims/$file";; *) dest="docs/$file";; esac
  if [ -s "$dest" ]; then
    echo "skip (exists): $dest"; skipped=$((skipped + 1)); continue
  fi
  echo "downloading: $desc"
  case "$kind" in
    epa)
      tmp="$dest.html.part"
      if curl -fsSL -A "Mozilla/5.0" --max-time 300 -o "$tmp" "$url" \
          && epa_to_text "$tmp" "$dest"; then
        rm -f "$tmp"; ok=$((ok + 1))
      else rm -f "$tmp"; echo "  FAILED: $dest"; failed=$((failed + 1)); fi
      ;;
    *)
      bar=-s; [ "$kind" = zim ] && bar=-#
      if curl -fL $bar --max-time 14400 -o "$dest.part" "$url" \
          && mv "$dest.part" "$dest"; then
        [ "$kind" = gutenberg ] && strip_gutenberg "$dest"
        ok=$((ok + 1))
      else rm -f "$dest.part"; echo "  FAILED: $dest"; failed=$((failed + 1)); fi
      ;;
  esac
done <<< "$SOURCES"

echo
echo "done: $ok downloaded, $skipped already present, $failed failed"
[ "$failed" -gt 0 ] && echo "re-run setup.sh to retry failures"

# ---------------------------------------------------------------------------
# Rebuild the index if the environment is ready
# ---------------------------------------------------------------------------
if [ "$ok" -gt 0 ] && [ -x venv/bin/python ]; then
  rebuild=y
  if [ -t 0 ] && command -v whiptail >/dev/null 2>&1; then
    whiptail --yesno "Rebuild the embedding index now?\n(Needs the LM Studio / llama.cpp embedding server running.)" 10 60 || rebuild=n
  fi
  if [ "$rebuild" = y ]; then
    ./venv/bin/python kit.py index || echo "index failed — run './venv/bin/python kit.py index' once the embedding server is up"
  fi
fi
