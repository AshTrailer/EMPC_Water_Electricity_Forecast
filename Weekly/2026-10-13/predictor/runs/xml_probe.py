"""Third pass: raw XML probes for master background and layout structure."""

import io
import os
import zipfile

DECKS = [
    (1, r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Forecasting_Deck.pptx"),
    (2, r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Weekly_2026-09-23.pptx"),
    (3, r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Predicitor.pptx"),
    (4, r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-08\deck\Capstone_Forecasting_v1.pptx"),
]
OUT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\xml_probe.log"
buf = io.StringIO()


def p(s=""):
    buf.write(s + "\n")


for n, path in DECKS:
    p("=" * 70)
    p("DECK %d %s" % (n, os.path.basename(path)))
    with zipfile.ZipFile(path) as z:
        masters = sorted(x for x in z.namelist() if x.startswith("ppt/slideMasters/") and x.endswith(".xml"))
        layouts = sorted(x for x in z.namelist() if x.startswith("ppt/slideLayouts/") and x.endswith(".xml"))
        slides = sorted(x for x in z.namelist() if x.startswith("ppt/slides/slide") and x.endswith(".xml"))
        pres = z.read("ppt/presentation.xml").decode("utf-8", "replace")
        p("masters=%d layouts=%d slides=%d" % (len(masters), len(layouts), len(slides)))
        p("presentation.xml has <p:sldSz>: %s" % ("<p:sldSz" in pres))
        i = pres.find("<p:sldSz")
        if i >= 0:
            p("  %s" % pres[i:pres.find("/>", i) + 2])
        p("presentation.xml sldMasterIdLst entries: %d" % pres.count("<p:sldMasterId "))
        for m in masters:
            data = z.read(m).decode("utf-8", "replace")
            has_bg = "<p:bg>" in data or "<p:bg " in data
            k = data.find("<p:cSld")
            name = ""
            if k >= 0:
                seg = data[k:data.find(">", k)]
                if 'name="' in seg:
                    a = seg.find('name="') + 6
                    name = seg[a:seg.find('"', a)]
                p("  %s cSld attrs=%r  name_attr_present=%s" % (m, seg[:160], 'name="' in seg))
            p("    has <p:bg>: %s" % has_bg)
            if has_bg:
                i2 = data.find("<p:bg")
                j2 = data.find("</p:bg>", i2)
                p("    bg xml: %s" % data[i2:j2 + 7][:400])
            # theme relationship
            for rel in ("theme",):
                pass
        # layout names
        for lay in layouts:
            data = z.read(lay).decode("utf-8", "replace")
            k = data.find("<p:cSld")
            seg = data[k:data.find(">", k)] if k >= 0 else ""
            a = seg.find('name="')
            nm = seg[a + 6:seg.find('"', a + 6)] if a >= 0 else "(no name attr)"
            has_bg = "<p:bg>" in data or "<p:bg " in data
            p("  LAYOUT %-28s name=%-32s bg=%s" % (os.path.basename(lay), nm, has_bg))
        # slides: does any slide declare its own bg, and which layout rel
        bgslides = []
        for s in slides:
            data = z.read(s).decode("utf-8", "replace")
            if "<p:bg>" in data or "<p:bg " in data:
                bgslides.append(os.path.basename(s))
        p("slides declaring their own <p:bg>: %d %s" % (len(bgslides), bgslides[:8]))

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
    fh.write(buf.getvalue())
print("WROTE %s" % OUT)
