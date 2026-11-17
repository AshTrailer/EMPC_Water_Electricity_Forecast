"""Second pass: verify facts the main pass could only assert weakly.

Checks: package parts (charts/equations), master names, text runs WITHOUT an explicit
font size (inherited sizes), picture shape/alt-text names, output-file encoding, and
whether the four .pptx files were modified.
Read-only against every .pptx.
"""

import io
import os
import zipfile

from pptx import Presentation

DECKS = [
    (1, r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Forecasting_Deck.pptx"),
    (2, r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Weekly_2026-09-23.pptx"),
    (3, r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Predicitor.pptx"),
    (4, r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-08\deck\Capstone_Forecasting_v1.pptx"),
]
OUT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\verify.log"

buf = io.StringIO()


def p(s=""):
    buf.write(s + "\n")


def tf_iter(shapes):
    for sh in shapes:
        if getattr(sh, "has_text_frame", False):
            yield sh
        if getattr(sh, "shapes", None) is not None:
            for sub in sh.shapes:
                yield sub


for n, path in DECKS:
    p("=" * 70)
    p("DECK %d  %s" % (n, os.path.basename(path)))
    p("size=%d  mtime=%d" % (os.path.getsize(path), os.path.getmtime(path)))
    prs = Presentation(path)

    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        p("parts total=%d" % len(names))
        for kind in ("chart", "oleObject", "equation", "embeddings", "media", "notesSlide",
                     "theme", "slideMaster", "slideLayout", "slide"):
            hits = [x for x in names if kind.lower() in x.lower()]
            if kind in ("slide", "theme", "slideMaster", "slideLayout", "notesSlide"):
                p("  %-14s %d" % (kind, len(hits)))
            elif hits:
                p("  %-14s %d  e.g. %s" % (kind, len(hits), hits[:3]))
        p("  media types: %s" % sorted({os.path.splitext(x)[1].lower() for x in names if "/media/" in x}))

    # masters: name as stored, and layout census
    for mi, m in enumerate(prs.slide_masters):
        nm = m.name
        p("  master[%d] name=%r  layouts=%d  name_is_none=%s" % (
            mi, nm, len(m.slide_layouts), nm is None))
        p("    layout names: %s" % [l.name for l in m.slide_layouts])
    p("  slide_masters count=%d" % len(prs.slide_masters))

    # explicit vs inherited run sizes
    tot_runs = 0
    sized_runs = 0
    unsized_samples = []
    nonsized_by_slide = {}
    for i, sl in enumerate(prs.slides, start=1):
        c = 0
        for sh in tf_iter(sl.shapes):
            for para in sh.text_frame.paragraphs:
                for run in para.runs:
                    tot_runs += 1
                    if run.font.size is None:
                        c += 1
                        if len(unsized_samples) < 6 and run.text.strip():
                            unsized_samples.append((i, run.text[:60]))
                    else:
                        sized_runs += 1
        if c:
            nonsized_by_slide[i] = c
    p("  runs total=%d with_explicit_size=%d without=%d" % (tot_runs, sized_runs, tot_runs - sized_runs))
    p("  runs without size per slide: %s" % nonsized_by_slide)
    for s in unsized_samples:
        p("    eg slide %d: %r" % s)

    # notes slides: text and sizes
    notes_runs = 0
    notes_text_chars = 0
    for sl in prs.slides:
        if sl.has_notes_slide:
            t = sl.notes_slide.notes_text_frame.text if sl.notes_slide.notes_text_frame else ""
            notes_text_chars += len(t)

    # picture names and alt text (all decks)
    p("  pictures (name | alt-text descr | position):")
    for i, sl in enumerate(prs.slides, start=1):
        for sh in sl.shapes:
            if sh.shape_type == 13:
                descr = sh._element._nvXxPr.cNvPr.get("descr")
                p("    slide %-3d %-14s descr=%r  w=%d h=%d" % (i, sh.name, descr, sh.width, sh.height))

p("=" * 70)
target = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\deck\DECK_INVENTORY.md"
if os.path.exists(target):
    raw = open(target, "rb").read()
    p("OUTPUT %s bytes=%d" % (target, len(raw)))
    p("  starts_with_BOM=%s" % raw.startswith(b"\xef\xbb\xbf"))
    p("  CRLF_count=%d  bare_LF_count=%d" % (raw.count(b"\r\n"), raw.count(b"\n") - raw.count(b"\r\n")))
    p("  non_ascii_bytes_present=%s" % (any(b > 127 for b in raw)))
    try:
        raw.decode("utf-8")
        p("  decodes_as_utf8=True")
    except UnicodeDecodeError as e:
        p("  decodes_as_utf8=False %s" % e)

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
    fh.write(buf.getvalue())
print("WROTE %s" % OUT)
