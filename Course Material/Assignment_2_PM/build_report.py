"""Build the Assignment 2 Part 1 project retrospective (DOCX) and report the word count."""

import re
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

OUT_DOCX = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Assignment_2_PM\Assignment2_PM_Retrospective_DRAFT_v2.docx"

LATIN_FONT = "Calibri"

TITLE = "Project Retrospective: Electricity Price Forecasting for Economic MPC of Pumping"

HEADING_1 = [
    "Objective and scope",
    "Risks and countermeasures",
    "Milestones, progress and the critical path",
    "People and teamwork",
    "Stakeholders",
    "Performance measurement",
    "Declaration of AI use",
]

BODY = [
    # ---- Objective and scope
    "Our charter committed us to deliver an electricity price-forecasting model and an economic model predictive control (EMPC) algorithm that schedules water pumps, and to test the forecaster against AEMO's published five-minute price forecast. The baseline is restated here because the charter is held by the supervisor.",
    "The objective stands. The integration argument changed: AEMO's short-term published product reaches about one hour ahead, so we set the control horizon to one hour as well, which makes the accuracy comparison direct rather than approximate, and over that window our forecaster wins. The charter expected a single forecast model, but the benchmark showed that accuracy depends on the horizon, so we settled on one predictor for the control window and kept the rest as measured alternatives. The live data feed stayed a Must, because the forecaster cannot be validated without it.",
    # ---- Risks and countermeasures
    "The charter listed three major risks. Data-link integrity occurred and cost about a week. The countermeasure was a cross-source audit of AEMO monthly files, dashboard exports and the market archive, which worked and is now re-runnable. It then found a genuine surprise.",
    "Forecaster accuracy below target occurred, and the countermeasure was to replace one aggregate accuracy target with error resolved by forecast horizon. That change produced the finding the project rests on, and it exposed three latent code defects in our own benchmark.",
    "The interface risk between our modules occurred, so we defined the handoff and tested it with a stub. It is now in place: the forecaster supplies the hourly price sequence and the controller turns it into pump decisions, with actual pump states driving the tank rather than the requested plan. Integration is complete, and the remaining work is the cost comparison.",
    "One risk was not on the list: our own measurement chain. A parsing defect meant the store of actual prices never held more than five rows, and a time-zone default would have shifted captured data by twelve intervals against our training set. We found both by auditing our own tooling first. Separately, error figures I passed to the supervisor moved from 15 to 42 dollars per megawatt-hour in two weeks, because two reports had scored different samples. All error numbers now come from one experiment that states its window and metric.",
    # ---- Milestones, progress, critical path
    "The chart has been the weak point. It promised a validated forecaster on 31 August, a working EMPC framework on 21 September, and a final report on 14 October. The two technical milestones are met, but the chart was never revised after submission, so it still shows zero progress on work that has since been done.",
    "Where the project actually stands: the controller runs a rolling three-pump schedule with hard tank-level limits and a pump switching penalty; the forecaster is benchmarked across 120 days and nine models through one entry point; and the link between them is closed at a one-hour horizon. The critical path has moved from building the forecast to proving its value.",
    "What remains is the cost comparison against the market operator's forecast and the report due on 14 October, which is one working day beyond our own target date. Whether to extend the control horizon is a scope decision for the second half, not a blocker, and it has no budget consequence because nothing has been spent outside committed student and supervisor hours.",
    # ---- People and teamwork
    "The split by expertise has worked, since each person holds a clear area and decides scheduling inside it without waiting for me. Its weakness was where we stood in September: nobody owned the interfaces between modules. I manage the data pipeline and chair the weekly meeting, but I should have opened a decision log far earlier.",
    "To hold the team through the final stretch, each person now owns one integration test of the end product, we run a short weekly retrospective whose only agenda item is blockers, and I keep the decision log. My performance has been sound on technical recovery and weak on process discipline: I let the reporting baseline drift and the schedule chart age.",
    # ---- Stakeholders
    "Our supervisor owns the learning objectives and the definition of success, and steered us to report error by horizon instead of selecting the best result. That steer shaped the comparison we can defend. Our industry adviser represents the water utility and wants cost per day. My team produces the deliverables. I have communicated least well with the adviser, sending status where he needed decision framing, and I am correcting that now.",
    # ---- Performance measurement
    "I proposed two sets of measures, and the team agreed them. Process measures, reviewed weekly, are decision turnaround time, experiment runtime, and data quality as null rates and row counts. Delivery measures are forecast error by horizon and time of day, a like-for-like cost comparison against the perfect-forecast and market-forecast cases, and the number of end-to-end tests passing. Process measures are ahead of baseline. On delivery, the forecaster beats the market operator's published forecast everywhere inside the control window, and degrades outside it, at 41 dollars per megawatt-hour against a signal standard deviation of 49. The cost number is still missing, and the sponsor should hear that from me now.",
    # ---- Declaration of AI use
    "A generative AI assistant (DeepSeek Harness) was used to audit the repository and reconstruct the project timeline from commits and working documents, to draft this retrospective, and to refine its wording. All figures cited were checked against project files by the author, the analysis and modelling were performed by the team, the two elective components and the lessons reported are the author's own judgements, and the author is responsible for the final content. The same declaration applies to the accompanying slides.",
]


def words(text):
    return len(re.findall(r"[A-Za-z0-9][A-Za-z0-9'\u2019./-]*", text))


def set_run(run, size, bold=False, color=None, italic=False):
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.name = LATIN_FONT
    run._element.rPr.rFonts.set(qn("w:eastAsia"), LATIN_FONT)
    if color:
        run.font.color.rgb = RGBColor(*color)


def add_para(doc, text, size=11, bold=False, color=None, space_after=8, space_before=0,
             align=None, italic=False):
    para = doc.add_paragraph()
    para.paragraph_format.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
    para.paragraph_format.line_spacing = 1.15
    para.paragraph_format.space_after = Pt(space_after)
    para.paragraph_format.space_before = Pt(space_before)
    if align is not None:
        para.alignment = align
    set_run(para.add_run(text), size, bold, color, italic=italic)
    return para


def add_heading(doc, text, size=13, space_before=12, space_after=5):
    para = doc.add_paragraph()
    para.paragraph_format.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
    para.paragraph_format.line_spacing = 1.15
    para.paragraph_format.space_before = Pt(space_before)
    para.paragraph_format.space_after = Pt(space_after)
    para.paragraph_format.keep_with_next = True
    set_run(para.add_run(text), size, bold=True, color=(0x1F, 0x33, 0x55))
    return para


# BODY paragraph indices grouped under their section headings. The AI declaration
# sits outside the 850-word limit and is built separately.
SECTIONS = [
    (HEADING_1[0], [0, 1]),
    (HEADING_1[1], [2, 3, 4, 5]),
    (HEADING_1[2], [6, 7, 8]),
    (HEADING_1[3], [9, 10]),
    (HEADING_1[4], [11]),
    (HEADING_1[5], [12]),
]
AI_PARAGRAPH_INDEX = 13


def main():
    doc = Document()
    for section in doc.sections:
        section.page_width = Cm(21.0)
        section.page_height = Cm(29.7)
        section.top_margin = Cm(2.54)
        section.bottom_margin = Cm(2.54)
        section.left_margin = Cm(3.18)
        section.right_margin = Cm(3.18)

    normal = doc.styles["Normal"]
    normal.font.name = LATIN_FONT
    normal.font.size = Pt(11)
    normal.element.rPr.rFonts.set(qn("w:eastAsia"), LATIN_FONT)

    add_para(doc, TITLE, size=15, bold=True, color=(0x1F, 0x33, 0x55), space_after=2)
    add_para(doc, "ENGR90037 Capstone, Assignment 2 Part 1  |  Project Management option  |  Ash",
             size=9.5, color=(0x59, 0x59, 0x59), space_after=4)
    add_para(doc, "The baseline objective, scope, risks and milestones cited below are the team's restatement of the submitted Project Charter.",
             size=9, italic=True, color=(0x59, 0x59, 0x59), space_after=10)

    for heading, indices in SECTIONS:
        add_heading(doc, heading)
        for index in indices:
            add_para(doc, BODY[index], align=WD_ALIGN_PARAGRAPH.JUSTIFY)

    add_heading(doc, HEADING_1[6])
    add_para(doc, BODY[AI_PARAGRAPH_INDEX], align=WD_ALIGN_PARAGRAPH.JUSTIFY)

    doc.save(OUT_DOCX)

    body_indices = [i for _, idx in SECTIONS for i in idx]
    body_count = sum(words(BODY[i]) for i in body_indices)
    ai_count = words(BODY[AI_PARAGRAPH_INDEX])
    print("BODY words (four required aspects + two elective components):", body_count)
    print("AI declaration words (outside the limit):", ai_count)
    print("limit check:", "PASS" if body_count <= 850 else "FAIL")
    for i, paragraph in enumerate(BODY):
        mark = "body" if i in body_indices else "AI  "
        print(f"  [{i:2d}] {mark} {words(paragraph):4d}  {paragraph[:58]}...")


if __name__ == "__main__":
    main()
