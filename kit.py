#!/usr/bin/env python3
"""Offline emergency knowledge kit.

Combines two retrieval sources into one grounded answer:
  1. Local ./docs (PDF/MD/TXT) chunked + embedded via LM Studio, cosine retrieval.
  2. Kiwix full-text search over local ZIMs (no embedding), keyword pattern.

Usage:
  python kit.py index            # (re)build the local docs embedding index
  python kit.py ask "question"
  python kit.py ask -v "question"   # also show retrieved chunks and scores

app.py wraps the same functions with a web UI; this file stays standalone.
Dependencies: numpy, pypdf. Everything else is stdlib (urllib for HTTP).
"""

import json
import os
import re
import sys
import time
import urllib.request
import urllib.parse
import urllib.error
from pathlib import Path
from xml.etree import ElementTree

import numpy as np

# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------
# Machine-specific overrides live in a gitignored .env next to this file
# (KEY=VALUE lines; see .env.example). Real environment variables win over .env.
def _load_env():
    env = {}
    p = Path(__file__).parent / ".env"
    if p.exists():
        for line in p.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    env.update(os.environ)
    return env

_ENV = _load_env()

def _extra_urls(key):
    return [u.strip() for u in _ENV.get(key, "").split(",") if u.strip()]

# Base URLs are tried in order; first one that answers wins. Defaults assume
# everything runs on one box (the laptop target). If LM Studio or kiwix live
# elsewhere (e.g. on the Windows host when developing under WSL2), add their
# URLs via LMSTUDIO_EXTRA_URLS / KIWIX_EXTRA_URLS in .env.
LMSTUDIO_URLS = [
    "http://localhost:1234/v1",
    "http://127.0.0.1:1234/v1",
] + _extra_urls("LMSTUDIO_EXTRA_URLS")
KIWIX_URLS = [
    "http://localhost:8080",
    "http://127.0.0.1:8080",
] + _extra_urls("KIWIX_EXTRA_URLS")

CHAT_MODEL = _ENV.get("CHAT_MODEL", "qwen3.5-4b")
# "none" suppresses qwen3.5's chain-of-thought entirely (LM Studio honors the
# OpenAI reasoning_effort field). Set to None to leave reasoning at model default.
REASONING_EFFORT = "none"
EMBED_MODEL = _ENV.get("EMBED_MODEL", "text-embedding-nomic-embed-text-v1.5@f16")

# Book names as reported by kiwix-serve (/content/<name>/ URLs), most useful
# first — searched in order, results merged up to TOP_K_WIKI.
KIWIX_BOOKS = [
    "wikipedia_en_medicine_maxi_2026-04",
    "wikipedia_en_100_2026-08",
]

DOCS_DIR = Path(__file__).parent / "docs"
INDEX_FILE = Path(__file__).parent / "index.npz"

CHUNK_CHARS = 1600        # ~400 tokens per chunk
CHUNK_OVERLAP = 200
EMBED_BATCH = 32

TOP_K_DOCS = 4            # local doc chunks in the prompt
TOP_K_WIKI = 2            # kiwix articles fetched
DOC_SCORE_FLOOR = 0.65    # drop doc chunks below this cosine similarity
WIKI_EXCERPT_CHARS = 2500 # per-article cap so wiki doesn't drown the prompt

MAX_ANSWER_TOKENS = 3000
REQUEST_TIMEOUT = 300

# nomic-embed-text-v1.5 is trained with task prefixes.
DOC_PREFIX = "search_document: "
QUERY_PREFIX = "search_query: "

SYSTEM_PROMPT = """You are an offline emergency reference assistant. Prefer the numbered sources provided. Rules:
- When the sources cover the question, base every statement on them and cite the source title inline after each claim, e.g. (EPA Emergency Disinfection of Drinking Water). Do not mix in facts from your own knowledge.
- Quote exact quantities, doses, and durations verbatim from the sources.
- If the sources do NOT cover the question (or none were retrieved), you may answer from your own general knowledge, but you MUST begin with exactly this line:
  **No sources cover this — answering from model memory, verify independently.**
  Then give your best answer. Never cite a source title for a claim that did not come from the sources, and never present a memory-based answer as sourced."""

MANIFEST_PROMPT = """

You also know your own library. If asked what you know, what topics you cover,
or whether you have material on some subject, answer from this manifest ONLY —
ignore any retrieved sources for such questions about your own library:

{manifest}"""


# ----------------------------------------------------------------------------
# HTTP helpers (urllib only)
# ----------------------------------------------------------------------------
def _http(url, data=None, timeout=REQUEST_TIMEOUT):
    req = urllib.request.Request(url)
    if data is not None:
        req.add_header("Content-Type", "application/json")
        req.data = json.dumps(data).encode()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def _pick_base(candidates, probe_path):
    for base in candidates:
        try:
            _http(base + probe_path, timeout=5)
            return base
        except Exception:
            continue
    raise RuntimeError(f"none of {candidates} responded at {probe_path}")


_lm_base = None
def lm_base():
    global _lm_base
    if _lm_base is None:
        _lm_base = _pick_base(LMSTUDIO_URLS, "/models")
    return _lm_base


_kiwix_base = None
def kiwix_base():
    global _kiwix_base
    if _kiwix_base is None:
        _kiwix_base = _pick_base(KIWIX_URLS, "/")
    return _kiwix_base


def embed(texts):
    out = _http(lm_base() + "/embeddings",
                {"model": EMBED_MODEL, "input": texts})
    data = json.loads(out)["data"]
    data.sort(key=lambda d: d["index"])
    return np.array([d["embedding"] for d in data], dtype=np.float32)


def _chat_payload(messages, stream=False):
    payload = {
        "model": CHAT_MODEL,
        "messages": messages,
        "temperature": 0.1,
        "max_tokens": MAX_ANSWER_TOKENS,
        "stream": stream,
    }
    if stream:
        payload["stream_options"] = {"include_usage": True}
    if REASONING_EFFORT:
        payload["reasoning_effort"] = REASONING_EFFORT
    return payload


def chat(messages):
    """Non-streaming completion -> (text, usage dict)."""
    out = _http(lm_base() + "/chat/completions", _chat_payload(messages))
    resp = json.loads(out)
    msg = resp["choices"][0]["message"]
    text = msg.get("content") or ""
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.S).strip()
    return text, resp.get("usage", {})


def chat_stream(messages):
    """Streaming completion -> yields content deltas, then a final
    ("__usage__", dict) tuple if the server reports usage."""
    req = urllib.request.Request(lm_base() + "/chat/completions")
    req.add_header("Content-Type", "application/json")
    req.data = json.dumps(_chat_payload(messages, stream=True)).encode()
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as r:
        for raw in r:
            line = raw.decode(errors="replace").strip()
            if not line.startswith("data:"):
                continue
            line = line[5:].strip()
            if line == "[DONE]":
                break
            try:
                obj = json.loads(line)
            except ValueError:
                continue
            if obj.get("usage"):
                yield ("__usage__", obj["usage"])
            for ch in obj.get("choices", []):
                delta = ch.get("delta", {}).get("content")
                if delta:
                    yield delta


# ----------------------------------------------------------------------------
# Local docs: extract, chunk, index
# ----------------------------------------------------------------------------
def _normalize(text):
    text = re.sub(r"[ \t]+", " ", text)
    return re.sub(r"\n{3,}", "\n\n", text)


def extract_pages(path):
    """Returns list of (page_number_or_None, normalized_text)."""
    if path.suffix.lower() == ".pdf":
        from pypdf import PdfReader
        return [(i + 1, _normalize(p.extract_text() or ""))
                for i, p in enumerate(PdfReader(path).pages)]
    return [(None, _normalize(path.read_text(errors="replace")))]


def chunk_file(path):
    """Chunk a file, tracking which page each chunk starts on.
    Returns list of {text, page}."""
    pages = extract_pages(path)
    offsets, buf, pos = [], [], 0
    for pno, ptext in pages:
        offsets.append((pos, pno))
        buf.append(ptext)
        pos += len(ptext) + 1
    text = "\n".join(buf).strip()

    chunks, start = [], 0
    while start < len(text):
        end = start + CHUNK_CHARS
        if end < len(text):
            cut = max(text.rfind("\n\n", start, end), text.rfind(". ", start, end))
            if cut > start + CHUNK_CHARS // 2:
                end = cut + 1
        chunk = text[start:end].strip()
        if len(chunk) > 50:
            page = None
            for off, pno in offsets:
                if off <= start:
                    page = pno
                else:
                    break
            chunks.append({"text": chunk, "page": page})
        start = end - CHUNK_OVERLAP if end < len(text) else len(text)
    return chunks


def describe_doc(name, head):
    """One-line description of a document, generated once at index time."""
    prompt = (f"Here is the beginning of a reference document named "
              f"'{name}':\n\n{head}\n\nDescribe this document in ONE short "
              f"sentence (what it is and what it covers). Reply with the "
              f"sentence only.")
    try:
        text, _ = chat([{"role": "user", "content": prompt}])
        return text.strip().split("\n")[0][:300]
    except Exception as e:
        print(f"warning: description failed for {name}: {e}", file=sys.stderr)
        return ""


def cmd_index():
    files = sorted(p for p in DOCS_DIR.iterdir()
                   if p.suffix.lower() in (".pdf", ".md", ".txt"))
    if not files:
        sys.exit(f"error: no PDF/MD/TXT files in {DOCS_DIR}")
    t0 = time.time()
    all_chunks, meta, descriptions = [], [], {}
    for f in files:
        chunks = chunk_file(f)
        print(f"{f.name}: {len(chunks)} chunks")
        descriptions[f.name] = describe_doc(
            f.name, "\n".join(c["text"] for c in chunks)[:2000])
        print(f"  description: {descriptions[f.name]}")
        for i, c in enumerate(chunks):
            all_chunks.append(c["text"])
            meta.append({"file": f.name, "chunk": i, "page": c["page"]})
    print(f"embedding {len(all_chunks)} chunks...")
    vecs = []
    for i in range(0, len(all_chunks), EMBED_BATCH):
        batch = [DOC_PREFIX + c for c in all_chunks[i:i + EMBED_BATCH]]
        vecs.append(embed(batch))
        print(f"  {min(i + EMBED_BATCH, len(all_chunks))}/{len(all_chunks)}", end="\r")
    vecs = np.vstack(vecs)
    vecs /= np.linalg.norm(vecs, axis=1, keepdims=True)
    np.savez_compressed(
        INDEX_FILE, embeddings=vecs,
        chunks=np.array(all_chunks, dtype=object),
        meta=np.array([json.dumps(m) for m in meta], dtype=object),
        descriptions=json.dumps(descriptions))
    print(f"\nindexed {len(all_chunks)} chunks from {len(files)} files "
          f"in {time.time() - t0:.1f}s -> {INDEX_FILE.name}")


_index_cache = None
def load_index():
    global _index_cache
    if _index_cache is None:
        if not INDEX_FILE.exists():
            raise RuntimeError("no index found — run `python kit.py index` first")
        _index_cache = np.load(INDEX_FILE, allow_pickle=True)
    return _index_cache


def doc_descriptions():
    idx = load_index()
    if "descriptions" not in idx.files:
        return {}
    return json.loads(str(idx["descriptions"]))


def search_docs(question, k=TOP_K_DOCS):
    idx = load_index()
    q = embed([QUERY_PREFIX + question])[0]
    q /= np.linalg.norm(q)
    scores = idx["embeddings"] @ q
    order = [i for i in np.argsort(scores)[::-1][:k]
             if scores[i] >= DOC_SCORE_FLOOR]
    return [{"score": float(scores[i]),
             "text": str(idx["chunks"][i]),
             **json.loads(str(idx["meta"][i]))} for i in order]


# ----------------------------------------------------------------------------
# Kiwix retrieval
# ----------------------------------------------------------------------------
# Words that carry no search signal in an emergency-reference question.
STOPWORDS = set("""a an and are as at be but by can could do does for from get
have how i if in is it its me my of on or should so that the them then there
this to und was we what when where which who why will with would you your much
many long need needs add make makes made using use i'm it's""".split())


def extract_keywords(question, max_kw=4):
    """2-4 content keywords for the kiwix full-text pattern (stopword strip)."""
    words = re.findall(r"[a-zA-Z][a-zA-Z0-9'-]+", question.lower())
    seen, content = set(), []
    for w in words:
        if w not in STOPWORDS and w not in seen:
            seen.add(w)
            content.append(w)
    # prefer longer words (more specific) but keep question order for ties
    content.sort(key=lambda w: -len(w))
    return sorted(content[:max_kw], key=lambda w: question.lower().find(w))


def strip_html(html):
    html = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", html, flags=re.S | re.I)
    html = re.sub(r"<[^>]+>", " ", html)
    html = html.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    html = html.replace("&#39;", "'").replace("&quot;", '"').replace("&nbsp;", " ")
    return re.sub(r"\s+", " ", html).strip()


def _kiwix_search_book(base, pattern, book, k):
    qs = urllib.parse.urlencode({
        "pattern": pattern, "format": "xml",
        "books.name": book, "pageLength": k})
    xml = _http(f"{base}/search?{qs}", timeout=30).decode(errors="replace")
    results = []
    for item in ElementTree.fromstring(xml).iter("item"):
        title = item.findtext("title", "").strip()
        link = item.findtext("link", "").strip()
        if not link:
            continue
        # normalize to a fetchable /content/ URL (this kiwix-tools version
        # already returns /content/<book>/<Article>)
        link = link.split("#")[-1]
        if not link.startswith("/"):
            link = "/content/" + link
        elif not link.startswith("/content/"):
            link = "/content" + link
        results.append({"title": title, "link": link, "book": book})
    return results


def search_kiwix(question, k=TOP_K_WIKI):
    base = kiwix_base()
    keywords = extract_keywords(question)
    pattern = " ".join(keywords)
    candidates = []
    for book in KIWIX_BOOKS:
        try:
            candidates += _kiwix_search_book(base, pattern, book, k)
        except Exception as e:
            print(f"warning: kiwix search failed for {book} ({e})",
                  file=sys.stderr)
    results = []
    for c in candidates[:k]:
        try:
            html = _http(base + urllib.parse.quote(c["link"]),
                         timeout=30).decode(errors="replace")
        except Exception as e:
            print(f"warning: fetch failed for {c['link']}: {e}", file=sys.stderr)
            continue
        text = strip_html(html)[:WIKI_EXCERPT_CHARS]
        # relevance floor: the article text must actually contain one of the
        # search keywords, otherwise it's a stray full-text match
        if not any(kw in text.lower() for kw in keywords):
            continue
        results.append({"title": c["title"], "url": c["link"],
                        "keywords": keywords, "text": text})
    return results


def kiwix_catalog():
    """ZIMs served by kiwix: [{title, summary, articles, path}] from OPDS."""
    base = kiwix_base()
    xml = _http(base + "/catalog/v2/entries", timeout=15).decode(errors="replace")
    ns = {"a": "http://www.w3.org/2005/Atom"}
    books = []
    for e in ElementTree.fromstring(xml).findall("a:entry", ns):
        path = ""
        for link in e.findall("a:link", ns):
            if link.get("type") == "text/html":
                path = link.get("href", "")
        books.append({
            "title": e.findtext("a:title", "", ns),
            "summary": e.findtext("a:summary", "", ns),
            "articles": int(e.findtext("a:articleCount", "0", ns) or 0),
            "path": path,
        })
    return books


# ----------------------------------------------------------------------------
# Retrieval + prompt assembly (shared by CLI and web app)
# ----------------------------------------------------------------------------
def retrieve(question):
    return search_docs(question), search_kiwix(question)


def sources_manifest():
    """What the kit knows: served ZIMs + indexed docs with descriptions."""
    idx = load_index()
    descs = doc_descriptions()
    counts = {}
    for m in idx["meta"]:
        f = json.loads(str(m))["file"]
        counts[f] = counts.get(f, 0) + 1
    docs = [{"file": f, "chunks": n, "description": descs.get(f, "")}
            for f, n in sorted(counts.items())]
    try:
        zims = kiwix_catalog()
    except Exception:
        zims = []
    return {"docs": docs, "zims": zims}


def manifest_text(manifest):
    lines = ["Local reference documents:"]
    for d in manifest["docs"]:
        lines.append(f"- {d['file']}: {d['description']} ({d['chunks']} chunks)")
    lines.append("Offline Wikipedia (kiwix, full-text searchable):")
    for z in manifest["zims"]:
        lines.append(f"- {z['title']}: {z['summary']} ({z['articles']} articles)")
    return "\n".join(lines)


def build_messages(question, doc_hits, wiki_hits, history=None, manifest=None):
    """history: prior [{role, content}] turns (answers without context blocks)."""
    system = SYSTEM_PROMPT
    if manifest:
        system += MANIFEST_PROMPT.format(manifest=manifest_text(manifest))
    sources, n = [], 0
    for h in doc_hits:
        n += 1
        page = f", p. {h['page']}" if h.get("page") else ""
        sources.append(f"[Source {n}: {h['file']}{page}]\n{h['text']}")
    for h in wiki_hits:
        n += 1
        sources.append(f"[Source {n}: Wikipedia - {h['title']}]\n{h['text']}")
    body = "SOURCES:\n\n" + "\n\n".join(sources) if sources else \
        "SOURCES: (none retrieved — nothing relevant found)"
    messages = [{"role": "system", "content": system}]
    messages += history or []
    messages.append({"role": "user", "content": body + f"\n\nQUESTION: {question}"})
    return messages


# ----------------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------------
def cmd_ask(question, verbose=False):
    t0 = time.time()
    doc_hits, wiki_hits = retrieve(question)
    t_retrieval = time.time() - t0

    if verbose:
        print("=" * 70)
        print("RETRIEVED CONTEXT")
        for h in doc_hits:
            page = f" p.{h['page']}" if h.get("page") else ""
            print(f"\n--- docs: {h['file']} chunk {h['chunk']}{page} "
                  f"(cosine {h['score']:.3f}) ---")
            print(h["text"])
        for h in wiki_hits:
            print(f"\n--- wikipedia: {h['title']} ({h['url']}) ---")
            print(h["text"])
        print("=" * 70)

    t1 = time.time()
    answer, usage = chat(build_messages(question, doc_hits, wiki_hits))
    t_llm = time.time() - t1

    print("\nANSWER:\n" + answer)
    print(f"\n[retrieval {t_retrieval:.1f}s | llm {t_llm:.1f}s | "
          f"prompt {usage.get('prompt_tokens', '?')} tok | "
          f"completion {usage.get('completion_tokens', '?')} tok]")


def main():
    args = sys.argv[1:]
    if args and args[0] == "index":
        cmd_index()
    elif args and args[0] == "ask":
        rest = args[1:]
        verbose = "-v" in rest
        rest = [a for a in rest if a != "-v"]
        if not rest:
            sys.exit("usage: kit.py ask [-v] \"question\"")
        cmd_ask(" ".join(rest), verbose)
    else:
        sys.exit("usage: kit.py index | kit.py ask [-v] \"question\"")


if __name__ == "__main__":
    main()
