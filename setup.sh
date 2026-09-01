#!/usr/bin/env bash
# Download the reference library (docs + ZIM archives) with an interactive
# selection screen (whiptail checklist, everything selected by default —
# uncheck with SPACE, confirm with ENTER), plus optional offline map
# extracts per US state (none selected by default; a state is ~0.5-2 GB).
#
#   ./setup.sh                     interactive selection
#   ./setup.sh --all               non-interactive: all docs/ZIMs, no maps
#   ./setup.sh --all --maps texas,oklahoma   ...plus specific state maps
#   ./setup.sh --topo texas        USGS topo raster for specific states
#   ./setup.sh --imagery texas     USGS aerial imagery for specific states
#   ./setup.sh --maps texas        maps only prompt skipped, docs interactive
#
# Already-downloaded files are skipped; delete a file to re-fetch it.
# Sources, licenses, and provenance: docs/SOURCES.md. Map data is
# OpenStreetMap via Protomaps daily builds (ODbL).
set -u
cd "$(dirname "$0")"
mkdir -p docs kiwix/zims maps

# tag|filename|kind|description|url
# kind: txt (as-is), pdf (as-is), gutenberg (strip PG boilerplate),
#       epa (HTML -> plain text), zim (into kiwix/zims/)
SOURCES=$(cat <<'EOF'
fm21-76|fm21-76-survival-manual.pdf|pdf|FM 21-76 Survival manual (shelter/water/fire/food, 3 MB)|https://archive.org/download/fm-21-76-us-army-survival-manual/FM%2021-76%20US%20ARMY%20SURVIVAL%20MANUAL.pdf
fm21-76-1|fm21-76-1-survival-evasion-recovery.txt|txt|FM 21-76-1 Survival, Evasion, Recovery (SERE quick ref)|https://archive.org/download/Fm21-76-1/Fm21-76-1_djvu.txt
fm21-75|fm21-75-combat-skills.txt|txt|FM 21-75 Combat Skills (cover, concealment, movement)|https://archive.org/download/milmanual-fm-21-75-combat-skills-of-the-soldier/fm_21-75_combat_skills_of_the_soldier_djvu.txt
fm21-77|fm21-77-evasion-and-escape.txt|txt|FM 21-77 Evasion and Escape (1958)|https://archive.org/download/fm-21-77-evasion-and-escape-1958/FM%2021-77%20Evasion%20And%20Escape%20%201958_djvu.txt
fm21-78|fm21-78-prisoner-of-war-resistance.txt|txt|FM 21-78 Prisoner of War Resistance (1981)|https://archive.org/download/fm-21-78-prisoner-of-war-resistance-1981/FM%2021-78%20Prisoner%20Of%20War%20Resistance%20%201981_djvu.txt
afr64-4|afr64-4-sere-survival-training.txt|txt|AFR 64-4 Search and Rescue Survival Training (1985, full SERE text)|https://archive.org/download/DTIC_ADA325861/DTIC_ADA325861_djvu.txt
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
usda-meat|usda-meat-on-the-farm.txt|txt|USDA, Meat on the Farm: Butchering, Curing, Keeping (1906)|https://archive.org/download/CAT10416773/farmbul0183rev1906_djvu.txt
usda-tanning|usda-home-tanning-leather.txt|txt|USDA, Home Tanning of Leather and Small Fur Skins (1947)|https://archive.org/download/CAT87206840/farmbul1334rev1947_djvu.txt
usda-poultry|usda-farm-poultry-raising.txt|txt|USDA, Farm Poultry Raising (1948)|https://archive.org/download/CAT87204532/farmbul1524rev1948_djvu.txt
handy-book|american-boys-handy-book-beard.txt|txt|Beard, The American Boy's Handy Book (crafts, kites, traps, boats)|https://archive.org/download/whattodohowtodoi00bear/whattodohowtodoi00bear_djvu.txt
blacksmithing|standard-blacksmithing-holmstrom.txt|txt|Holmstrom, Standard Blacksmithing (1907)|https://archive.org/download/standardblacksmi00holm/standardblacksmi00holm_djvu.txt
war-garden|war-gardening-home-storage-vegetables.txt|txt|War Gardening and Home Storage of Vegetables (1918)|https://archive.org/download/wargardeninghome00vict/wargardeninghome00vict_djvu.txt
soap-making|art-of-soap-making-watt.txt|txt|Watt, The Art of Soap-Making (1896)|https://archive.org/download/artsoapmakingap00wattgoog/artsoapmakingap00wattgoog_djvu.txt
bee-culture|abc-of-bee-culture-root.txt|txt|Root, ABC of Bee Culture (1890)|https://archive.org/download/CAT11016093/CAT11016093_djvu.txt
zim-medicine|wikipedia_en_medicine_maxi_2026-04.zim|zim|ZIM: WikiMed Medical Encyclopedia (~2.1 GB)|https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2026-04.zim
zim-wiki100|wikipedia_en_100_2026-08.zim|zim|ZIM: Wikipedia top-100 articles (~320 MB)|https://download.kiwix.org/zim/wikipedia/wikipedia_en_100_2026-08.zim
EOF
)

# US state map extracts: tag|bbox (W,S,E,N)
STATES=$(cat <<'EOF'
alabama|-88.5,30.1,-84.9,35.1
alaska|-170.0,51.2,-129.9,71.5
arizona|-114.9,31.3,-109.0,37.1
arkansas|-94.7,33.0,-89.6,36.6
california|-124.5,32.5,-114.1,42.1
colorado|-109.1,36.9,-102.0,41.1
connecticut|-73.8,40.9,-71.8,42.1
delaware|-75.8,38.4,-74.9,39.9
florida|-87.7,24.4,-79.9,31.1
georgia|-85.7,30.3,-80.8,35.1
hawaii|-160.3,18.8,-154.7,22.3
idaho|-117.3,41.9,-111.0,49.1
illinois|-91.6,36.9,-87.0,42.6
indiana|-88.2,37.7,-84.7,41.8
iowa|-96.7,40.3,-90.1,43.6
kansas|-102.1,36.9,-94.5,40.1
kentucky|-89.6,36.4,-81.9,39.2
louisiana|-94.1,28.8,-88.7,33.1
maine|-71.1,42.9,-66.9,47.5
maryland|-79.5,37.8,-74.9,39.8
massachusetts|-73.6,41.2,-69.8,42.9
michigan|-90.5,41.6,-82.3,48.4
minnesota|-97.3,43.4,-89.4,49.5
mississippi|-91.7,30.1,-88.0,35.1
missouri|-95.8,35.9,-89.0,40.7
montana|-116.1,44.3,-104.0,49.1
nebraska|-104.1,39.9,-95.3,43.1
nevada|-120.1,35.0,-114.0,42.1
new-hampshire|-72.6,42.6,-70.5,45.4
new-jersey|-75.6,38.8,-73.8,41.4
new-mexico|-109.1,31.2,-103.0,37.1
new-york|-79.8,40.4,-71.8,45.1
north-carolina|-84.4,33.7,-75.3,36.7
north-dakota|-104.1,45.9,-96.5,49.1
ohio|-84.9,38.3,-80.5,42.0
oklahoma|-103.1,33.5,-94.4,37.1
oregon|-124.7,41.9,-116.4,46.4
pennsylvania|-80.6,39.6,-74.6,42.4
rhode-island|-71.95,41.1,-71.0,42.1
south-carolina|-83.4,32.0,-78.4,35.3
south-dakota|-104.1,42.4,-96.4,46.0
tennessee|-90.4,34.9,-81.6,36.7
texas|-106.75,25.75,-93.4,36.6
utah|-114.1,36.9,-109.0,42.1
vermont|-73.5,42.7,-71.4,45.1
virginia|-83.7,36.5,-75.2,39.5
washington|-124.9,45.5,-116.9,49.1
west-virginia|-82.7,37.1,-77.7,40.7
wisconsin|-92.9,42.4,-86.7,47.1
wyoming|-111.1,40.9,-104.0,45.1
EOF
)

# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------
ALL_TAGS=$(echo "$SOURCES" | cut -d'|' -f1)

# parse args: --all, --maps state1,state2
NONINTERACTIVE=""
MAPS_ARG=""
TOPO_ARG=""
IMAGERY_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --all) NONINTERACTIVE=1 ;;
    --maps) shift; MAPS_ARG="${1:-}" ;;
    --topo) shift; TOPO_ARG="${1:-}" ;;
    --imagery) shift; IMAGERY_ARG="${1:-}" ;;
    *) echo "unknown option: $1"; exit 1 ;;
  esac
  shift
done

if [ -n "$NONINTERACTIVE" ]; then
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
# Offline maps (OpenStreetMap via Protomaps; one .pmtiles per state)
# ---------------------------------------------------------------------------
pick_states() {  # $1 = dialog title, $2 = filename suffix for "(downloaded)"
  MARGS=()
  while IFS='|' read -r tag bbox; do
    state=$(echo "$tag" | tr '-' ' ' | sed 's/\b\(.\)/\u\1/g')
    [ -s "maps/$tag$2.pmtiles" ] && state="$state (downloaded)"
    MARGS+=("$tag" "$state" OFF)
  done <<< "$STATES"
  whiptail --title "$1" \
    --checklist "SPACE toggles, ENTER confirms; select none to skip." \
    24 70 16 "${MARGS[@]}" 3>&1 1>&2 2>&3 | tr -d '"' | tr ' ' '\n'
}

if [ -n "$MAPS_ARG" ]; then
  MAP_SELECTED=$(echo "$MAPS_ARG" | tr ',' '\n')
elif [ -z "$NONINTERACTIVE" ] && command -v whiptail >/dev/null 2>&1 && [ -t 0 ]; then
  MAP_SELECTED=$(pick_states "Street maps (OpenStreetMap, ~0.5-2 GB/state)" "") || MAP_SELECTED=""
else
  MAP_SELECTED=""
fi

if [ -n "$TOPO_ARG" ]; then
  TOPO_SELECTED=$(echo "$TOPO_ARG" | tr ',' '\n')
elif [ -z "$NONINTERACTIVE" ] && command -v whiptail >/dev/null 2>&1 && [ -t 0 ]; then
  TOPO_SELECTED=$(pick_states "USGS topo maps (raster, ~2-4 GB and ~1 h/state)" "-topo") || TOPO_SELECTED=""
else
  TOPO_SELECTED=""
fi

if [ -n "$IMAGERY_ARG" ]; then
  IMAGERY_SELECTED=$(echo "$IMAGERY_ARG" | tr ',' '\n')
elif [ -z "$NONINTERACTIVE" ] && command -v whiptail >/dev/null 2>&1 && [ -t 0 ]; then
  IMAGERY_SELECTED=$(pick_states "USGS aerial imagery (~16 m/px statewide, ~3-6 GB/state)" "-imagery") || IMAGERY_SELECTED=""
else
  IMAGERY_SELECTED=""
fi

if [ -n "$MAP_SELECTED" ] || [ -n "$TOPO_SELECTED" ] || [ -n "$IMAGERY_SELECTED" ]; then
  # map viewer libraries (MapLibre BSD, pmtiles BSD, protomaps basemaps BSD,
  # Noto fonts OFL) — vendored locally so the viewer works fully offline
  if [ ! -f static/vendor/maplibre-gl.js ]; then
    echo "downloading map viewer libraries..."
    mkdir -p static/vendor
    curl -fsL -o static/vendor/maplibre-gl.js https://unpkg.com/maplibre-gl@5/dist/maplibre-gl.js
    curl -fsL -o static/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5/dist/maplibre-gl.css
    curl -fsL -o static/vendor/pmtiles.js https://unpkg.com/pmtiles@4/dist/pmtiles.js
    curl -fsL -o static/vendor/basemaps.js "https://unpkg.com/@protomaps/basemaps@5/dist/basemaps.js"
    curl -fsL -o /tmp/basemaps-assets.tar.gz https://github.com/protomaps/basemaps-assets/archive/refs/heads/main.tar.gz \
      && tar xzf /tmp/basemaps-assets.tar.gz -C /tmp \
      && mkdir -p static/vendor/basemaps-assets/fonts \
      && cp -r "/tmp/basemaps-assets-main/fonts/Noto Sans Regular" \
               "/tmp/basemaps-assets-main/fonts/Noto Sans Medium" \
               "/tmp/basemaps-assets-main/fonts/Noto Sans Italic" \
               /tmp/basemaps-assets-main/fonts/OFL.txt \
               static/vendor/basemaps-assets/fonts/ \
      && cp -r /tmp/basemaps-assets-main/sprites static/vendor/basemaps-assets/sprites \
      && rm -rf /tmp/basemaps-assets.tar.gz /tmp/basemaps-assets-main
  fi
  if [ ! -x maps/pmtiles ]; then
    echo "downloading pmtiles CLI..."
    curl -fsL -o maps/pmtiles.tar.gz \
      https://github.com/protomaps/go-pmtiles/releases/download/v1.31.2/go-pmtiles_1.31.2_Linux_x86_64.tar.gz \
      && tar xzf maps/pmtiles.tar.gz -C maps pmtiles && rm -f maps/pmtiles.tar.gz
  fi
fi

if [ -n "$MAP_SELECTED" ]; then
  # find the newest available daily planet build (today, else back a few days)
  BUILD=""
  for d in 0 1 2 3; do
    day=$(date -u -d "-$d day" +%Y%m%d)
    if curl -sfI --max-time 20 "https://build.protomaps.com/$day.pmtiles" >/dev/null; then
      BUILD="https://build.protomaps.com/$day.pmtiles"; break
    fi
  done
  if [ -z "$BUILD" ]; then
    echo "ERROR: no protomaps build reachable — skipping maps"
  else
    echo "extracting from $BUILD"
    while IFS='|' read -r tag bbox; do
      echo "$MAP_SELECTED" | grep -qx "$tag" || continue
      if [ -s "maps/$tag.pmtiles" ]; then
        echo "skip (exists): maps/$tag.pmtiles"; continue
      fi
      echo "extracting map: $tag ($bbox)"
      if ./maps/pmtiles extract "$BUILD" "maps/$tag.pmtiles.part" --bbox="$bbox"; then
        mv "maps/$tag.pmtiles.part" "maps/$tag.pmtiles"
        du -h "maps/$tag.pmtiles"
      else
        rm -f "maps/$tag.pmtiles.part"; echo "  FAILED: $tag"
      fi
    done <<< "$STATES"
  fi
fi

# USGS raster layers (public domain). Zoom envs control detail: topo
# TOPO_MAX_ZOOM (13 default, 15 = full 1:24k, ~16x cost); imagery
# IMAGERY_MAX_ZOOM (13 default ~16 m/px; 16-17 shows buildings but is
# ~100+ GB per state — use scripts/fetch_usgs.py directly with a small
# bbox for a high-detail area of interest).
fetch_usgs_layer() {  # $1 = selected tags, $2 = suffix (topo|imagery)
  while IFS='|' read -r tag bbox; do
    echo "$1" | grep -qx "$tag" || continue
    if [ -s "maps/$tag-$2.pmtiles" ]; then
      echo "skip (exists): maps/$tag-$2.pmtiles"; continue
    fi
    echo "fetching USGS $2: $tag ($bbox)"
    if python3 scripts/fetch_usgs.py "maps/$tag-$2.mbtiles" "$bbox" "$2" \
        && ./maps/pmtiles convert "maps/$tag-$2.mbtiles" "maps/$tag-$2.pmtiles"; then
      rm -f "maps/$tag-$2.mbtiles"
      du -h "maps/$tag-$2.pmtiles"
    else
      echo "  FAILED: $tag $2 (mbtiles kept for resume — re-run setup.sh)"
    fi
  done <<< "$STATES"
}

[ -n "$TOPO_SELECTED" ] && fetch_usgs_layer "$TOPO_SELECTED" topo
[ -n "$IMAGERY_SELECTED" ] && fetch_usgs_layer "$IMAGERY_SELECTED" imagery

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
