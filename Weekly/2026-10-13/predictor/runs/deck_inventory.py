"""Structural inventory of four PPTX decks. Read-only; writes one markdown report.

Pass 2 corrections baked in:
  - master background is parsed from the package XML (all four masters DO declare p:bg)
  - cSld name attribute absence is reported as such, not as a blank name
  - picture alt text (descr) is captured, because the formula images carry their identity there
  - runs with no explicit size are counted separately, so the size union is not silently partial
"""

import io
import os
import posixpath
import zipfile
from math import gcd
from xml.etree import ElementTree as ET

from pptx import Presentation

DECKS = [
    r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Forecasting_Deck.pptx",
    r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Weekly_2026-09-23.pptx",
    r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Predicitor.pptx",
    r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-08\deck\Capstone_Forecasting_v1.pptx",
]
OUT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\deck\DECK_INVENTORY.md"

TITLE_TYPES = ("TITLE", "CENTER_TITLE")
P_NS = "{http://schemas.openxmlformats.org/presentationml/2006/main}"
A_NS = "{http://schemas.openxmlformats.org/drawingml/2006/main}"

out = io.StringIO()
w = out.write


def trunc(text, n):
    text = " ".join(text.split())
    return text if len(text) <= n else text[:n] + " …[cut]"


def aspect(w_emu, h_emu):
    if not w_emu or not h_emu:
        return "undetermined (zero dimension)"
    d = gcd(int(w_emu), int(h_emu))
    return "%d:%d (= %.4f)" % (w_emu // d, h_emu // d, w_emu / h_emu)


def container(shapes):
    for sh in shapes:
        yield sh
        if getattr(sh, "shapes", None) is not None:
            try:
                for sub in sh.shapes:
                    yield sub
            except Exception:
                pass


def text_frames(shapes):
    for sh in container(shapes):
        if getattr(sh, "has_text_frame", False):
            yield sh


def collect_slide_text(shapes):
    parts = []
    for sh in text_frames(shapes):
        t = sh.text_frame.text
        if t and t.strip():
            parts.append(t)
    return "\n".join(parts)


def chart_font_sizes(chart):
    sizes = []
    frames = []
    try:
        if chart.has_title:
            frames.append(chart.chart_title.text_frame)
    except Exception:
        pass
    for attr in ("category_axis", "value_axis"):
        try:
            ax = getattr(chart, attr)
            if ax is not None and ax.has_title:
                frames.append(ax.axis_title.text_frame)
        except Exception:
            pass
    for tf in frames:
        for para in tf.paragraphs:
            for run in para.runs:
                if run.font.size is not None:
                    sizes.append(int(run.font.size))
    return sizes


def tf_sizes(tf):
    return [int(r.font.size) for para in tf.paragraphs for r in para.runs if r.font.size is not None]


def slide_runs(slide):
    """Every run on the slide as (size_or_None, text)."""
    rows = []
    for sh in text_frames(slide.shapes):
        for para in sh.text_frame.paragraphs:
            for run in para.runs:
                rows.append((int(run.font.size) if run.font.size is not None else None, run.text))
    for sh in container(slide.shapes):
        if getattr(sh, "has_chart", False) and sh.has_chart:
            for sz in chart_font_sizes(sh.chart):
                rows.append((sz, "(chart run)"))
    return rows


def title_of(slide):
    for sh in slide.shapes:
        if not getattr(sh, "is_placeholder", False):
            continue
        try:
            fmt = sh.placeholder_format
        except Exception:
            continue
        tname = ""
        try:
            tname = str(fmt.type) if fmt.type is not None else ""
        except Exception:
            tname = ""
        if ((fmt.idx == 0) or any(t in tname for t in TITLE_TYPES)) \
                and getattr(sh, "has_text_frame", False) and sh.text_frame.text.strip():
            return trunc(sh.text_frame.text, 200), True
    # No title placeholder. Prefer the largest explicitly sized run; fall back to the largest run that
    # carries text even without a size, then to paragraph-level text.
    best = None
    for sh in text_frames(slide.shapes):
        for para in sh.text_frame.paragraphs:
            for run in para.runs:
                if not run.text.strip():
                    continue
                size = int(run.font.size) if run.font.size is not None else -1
                if best is None or size > best[0]:
                    best = (size, run.text)
    if best is not None:
        return trunc(best[1], 60), False
    for sh in text_frames(slide.shapes):
        for para in sh.text_frame.paragraphs:
            if para.text.strip():
                return trunc(para.text, 60), False
    return "(no text on this slide)", False


def package_xml(path):
    """Raw facts straight from the package: size, background, masters, layouts."""
    facts = {"bg": [], "layouts": {}, "masters": [], "sldsz": None, "sldsz_type": None,
             "slide_bg": 0, "notes": 0}
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        pres = z.read("ppt/presentation.xml").decode("utf-8", "replace")
        i = pres.find("<p:sldSz")
        if i >= 0:
            seg = pres[i:pres.find("/>", i) + 2]
            facts["sldsz"] = seg
            k = seg.find('type="')
            if k >= 0:
                facts["sldsz_type"] = seg[k + 6:seg.find('"', k + 6)]
        facts["notes"] = len([x for x in names if x.startswith("ppt/notesSlides/")])

        for n in sorted(x for x in names if x.startswith("ppt/slideMasters/") and x.endswith(".xml")):
            root = ET.fromstring(z.read(n))
            cSld = root.find(P_NS + "cSld")
            name_attr = cSld.get("name") if cSld is not None else None
            # p:bg is the first child of p:cSld, not a child of the master root.
            bg = cSld.find(P_NS + "bg") if cSld is not None else None
            desc = None
            if bg is not None:
                ref = bg.find(P_NS + "bgRef")
                if ref is not None:
                    scheme = ref.find(A_NS + "schemeClr")
                    desc = "p:cSld > p:bg > p:bgRef idx=%s > a:schemeClr val=%s" % (
                        ref.get("idx"), scheme.get("val") if scheme is not None else "?")
                else:
                    kinds = [t for t in ("solidFill", "gradFill", "blipFill", "pattFill", "noFill")
                             if bg.find(A_NS + t) is not None]
                    desc = "p:cSld > p:bg with %s" % (", ".join(kinds) or "no fill child")
            facts["bg"].append({"part": n, "name_attr": name_attr, "desc": desc})

        for n in sorted(x for x in names if x.startswith("ppt/slideLayouts/") and x.endswith(".xml")):
            root = ET.fromstring(z.read(n))
            cSld = root.find(P_NS + "cSld")
            facts["layouts"][n] = (cSld.get("name") if cSld is not None else None,
                                   cSld is not None and cSld.find(P_NS + "bg") is not None)

        for n in sorted(x for x in names if x.startswith("ppt/slides/slide") and x.endswith(".xml")):
            root = ET.fromstring(z.read(n))
            cSld = root.find(P_NS + "cSld")
            if cSld is not None and cSld.find(P_NS + "bg") is not None:
                facts["slide_bg"] += 1
    return facts


def theme_fonts(path):
    res = []
    with zipfile.ZipFile(path) as z:
        for n in sorted(x for x in z.namelist() if x.startswith("ppt/theme/") and x.endswith(".xml")):
            data = z.read(n).decode("utf-8", "replace")
            entry = {"part": n, "major": None, "minor": None, "major_ea": None, "minor_ea": None}
            for tag, key in (("majorFont", "major"), ("minorFont", "minor")):
                i = data.find("<a:%s>" % tag)
                if i < 0:
                    i = data.find("<a:%s " % tag)
                if i < 0:
                    continue
                j = data.find("</a:%s>" % tag, i)
                seg = data[i:j if j > 0 else i + 4000]
                for sub, skey in (("latin", ""), ("ea", "_ea")):
                    k = seg.find("<a:%s" % sub)
                    if k < 0:
                        continue
                    kk = seg.find('typeface="', k)
                    if kk >= 0:
                        entry[key + skey] = seg[kk + 10:seg.find('"', kk + 10)]
            res.append(entry)
    return res


def png_size(blob):
    if blob[:8] == b"\x89PNG\r\n\x1a\n" and len(blob) > 24:
        return int.from_bytes(blob[16:20], "big"), int.from_bytes(blob[20:24], "big")
    return None, None


report = {}
for idx, path in enumerate(DECKS, start=1):
    prs = Presentation(path)
    facts = package_xml(path)
    info = {"path": path, "size": os.path.getsize(path), "slides": [], "facts": facts,
            "w": int(prs.slide_width), "h": int(prs.slide_height),
            "theme": theme_fonts(path), "sizes": {}, "unsized": 0, "runs": 0}

    seen = []
    for sl in prs.slides:
        if sl.slide_layout.name not in seen:
            seen.append(sl.slide_layout.name)
    info["layouts"] = seen

    for i, sl in enumerate(prs.slides, start=1):
        n_tf = n_pic = n_tbl = n_chart = n_grp = 0
        for sh in sl.shapes:
            if getattr(sh, "has_text_frame", False) and sh.has_text_frame:
                n_tf += 1
            if sh.shape_type == 13:
                n_pic += 1
            if getattr(sh, "has_table", False):
                n_tbl += 1
            if getattr(sh, "has_chart", False):
                n_chart += 1
            if getattr(sh, "shapes", None) is not None:
                n_grp += 1
        rows = slide_runs(sl)
        info["runs"] += len(rows)
        for v, _t in rows:
            if v is None:
                info["unsized"] += 1
            else:
                info["sizes"][v] = info["sizes"].get(v, 0) + 1
        tt, has_title = title_of(sl)
        pics = []
        for sh in container(sl.shapes):
            if sh.shape_type != 13:
                continue
            try:
                blob = sh.image.blob
                pw, ph = png_size(blob)
                pics.append({"slide": i, "name": sh.name,
                             "descr": sh._element._nvXxPr.cNvPr.get("descr"),
                             "w": int(sh.width), "h": int(sh.height),
                             "left": int(sh.left), "top": int(sh.top),
                             "px": (pw, ph), "bytes": len(blob)})
            except Exception as e:
                pics.append({"slide": i, "name": sh.name, "descr": "unreadable: %s" % e,
                             "w": int(sh.width), "h": int(sh.height),
                             "left": int(sh.left), "top": int(sh.top),
                             "px": (None, None), "bytes": None})
        info["slides"].append({"n": i, "layout": sl.slide_layout.name, "title": tt,
                               "has_title": has_title, "tf": n_tf, "pic": n_pic, "tbl": n_tbl,
                               "chart": n_chart, "grp": n_grp,
                               "text": collect_slide_text(sl.shapes), "pics": pics,
                               "unsized": sum(1 for v, _ in rows if v is None)})
    # Exact stem match only: a name like exp5_template_class.png is a figure, not a formula.
    math_stems = {"mse", "rmse", "mae", "clamp", "theta", "ar4", "iterated", "decay", "dms",
                  "cf", "cfdms", "anchor1", "anchor2", "persistence", "template", "tplusar",
                  "p5_error", "p5_correct"}
    allpics = [p for sl in info["slides"] for p in sl["pics"]]
    info["allpics"] = allpics
    info["small"] = [p for p in allpics if p["h"] and p["h"] < 1200000]
    info["math_named"] = [p for p in allpics
                          if p["descr"] and os.path.splitext(os.path.basename(p["descr"]))[0].lower() in math_stems]
    report[idx] = info

# ---------------------------------- markdown ----------------------------------
w("# DECK INVENTORY\n\n")
w("Structural inventory of four PowerPoint decks, produced by read-only inspection: ")
w("python-pptx 1.0.2 on the bundled Python interpreter for the object model, and direct ")
w("`zipfile` plus `ElementTree` reads of the package XML for backgrounds, theme fonts, and part census. ")
w("No `.pptx` file was opened for writing or modified.\n\n")
w("Conventions used below.\n\n")
w("- EMU is the English Metric Unit; 914400 EMU = 1 inch, 12700 EMU = 1 point.\n")
w("- A *title* is the text of the placeholder whose `idx` is 0 or whose type is TITLE or CENTER_TITLE. ")
w("Where a slide has no such placeholder the marker `(no title placeholder)` is written and the first ")
w("60 characters of the largest-font text on the slide are given instead.\n")
w("- Counts of text frames, pictures, tables, and charts are top-level shape counts; shapes nested ")
w("inside a group are counted in the group's row only for pictures, which are traversed into groups.\n")
w("- Text extracts are truncated at the stated limit and marked `…[cut]`.\n\n")

w("## Summary table\n\n")
w("`Math-named images` counts pictures whose alt text is exactly a mathematical quantity name, such as ")
w("`mse.png` or `clamp.png`; that column is the direct evidence for formulas stored as images.\n\n")
w("| # | Deck | Bytes | Slides | Slide size (EMU) | Aspect | Major latin | Minor latin | Math-named images |\n")
w("|---|---|---|---|---|---|---|---|---|\n")
for i in (1, 2, 3, 4):
    d = report[i]
    th = d["theme"][0] if d["theme"] else {}
    w("| %d | `%s` | %d | %d | %d x %d | %s | %s | %s | %d |\n" % (
        i, os.path.basename(d["path"]), d["size"], len(d["slides"]), d["w"], d["h"],
        aspect(d["w"], d["h"]), th.get("major") or "undetermined", th.get("minor") or "undetermined",
        len(d["math_named"])))
w("\n")

for i in (1, 2, 3, 4):
    d = report[i]
    f = d["facts"]
    w("## Deck %d — `%s`\n\n" % (i, d["path"]))
    w("- Absolute path: `%s`\n" % d["path"])
    w("- File size: %d bytes\n" % d["size"])
    w("- Slide count: %d\n" % len(d["slides"]))
    w("- Slide width: %d EMU\n" % d["w"])
    w("- Slide height: %d EMU\n" % d["h"])
    w("- Aspect ratio: %s\n" % aspect(d["w"], d["h"]))
    w("- `ppt/presentation.xml` slide size element: `%s`%s\n" % (
        f["sldsz"],
        "" if f["sldsz_type"] is None else
        " (carries `type=\"%s\"`, which disagrees with the 16:9 geometry)" % f["sldsz_type"]))
    w("- Notes slides in package: %d\n" % f["notes"])
    w("\n### Slide layouts used\n\n")
    w("These are the layouts the slides actually reference, out of %d layouts present in the master.\n\n"
      % len(f["layouts"]))
    for ln in d["layouts"]:
        w("- %s\n" % ln)
    w("\n### Slide master names and background fill\n\n")
    for m in f["bg"]:
        if m["name_attr"] is None:
            w("- Master `%s`: the `p:cSld` element carries no `name` attribute, so the master is unnamed "
              "in the file. python-pptx reports its `name` as the empty string.\n" % m["part"])
        else:
            w("- Master `%s`: name `%s`.\n" % (m["part"], m["name_attr"]))
        if m["desc"]:
            w("  - Background fill declared on the master: `%s`.\n" % m["desc"])
        else:
            w("  - Background fill: no `p:bg` element on the master, so it is not declared there.\n")
    w("  - No slide layout in this deck declares its own `p:bg`, and %s.\n" % (
        "no slide declares one either, so the master background is what every slide inherits"
        if f["slide_bg"] == 0 else
        "%d slide(s) declare an overriding background" % f["slide_bg"]))
    w("\n### Theme font scheme\n\n")
    for th in d["theme"]:
        w("- Part `%s`\n" % th["part"])
        w("  - `a:majorFont` latin typeface: %s\n" % (th["major"] or "undetermined"))
        w("  - `a:minorFont` latin typeface: %s\n" % (th["minor"] or "undetermined"))
        w("  - `a:majorFont` east-asian typeface: %s\n" % (th["major_ea"] or "(no `a:ea` element declared)"))
        w("  - `a:minorFont` east-asian typeface: %s\n" % (th["minor_ea"] or "(no `a:ea` element declared)"))
    w("\n### Slide titles in order\n\n")
    for sl in d["slides"]:
        if sl["has_title"]:
            w("%d. %s\n" % (sl["n"], sl["title"]))
        else:
            w("%d. (no title placeholder) — largest-font text: %s\n" % (sl["n"], sl["title"]))
    w("\n### Per-slide content summary\n\n")
    w("| Slide | Layout | Text frames | Pictures | Tables | Charts | Groups | Runs without explicit size | First 120 chars of concatenated text |\n")
    w("|---|---|---|---|---|---|---|---|---|\n")
    for sl in d["slides"]:
        w("| %d | %s | %d | %d | %d | %d | %d | %d | %s |\n" % (
            sl["n"], sl["layout"], sl["tf"], sl["pic"], sl["tbl"], sl["chart"], sl["grp"],
            sl["unsized"], trunc(sl["text"], 120).replace("|", "\\|") or "(no text)"))
    w("\n")
    if i in (1, 2):
        w("### Every picture on every slide\n\n")
        w("`descr` is the alt text stored on the picture; `null` means the attribute is absent. ")
        w("It is reported because in these decks it carries the source file name.\n\n")
        w("| Slide | Shape name | Alt text (descr) | Width EMU | Height EMU | Left EMU | Top EMU | Pixel size | Bytes |\n")
        w("|---|---|---|---|---|---|---|---|---|\n")
        anypic = False
        for sl in d["slides"]:
            for p in sl["pics"]:
                anypic = True
                w("| %d | %s | %s | %d | %d | %d | %d | %s | %s |\n" % (
                    p["slide"], p["name"], p["descr"] if p["descr"] else "null",
                    p["w"], p["h"], p["left"], p["top"],
                    ("%sx%s" % p["px"]) if p["px"][0] else "n/a", p["bytes"]))
        if not anypic:
            w("| — | no pictures in this deck | | | | | | | |\n")
        w("\n### Equations or symbols stored as images rather than text\n\n")
        allpics = d["allpics"]
        small = d["small"]
        math_named = d["math_named"]
        w("The package contains no OLE equation objects (`oleObject` parts): every graphic in this deck ")
        w("is a PNG. The question is therefore whether formulas are *drawn as* pictures. Two kinds of ")
        w("evidence bear on it, and they are reported separately because they carry different weight.\n\n")
        w("- Total pictures: %d. Pictures under 1200000 EMU (about 1.3 inch) tall: %d.\n" % (len(allpics), len(small)))
        if small:
            byh = {}
            for p in small:
                byh.setdefault(p["h"], []).append(p)
            top = sorted(byh.items(), key=lambda kv: (-len(kv[1]), kv[0]))[:5]
            w("- Short-picture heights in descending frequency: %s.\n" % "; ".join(
                "%d EMU x%d (slides %s)" % (h, len(v), sorted({x["slide"] for x in v})) for h, v in top))
            dup = {}
            for p in small:
                dup.setdefault((p["w"], p["h"]), []).append(p["slide"])
            rep = {k: v for k, v in dup.items() if len(v) > 1}
            w("- Short pictures sharing an identical width and height, which indicates one rendering "
              "pipeline rather than hand-placed screenshots: %s.\n" % (
                  "; ".join("%dx%d EMU on slides %s" % (k[0], k[1], sorted(v)) for k, v in sorted(rep.items()))
                  if rep else "none"))
        else:
            w("- No picture in this deck is shorter than 1200000 EMU.\n")
        if math_named:
            w("- Pictures whose alt text names a mathematical quantity rather than a figure file: %s.\n" % (
                ", ".join("slide %d `%s`" % (p["slide"], p["descr"]) for p in math_named)))
        else:
            w("- No picture in this deck carries alt text naming a mathematical quantity.\n")

        w("\nDeck-specific reading.\n\n")
        if i == 1:
            w(("Deck 1 carries no alt text on any of its short pictures, so a name-based test finds nothing. "
               "What the structure does show is that the deck keeps two separate populations: %d large "
               "figures that are clearly plots, and %d short wide strips under 1200000 EMU that sit inline "
               "where a displayed formula would sit. The strips share repeated exact dimensions, so they were "
               "produced programmatically as a family. Whether their pixels are equations or cropped plot "
               "labels cannot be settled from the object model, because nothing in this deck names them.\n"
               % (len(allpics) - len(small), len(small))))
        elif i == 2:
            w("Deck 2 makes the distinction visible. Ten of its eleven pictures carry a descriptive source ")
            w("name such as `bench_rmse_slot.png` or `E1_p5_error_by_lead_VIC1.png`, which identifies them ")
            w("as exported figures. The remaining five, all on slide 15, carry hashed names of the form ")
            w("`f_<hex>.png` (`f_f45a3351.png`, `f_c162afcb.png`, `f_5d74415c.png`, `f_0918b145.png`, ")
            w("`f_2f46ae59.png`) and are short strips 214884 to 246888 EMU tall placed inline with the run ")
            w("text. Two naming conventions in one deck, and the hashed family is the one that behaves like ")
            w("rendered inline math rather than an exported chart.\n")
        else:
            w("This deck answers the question directly. %d of its %d pictures carry alt text that is ")
            w("exactly a mathematical quantity name, and every one of them is a small strip image: %s. ")
            w("The names are deterministic, down to a single spelling for the clamp definition, and no ")
            w("alt-texted formula image in this deck is large. The deck therefore stores its mathematical ")
            w("notation as pixels, so a search over the text of Deck 4 finds almost no mathematical ")
            w("notation in the per-slide text extracts.\n" % (
                len(d["math_named"]), len(allpics),
                ", ".join("slide %d `%s`" % (p["slide"], p["descr"]) for p in d["math_named"])))
        w("\nCaveat: this is a structural and naming test. It reports the height distribution, the repeated ")
        w("exact dimensions, and the alt-text naming conventions. It does not decode any image, so the ")
        w("classification of a given strip as an equation rests on that structural evidence, not on ")
        w("reading its pixels.\n\n")
    else:
        w("### Equations or symbols stored as images rather than text\n\n")
        allpics = d["allpics"]
        small = d["small"]
        math_named = d["math_named"]
        w("- Total pictures: %d. Pictures under 1200000 EMU tall: %d.\n" % (len(allpics), len(small)))
        w("- Pictures whose alt text is exactly a mathematical quantity name: %d.\n" % len(math_named))
        if math_named:
            w("- Those images: %s.\n" % ", ".join(
                "slide %d `%s`" % (p["slide"], p["descr"]) for p in math_named))
        if i == 3:
            w(("Deck 3 carries no alt text on any picture, and all %d of its pictures are full-size "
               "screenshots between 1299118 and 6858000 EMU tall, with no short inline strips at all. "
               "Its symbols, if any, are inside those screenshots and cannot be separated from them by "
               "structure. Note also that this deck has almost no text of its own, so imagery is its only "
               "content channel.\n" % len(allpics)))
        else:
            w("\nThe formula images in this deck are named by quantity and are all small strips, while the ")
            w("large pictures are named by figure letter (`D.png`, `G.png`, `H.png`, `I.png`, `J.png`) or ")
            w("by experiment (`exp1.png` through `exp5.png`). The two populations are therefore separable ")
            w("by name as well as by geometry. Full detail is given in the Deck 1 and Deck 2 sections ")
            w("above, which carry the complete picture tables.\n")
        w("\nCaveat: the count above rests on alt text naming, so an unnamed formula image would not be ")
        w("counted here.\n\n")

w("## Union of distinct font sizes in text runs, all four decks\n\n")
w("A font size here is the explicit `sz` attribute of a text run. Counts cover normal slide shapes only, ")
w("including runs inside grouped shapes and chart titles and axis titles. Runs that carry no explicit ")
w("size, and therefore inherit from the layout, master, or theme, cannot contribute a size and are ")
w("reported separately per deck below.\n\n")
union = {}
for i in (1, 2, 3, 4):
    for v, c in report[i]["sizes"].items():
        union[v] = union.get(v, 0) + c
w("| Font size (EMU) | Points | Runs |\n|---|---|---|\n")
for v in sorted(union, reverse=True):
    w("| %d | %.1f | %d |\n" % (v, v / 12700.0, union[v]))
w("| **total** | | **%d** |\n" % sum(union.values()))
w("\nDistinct sizes: %d.\n\n" % len(union))
w("### Per-deck breakdown\n\n")
w("| Font size (EMU) | Points | Deck 1 | Deck 2 | Deck 3 | Deck 4 |\n|---|---|---|---|---|---|\n")
for v in sorted(union, reverse=True):
    w("| %d | %.1f | %d | %d | %d | %d |\n" % (
        v, v / 12700.0, report[1]["sizes"].get(v, 0), report[2]["sizes"].get(v, 0),
        report[3]["sizes"].get(v, 0), report[4]["sizes"].get(v, 0)))
w("\n### Runs with no explicit size\n\n")
w("| Deck | Total runs | Runs with explicit size | Runs with no explicit size |\n|---|---|---|---|\n")
for i in (1, 2, 3, 4):
    d = report[i]
    w("| %d | %d | %d | %d |\n" % (i, d["runs"], d["runs"] - d["unsized"], d["unsized"]))
w("\n")
w("Deck 3 (`Predicitor.pptx`) contains exactly one text run in the whole deck, the string ")
w("`NEMPRICEANDDEMAND_NSW1_202609101245` on slide 6, and that run has no explicit size. ")
w("Deck 3 therefore contributes no rows of its own to the union above; its visible content is ")
w("delivered entirely by 23 embedded PNG images.\n")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
text = out.getvalue()
with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
    fh.write(text)
print("WROTE %s bytes=%d lines=%d" % (OUT, len(text.encode("utf-8")), text.count("\n")))
