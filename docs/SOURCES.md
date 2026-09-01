# Reference documents

The embedding index (`python kit.py index`) expects these files in `./docs/`.
Downloaded files are not committed to the repo — fetch them to the exact
filenames below, then rebuild the index. Text versions come from archive.org's
OCR layer (`_djvu.txt`) or Project Gutenberg; strip the Gutenberg
header/footer boilerplate (between the `*** START OF ***` / `*** END OF ***`
markers) after download.

## Survival, SERE, and fieldcraft (US Army — public domain, approved for public release)

| Save as | Document | Download |
|---|---|---|
| `fm21-76-survival-manual.pdf` | FM 21-76, Survival (277 pp. — shelter, water, fire, food, plants, traps) | https://archive.org/download/fm-21-76-us-army-survival-manual/FM%2021-76%20US%20ARMY%20SURVIVAL%20MANUAL.pdf |
| `fm21-76-1-survival-evasion-recovery.txt` | FM 21-76-1 / MCRP 3-02H, Survival, Evasion, and Recovery (multiservice SERE quick reference) | https://archive.org/download/Fm21-76-1/Fm21-76-1_djvu.txt |
| `fm21-75-combat-skills.txt` | FM 21-75, Combat Skills of the Soldier (cover, concealment, movement, observation, evasion) | https://archive.org/download/milmanual-fm-21-75-combat-skills-of-the-soldier/fm_21-75_combat_skills_of_the_soldier_djvu.txt |
| `fm7-8-infantry-platoon-squad.txt` | FM 7-8, Infantry Rifle Platoon and Squad (1992 — small-unit tactics, patrolling, defense) | https://archive.org/download/fm-7-8-infantry-rifle-platoon-and-sqaud-1992/FM%207-8%20Infantry%20Rifle%20Platoon%20And%20Sqaud%20%201992_djvu.txt |
| `fm5-103-survivability-fieldworks.txt` | FM 5-103, Survivability (1985 — fighting/protective positions, field fortification) | https://archive.org/download/fm-5-103-survivability-1985/FM%205-103%20Survivability%20%201985_djvu.txt |
| `fm31-70-cold-weather.txt` | FM 31-70, Basic Cold Weather Manual (1968 — clothing, shelters, cold injuries) | https://archive.org/download/fm-31-70-basic-cold-weather-manual-1968/FM%2031-70%20Basic%20Cold%20Weather%20Manual%20%201968_djvu.txt |

Note: FM 3-05.70 (the 2002 successor to FM 21-76) was deliberately excluded —
it carries a restricted-distribution marking; FM 21-76 covers the same ground
and is unrestricted.

## Health, sanitation, and long-duration emergencies

| Save as | Document | License | Download |
|---|---|---|---|
| `fm4-25.11-first-aid.pdf` | FM 4-25.11, First Aid (joint services) | Public domain (US gov) | https://archive.org/download/FM4-25x11/FM4-25x11.pdf |
| `fm21-10-field-hygiene-sanitation.txt` | FM 21-10 / MCRP 4-11.1D, Field Hygiene and Sanitation (camp sanitation, waste, disease prevention) | Public domain (US gov) | https://archive.org/download/milmanual-fm-21-10-mcrp-4-11.1d-field-hygiene-and-sanitation/fm_21-10_mcrp_4-11.1d_field_hygiene_and_sanitation_djvu.txt |
| `epa-emergency-disinfection-drinking-water.txt` | EPA, Emergency Disinfection of Drinking Water (saved as plain text) | Public domain (US gov) | https://www.epa.gov/ground-water-and-drinking-water/emergency-disinfection-drinking-water |
| `nuclear-war-survival-skills-kearny.txt` | Cresson Kearny, Nuclear War Survival Skills (Oak Ridge National Laboratory research; fallout shelters, expedient meters, water/food after fallout) | ORNL-origin work; author granted blanket permission for non-commercial reproduction | https://archive.org/download/nuclear-war-survival-skills-by-cresson-h.-kearny/Nuclear%20War%20Survival%20Skills%2C%20by%20Cresson%20H.%20Kearny_djvu.txt |
| `fm3-19.15-civil-disturbance.txt` | FM 3-19.15, Civil Disturbance Operations (2005 — crowd dynamics, riot control doctrine) | Public domain (US gov) | https://archive.org/download/fm-3-19.15-civil-disturbance-operations-2005/FM%203-19.15%20Civil%20Disturbance%20Operations%20%202005_djvu.txt |

## Food: growing, preserving, trapping

| Save as | Document | License | Download |
|---|---|---|---|
| `usda-complete-guide-home-canning.txt` | USDA Complete Guide to Home Canning (2015 revision, AIB 539) | Public domain (US gov) | https://archive.org/download/usda-complete-guide-to-home-canning-2015-revision/USDA-Complete-Guide-to-Home-Canning-2015-revision_djvu.txt |
| `vegetable-gardening-watts.txt` | R. L. Watts, Vegetable Gardening (1912) | Public domain (pre-1929) | https://archive.org/download/vegetablegardeni00wattrich/vegetablegardeni00wattrich_djvu.txt |
| `camp-life-woods-tricks-of-trapping.txt` | W. H. Gibson, Camp Life in the Woods and the Tricks of Trapping (1881) | Public domain (pre-1929) | https://archive.org/download/william-hamilton-gibson-camp-life-in-the-woods-the-tricks-of-trapping/William_Hamilton_Gibson_Camp_Life_in_the_Woods_%26_the_Tricks_of_Trapping_djvu.txt |

## Woodcraft, camping, primitive building

| Save as | Document | License | Download |
|---|---|---|---|
| `shelters-shacks-and-shanties-beard.txt` | D. C. Beard, Shelters, Shacks and Shanties (1914 — structures built with axe and hand tools) | Public domain (pre-1929) | https://www.gutenberg.org/cache/epub/28255/pg28255.txt |
| `woodcraft-and-camping-nessmuk.txt` | G. W. Sears ("Nessmuk"), Woodcraft and Camping | Public domain (pre-1929) | https://www.gutenberg.org/cache/epub/34607/pg34607.txt |
| `boy-scouts-handbook-1911.txt` | Boy Scouts Handbook, 1st ed. (1911 — firecraft, knots, camping, signaling, first aid) | Public domain (pre-1929) | https://www.gutenberg.org/cache/epub/29558/pg29558.txt |

## Worth adding manually (not auto-downloadable)

- FEMA "Are You Ready?" all-hazards guide — fema.gov blocks scripted
  downloads; grab it in a browser and drop the PDF in `./docs/`.
- Hesperian's *Where There Is No Doctor* — excellent long-emergency medical
  reference; free for personal use but Hesperian's open-copyright license
  gates downloads behind a form, so fetch it yourself.

Rebuild: download each file above to its `Save as` name, strip Gutenberg
boilerplate, then `./venv/bin/python kit.py index`.
