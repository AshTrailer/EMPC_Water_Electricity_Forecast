"""在 lit\\_txt\\<slug>.txt 里按关键词检索，输出命中数与上下文窗口。用法：
python _grep_ctx.py <slug> <regex> [窗口字符数=260] [最多命中=12]
"""
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(r"C:\Ash\_research_20261013\lit\_txt")
slug = sys.argv[1]
pat = re.compile(sys.argv[2], re.I)
win = int(sys.argv[3]) if len(sys.argv) > 3 else 260
cap = int(sys.argv[4]) if len(sys.argv) > 4 else 12

text = (ROOT / f"{slug}.txt").read_text(encoding="utf-8")
flat = re.sub(r"\s+", " ", text)
hits = list(pat.finditer(flat))
print(f"[{slug}] pattern={sys.argv[2]!r} hits={len(hits)} (text {len(flat)} chars)")
for i, m in enumerate(hits[:cap]):
    a = max(0, m.start() - win)
    b = min(len(flat), m.end() + win)
    print(f"--- hit {i + 1} @{m.start()} ---")
    print(flat[a:b])
