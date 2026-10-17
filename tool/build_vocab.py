"""把本地整理的词表 txt 解析成 App 用的 JSON 词库（本项目自编词库的生成脚本）。"""
import json, re, sys, os
from collections import Counter

sys.stdout.reconfigure(encoding="utf-8")

# 输入是本地整理的纯文本词表（每行：单词 音标 分级 释义），也可用命令行参数指定别的路径
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(r"~\Desktop\高考英语3500词库\高考英语3500词.txt")
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "words_gaokao.json")

LINE_RE = re.compile(r"^\s*(.+?)\s+(/[^/]*/)\s+(easy|normal|hard|extra)\s+(.+?)\s*$")
POS_RE = re.compile(r"^((?:[a-z]{1,6}\.)+\s*)(.*)$")

rows, bad = [], []
with open(SRC, encoding="utf-8") as f:
    for raw in f:
        line = raw.rstrip("\n")
        if not line.strip():
            continue
        m = LINE_RE.match(line)
        if not m:
            bad.append(line)
            continue
        word, phonetic, level, rest = m.groups()
        pm = POS_RE.match(rest)
        if pm:
            pos, meaning = pm.group(1).strip(), pm.group(2).strip()
        else:
            pos, meaning = "", rest.strip()
        if not meaning:
            bad.append(line)
            continue
        rows.append({"word": word.strip(), "phonetic": phonetic, "level": level, "pos": pos, "meaning": meaning})

print(f"parsed={len(rows)} bad={len(bad)}")
for b in bad[:5]:
    print("  BAD:", b)

# 去重：同一个单词 + 同一个释义才算重复
seen, words = set(), []
for r in rows:
    key = (r["word"].lower(), r["meaning"])
    if key in seen:
        continue
    seen.add(key)
    words.append(r)

print("after dedup:", len(words))
print("levels:", Counter(w["level"] for w in words))

TIER = {"easy": "core", "normal": "core", "hard": "core", "extra": "ext"}
for i, w in enumerate(words):
    w["id"] = f'{w["word"].lower().replace(" ", "-")}-{w["level"]}-{i}'
    w["tier"] = TIER[w["level"]]

core = sum(1 for w in words if w["tier"] == "core")
print(f"core={core} ext={len(words)-core} total={len(words)}")
print("no pos:", sum(1 for w in words if not w["pos"]))
print("long meanings:", sum(1 for w in words if len(w["meaning"]) > 60))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
payload = {
    "version": 1,
    "counts": {"all": len(words), "core": core, "extra": len(words) - core},
    "words": [
        {k: w[k] for k in ("id", "word", "phonetic", "pos", "meaning", "level", "tier")}
        for w in words
    ],
}
with open(OUT, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
print("wrote", OUT, round(os.path.getsize(OUT) / 1024), "KB")
