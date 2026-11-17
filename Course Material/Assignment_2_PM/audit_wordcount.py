"""Independent check of the Part 1 word count in a retrospective DOCX.

Counts every paragraph and table cell the marker would count, and separately reports what the
course brief excludes: the title block, section headings, figure captions, the references and the
AI declaration. The output must agree with build_retrospective_v5.py, which counts the body list.

Usage: audit_wordcount.py <docx> [more.docx ...]
"""

import re
import sys

import docx
from docx.oxml.ns import qn
from docx.table import Table
from docx.text.paragraph import Paragraph

TOKEN = re.compile(r"[A-Za-z0-9][A-Za-z0-9'\u2019./-]*")

HEADINGS = {
    "Objective and scope",
    "Risks and countermeasures",
    "Milestones and progress",
    "People and teamwork",
    "Stakeholders",
    "How we measure success",
    "Lessons and the actions taken",
    "Appendix A: schedule as planned",
    "Appendix B: schedule as delivered",
    "References",
    "Declaration of AI use",
}


def words(text):
    return len(TOKEN.findall(text))


def blocks(document):
    """Yield (kind, style, text) in document order, tables flattened row by row."""
    for child in document.element.body.iterchildren():
        if child.tag == qn("w:p"):
            para = Paragraph(child, document)
            text = para.text.strip()
            if text:
                yield "p", para.style.name, text
        elif child.tag == qn("w:tbl"):
            for row in Table(child, document).rows:
                for cell in row.cells:
                    text = cell.text.strip()
                    if text:
                        yield "t", "Table", text


def audit(path):
    document = docx.Document(path)
    buckets = {"title block": 0, "headings": 0, "captions": 0, "references": 0,
               "ai declaration": 0, "body": 0}
    section = "title block"
    banner = True
    for kind, style, text in blocks(document):
        if banner and kind == "p" and text not in HEADINGS:
            buckets["title block"] += words(text)
            continue
        if kind == "p" and text in HEADINGS:
            banner = False
            section = text
            buckets["headings"] += words(text)
            continue
        if section in ("References", "Declaration of AI use"):
            key = "references" if section == "References" else "ai declaration"
            buckets[key] += words(text)
            continue
        if style == "Table":
            buckets["body"] += words(text)
            continue
        if section.startswith("Appendix"):
            buckets["captions"] += words(text)
            continue
        if re.match(r"^Figure\s+\d+\.", text):
            buckets["captions"] += words(text)
            continue
        buckets["body"] += words(text)

    total = sum(buckets.values())
    print(f"{path}")
    for key, value in buckets.items():
        print(f"  {key:<16}{value:>6}")
    print(f"  {'TOTAL':<16}{total:>6}")
    print(f"  Part 1 count (all text less references and AI declaration): "
          f"{total - buckets['references'] - buckets['ai declaration']}")
    print(f"  Part 1 count (also less title block, headings and captions): "
          f"{buckets['body']}")
    print()


if __name__ == "__main__":
    for argument in sys.argv[1:]:
        audit(argument)
