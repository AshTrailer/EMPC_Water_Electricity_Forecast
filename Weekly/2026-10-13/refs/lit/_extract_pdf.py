"""把 lit\\_pdf 下的 PDF 抽成同名 .txt，供关键词检索。只写 lit 目录。"""
import sys
from pathlib import Path

import pymupdf

ROOT = Path(r"C:\Ash\_research_20261013\lit")
PDF = ROOT / "_pdf"
TXT = ROOT / "_txt"
TXT.mkdir(exist_ok=True)

targets = sys.argv[1:] or [p.stem for p in sorted(PDF.glob("*.pdf"))]
for slug in targets:
    src = PDF / f"{slug}.pdf"
    if not src.exists():
        print("missing", slug)
        continue
    doc = pymupdf.open(src)
    parts = []
    for i, page in enumerate(doc):
        parts.append(f"\n=== page {i + 1} ===\n" + page.get_text())
    text = "".join(parts)
    (TXT / f"{slug}.txt").write_text(text, encoding="utf-8")
    print(f"{slug}: pages={doc.page_count} chars={len(text)}")
    doc.close()
