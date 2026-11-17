# -*- coding: utf-8 -*-
"""Pre-flight for the carry-over: three facts that decide how the copy is done.

  1. python-pptx's default template theme, against the sources' theme. If they
     differ, a carried shape that says schemeClr accent1 would change colour.
  2. Every distinct schemeClr element in the sources, with children. A scheme
     reference carrying a lumMod/shade/tint cannot simply be renamed to srgbClr.
  3. Every relationship a carried slide holds, other than its layout. Anything
     that is not a picture has to be reported before it can be copied.

Read-only.
"""

import os
import re
import sys
import zipfile
from collections import Counter, defaultdict
import xml.etree.ElementTree as ET

from pptx import Presentation

A = "http://schemas.openxmlformats.org/drawingml/2006/main"
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
P = "http://schemas.openxmlformats.org/presentationml/2006/main"

SOURCES = [
    r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Forecasting_Deck.pptx",
    r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Weekly_2026-09-23.pptx",
    r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-08\deck\Capstone_Update_2026-10-08_EN.pptx",
]


def clr_scheme(root):
    out = {}
    for scheme in root.iter("{%s}clrScheme" % A):
        for child in scheme:
            tag = child.tag.split("}")[1]
            val = None
            for sub in child:
                st = sub.tag.split("}")[1]
                val = sub.get("val") if st in ("srgbClr", "sysClr") else st
            out[tag] = val
    return out


def theme_of(path_or_prs):
    if isinstance(path_or_prs, str):
        with zipfile.ZipFile(path_or_prs) as z:
            return clr_scheme(ET.fromstring(z.read("ppt/theme/theme1.xml")))
    import io
    blob = path_or_prs.part.package.save  # not used
    return None


def main():
    print("=== 1. theme comparison ===")
    prs = Presentation()
    import tempfile
    tmp = os.path.join(os.environ.get("TEMP", "."), "_carry_probe_default.pptx")
    prs.save(tmp)
    print("%-22s %s" % ("python-pptx default", theme_of(tmp)))
    for s in SOURCES:
        print("%-22s %s" % (os.path.basename(s)[:22], theme_of(s)))
    os.remove(tmp)

    print("")
    print("=== 2. schemeClr elements with their children ===")
    for s in SOURCES:
        with zipfile.ZipFile(s) as z:
            names = sorted(n for n in z.namelist() if re.match(r"ppt/slides/slide\d+\.xml$", n))
            hits = Counter()
            slides_of = defaultdict(list)
            for n in names:
                x = z.read(n).decode("utf-8", "replace")
                for m in re.finditer(r"<a:schemeClr[^>]*/>|<a:schemeClr[^>]*>.*?</a:schemeClr>", x, re.S):
                    frag = m.group(0)
                    hits[frag] += 1
                    slides_of[frag].append(int(re.search(r"slide(\d+)", n).group(1)))
            print("-- %s" % os.path.basename(s))
            for frag, cnt in hits.most_common():
                short = re.sub(r"\s+", " ", frag)
                print("   %4d x  %s" % (cnt, short[:150]))
                sl = sorted(set(slides_of[frag]))
                print("          on slides %s" % (sl if len(sl) < 12 else "%s ... (%d)" % (sl[:12], len(sl))))

    print("")
    print("=== 3. relationships held by the slides, other than the layout ===")
    for s in SOURCES:
        prs = Presentation(s)
        kinds = Counter()
        examples = defaultdict(list)
        for i, slide in enumerate(prs.slides, 1):
            for rel in slide.part.rels.values():
                if rel.reltype.endswith("/slideLayout"):
                    kinds["slideLayout"] += 1
                    continue
                short = rel.reltype.rsplit("/", 1)[-1]
                kinds[short] += 1
                if len(examples[short]) < 4:
                    examples[short].append("p%d %s" % (i, getattr(rel, "target_partname", "?")))
        print("-- %s" % os.path.basename(s))
        for k, v in kinds.most_common():
            print("   %-22s %4d   %s" % (k, v, examples[k]))

    print("")
    print("=== 4. non-picture relationship ids referenced inside slide XML ===")
    for s in SOURCES:
        with zipfile.ZipFile(s) as z:
            names = sorted(n for n in z.namelist() if re.match(r"ppt/slides/slide\d+\.xml$", n))
            refs = Counter()
            for n in names:
                x = z.read(n).decode("utf-8", "replace")
                for m in re.finditer(r"<a:blip[^>]*r:embed=\"(rId\d+)\"", x):
                    refs["blip embed"] += 1
                for m in re.finditer(r"r:link=\"(rId\d+)\"", x):
                    refs["r:link"] += 1
                for m in re.finditer(r"<a:hlinkClick[^>]*r:id=\"(rId\d+)\"", x):
                    refs["hlinkClick"] += 1
                for m in re.finditer(r"<p:oleObj[^>]*r:id=\"(rId\d+)\"", x):
                    refs["oleObj"] += 1
                for m in re.finditer(r"<a:audioFile[^>]*r:link", x):
                    refs["audioFile"] += 1
                for m in re.finditer(r"<a:videoFile[^>]*r:link", x):
                    refs["videoFile"] += 1
                for m in re.finditer(r"<p:contentPart[^>]*r:id", x):
                    refs["contentPart"] += 1
            print("-- %-46s %s" % (os.path.basename(s)[:46], dict(refs)))


if __name__ == "__main__":
    main()
