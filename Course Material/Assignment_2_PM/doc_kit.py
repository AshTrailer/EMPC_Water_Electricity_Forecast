"""Build the Assignment 2 deliverables: the cost comparison report and the retrospective."""

import re
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

BASE = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Assignment_2_PM"
OUT_COST = BASE + r"\Cost_Comparison_EMPC_20261016.docx"
OUT_RETRO = BASE + r"\Assignment2_PM_Retrospective_v4.docx"

FONT = "Calibri"
NAVY = (0x1F, 0x33, 0x55)
GREY = (0x59, 0x59, 0x59)


def words(text):
    return len(re.findall(r"[A-Za-z0-9][A-Za-z0-9'\u2019./-]*", text))


class Doc:
    def __init__(self):
        self.doc = Document()
        for section in self.doc.sections:
            section.page_width = Cm(21.0)
            section.page_height = Cm(29.7)
            section.top_margin = Cm(2.54)
            section.bottom_margin = Cm(2.54)
            section.left_margin = Cm(3.18)
            section.right_margin = Cm(3.18)
        normal = self.doc.styles["Normal"]
        normal.font.name = FONT
        normal.font.size = Pt(11)
        normal.element.rPr.rFonts.set(qn("w:eastAsia"), FONT)
        self.body = []

    def _para(self, text, size, bold, color, after, before, align, italic, line):
        para = self.doc.add_paragraph()
        para.paragraph_format.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
        para.paragraph_format.line_spacing = line
        para.paragraph_format.space_after = Pt(after)
        para.paragraph_format.space_before = Pt(before)
        if align is not None:
            para.alignment = align
        run = para.add_run(text)
        run.font.size = Pt(size)
        run.font.bold = bold
        run.font.italic = italic
        run.font.color.rgb = RGBColor(*color) if color else RGBColor(0x22, 0x2B, 0x38)
        run.font.name = FONT
        run._element.rPr.rFonts.set(qn("w:eastAsia"), FONT)
        return para

    def title(self, text, sub=None, note=None):
        self._para(text, 15, True, NAVY, 3, 0, None, False, 1.1)
        if sub:
            self._para(sub, 9.5, False, GREY, 3, 0, None, False, 1.1)
        if note:
            self._para(note, 9, False, GREY, 10, 0, None, True, 1.1)

    def heading(self, text):
        para = self._para(text, 12.5, True, NAVY, 5, 12, None, False, 1.15)
        para.paragraph_format.keep_with_next = True

    def body_para(self, text):
        self.body.append(text)
        self._para(text, 11, False, None, 8, 0, WD_ALIGN_PARAGRAPH.JUSTIFY, False, 1.15)

    def bullet(self, text):
        para = self._para(text, 11, False, None, 5, 0, None, False, 1.15)
        para.paragraph_format.left_indent = Cm(0.6)
        para.paragraph_format.first_line_indent = Cm(-0.35)

    def table(self, header, rows, widths=None, style="Table Grid", size=9.0):
        table = self.doc.add_table(rows=1, cols=len(header))
        table.style = style
        table.autofit = False
        for i, text in enumerate(header):
            cell = table.rows[0].cells[i]
            cell.text = ""
            run = cell.paragraphs[0].add_run(text)
            run.font.size = Pt(size)
            run.font.bold = True
            run.font.name = FONT
        for row in rows:
            cells = table.add_row().cells
            for i, text in enumerate(row):
                cells[i].text = ""
                para = cells[i].paragraphs[0]
                para.paragraph_format.space_after = Pt(1)
                run = para.add_run(str(text))
                run.font.size = Pt(size)
                run.font.name = FONT
        if widths:
            for row in table.rows:
                for i, cm in enumerate(widths):
                    row.cells[i].width = Cm(cm)
        self.doc.add_paragraph().paragraph_format.space_after = Pt(4)
        return table

    def picture(self, path, width_cm=15.0):
        self.doc.add_picture(path, width=Cm(width_cm))
        self.doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER

    def caption(self, text):
        self._para(text, 8.5, False, GREY, 10, 0, WD_ALIGN_PARAGRAPH.CENTER, True, 1.1)

    def page_break(self):
        self.doc.add_page_break()

    def save(self, path):
        self.doc.save(path)
        return sum(words(p) for p in self.body)
