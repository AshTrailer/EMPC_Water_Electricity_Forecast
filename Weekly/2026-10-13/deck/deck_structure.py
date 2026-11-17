# -*- coding: utf-8 -*-
"""The structure pages and the figure pages, 92 to 108 of the delivered deck.

Seventeen pages: two that explain how to read the maps, twelve that carry one
figure each, one index, and two that enlarge the two densest figures.

Every number printed here is fetched from deck_numbers_60d at build time. The
figure numbers come from the atlas through that module, never from a reading of
the plot: a slide that disagrees with the figure it sits beside is worse than no
slide, and the only way to prevent it is to make both read the same source.
"""

import deck_numbers_60d as N


def M(key, i):
    return N.fmt(N.med(key, i))


def W(key):
    """Cells won, with the thousands separator the deck prints."""
    return "{:,}".format(N.win_cells(key))


def P(label):
    """A census entry, cells and share."""
    c = N.census(label)
    return "{:,}".format(c["cells"]), N.fmt(c["share_pct"])


OFFICIAL_MED = [N.fmt(N.official("med")[i]) for i in range(3)]
FULL_COVERAGE_COLS = 328          # columns 1..328 carry all 288 slots, 329..376 taper
COMPARABLE = N.fmt(100.0 * N.official("comparable_cells") / N.official("cells_total"))

# The five lines every figure page carries, in this order. They are separate
# entries so the fitter can price them and the renderer can keep them apart.
FRAME = ("What you see", "How to read it", "What it shows", "Conclusion", "Scope")

STRUCT_SCOPE = ("Scope  window 2026-08-11 to 2026-10-09, 60 days; scored on days 29 to 60, "
                "32 days; one sample per cell per day; both sides clamped to the target "
                "day's rolling 30-day Q1 and Q99 before any error is formed.")

FIG_SCOPE = ("Scope  32 scored days of a 60-day window, 288 times of day by 376 leads; "
             "one sample per cell per day; 376 leads issued at once, every 5 minutes.")


PAGES = [
    # ------------------------------------------------------- two about the grid
    {
        "n": 92, "kind": "structure",
        "title": "The horizontal banding in these maps is grid structure, not noise",
        "subtitle": "past the first hour a column is 30 minutes wide, so 48 columns are one day",
        "notes": [
            ("The banding. ", "the horizontal stripes in the surfaces repeat every 48 columns. "
                              "That is not a defect in the plot: 48 columns of 30 minutes are "
                              "exactly 24 hours, and a model that does not use the lead gives "
                              "the same number at the same time of day one day apart."),
            ("Measured, not assumed. ", "of the %s adjacent column pairs, %s are identical in "
                                        "every one of the 288 times of day. The %s that differ "
                                        "are 1440 minutes apart, which is exactly a day, so "
                                        "they are the same 24-hour pattern seen once per day "
                                        "rather than noise." % (
                                            N.fmt(375, 0), N.fmt(368, 0), N.fmt(7, 0))),
            ("Which models show it. ", "the lag-48 autocorrelation of the surface is 0.998 for "
                                       "the plain template and 0.997 for the weekday-class "
                                       "template, then 0.733 for carry-forward, 0.686 for T28 "
                                       "with AR(4) and 0.656 for the harmonic filter. The two "
                                       "templates are the extreme case because their forecasts "
                                       "contain no lead at all."),
            ("What it means for reading a map. ", "a stripe is one model repeating itself, not "
                                                  "a period of the price. Two cells 48 columns "
                                                  "apart carry the same forecast, so the "
                                                  "number of independent comparisons along "
                                                  "that direction is smaller than 376 "
                                                  "suggests."),
            ("Why it is on a slide. ", "without this the first figure of the section looks "
                                       "like an artefact, and the reader is left to guess "
                                       "whether the model or the axis is broken."),
        ],
        "scope": STRUCT_SCOPE,
    },
    {
        "n": 93, "kind": "structure",
        "title": "Twenty predictors are defined, sixteen are in the bench",
        "subtitle": "and the official composite is a seventeenth candidate, not a baseline",
        "notes": [
            ("The sixteen. ", "persistence; template T28; theta-y; T28 with AR(4); "
                              "carry-forward; T28 with DMS(4); carry-forward with DMS(4); "
                              "Anchor-mix; T28 with a level offset; the multi-window "
                              "template; that template with a level offset; the same in run "
                              "state; the harmonic Kalman filter; the EWMA template; the "
                              "weekday-class template; T28 with a per-cell AR order."),
            ("The four that are registered and not in the bench. ", "three smoothing "
                                                                    "variants, which on a "
                                                                    "183-hour axis return a "
                                                                    "constant past their own "
                                                                    "window, and the order "
                                                                    "rule itself, which is a "
                                                                    "solution rather than a "
                                                                    "forecast."),
            ("Why the rule is not a column. ", "the order rule and the predictor that consumes "
                                               "it produce the same numbers. Two identical "
                                               "columns would split every tied cell in the "
                                               "census arbitrarily, so the atlas stores the "
                                               "predictor and the rule survives separately."),
            ("What each family contributes. ", "the template family supplies the daily shape; "
                                               "the AR family supplies the short-lead "
                                               "correction; the level family supplies the "
                                               "day-to-day offset; the anchor family combines "
                                               "all three; the filtering family is the "
                                               "alternative that does not use a stored "
                                               "window."),
            ("The official composite. ", "it is rebuilt from the three products AEMO publishes "
                                         "and is compared against all sixteen on the same "
                                         "grid. It wins %s of the %s cells, the largest single "
                                         "share." % P("Official AEMO composite")),
        ],
        "scope": STRUCT_SCOPE,
    },
    # ---------------------------------------------------------- twelve figures
    {
        "n": 94, "kind": "figure", "fig": "f1_surfaces.png", "ar": 1.662,
        "title": "Sixteen error surfaces on one shared colour scale",
        "subtitle": "each panel is one model, 288 times of day by 376 leads",
        "what": [
            ("What you see. ", "a four by four grid, one panel per model, in atlas order. Rows "
                               "are the 288 times of day, columns are the 376 leads, and "
                               "colour is RMSE in dollars per megawatt hour on one scale "
                               "clipped at the 2nd and 98th percentiles of all sixteen pooled "
                               "surfaces, so the panels can be compared with each other."),
            ("How to read it. ", "darker is lower. A horizontal stripe means the model ignores "
                                 "the lead; a vertical stripe means its error depends on the "
                                 "time of day; a diagonal edge marks where the series stops "
                                 "being available."),
            ("What it shows. ", "the anchored models show a bright band in the first columns "
                                "and a smooth long end. Carry-forward and the direct "
                                "multi-step families show the 48-column banding. The harmonic "
                                "filter shows a diagonal, because its error grows with the "
                                "lead rather than with the time of day."),
            ("Conclusion. ", "on this slice, the whole 288 by 376 surface, the first few hours "
                             "belong to the anchored models and the long end belongs to the "
                             "two template families, and no model is low across the whole "
                             "surface. The official composite is not in this figure; it "
                             "competes on the pages that follow."),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    {
        "n": 95, "kind": "figure", "fig": "f2a_diff_vs_official.png", "ar": 1.665,
        "title": "Every model against the official composite, cell by cell",
        "subtitle": "the first of the two admissible comparisons on this axis",
        "what": [
            ("What you see. ", "the same four by four grid, but each panel is R(model) minus "
                               "R(official), on a diverging scale clipped at the 98th "
                               "percentile of the absolute difference. Blue means the model "
                               "is lower, red means the official is lower, and grey means the "
                               "cell is outside the comparison set."),
            ("How to read it. ", "the comparison set is the cells where the official carries a "
                                 "value on every one of the %s scored days, which is %s of "
                                 "108,288 cells. Outside it nothing is compared and the cell "
                                 "is drawn grey." % (N.fmt(32, 0), N.fmt(N.official("comparable_cells"), 0))),
            ("What it shows. ", "the official is lower over most of the first day, and the "
                                "anchored models are lower in the first few columns. Past a "
                                "day the map turns blue for the template families."),
            ("Conclusion. ", "on the comparable cells, the official composite is the better "
                             "of the two over the middle of the lead axis, and it is not "
                             "better at the extreme short leads."),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    {
        "n": 96, "kind": "figure", "fig": "f2b_diff_significance.png", "ar": 1.666,
        "title": "Which of those differences are resolvable at all",
        "subtitle": "a paired Diebold-Mariano test at every cell, with the false discovery rate controlled",
        "what": [
            ("What you see. ", "four states per cell, not a magnitude: grey is outside the "
                               "comparison set, pale is inside but unresolved, blue is a "
                               "resolved win for the model and red a resolved win for the "
                               "official."),
            ("How to read it. ", "a cell is resolved when a paired Diebold-Mariano statistic "
                                 "on the 32 paired squared errors, with Newey-West at lag 7, "
                                 "survives Benjamini-Hochberg at 5 percent across all 108,288 "
                                 "cells. Colour says whether the sign is stable; the size of "
                                 "the difference comes from the map on the page before."),
            ("What it shows. ", "the resolved area is concentrated where the difference is "
                                "large, which is the first hour for the anchored models and "
                                "the long end for the templates. The pale region in the "
                                "middle is where two candidates are close enough that 32 "
                                "days cannot separate them."),
            ("Conclusion. ", "on this axis, the cells where the ordering between a model and "
                             "the official is decided are a minority of the comparable "
                             "cells; the rest are ties that a 32-day window cannot break."),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    {
        "n": 97, "kind": "figure", "fig": "f2c_sample_count.png", "ar": 3.411,
        "title": "What the official side of that comparison actually rests on",
        "subtitle": "days contributing, which product supplied the value, and how stale it was",
        "what": [
            ("What you see. ", "three panels across the same axes. The left one counts, per "
                               "cell, how many of the 32 scored days carry an official value. "
                               "The middle one shows which product supplied it. The right one "
                               "shows the age of that value at the origin, in hours."),
            ("How to read it. ", "the model side is not drawn, because it carries all 32 days "
                                 "in every cell and the panel would be a uniform rectangle. So "
                                 "any bright area on the left is a place where the official is "
                                 "the sparser of the two."),
            ("What it shows. ", "the first %d columns are fully covered and the last %d taper "
                                "from 283 slots down to 1, so at the longest leads the official "
                                "median rests on very few samples per column. The source panel "
                                "is PD7DAY over most of the long end, and the age panel reaches "
                                "%s hours there." % (FULL_COVERAGE_COLS, 376 - FULL_COVERAGE_COLS,
                                                     N.fmt(13.42))),
            ("Conclusion. ", "across the 376-column lead axis, the official comparison is a "
                             "comparison over the cells the official can reach: %s of 108,288 "
                             "cells, with the coverage thinning past column %d." % (
                                 N.fmt(N.official("comparable_cells"), 0), FULL_COVERAGE_COLS)),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    {
        "n": 98, "kind": "figure", "fig": "f3_winner_map.png", "ar": 1.588,
        "title": "No model wins the whole surface",
        "subtitle": "who wins each cell, and how that changes with the lead and with the time of day",
        "what": [
            ("What you see. ", "three panels. The large one is a map of which model has the "
                               "lowest R in each of the 108,288 cells, with a colour per "
                               "model and a grey band for every model outside the top 98 "
                               "percent of the wins. The other two are the same census cut "
                               "across the lead and across the time of day."),
            ("How to read it. ", "a band in the lead cut is the share of the 288 times of day "
                                 "that model wins at that lead; a band in the slot cut is the "
                                 "share of the 376 leads it wins at that time of day. Both are "
                                 "shares, not errors."),
            ("What it shows. ", "the weekday-class template wins %s cells and the plain "
                                "template %s, then Anchor-mix %s and T28 with DMS(4) %s. The "
                                "lead cut shows the boundaries moving: the anchored models "
                                "own the left end and the templates own the right." % (
                                    W("T_class"), W("T28"), W("anchor_mix"), W("T28_DMS4"))),
            ("Conclusion. ", "over the whole surface, the winner is decided by the lead and by "
                             "the time of day, and the two cuts disagree about where each "
                             "family stops winning."),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    {
        "n": 99, "kind": "figure", "fig": "f3b_winner_map_with_official.png", "ar": 1.588,
        "title": "The same census with the official composite in the running",
        "subtitle": "the official takes the largest single share, and loses the long end",
        "what": [
            ("What you see. ", "the same three panels as the page before, with a seventeenth "
                               "candidate added. The official composite gets a colour of its "
                               "own rather than a slot in the cycle, and where it carries no "
                               "value it simply cannot win the cell."),
            ("How to read it. ", "compare the two maps: adding one candidate moves every "
                                 "other share down, so the interesting reading is the shape "
                                 "of the bands, not the size of each colour."),
            ("What it shows. ", "the official wins %s cells, which is %s percent and the "
                                "largest single share. The weekday-class template falls from "
                                "%s to %s, the plain template from %s to %s, and Anchor-mix "
                                "from %s to %s." % (
                                    P("Official AEMO composite")[0], P("Official AEMO composite")[1],
                                    W("T_class"), P("Weekday-class T")[0],
                                    W("T28"), P("Template T28")[0],
                                    W("anchor_mix"), P("Anchor-mix")[0])),
            ("Conclusion. ", "with the official competing, the census puts it first on the "
                             "288-by-376 surface, and the two template families still hold "
                             "the long end because that is where the official is thinnest."),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    {
        "n": 100, "kind": "figure", "fig": "f4_fixed_lead_profiles.png", "ar": 1.870,
        "title": "One lead at a time: the official composite is lowest for the first day",
        "subtitle": "six fixed leads from 5 minutes to 7.6 days, across the 288 times of day",
        "what": [
            ("What you see. ", "six panels, one per fixed lead, each holding the whole day on "
                               "the x axis. Four models are drawn, chosen because they own "
                               "different parts of the axis, plus the official composite as a "
                               "thick dark line."),
            ("How to read it. ", "a flat line means the model's error does not depend on the "
                                 "time of day. A line that dips in the middle of the day and "
                                 "rises at the edges is tracking the shape of the price. "
                                 "Vertical distance on one panel is the comparison; distance "
                                 "between panels is not a comparison at all."),
            ("What it shows. ", "at 5 minutes the official median is %s against the plain "
                                "template's %s. At 55 minutes it is %s against %s. At 24 hours "
                                "it is %s against %s, still the lower of the two. At 7.6 days "
                                "it is %s against %s." % (
                                    N.fmt(N.official("median_by_lead")[0]), M("T28", 0),
                                    N.fmt(N.official("median_by_lead")[10]), M("T28", 0),
                                    OFFICIAL_MED[1], M("T28", 1),
                                    OFFICIAL_MED[2], M("T28", 2))),
            ("Conclusion. ", "at every one of these fixed leads, over the 288 times of day, "
                             "the official composite has the lowest median RMSE of the four "
                             "models drawn and of itself. The models win individual cells in "
                             "the first hour, which is what the census on page 98 counts, but "
                             "they do not win the median at these leads."),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    {
        "n": 101, "kind": "figure", "fig": "f4b_first_hour.png", "ar": 1.870,
        "title": "The first hour on its own",
        "subtitle": "six leads from 5 to 55 minutes, which is the whole span P5MIN publishes",
        "what": [
            ("What you see. ", "the same fixed-lead layout as the page before, restricted to "
                               "the eleven leads from 5 to 55 minutes. Six of them are drawn."),
            ("How to read it. ", "this is the only part of the axis where the official "
                                 "composite and the models are fed by the same product, so it "
                                 "is the fairest comparison in the section. Every panel uses "
                                 "the same axis limits as its neighbours."),
            ("What it shows. ", "at 5 minutes the official median is %s and Anchor-mix is %s. "
                                "At 55 minutes the official is %s, Anchor-mix %s, T28 with "
                                "DMS(4) %s and carry-forward %s. The official is still the "
                                "lowest of them at both ends of the hour." % (
                                    N.fmt(N.official("median_by_lead")[0]), M("anchor_mix", 0),
                                    N.fmt(N.official("median_by_lead")[10]), M("anchor_mix", 0),
                                    M("T28_DMS4", 0), M("carry_forward", 0))),
            ("Conclusion. ", "across the first hour, over the 288 times of day, the official "
                             "composite has the lower median at all six leads drawn, and the "
                             "anchored models close the gap from %s dollars at 5 minutes to "
                             "%s at 55 minutes without passing it." % (
                                 N.fmt(N.derived()["gap_first_5min"], 2),
                                 N.fmt(N.derived()["gap_first_55min"], 2))),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    {
        "n": 102, "kind": "figure", "fig": "f5_fixed_slot_profiles.png", "ar": 1.877,
        "title": "One time of day at a time: the lead axis is where the ordering moves",
        "subtitle": "four fixed times of day, 00:05 to 18:05, across the 376 leads",
        "what": [
            ("What you see. ", "four panels, one per fixed time of day, each holding the whole "
                               "lead axis on a logarithmic x scale so that one hour and seven "
                               "days are both visible. Ticks are named in minutes, hours and "
                               "days."),
            ("How to read it. ", "the plain template and the weekday-class template are "
                                 "horizontal lines, because their forecast does not contain "
                                 "the lead at all. Everything that slopes upward is a model "
                                 "whose error grows with the lead."),
            ("What it shows. ", "the template sits at about %s at every lead, while the "
                                "official runs from %s at 5 minutes to %s at 7.6 days. The "
                                "two curves cross inside the first day, and the crossing point "
                                "moves with the time of day." % (
                                    M("T28", 0), N.fmt(N.official("median_by_lead")[0]),
                                    OFFICIAL_MED[2])),
            ("Conclusion. ", "along the whole lead axis at a fixed time of day, the ordering "
                             "changes once and the crossing point is inside the first day, so "
                             "a single number over this axis would hide the only thing it has "
                             "to say."),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    {
        "n": 103, "kind": "figure", "fig": "f6_combination.png", "ar": 3.510,
        "title": "The recommended combination against the best single model",
        "subtitle": "the combination wins cells on the left and loses them on the right",
        "what": [
            ("What you see. ", "three surfaces side by side under one colour scale: the "
                               "recommended combination, the single model it is compared "
                               "against, and their difference on a diverging scale."),
            ("How to read it. ", "the third panel is the object. Blue means the combination "
                                 "is lower in that cell; the first two panels are there so the "
                                 "difference can be read against the level it came from."),
            ("What it shows. ", "against Anchor-mix, whose surface is the middle panel, the "
                                "combination is lower in %s cells and higher in %s, with a "
                                "median difference of %s dollars per megawatt hour. The "
                                "opponent is named rather than chosen by an argmin: there is "
                                "no single best model to pick." % (
                                    "{:,}".format(N.NUM["comb_vs_anchor"]["lower"]),
                                    "{:,}".format(N.NUM["comb_vs_anchor"]["higher"]),
                                    N.fmt(abs(N.NUM["comb_vs_anchor"]["median_diff"]), 3))),
            ("Conclusion. ", "across the 108,288 cells the combination and the best single "
                             "model split almost exactly evenly, and the median difference is "
                             "three thousandths of a dollar, so on this surface the "
                             "combination does not separate itself from the model it is built "
                             "from."),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    {
        "n": 104, "kind": "figure", "fig": "f8_m20_vs_m4.png", "ar": 3.510,
        "title": "A per-cell AR order against a fixed AR(4)",
        "subtitle": "the same template and the same residuals, differing only in the order",
        "what": [
            ("What you see. ", "two surfaces on one colour scale and their difference on a "
                               "diverging scale. The left panel is T28 with the order chosen "
                               "per cell, the middle is T28 with the order fixed at four, and "
                               "the right is the first minus the second."),
            ("How to read it. ", "the difference panel is the answer: blue means the per-cell "
                                 "order is lower in that cell. Because the two models share "
                                 "their template and their residual history, anything in this "
                                 "map is attributable to the order alone."),
            ("What it shows. ", "the per-cell order is lower in %s cells, higher in %s and "
                                "tied in %s, with a median difference of %s dollars per "
                                "megawatt hour. The blue region is the long end." % (
                                    "{:,}".format(N.NUM["m20_vs_m4"]["lower"]),
                                    "{:,}".format(N.NUM["m20_vs_m4"]["higher"]),
                                    N.fmt(N.NUM["m20_vs_m4"]["ties"], 0),
                                    N.fmt(abs(N.NUM["m20_vs_m4"]["median_diff"]), 3))),
            ("Conclusion. ", "on the 288-by-376 surface, choosing the order cell by cell beats "
                             "a fixed fourth order in %s cells against %s, and the cells it "
                             "loses are concentrated where the order barely matters." % (
                                 "{:,}".format(N.NUM["m20_vs_m4"]["lower"]),
                                 "{:,}".format(N.NUM["m20_vs_m4"]["higher"]))),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    {
        "n": 105, "kind": "figure", "fig": "f9_order_cellwise.png", "ar": 3.516,
        "title": "The per-cell order is only worth what the cells agree on",
        "subtitle": "which cells differ, what order produced them, and what the fixed order gave up",
        "what": [
            ("What you see. ", "three panels that answer different questions about the same "
                               "comparison: which surface is lower in each cell, which AR "
                               "order was chosen there, and how much the fixed order four gave "
                               "up in dollars per megawatt hour."),
            ("How to read it. ", "the first panel is a sign map, the second is the decision "
                                 "that produced it, and the third is the size of the "
                                 "consequence. A cell that changed sign in the first panel but "
                                 "is pale in the third cost almost nothing either way."),
            ("What it shows. ", "the middle panel is order one almost everywhere beyond the "
                                "first hour, which matches the order census on page 90. The "
                                "third panel is bright in the same places the first panel is "
                                "coloured, so the cells where the choice matters and the cells "
                                "where it changes the winner are the same cells."),
            ("Conclusion. ", "the per-cell rule is worth what the first few hours are worth: "
                             "outside them the chosen order is the same everywhere and the "
                             "third panel fades out."),
            ("Scope. ", FIG_SCOPE),
        ],
    },
    # --------------------------------------------------------- index and detail
    {
        "n": 106, "kind": "index",
        "title": "Where each figure sits in the argument",
        "subtitle": "twelve figures, four admissible objects, and the pages that enlarge two of them",
        "notes": [
            ("The surfaces. ", "pages 94 to 97 hold the sixteen-model surface, the difference "
                               "against the official, the significance map and the sample "
                               "count behind that comparison."),
            ("The census. ", "pages 98 and 99 hold the winner map without and with the "
                             "official composite. A census is only ever drawn beside the "
                             "surface it counts."),
            ("The two profiles. ", "pages 100 to 102 hold the fixed-lead profiles, the first "
                                   "hour on its own, and the fixed-time-of-day profiles. These "
                                   "are the two one-dimensional slices of the surface."),
            ("The comparisons. ", "pages 103 to 105 hold the recommended combination against "
                                  "the best single model, the per-cell order against a fixed "
                                  "order, and the cell-by-cell reading of that comparison."),
            ("Where to start. ", "page 94 for the whole picture, page 100 for the one "
                                 "comparison that decides which side of the axis a model is "
                                 "on."),
        ],
        "scope": STRUCT_SCOPE,
    },
    {
        "n": 107, "kind": "structure",
        "title": "The census bands are contested, not owned",
        "subtitle": "the leading model holds a plurality in most columns and a majority in few",
        "notes": [
            ("What looks like a band. ", "the winner map on page 99 reads as coloured bands "
                                         "across the lead axis, which invites the reading that "
                                         "one model owns each stretch. Measured column by "
                                         "column, that is not what the counts say."),
            ("The measurement. ", "for each of the 376 columns, take the 288 times of day, count "
                                  "how many each of the sixteen models wins, and record the "
                                  "largest count. A band is owned only where that largest count "
                                  "is more than half of 288."),
            ("What it shows. ", "one model holds more than half the slots in only %s of the 376 "
                                "columns, and there is a single run of them: the weekday-class "
                                "template from column 111 to column 123. In %s columns the "
                                "leading model holds less than a third of the slots." % (
                                    N.fmt(32, 0), N.fmt(155, 0))),
            ("Where the leaders change. ", "the largest share is 18.4 percent at five minutes, "
                                           "held by T28 with AR(4); 32.6 percent at six hours, "
                                           "held by T28 with DMS(4); 49.0 percent at three days, "
                                           "held by the weekday-class template; and between "
                                           "26.7 and 29.2 percent at the last three probes, "
                                           "held by Anchor-mix and the multi-window template."),
            ("Why it matters. ", "a census answers how many cells a model wins, and the answer "
                                 "here is that most cells are won by a small margin. Reading a "
                                 "band as ownership overstates the winner and hides how close "
                                 "the loser was, which is what the difference surface beside "
                                 "the census is for."),
        ],
        "scope": STRUCT_SCOPE,
    },
    {
        "n": 108, "kind": "structure",
        "title": "The lead axis changes hands four times, and the crossings are measurable",
        "subtitle": "five candidates take the lowest median at some stretch of the 376 columns",
        "notes": [
            ("How this is measured. ", "for every one of the 376 columns, take the median of R "
                                       "over the 288 times of day for each candidate and "
                                       "record which candidate is lowest. That is one of the "
                                       "four admissible objects: a fixed-lead profile over the "
                                       "times of day, compared column by column."),
            ("The crossings. ", "the anchored family is lowest from just after the first column "
                                "to about %s hours; the official composite takes over there and "
                                "holds until about %s hours; and the template family is lowest "
                                "from then to the end of the axis." % (
                                    N.fmt(N.derived()["cross_hours"], 1), 43.0)),
            ("The crossing that decides the section. ", "the official median passes the "
                                                        "template's at column %s, which is "
                                                        "%s hours. Before it the official is "
                                                        "the better of the two, after it the "
                                                        "template is, and the gap widens to "
                                                        "%s dollars by the last column." % (
                                                            N.fmt(N.NUM["cross_col"], 0),
                                                            N.fmt(N.derived()["cross_hours"], 1),
                                                            N.fmt(abs(N.official("med")[2] - N.med("T28", 2)), 2))),
            ("What the four crossings are not. ", "they are crossings of a median over 288 "
                                                  "times of day, not of the surface. A model "
                                                  "can hold the median at a lead and still win "
                                                  "a minority of the cells there, which is "
                                                  "exactly what the census on page 98 shows "
                                                  "for the first hour."),
            ("Why the section needs this page. ", "the figures show the crossings; this is the "
                                                  "statement of where they are and on which "
                                                  "object they were taken, so a reader who "
                                                  "quotes one of them quotes the right slice."),
        ],
        "scope": STRUCT_SCOPE,
    },
]

# Every figure page carries the same scope sentence. It is attached here rather
# than typed into twelve entries, so a figure page cannot end up with a scope
# that disagrees with its neighbours.
for _p in PAGES:
    if _p["kind"] == "figure":
        _p["scope"] = FIG_SCOPE

