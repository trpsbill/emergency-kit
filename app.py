#!/usr/bin/env python3
"""Web UI for the offline emergency knowledge kit.

Thin FastAPI wrapper around kit.py — retrieval and prompting live there.

  ./venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000

Endpoints:
  GET  /             chat UI (static/index.html)
  GET  /api/sources  manifest of everything the kit knows
  POST /api/ask      SSE stream: meta event (retrieved context), token deltas,
                     done event (usage)
"""

import json
import time
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

import kit

# Kiwix base as seen from the user's browser (article links in citations).
KIWIX_PUBLIC_URL = kit._ENV.get("KIWIX_PUBLIC_URL", "http://localhost:8080")
MAX_HISTORY_TURNS = 6     # question+answer pairs kept as conversation context
# KIT_DEBUG=1 (env or .env, or `./start.sh --debug`) adds token counts and
# tokens/s to each answer's stats line for troubleshooting.
DEBUG_STATS = kit._ENV.get("KIT_DEBUG", "") not in ("", "0")
# Suggested replies after each answer (one extra small LLM call).
# Disable with KIT_SUGGESTIONS=0 (worth it on slow CPU).
SUGGESTIONS = kit._ENV.get("KIT_SUGGESTIONS", "1") not in ("", "0")

app = FastAPI(title="Emergency Knowledge Kit")
STATIC = Path(__file__).parent / "static"
MAPS = Path(__file__).parent / "maps"

app.mount("/static", StaticFiles(directory=STATIC), name="static")
if MAPS.is_dir():
    # StaticFiles serves byte ranges, which pmtiles clients require
    app.mount("/maps", StaticFiles(directory=MAPS), name="maps")


class AskRequest(BaseModel):
    question: str
    # prior turns, oldest first: [{"role": "user"|"assistant", "content": str}]
    history: list[dict] = []


@app.get("/")
def index():
    return FileResponse(STATIC / "index.html")


@app.get("/map")
def map_page():
    return FileResponse(STATIC / "map.html")


@app.get("/api/maps")
def maps_list():
    files = sorted(MAPS.glob("*.pmtiles")) if MAPS.is_dir() else []
    out = []
    for f in files:
        topo = f.stem.endswith("-topo")
        name = f.stem.removesuffix("-topo").replace("-", " ").title()
        out.append({
            "name": name + (" Topo (USGS)" if topo else ""),
            "url": f"/maps/{f.name}",
            "type": "raster" if topo else "vector",
            "size_mb": round(f.stat().st_size / 1e6)})
    return JSONResponse(out)


@app.get("/api/sources")
def sources():
    m = kit.sources_manifest()
    m["kiwix_url"] = KIWIX_PUBLIC_URL
    return JSONResponse(m)


def _sse(event, data):
    return f"event: {event}\ndata: {json.dumps(data)}\n\n"


@app.post("/api/ask")
def ask(req: AskRequest):
    question = req.question.strip()
    history = [
        {"role": m["role"], "content": str(m["content"])[:4000]}
        for m in req.history
        if m.get("role") in ("user", "assistant") and m.get("content")
    ][-2 * MAX_HISTORY_TURNS:]

    def generate():
        if not kit.check_llm():
            yield _sse("error", {"message":
                "The language model server is not reachable. Start LM Studio "
                "(or llama.cpp) with the server enabled, then try again. "
                f"Tried: {', '.join(kit.LMSTUDIO_URLS)}"})
            return
        t0 = time.time()
        try:
            doc_hits, wiki_hits = kit.retrieve(question)
            manifest = kit.sources_manifest()
        except Exception as e:
            yield _sse("error", {"message": str(e)})
            return
        t_retrieval = time.time() - t0

        yield _sse("meta", {
            "retrieval_seconds": round(t_retrieval, 2),
            "docs": [{"file": h["file"], "chunk": h["chunk"],
                      "page": h.get("page"), "score": round(h["score"], 3),
                      "text": h["text"]} for h in doc_hits],
            "wiki": [{"title": h["title"],
                      "url": KIWIX_PUBLIC_URL + h["url"],
                      "images": [KIWIX_PUBLIC_URL + i
                                 for i in h.get("images", [])],
                      "text": h["text"]} for h in wiki_hits],
        })

        messages = kit.build_messages(question, doc_hits, wiki_hits,
                                      history=history, manifest=manifest)
        answer_parts = []
        if not doc_hits and not wiki_hits:
            yield _sse("token", {"t": kit.DISCLAIMER})
        t1 = time.time()
        usage = {}
        try:
            for delta in kit.chat_stream(messages):
                if isinstance(delta, tuple) and delta[0] == "__usage__":
                    usage = delta[1]
                else:
                    answer_parts.append(delta)
                    yield _sse("token", {"t": delta})
        except Exception as e:
            yield _sse("error", {"message": f"LLM request failed: {e}"})
            return
        t_llm = time.time() - t1
        done = {"llm_seconds": round(t_llm, 1)}
        if DEBUG_STATS:
            comp = usage.get("completion_tokens")
            done.update({
                "prompt_tokens": usage.get("prompt_tokens"),
                "completion_tokens": comp,
                "tokens_per_s": round(comp / t_llm, 1) if comp and t_llm > 0 else None,
            })
        yield _sse("done", done)
        if SUGGESTIONS:
            replies = kit.suggest_replies(question, "".join(answer_parts))
            if replies:
                yield _sse("suggestions", {"items": replies})

    return StreamingResponse(generate(), media_type="text/event-stream",
                             headers={"Cache-Control": "no-cache",
                                      "X-Accel-Buffering": "no"})
