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
from pydantic import BaseModel

import kit

# Kiwix base as seen from the user's browser (article links in citations).
KIWIX_PUBLIC_URL = kit._ENV.get("KIWIX_PUBLIC_URL", "http://localhost:8080")
MAX_HISTORY_TURNS = 6     # question+answer pairs kept as conversation context

app = FastAPI(title="Emergency Knowledge Kit")
STATIC = Path(__file__).parent / "static"


class AskRequest(BaseModel):
    question: str
    # prior turns, oldest first: [{"role": "user"|"assistant", "content": str}]
    history: list[dict] = []


@app.get("/")
def index():
    return FileResponse(STATIC / "index.html")


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
                      "text": h["text"]} for h in wiki_hits],
        })

        messages = kit.build_messages(question, doc_hits, wiki_hits,
                                      history=history, manifest=manifest)
        t1 = time.time()
        usage = {}
        try:
            for delta in kit.chat_stream(messages):
                if isinstance(delta, tuple) and delta[0] == "__usage__":
                    usage = delta[1]
                else:
                    yield _sse("token", {"t": delta})
        except Exception as e:
            yield _sse("error", {"message": f"LLM request failed: {e}"})
            return
        yield _sse("done", {
            "llm_seconds": round(time.time() - t1, 1),
            "prompt_tokens": usage.get("prompt_tokens"),
            "completion_tokens": usage.get("completion_tokens"),
        })

    return StreamingResponse(generate(), media_type="text/event-stream",
                             headers={"Cache-Control": "no-cache",
                                      "X-Accel-Buffering": "no"})
