#!/usr/bin/env python3
"""Fetch USGS raster tiles (topo or aerial imagery) for a bounding box into
an MBTiles file.

Usage:
  python3 scripts/fetch_usgs.py <out.mbtiles> <west,south,east,north> [topo|imagery]

Env:
  TOPO_MAX_ZOOM     deepest zoom for topo (default 13; ~1:70k, first contour
                    detail. Each +1 zoom is ~4x more tiles/time/disk; 15 is
                    full 1:24k quad detail)
  IMAGERY_MAX_ZOOM  deepest zoom for imagery (default 13, ~16 m/px terrain
                    context. 16-17 shows buildings but is ~100+ GB per state
                    — use a small bounding box for high zooms)
  TOPO_CONCURRENCY  parallel requests (default 8 — keep modest; this is a
                    free public USGS service)

Resumable: re-running skips tiles already stored. Convert the result with
  ./maps/pmtiles convert out.mbtiles out.pmtiles

High-detail area of interest (e.g. ~30 mi around home at ~1 m/px):
  IMAGERY_MAX_ZOOM=17 python3 scripts/fetch_usgs.py maps/home-imagery.mbtiles \
      -97.0,30.0,-96.5,30.4 imagery

Data: USGS The National Map (public domain).
"""

import math
import os
import sqlite3
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

SERVICES = {
    "topo": ("USGSTopo", "USGS Topo", "TOPO_MAX_ZOOM"),
    "imagery": ("USGSImageryOnly", "USGS Imagery", "IMAGERY_MAX_ZOOM"),
}
CONCURRENCY = int(os.environ.get("TOPO_CONCURRENCY", "8"))
RETRIES = 3


def tile_range(z, west, south, east, north):
    def x_of(lon):
        return int((lon + 180) / 360 * (1 << z))
    def y_of(lat):
        r = math.radians(lat)
        return int((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi)
                   / 2 * (1 << z))
    n = (1 << z) - 1
    x0, x1 = max(0, x_of(west)), min(n, x_of(east))
    y0, y1 = max(0, y_of(north)), min(n, y_of(south))
    return x0, x1, y0, y1


def fetch(tile_url, z, x, y):
    req = urllib.request.Request(
        tile_url.format(z=z, x=x, y=y),
        headers={"User-Agent": "emergency-kit-offline-maps/1.0"})
    for attempt in range(RETRIES):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except Exception:
            if attempt == RETRIES - 1:
                return None
            time.sleep(1 + attempt * 2)


def main():
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    out = sys.argv[1]
    west, south, east, north = map(float, sys.argv[2].split(","))
    service = sys.argv[3] if len(sys.argv) == 4 else "topo"
    if service not in SERVICES:
        sys.exit(f"unknown service {service!r} — use: {', '.join(SERVICES)}")
    arcgis_name, label, zoom_env = SERVICES[service]
    tile_url = (f"https://basemap.nationalmap.gov/arcgis/rest/services/"
                f"{arcgis_name}/MapServer/tile/{{z}}/{{y}}/{{x}}")
    max_zoom = int(os.environ.get(zoom_env, "13"))

    db = sqlite3.connect(out)
    db.executescript("""
      CREATE TABLE IF NOT EXISTS metadata (name TEXT, value TEXT);
      CREATE TABLE IF NOT EXISTS tiles (
        zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER,
        tile_data BLOB);
      CREATE UNIQUE INDEX IF NOT EXISTS tile_index
        ON tiles (zoom_level, tile_column, tile_row);
    """)
    db.execute("DELETE FROM metadata")
    for k, v in [("name", label), ("format", "jpg"),
                 ("type", "baselayer"), ("version", "1"),
                 ("description", f"{label}, USGS The National Map (public domain)"),
                 ("bounds", f"{west},{south},{east},{north}"),
                 ("minzoom", "0"), ("maxzoom", str(max_zoom))]:
        db.execute("INSERT INTO metadata VALUES (?, ?)", (k, v))
    db.commit()

    jobs = []
    for z in range(0, max_zoom + 1):
        x0, x1, y0, y1 = tile_range(z, west, south, east, north)
        have = {(x, y) for x, y in db.execute(
            "SELECT tile_column, tile_row FROM tiles WHERE zoom_level=?", (z,))}
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                if (x, (1 << z) - 1 - y) not in have:   # mbtiles rows are TMS
                    jobs.append((z, x, y))
    total = len(jobs)
    print(f"{label}: {total} tiles to fetch (z0-{max_zoom}), "
          f"{CONCURRENCY} parallel")
    if not total:
        print("nothing to do"); return

    done = failed = 0
    t0 = time.time()
    with ThreadPoolExecutor(CONCURRENCY) as pool:
        futs = {pool.submit(fetch, tile_url, z, x, y): (z, x, y)
                for z, x, y in jobs}
        for fut in as_completed(futs):
            z, x, y = futs[fut]
            data = fut.result()
            if data:
                db.execute("INSERT OR IGNORE INTO tiles VALUES (?, ?, ?, ?)",
                           (z, x, (1 << z) - 1 - y, sqlite3.Binary(data)))
            else:
                failed += 1
            done += 1
            if done % 500 == 0:
                db.commit()
                rate = done / (time.time() - t0)
                eta = (total - done) / rate / 60 if rate else 0
                print(f"  {done}/{total} ({rate:.0f}/s, eta {eta:.0f} min, "
                      f"{failed} failed)", flush=True)
    db.commit()
    db.execute("VACUUM")
    db.close()
    print(f"done: {done - failed} tiles stored, {failed} failed, "
          f"{(time.time() - t0) / 60:.0f} min")
    if failed:
        print("re-run the same command to retry failed tiles")


if __name__ == "__main__":
    main()
