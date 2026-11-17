# -*- coding: utf-8 -*-
"""Merge the carried pages and the new pages into one delivered deck.

WHY THE LAYOUTS ARE REGISTERED FIRST. python-pptx builds a slide from a layout
that belongs to the destination presentation, and silently repairs a foreign
layout reference by pointing the cloned slide at the blank layout. The repair
loses the layout's name and any placeholder inheritance, and it does it without
an error. Registering the source layouts in the destination first removes the
repair from the path: a source layout is looked up by partname and reused when
the destination already holds one, so each new slide keeps the layout it was
built on.

The carried pages are copied shape by shape instead, because a carried page's
layout was never the point: every shape on it carries absolute geometry and an
explicit font, which is what build_carry.py proved before it wrote them.
"""

import json
import os
import sys
from copy import deepcopy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))

from pptx import Presentation                                     # noqa: E402
from pptx.opc.constants import RELATIONSHIP_TYPE as RT            # noqa: E402
from pptx.opc.package import XmlPart                              # noqa: E402
from pptx.opc.packuri import PackURI                              # noqa: E402

A = "http://schemas.openxmlformats.org/drawingml/2006/main"
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
BLIP = "{%s}blip" % A
EMBED = "{%s}embed" % R


def _layouts(prs):
    return {os.path.basename(str(l.part.partname)): l for l in prs.slide_layouts}


def _register_layouts(dst, src):
    """Add every source layout the destination does not already carry."""
    have = _layouts(dst)
    added = 0
    for src_layout in src.slide_layouts:
        name = os.path.basename(str(src_layout.part.partname))
        if name in have:
            continue
        element = deepcopy(src_layout._element)
        partname = PackURI("/ppt/slideLayouts/%s" % name)
        part = XmlPart(partname, src_layout.part.content_type, element,
                       src_layout.part.package)
        new = dst.slide_layouts._sldLayoutIdLst.add_sldLayoutId()
        new.id = max([int(x.id) for x in dst.slide_layouts._sldLayoutIdLst] or [0]) + 1
        new.rId = dst.part.relate_to(part, RT.SLIDE_LAYOUT)
        have[name] = None
        added += 1
    return added


def append(dst, src, origin, source_name):
    """Append every slide of `src` to `dst`, recording where each came from.

    Returns the number of pictures re-linked. Every relationship a new slide
    holds is either its layout or an image, and an unhandled one raises rather
    than arriving as a dangling id.
    """
    layout_of = _layouts(dst)
    n_pic = 0
    for i, slide in enumerate(src.slides, start=1):
        name = os.path.basename(str(slide.slide_layout.part.partname))
        if name not in layout_of:
            raise RuntimeError("%s slide %d uses layout %s, which the destination "
                               "does not carry" % (source_name, i, name))
        new = dst.slides.add_slide(layout_of[name])
        # add_slide copies the layout's placeholders; this deck's pages draw
        # everything themselves, so any placeholder it cloned is removed.
        for shp in list(new.shapes):
            if shp.is_placeholder:
                shp._element.getparent().remove(shp._element)
        for el in list(slide.shapes._spTree):
            local = el.tag.split("}")[-1]
            if local in ("nvGrpSpPr", "grpSpPr"):
                continue
            clone = deepcopy(el)
            for blip in clone.iter(BLIP):
                embed = blip.get(EMBED)
                if embed is None:
                    raise RuntimeError("%s slide %d: a blip without r:embed"
                                       % (source_name, i))
                rel = slide.part.rels[embed]
                if not rel.reltype.endswith("/image"):
                    raise RuntimeError("%s slide %d: a blip points at %s"
                                       % (source_name, i,
                                          rel.reltype.rsplit("/", 1)[-1]))
                blob = io_bytes(rel.target_part.blob)
                _, rid = new.part.get_or_add_image_part(blob)
                blip.set(EMBED, rid)
                n_pic += 1
            for attr in ("{%s}id" % R, "{%s}link" % R):
                for node in clone.iter():
                    if node.get(attr) is not None:
                        raise RuntimeError("%s slide %d: unhandled relationship %s "
                                           "on %s" % (source_name, i, attr,
                                                      node.tag.split("}")[-1]))
            new.shapes._spTree.append(clone)
        origin.append({"index": len(origin) + 1, "kind": "new",
                       "source": source_name, "source_slide": i, "pictures": n_pic})
    return n_pic


def io_bytes(blob):
    import io
    return io.BytesIO(blob)


def merge(base="deck_A_carry.pptx", new="deck_B_new.pptx", out="deck_final.pptx"):
    """Build the delivered deck from the carried deck and the new one.

    The merge always starts from `base` and always writes through a temporary
    file. Running it twice without this appended another 50 pages to the output
    it had already written, and the page count check downstream then reported a
    162 page deck whose last 50 pages were a duplicate.
    """
    base_path = os.path.join(HERE, base)
    new_path = os.path.join(HERE, new)
    out_path = os.path.join(HERE, out)
    tmp_path = out_path + ".tmp.pptx"
    prs = Presentation(base_path)
    src = Presentation(new_path)
    with open(os.path.join(HERE, "slide_origin.json"), encoding="utf-8") as fh:
        origin = json.load(fh)["slides"]
    if len(origin) != len(prs.slides._sldIdLst):
        raise SystemExit("slide_origin.json lists %d slides but %s holds %d"
                         % (len(origin), base, len(prs.slides._sldIdLst)))
    added = _register_layouts(prs, src)
    pics = append(prs, src, origin, os.path.basename(new_path))
    prs.slide_width = Emu_exact(12192000)
    prs.slide_height = Emu_exact(6858000)
    prs.save(tmp_path)
    os.replace(tmp_path, out_path)
    with open(os.path.join(HERE, "slide_origin.json"), "w", encoding="utf-8") as fh:
        json.dump({"slide_width": prs.slide_width, "slide_height": prs.slide_height,
                   "slides": origin}, fh, indent=1, ensure_ascii=False)
    print("layouts registered from %s: %d" % (os.path.basename(new_path), added))
    print("pages %d   pictures re-linked %d   %.1f MB"
          % (len(origin), pics, os.path.getsize(out_path) / 1048576.0))
    return out_path


def Emu_exact(v):
    from pptx.util import Emu
    return Emu(v)


if __name__ == "__main__":
    merge()
