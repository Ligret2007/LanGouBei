#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 ECDICT 的 ecdict.csv 处理成 App 能用的资源。

产出（都在 langobei/assets 下）：
  dict/manifest.json      词典分片清单 + 词条总数
  dict/<字母>.json        分片词典，按首字母切，App 只加载需要的那一片
  dict/forms.json         词形变化 → 原型（gave → give）
  banks/ecdict_cet4.json  四级词库（词库格式 langobei-bank）
  banks/ecdict_cet6.json  六级词库
  banks/ecdict_ielts.json 雅思词库
  banks/ecdict_ky.json    考研词库
  以及 assets/banks/index.json 的内置词库清单更新

用法：
  python tool/build_dict.py                    # 默认从 artifacts/ecdict 读
  python tool/build_dict.py --csv a.csv --out ../
"""

import argparse
import csv
import io
import json
import os
import sys

TAGS_WANTED = ["zk", "gk", "cet4", "cet6", "ky", "toefl", "ielts", "gre"]

# 词典分片总大小上限（字节）。再多就让安装包太胖了。
DICT_BUDGET = 7 * 1024 * 1024

BANKS = [
    # (bank id, 显示名, 副标题, 需要的标签)
    ("cet4", "四级词汇", "四级大纲词 · 词库来自 ECDICT", "cet4"),
    ("cet6", "六级词汇", "六级大纲词 · 词库来自 ECDICT", "cet6"),
    ("ielts", "雅思词汇", "雅思高频 · 词库来自 ECDICT", "ielts"),
    ("ky", "考研词汇", "考研大纲词 · 词库来自 ECDICT", "ky"),
]


def clean(text, limit=200):
    """释义里的换行换成间隔号，去掉多余空白，超长截断。"""
    if not text:
        return ""
    parts = [p.strip().strip("；;") for p in text.replace("\r", "").split("\n")]
    parts = [p for p in parts if p]
    out = "；".join(parts)
    return out[:limit]


def short_pos(pos):
    """n:46/v:54 → n/v"""
    if not pos:
        return ""
    letters = []
    for chunk in pos.split("/"):
        name = chunk.split(":")[0].strip()
        if name and name not in letters:
            letters.append(name)
    return "/".join(letters)


def level_of(frq, bnc, tags):
    if "gk" in tags or "zk" in tags:
        return "easy"
    f = min(frq or 10**9, bnc or 10**9)
    if f <= 3000:
        return "easy"
    if f <= 8000:
        return "normal"
    if f <= 20000:
        return "hard"
    return "extra"


def importance(entry):
    """越小越重要：有考试标签 → 牛津三千 → 柯林斯星级 → 词频。"""
    tags, oxford, collins, frq, bnc = entry["tags"], entry["oxford"], entry["collins"], entry["frq"], entry["bnc"]
    tagged = 0 if tags else 1
    f = min(frq or 10**9, bnc or 10**9)
    return (tagged, 0 if oxford else 1, -collins, f)


def read_ecdict(csv_path):
    entries = []
    total = 0
    skipped_no_translation = 0
    seen = set()

    with io.open(csv_path, encoding="utf-8", newline="") as fh:
        reader = csv.reader(fh)
        header = next(reader)
        idx = {name: i for i, name in enumerate(header)}
        for row in reader:
            total += 1
            if len(row) <= idx["translation"]:
                continue
            word = row[idx["word"]].strip()
            if not word or len(word) > 30:
                continue
            # 只收纯英文词（ECDICT 里有少量中文、俄文条目）
            if any(ord(c) > 127 for c in word):
                continue
            key = word.lower()
            if key in seen:
                continue
            translation = clean(row[idx["translation"]], limit=180)
            if not translation:
                skipped_no_translation += 1
                continue
            tags = [t for t in row[idx["tag"]].split() if t in TAGS_WANTED]
            try:
                collins = int(row[idx["collins"]] or 0)
            except ValueError:
                collins = 0
            try:
                oxford = int(row[idx["oxford"]] or 0)
            except ValueError:
                oxford = 0
            frq = int(row[idx["frq"]]) if row[idx["frq"]].strip().isdigit() else 0
            bnc = int(row[idx["bnc"]]) if row[idx["bnc"]].strip().isdigit() else 0
            seen.add(key)
            entries.append(
                {
                    "word": word,
                    "phonetic": row[idx["phonetic"]].strip()[:64],
                    "translation": translation,
                    "pos": short_pos(row[idx["pos"]]),
                    "tags": tags,
                    "collins": collins,
                    "oxford": oxford,
                    "frq": frq,
                    "bnc": bnc,
                    "exchange": row[idx["exchange"]].strip()[:200],
                }
            )
    return entries, total, skipped_no_translation


def keep_for_dict(entry):
    if entry["tags"] or entry["oxford"] or entry["collins"] > 0:
        return True
    f = min(entry["frq"] or 10**9, entry["bnc"] or 10**9)
    return f <= 30000


def shard_key(word):
    first = word[0].lower()
    return first if "a" <= first <= "z" else "_"


def entry_json(e):
    """紧凑但仍是对象，Dart 侧好读。"""
    obj = {"w": e["word"], "t": e["translation"]}
    if e["phonetic"]:
        obj["p"] = e["phonetic"]
    if e["pos"]:
        obj["o"] = e["pos"]
    if e["tags"]:
        obj["g"] = e["tags"]
    if e["collins"]:
        obj["c"] = e["collins"]
    if e["oxford"]:
        obj["x"] = 1
    if e["frq"]:
        obj["f"] = e["frq"]
    if e["bnc"]:
        obj["b"] = e["bnc"]
    if e["exchange"]:
        obj["e"] = e["exchange"]
    return obj


def build_forms(entries, kept_words):
    """从 exchange 字段抽词形变化，只保留原型在词典里的映射能省不少体积。"""
    forms = {}
    for e in entries:
        ex = e["exchange"]
        if not ex:
            continue
        base = e["word"].lower()
        if base not in kept_words:
            continue
        for item in ex.split("/"):
            if ":" not in item:
                continue
            kind, form = item.split(":", 1)
            if kind in ("0", "1"):  # 0/1 是 lemma 方向，这里不要
                continue
            form = form.strip().lower()
            if not form or form == base or len(form) > 30:
                continue
            if any(ord(c) > 127 for c in form):
                continue
            # 已经是词条本身的就不再记录
            if form in kept_words:
                continue
            forms.setdefault(form, base)
    return forms


def build_bank(bank_id, name, subtitle, tag, entries):
    words = []
    for e in entries:
        if tag not in e["tags"]:
            continue
        words.append(
            {
                "word": e["word"],
                "phonetic": e["phonetic"],
                "pos": e["pos"],
                "meaning": e["translation"][:120],
                "level": level_of(e["frq"], e["bnc"], e["tags"]),
                "tier": "core",
            }
        )
    words.sort(key=lambda w: w["word"].lower())
    return {
        "format": "langobei-bank",
        "formatVersion": 1,
        "id": bank_id,
        "name": name,
        "subtitle": subtitle,
        "description": "由 ECDICT 的考试大纲标注生成，释义与音标来自 ECDICT（MIT）。",
        "author": "ECDICT",
        "version": "1.0.0",
        "words": words,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=r"..\..\artifacts\ecdict\ecdict.csv")
    ap.add_argument("--out", default="..")
    args = ap.parse_args()

    csv_path = os.path.abspath(args.csv)
    app_root = os.path.abspath(args.out)
    assets = os.path.join(app_root, "assets")
    dict_dir = os.path.join(assets, "dict")
    banks_dir = os.path.join(assets, "banks")
    os.makedirs(dict_dir, exist_ok=True)
    os.makedirs(banks_dir, exist_ok=True)

    if not os.path.exists(csv_path):
        print("找不到 CSV: %s" % csv_path, file=sys.stderr)
        return 1

    print("读取 %s ..." % csv_path)
    entries, total, skipped = read_ecdict(csv_path)
    print("  总行数 %d，可用词条 %d，无中文释义跳过 %d" % (total, len(entries), skipped))

    by_tag = {t: sum(1 for e in entries if t in e["tags"]) for t in TAGS_WANTED}
    print("  标签统计: %s" % ", ".join("%s=%d" % (k, v) for k, v in by_tag.items()))

    candidates = [e for e in entries if keep_for_dict(e)]
    candidates.sort(key=importance)
    print("  进入词典候选 %d 条" % len(candidates))

    # 按体积预算截断
    kept = []
    size = 0
    for e in candidates:
        blob = len(json.dumps(entry_json(e), ensure_ascii=False).encode("utf-8")) + 1
        if size + blob > DICT_BUDGET:
            break
        kept.append(e)
        size += blob
    print("  实际收录 %d 条，约 %.1f MB" % (len(kept), size / 1e6))

    shards = {}
    for e in kept:
        shards.setdefault(shard_key(e["word"]), []).append(entry_json(e))
    for key in shards:
        shards[key].sort(key=lambda o: o["w"].lower())

    letters = {}
    for key, items in shards.items():
        path = os.path.join(dict_dir, "%s.json" % key)
        with io.open(path, "w", encoding="utf-8", newline="") as fh:
            json.dump(items, fh, ensure_ascii=False, separators=(",", ":"))
        letters[key] = len(items)
        print("  分片 %s.json  %d 条  %.2f MB" % (key, len(items), os.path.getsize(path) / 1e6))

    kept_words = {e["word"].lower() for e in kept}
    forms = build_forms(kept, kept_words)
    with io.open(os.path.join(dict_dir, "forms.json"), "w", encoding="utf-8", newline="") as fh:
        json.dump(forms, fh, ensure_ascii=False, separators=(",", ":"))
    print("  词形表 forms.json  %d 条  %.2f MB"
          % (len(forms), os.path.getsize(os.path.join(dict_dir, "forms.json")) / 1e6))

    manifest = {
        "format": "langobei-dict",
        "formatVersion": 1,
        "source": "ECDICT",
        "sourceUrl": "https://github.com/skywind3000/ECDICT",
        "license": "MIT",
        "total": len(kept),
        "letters": letters,
    }
    with io.open(os.path.join(dict_dir, "manifest.json"), "w", encoding="utf-8", newline="") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)

    # 内置词库：ECDICT 的四个考试大纲
    builtin = []
    for bank_id, name, subtitle, tag in BANKS:
        bank = build_bank(bank_id, name, subtitle, tag, entries)
        if not bank["words"]:
            print("  跳过 %s（没有匹配词条）" % bank_id)
            continue
        bank["subtitle"] = "%d 词 · %s" % (len(bank["words"]), subtitle)
        path = os.path.join(banks_dir, "ecdict_%s.json" % bank_id)
        with io.open(path, "w", encoding="utf-8", newline="") as fh:
            json.dump(bank, fh, ensure_ascii=False, separators=(",", ":"))
        builtin.append(
            {
                "id": bank_id,
                "name": name,
                "subtitle": bank["subtitle"],
                "description": "ECDICT 的 %s 大纲词，释义与音标来自 ECDICT（MIT）。" % name,
                "author": "ECDICT",
                "asset": "assets/banks/ecdict_%s.json" % bank_id,
                "tier": None,
                "wordCount": len(bank["words"]),
            }
        )
        print("  词库 %s  %d 词  %.0f KB" % (bank_id, len(bank["words"]), os.path.getsize(path) / 1024))

    # 合并 index.json：保留原有高考两个库，替换同 id 的条目
    index_path = os.path.join(banks_dir, "index.json")
    existing = {"format": "langobei-bank-index", "formatVersion": 1, "banks": []}
    if os.path.exists(index_path):
        with io.open(index_path, encoding="utf-8") as fh:
            existing = json.load(fh)
    drop = {b["id"] for b in builtin}
    existing.pop("builtin", None)  # 早期版本误写过这个键，清掉
    existing["banks"] = [b for b in existing.get("banks", []) if b.get("id") not in drop]
    existing["banks"].extend(builtin)
    with io.open(index_path, "w", encoding="utf-8", newline="") as fh:
        json.dump(existing, fh, ensure_ascii=False, indent=2)
    print("  内置词库清单：%d 个" % len(existing["banks"]))
    for item in existing["banks"]:
        print("    - %s (%s)" % (item["id"], item["name"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
