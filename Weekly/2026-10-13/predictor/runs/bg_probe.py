"""Pin down the master p:bg element and why python-pptx root.find() misses it."""

import io
import zipfile
from xml.etree import ElementTree as ET

P = "{http://schemas.openxmlformats.org/presentationml/2006/main}"
PATH = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Forecasting_Deck.pptx"
OUT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\bg_probe.log"
buf = io.StringIO()


def p(s=""):
    buf.write(str(s) + "\n")


with zipfile.ZipFile(PATH) as z:
    data = z.read("ppt/slideMasters/slideMaster1.xml").decode("utf-8", "replace")
    p("raw length=%d" % len(data))
    i = data.find("p:bg")
    p("first index of 'p:bg' = %d" % i)
    p("context: %r" % data[max(0, i - 120):i + 160])
    root = ET.fromstring(data)
    p("root.tag=%s" % root.tag)
    p("children tags: %s" % [c.tag for c in root])
    bg = root.find(P + "bg")
    p("root.find(P+bg) = %s" % bg)
    if bg is not None:
        p("  bg.tag=%s" % bg.tag)
        p("  bg children=%s" % [c.tag for c in bg])
        ref = bg.find(P + "bgRef")
        p("  bg.find(P+bgRef)=%s" % ref)
        for c in bg:
            p("  child %s attrs=%s" % (c.tag, c.attrib))
            for cc in c:
                p("    grandchild %s attrs=%s" % (cc.tag, cc.attrib))

    # where is bg relative to cSld?
    tags = [c.tag.split('}')[-1] for c in root]
    p("master children order (local names): %s" % tags)

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
    fh.write(buf.getvalue())
print("WROTE %s" % OUT)
