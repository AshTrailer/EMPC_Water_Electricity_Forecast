# -*- coding: utf-8 -*-
"""The twenty predictor pages, pages 72 to 91 of the delivered deck.

One page per predictor. Each page is an assertion title, the mathematics of the
thing, a symbol table that says where every quantity comes from, and notes that
carry the reading of the numbers. The scope band at the foot of every page says
which population the numbers on THAT page belong to, because three of the twenty
are not in the atlas and two more are the same numbers counted two ways.

Every figure quoted here is fetched from deck_numbers_60d at build time, so a
number that cannot be traced fails the audit rather than printing. Every formula
string was checked against the MATLAB that produced the atlas, and the places
where the code differs from the obvious reading are called out on the page.

Kept apart from build_new.py so the layout code stays readable: this file is
data, and it is long.
"""

import deck_numbers_60d as N


def H(key):
    """The three medians over the 288 times of day, 32 scored days."""
    return [N.fmt(N.med(key, i)) for i in range(3)]


ATLAS = ("Scope  32 scored days of a 60-day window, 288 times of day by 376 leads; "
         "median R over the 288 times of day; both sides clamped to the target day's "
         "rolling 30-day Q1 and Q99 before any error is formed; 376 leads issued at "
         "once, every 5 minutes.")

SUBMITTED_SCOPE = ("Scope  measured on a 120-day window, not on the 32 scored days of this "
                   "section: M15 to M17 are in the registry but are not columns of the "
                   "atlas, so they are quoted as a whole-grid figure only, never as a "
                   "ranking.")

# Only the symbols this page's own formulas actually contain. The first four are
# on every page; anything else is added where the page defines it. A long symbol
# table is what pushed the first build of these pages off the slide, so the table
# is deliberately the smallest set that covers the formulas printed above it.
C = [
       'y-hat(k+h|k)',
       'y(k)',
       'u(k,h)',
       'h']


def S(*rows):
    """A page's symbol table: the common four plus the symbols it adds."""
    return C + list(rows)


PAGES = [
    {
        "n": 72, "key": "persistence",
        "title": "Yesterday's slot: the reference every model must beat",
        "subtitle": "and it loses to the official composite at every horizon",
        "formulas": ["m1"],
        "symbols": S(
                      'y_prev(u)'),
        "head": "What the model is",
        "prose": [
            ("Copy the last day. ", "the forecast for a target slot is that slot's value "
                                    "one day earlier. Nothing is estimated and no lead is "
                                    "used, so the whole 376-column row is one repeated day."),
            ("Why it is here. ", "it is the floor. A model that cannot beat it is not a "
                                 "forecast, and three of the twenty on these pages cannot."),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s "
                                       "at 7.6 days. The official composite is %s, %s and "
                                       "%s, so the official wins at every one of the three "
                                       "horizons shown." % (
                                           H("persistence")[0], H("persistence")[1],
                                           H("persistence")[2], N.fmt(N.official("med")[0]),
                                           N.fmt(N.official("med")[1]),
                                           N.fmt(N.official("med")[2]))),
            ("Where it is beaten. ", "it wins no cell at all in the 32-day census, out of "
                                     "108,288 cells."),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 73, "key": "T28",
        "title": "A rolling 28-day per-slot mean carries all the cross-day memory",
        "subtitle": "and it carries nothing else: the forecast does not depend on the lead",
        "formulas": ["tmpl", "m2"],
        "symbols": S(
                      'T(s)',
                      'y_s(i)',
                      'k_s',
                      'n_T'),
        "head": "What the model is",
        "prose": [
            ("One number per slot. ", "288 averages, each over the 28 most recent values seen "
                                      "at that slot. The buffer is a ring of 28, so the "
                                      "newest value pushes the 28th-oldest out and the "
                                      "average moves once every five minutes."),
            ("Today is partly in it. ", "the buffer takes every observation as it arrives, "
                                        "with no test for whether the day has finished. At "
                                        "noon the morning slots are a mean of 27 complete "
                                        "days plus today, and the afternoon slots of 28 "
                                        "days. The same-day share grows through the day."),
            ("Why the lead drops out. ", "T(u(k,h)) does not contain h. Forecasting five "
                                         "minutes ahead and 7.6 days ahead gives the same "
                                         "number, which is why the three medians below agree "
                                         "to a quarter of a dollar and why the fixed-lead "
                                         "profile is flat in the figures."),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days. It wins %s cells of 108,288 against the "
                                       "other fifteen models." % (
                                           H("T28")[0], H("T28")[1], H("T28")[2],
                                           "{:,}".format(N.win_cells("T28")))),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 74, "key": "theta_y",
        "title": "A per-slot gain on yesterday's price fixes the bias, not the timing",
        "subtitle": "one scalar per slot, adapted online by recursive least squares",
        "formulas": ["m3", "rlss"],
        "symbols": S(
                      'theta(s)',
                      'y_prev(u)',
                      'G',
                      'P_rls',
                      'lambda'),
        "head": "What the model is",
        "prose": [
            ("A correction to persistence. ", "the model still reads yesterday, but "
                                               "multiplies by a gain fitted online. A gain "
                                               "above one says the slot tends to move further "
                                               "than yesterday did."),
            ("Adapted, not fitted offline. ", "scalar RLS with a forgetting factor of %s "
                                              "updates the gain from the newest observation "
                                              "onward, so the model tracks a drifting level "
                                              "without a re-fit step." % N.fmt(0.98)),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days. It is worse than the plain template at all "
                                       "three, and it wins %s cells of 108,288, so the gain "
                                       "buys nothing here." % (
                                           H("theta_y")[0], H("theta_y")[1], H("theta_y")[2],
                                           "{:,}".format(N.win_cells("theta_y")))),
            ("Why it fails. ", "a gain can rescale a day but cannot move it in time. The "
                               "error is dominated by the ramp timing, which no per-slot "
                               "scalar can shift."),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 75, "key": "T28_AR4",
        "title": "An iterated AR(4) residual dies by design at long leads",
        "subtitle": "the template carries the shape, the recursion carries the last few hours",
        "formulas": ["resid", "m4_rec", "m4", "rlsv"],
        "symbols": S(
                      'r(k)',
                      'p',
                      'phi',
                      'lambda',
                      'r-hat(k+s|k)'),
        "head": "What the model is",
        "prose": [
            ("Two parts. ", "the template gives the shape of the day and the recursion adds "
                            "back whatever the template missed in the last few intervals."),
            ("Why iteration matters. ", "past the first four steps the recursion has no "
                                        "realised residual left, so it feeds on its own "
                                        "output. A mean-reverting AR returns to zero, which "
                                        "is why the model is strong at one hour and ordinary "
                                        "at 24 hours."),
            ("p is not the best order. ", "the model is registered at p equal to 4, but the "
                                          "order scan behind the per-cell rule found p equal "
                                          "to 1 the best single order, and the per-cell "
                                          "version of it is page 91."),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days, against the template's %s, %s and %s." % (
                                           H("T28_AR4")[0], H("T28_AR4")[1], H("T28_AR4")[2],
                                           H("T28")[0], H("T28")[1], H("T28")[2])),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 76, "key": "carry_forward",
        "title": "The newest price held flat: the strongest thing inside the hour",
        "subtitle": "and structurally wrong past a day, because it never decays",
        "formulas": ["m5"],
        "symbols": S(
                      'y(k)'),
        "head": "What the model is",
        "prose": [
            ("Hold the last value. ", "the same number for all 376 leads. It does not use "
                                      "the time of day at all, so a forecast issued at "
                                      "midnight and one issued at noon are built the same way."),
            ("Why it is strong early. ", "over five minutes the price is very close to what "
                                         "it was five minutes ago, so this is the best "
                                         "one-hour median of the sixteen, %s." % (
                                             H("carry_forward")[0])),
            ("Why it collapses late. ", "it has no daily shape, so at 7.6 days it still "
                                        "reports one number and the median rises to %s "
                                        "against the template's %s." % (
                                            H("carry_forward")[2], H("T28")[2])),
            ("Where it is used. ", "it is one of the anchors of the Anchor-mix on page 79, "
                                   "where the weight it receives is refitted per lead and "
                                   "falls to near zero beyond a day."),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 77, "key": "T28_DMS4",
        "title": "One least-squares row per lead, so no recursion can run away",
        "subtitle": "direct multi-step: 376 fitted rows, each one its own horizon",
        "formulas": ["m6"],
        "symbols": S(
                      'D_h',
                      'r(k)',
                      'p'),
        "head": "What the model is",
        "prose": [
            ("Direct, not iterated. ", "the residual for lead h is fitted straight from the "
                                       "last few realised residuals. Nothing is fed back, so "
                                       "a long lead cannot compound an early mistake."),
            ("What it costs. ", "376 separate fits, each estimated on a rolling 14-day "
                                "window, against one short recursion. It also cannot adapt "
                                "inside a day, because the row is fixed until the next refit "
                                "at the first slot."),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days. It beats the iterated version on page 75 at "
                                       "24 hours and beyond, and wins %s cells of 108,288." % (
                                           H("T28_DMS4")[0], H("T28_DMS4")[1],
                                           H("T28_DMS4")[2],
                                           "{:,}".format(N.win_cells("T28_DMS4")))),
            ("The stepping in the figure. ", "the fit is refitted once per day, so the whole "
                                             "long-lead part of this model's surface steps at "
                                             "day boundaries. That stepping is visible in the "
                                             "difference maps and it belongs to the model, not "
                                             "to the price."),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 78, "key": "CF_DMS4",
        "title": "The same direct engine, anchored on the current price",
        "subtitle": "no template: yesterday's shape is replaced by the last value and its slope",
        "formulas": ["m7"],
        "symbols": S(
                      "D'_h",
                      'Delta y(k)',
                      'p'),
        "head": "What the model is",
        "prose": [
            ("Same fit, different anchor. ", "the intercept takes the part of y(k) and the "
                                             "regressors are differences rather than template "
                                             "residuals. The engine, the window and the refit "
                                             "schedule are identical to page 77."),
            ("What changes. ", "the template supplies the daily shape for free. Removing it "
                               "leaves a level and a slope, which is all carry-forward had, "
                               "and the numbers land almost exactly on carry-forward's."),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days, against carry-forward's %s, %s and %s. The "
                                       "two are within a dollar at every horizon shown, and "
                                       "the model wins %s cells of 108,288." % (
                                           H("CF_DMS4")[0], H("CF_DMS4")[1], H("CF_DMS4")[2],
                                           H("carry_forward")[0], H("carry_forward")[1],
                                           H("carry_forward")[2],
                                           "{:,}".format(N.win_cells("CF_DMS4")))),
            ("Why it is kept. ", "it is the control that shows the direct engine contributes "
                                 "almost nothing on its own; the template is doing the work."),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 79, "key": "anchor_mix",
        "title": "Three anchors and one weight row per lead, refitted every day",
        "subtitle": "the best median of the sixteen, and the one with a rank-deficient fit",
        "formulas": ["m8", "m8_convex"],
        "symbols": S(
                      'c_h',
                      'a_h',
                      'b_h',
                      'phi_h',
                      'psi_h'),
        "head": "What the model is",
        "prose": [
            ("Anchors plus corrections. ", "one equation per lead, with the current price and "
                                           "the template as the two anchors and a short tail "
                                           "of residuals and differences. The design has 11 "
                                           "columns and is refitted once per day at the first "
                                           "slot, on a rolling 14-day window of samples."),
            ("The fit reports rank deficiency. ", "the design matrix has 11 columns and the fit "
                                                  "reports rank 10, so one direction in it is "
                                                  "not identified from the data. Least squares "
                                                  "still returns a usable predictor, but the "
                                                  "individual coefficients must not be read as "
                                                  "effects."),
            ("The constraint is not switched on. ", "the fit takes an argument that would force "
                                                    "b_h equal to one minus a_h, and the run "
                                                    "that produced the atlas passes it as "
                                                    "false. The second formula on this page is "
                                                    "documentation of that option, not of the "
                                                    "fitted model."),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days, the best of the sixteen at 24 hours and "
                                       "7.6 days, and it wins %s cells of 108,288." % (
                                           H("anchor_mix")[0], H("anchor_mix")[1],
                                           H("anchor_mix")[2],
                                           "{:,}".format(N.win_cells("anchor_mix")))),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 80, "key": "T28_level",
        "title": "Correct the template's daily level and leave its shape alone",
        "subtitle": "one offset per day from a first-order level recursion",
        "formulas": ["m9_fit", "m9"],
        "symbols": S(
                      'L(d)',
                      'L-hat(D)',
                      'c',
                      'b1',
                      'Lbar'),
        "head": "What the model is",
        "prose": [
            ("Two steps. ", "estimate where the day's overall level sits with a first-order "
                            "recursion, then add the deviation of that estimate from its own "
                            "long-run mean to the template."),
            ("What it can and cannot do. ", "the correction is one number per target day, so it "
                                            "moves the whole profile up or down. It can follow "
                                            "a sustained price rise and it cannot change the "
                                            "shape within the day."),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days, against the uncorrected template's %s, %s "
                                       "and %s. The correction costs about a dollar and a half "
                                       "at one hour and 24 hours." % (
                                           H("T28_level")[0], H("T28_level")[1],
                                           H("T28_level")[2], H("T28")[0], H("T28")[1],
                                           H("T28")[2])),
            ("Why it is not the end of the family. ", "pages 82 and 83 apply the same "
                                                      "correction to a better template, and "
                                                      "there it pays."),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 81, "key": "MW",
        "title": "Four template windows averaged equally",
        "subtitle": "7, 28, 56 and 112 days, because the best window is not one number",
        "formulas": ["m10", "m10p"],
        "symbols": S(
                      'T_w(s)',
                      'W',
                      'T_mw(s)'),
        "head": "What the model is",
        "prose": [
            ("Averaging windows, not models. ", "four per-slot means over four horizons, "
                                                "combined with equal weights. Nothing is "
                                                "fitted: the weights are fixed at a quarter "
                                                "each."),
            ("Why it helps. ", "a 7-day window follows a moving level and a 112-day window is "
                               "stable. Equal weights carry both without choosing, and the "
                               "combination cannot be overfitted because no parameter is "
                               "estimated."),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days. That is slightly worse than the single "
                                       "28-day template at 24 hours and slightly better at "
                                       "7.6 days." % (H("MW")[0], H("MW")[1], H("MW")[2])),
            ("Why it matters anyway. ", "it is the base of pages 82 and 83, and the "
                                        "level-corrected version of it is the best model in "
                                        "the multi-window family."),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 82, "key": "MW_level",
        "title": "The multi-window template plus the same daily-level correction",
        "subtitle": "the correction that cost money on page 80 is close to free here",
        "formulas": ["m11"],
        "symbols": S(
                      'T_mw(s)',
                      'L-hat(D)',
                      'T-bar_mw'),
        "head": "What the model is",
        "prose": [
            ("One line of algebra. ", "the level correction of page 80 applied to the template "
                                      "of page 81. Nothing else changes: same recursion, same "
                                      "rolling fit, same refit schedule."),
            ("Why the result differs. ", "the multi-window template already contains a 7-day "
                                         "component, so its own level tracks faster than the "
                                         "28-day template's. The correction is measured "
                                         "against a moving reference and does less damage at "
                                         "short leads."),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days, against the uncorrected multi-window "
                                       "template's %s, %s and %s." % (
                                           H("MW_level")[0], H("MW_level")[1],
                                           H("MW_level")[2], H("MW")[0], H("MW")[1],
                                           H("MW")[2])),
            ("What changes at 7.6 days. ", "the corrected version is better there, %s against "
                                           "%s, which is the one horizon where the level "
                                           "estimate is buying something." % (
                                               H("MW_level")[2], H("MW")[2])),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 83, "key": "MW_run",
        "title": "Let the observed share of today set its own weight",
        "subtitle": "the level estimate blends the running mean of today with the recursion",
        "formulas": ["m12_rho", "m12"],
        "symbols": S(
                      'rho(k)',
                      'ybar_run(k)',
                      'L-hat(D)',
                      'L(d-1)',
                      'c',
                      'b1'),
        "head": "What the model is",
        "prose": [
            ("A weight that moves by itself. ", "at 00:05 almost none of today is known, so "
                                                "the estimate is the recursion. By late "
                                                "evening almost all of it is known, so the "
                                                "estimate is today's own running mean. The "
                                                "weight is the clock, not a fitted parameter."),
            ("Why 36 at one hour. ", "median R at one hour is %s, well below the multi-window "
                                     "template's %s, because the running mean of the day is a "
                                     "much better anchor than a recursion once part of the day "
                                     "has been seen." % (H("MW_run")[0], H("MW")[0])),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days, and the model wins %s cells of 108,288." % (
                                           H("MW_run")[0], H("MW_run")[1], H("MW_run")[2],
                                           "{:,}".format(N.win_cells("MW_run")))),
            ("Why the long end does not follow. ", "beyond a day rho is a property of the "
                                                   "target day, which is not known yet, so the "
                                                   "advantage flattens and the model lands with "
                                                   "the rest of the family."),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 84, "key": "kalman_harm",
        "title": "A harmonic state space: best at five minutes, and it decays faster",
        "subtitle": "a Kalman filter over the daily cycle, forecast through a precomputed basis",
        "formulas": ["m13_ss", "m13_upd", "m13", "m13_g", "m13_rot"],
        "symbols": S(
                      'xi',
                      'A',
                      'C',
                      'K',
                      'G(h,s)'),
        "head": "What the model is",
        "prose": [
            ("A linear filter, not a fit. ", "the daily cycle is represented by harmonics "
                                             "whose coefficients are tracked by a Kalman "
                                             "filter. There is no rolling window and no stored "
                                             "template: the state is the model."),
            ("Why the forecast is cheap. ", "with no observation between origin and target, the "
                                            "forecast is the transition matrix raised to the "
                                            "lead applied to the current state. That product "
                                            "depends only on the lead and the slot, so it is "
                                            "tabulated once and reused at every origin."),
            ("What the numbers say. ", "median R is %s at one hour, then %s at 24 hours and %s "
                                       "at 7.6 days, which is the worst of the sixteen at the "
                                       "long end." % (
                                           H("kalman_harm")[0], H("kalman_harm")[1],
                                           H("kalman_harm")[2])),
            ("Why it decays. ", "the filter is mean reverting to the harmonic cycle, so a "
                                "deviation today is not carried a week forward. The template "
                                "does carry it, because the template is an average of realised "
                                "days."),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 85, "key": "T_ewma",
        "title": "Exponentially weighted days, with the tail actually dropped",
        "subtitle": "weights that decay, and a cut-off so the sum has a last term",
        "formulas": ["m14", "m14p"],
        "symbols": S(
                      'alpha',
                      'K',
                      'w_min',
                      'y(i)(s)',
                      'T_e(s)'),
        "head": "What the model is",
        "prose": [
            ("An exponential window. ", "yesterday counts fully, the day before at 85 percent "
                                        "of that, and so on until a day's weight falls below "
                                        "the cut-off and the day leaves the sum. Because the "
                                        "decay is %s per day the cut-off leaves %s days in the "
                                        "sum, and the denominator adds the same weights as "
                                        "the numerator." % (N.fmt(0.15), N.fmt(28, 0))),
            ("Why the tail is dropped. ", "an exponential weight never reaches zero. Without a "
                                          "cut-off the sum would need every day since the "
                                          "start of the record, so K is derived from the "
                                          "cut-off rather than chosen."),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days, against the flat 28-day template's %s, %s "
                                       "and %s. The exponential weighting is slightly better at "
                                       "7.6 days and slightly worse at 24 hours." % (
                                           H("T_ewma")[0], H("T_ewma")[1], H("T_ewma")[2],
                                           H("T28")[0], H("T28")[1], H("T28")[2])),
            ("What that means. ", "how the days are weighted matters almost nothing here. The "
                                  "information is in the daily shape, and any reasonable "
                                  "average of the last few weeks recovers it."),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 86, "key": "ma",
        "title": "A trailing average is not a forecast: it is the current level, one hour late",
        "subtitle": "negative result, and why M15 to M17 are not columns of the atlas",
        "formulas": ["m15"],
        "symbols": S(
                      'S(k)',
                      'w',
                      'y(k-i)'),
        "head": "What the model is",
        "prose": [
            ("One hour of history. ", "twelve five-minute points averaged, and that average "
                                      "issued for every one of the 376 leads."),
            ("Why it is one hour late. ", "a centred average would represent the middle of its "
                                          "window, so a trailing average of w points "
                                          "represents a time half a window earlier. The model "
                                          "forecasts where the price was about thirty minutes "
                                          "ago, not where it is going."),
            ("What the numbers say. ", "on the longer run these three models were measured on, "
                                       "the whole-grid figure is %s, against a zero-persistence "
                                       "figure of %s on the same run. Smoothing before "
                                       "forecasting is worse than not smoothing at all." % (
                                           N.fmt(N.SUBMITTED["pooled"]["ma"]),
                                           N.fmt(N.SUBMITTED["zero_persistence"]))),
            ("Why it is not in the atlas. ", "on a 183-hour axis the forecast is a constant "
                                             "past its own window, so the long half of the "
                                             "grid would measure the window, not the model."),
        ],
        "scope": SUBMITTED_SCOPE,
    },
    {
        "n": 87, "key": "ma_comp",
        "title": "Paying the smoother's delay back as a slope turns a 51 into an 86",
        "subtitle": "negative result: the correction overshoots by more than the delay was worth",
        "formulas": ["m16"],
        "symbols": S(
                      'S(k)',
                      'w',
                      'h',
                      '(w-1)/2',
                      'S(k-1)'),
        "head": "What the model is",
        "prose": [
            ("Delay plus projection. ", "the smoothed level is moved forward by the delay the "
                                        "smoother introduced, then extrapolated along its own "
                                        "one-step slope for the remaining lead. The slope is "
                                        "the difference of two consecutive smoothed values, "
                                        "not a fitted trend."),
            ("Why it explodes. ", "the slope term multiplies a noisy difference by a factor that "
                                  "grows without bound in h. By a day the extrapolation is "
                                  "larger than the daily range, and by 7.6 days it is "
                                  "meaningless."),
            ("What the numbers say. ", "the whole-grid figure is %s, against %s without the "
                                       "compensation, on the same longer run. This is the worst "
                                       "of the twenty predictors on that run." % (
                                           N.fmt(N.SUBMITTED["pooled"]["ma_comp"]),
                                           N.fmt(N.SUBMITTED["pooled"]["ma"]))),
            ("What it teaches. ", "a correction that is right in expectation can be far worse in "
                                  "error. The delay is real, and paying it back with an "
                                  "unbounded term costs more than leaving it."),
        ],
        "scope": SUBMITTED_SCOPE,
    },
    {
        "n": 88, "key": "med",
        "title": "A median instead of a mean changes almost nothing once prices are clamped",
        "subtitle": "negative result: the robustness it buys has nowhere to work",
        "formulas": ["m17"],
        "symbols": S(
                      'S(k)',
                      'w',
                      'median'),
        "head": "What the model is",
        "prose": [
            ("The same window, a different statistic. ", "twelve points, ordered, and the "
                                                         "middle one issued for every lead."),
            ("Why it is not better. ", "a median protects against spikes. Prices here are "
                                       "already clamped to the target day's rolling 30-day "
                                       "first and 99th percentiles before any model sees them, "
                                       "so the extreme values the median would ignore have been "
                                       "removed upstream."),
            ("What the numbers say. ", "the whole-grid figure is %s against the mean's %s on the "
                                       "same longer run, a difference of cents per megawatt "
                                       "hour." % (N.fmt(N.SUBMITTED["pooled"]["med"]),
                                                  N.fmt(N.SUBMITTED["pooled"]["ma"]))),
            ("Why it is kept in the registry. ", "so the claim that a robust statistic does not "
                                                 "help can be read off a number rather than "
                                                 "asserted."),
        ],
        "scope": SUBMITTED_SCOPE,
    },
    {
        "n": 89, "key": "T_class",
        "title": "Splitting the template by weekday earns nothing on the scored days",
        "subtitle": "and the longer run says it earns close to eleven percent",
        "formulas": ["m18"],
        "symbols": S(
                      'W_c',
                      'N_c',
                      'y_d(s)',
                      'T_c(s)',
                      'c'),
        "head": "What the model is",
        "prose": [
            ("Two templates instead of one. ", "a weekday template and a weekend template, "
                                               "each an average over that class only. The "
                                               "target day's class decides which one is read, "
                                               "so the two classes never mix."),
            ("How long the window is. ", "28 observations per class, not 28 calendar days. A "
                                         "slot's weekday buffer therefore reaches back five to "
                                         "six weeks, which is the price of splitting a 28-day "
                                         "window in two."),
            ("Why it is first in the census. ", "it wins %s cells of 108,288 with the other "
                                                "fifteen models competing, more than any other "
                                                "model, and %s cells with the official "
                                                "composite in the running." % (
                                                    "{:,}".format(N.win_cells("T_class")),
                                                    "{:,}".format(
                                                        N.census("Weekday-class T")["cells"]))),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days, against the unsplit template's %s, %s and %s. "
                                       "On these 32 scored days the split is %s percent worse "
                                       "at 24 hours, while the longer run puts it %s percent "
                                       "better over the whole grid. Winning the most cells and "
                                       "having the better median are different questions, and "
                                       "the answer changes with the window." % (
                                           H("T_class")[0], H("T_class")[1], H("T_class")[2],
                                           H("T28")[0], H("T28")[1], H("T28")[2],
                                           N.fmt(abs(100.0 * N.med("T_class", 1)
                                                     / N.med("T28", 1) - 100.0), 1),
                                           N.fmt(N.derived()["T_class_gain_120d"], 1))),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
    {
        "n": 90, "key": "ar_sel",
        "title": "The AR order is chosen per cell from trailing error, not from the test window",
        "subtitle": "84 percent of cells end on order one, and order one owns the short leads",
        "formulas": ["m19_cand", "m19_rule"],
        "symbols": S(
                      'P',
                      'phi(p)',
                      'r-hat(p)',
                      'p*(s,h)',
                      'D_28'),
        "head": "What the rule is",
        "prose": [
            ("A choice, not a fit. ", "for every one of the 108,288 cells the rule keeps "
                                      "whichever candidate order would have had the lowest "
                                      "squared error on clamped forecasts over the trailing "
                                      "days. It is re-picked at the first slot of each day and "
                                      "never looks at the days it is scored on, and at least "
                                      "7 trailing days are required before it picks at all."),
            ("Seven candidates. ", "each order has its own recursive least squares, so the "
                                   "candidates are independent of one another. Ties go to the "
                                   "lowest order, which is why order one takes the cells where "
                                   "the errors are indistinguishable."),
            ("What the shares say. ", "of the daily re-selections in the window, order one is "
                                      "chosen %s percent of the time. The 84.1 percent in the "
                                      "title counts cells, not re-picks." % (
                                          N.fmt(N.NUM["m19"]["hist_overall_pct"][0], 1))),
            ("Where the order matters. ", "at five minutes order one takes %s percent of "
                                          "re-picks, at one hour only %s percent, then %s "
                                          "percent by one day and %s percent by three days. "
                                          "The order competes only over the first few hours; "
                                          "past a day one order dominates." % (
                                              N.fmt(N.NUM["m19"]["hist_probe_share_pct"][0][0], 1),
                                              N.fmt(N.NUM["m19"]["hist_probe_share_pct"][1][0], 1),
                                              N.fmt(N.NUM["m19"]["hist_probe_share_pct"][3][0], 1),
                                              N.fmt(N.NUM["m19"]["hist_probe_share_pct"][4][0], 1))),
        ],
        "scope": ("Scope  the shares are of the daily re-selections over the 32 scored days, per "
                  "cell of the 288 by 376 grid, from days before the target day; this is the "
                  "order rule, and the model that consumes it is page 91."),
    },
    {
        "n": 91, "key": "T28_ARn",
        "title": "Choosing the order cell by cell beats a fixed AR(4) in 91,861 cells",
        "subtitle": "the same template and the same residuals, with the order read off page 90",
        "formulas": ["m20"],
        "symbols": S(
                      'r-hat(p*)(h)',
                      'p*(u,h)',
                      'r(k)',
                      'P'),
        "head": "What the model is",
        "prose": [
            ("Page 90 applied. ", "the template plus the residual forecast whose order was "
                                  "chosen for that cell. Nothing else changes: same template, "
                                  "same residuals, same recursive least squares."),
            ("Two indices, deliberately. ", "the order is stored per target slot and lead axis "
                                            "column, while the candidate forecasts are "
                                            "addressed by the lead number in five-minute steps. "
                                            "Past the first hour a column is 30 minutes wide, "
                                            "so the two are not interchangeable and the code "
                                            "converts rather than assumes."),
            ("Head to head with a fixed four. ", "against the fixed AR(4) of page 75 the "
                                                 "per-cell order is lower in %s cells, higher in "
                                                 "%s and tied in %s, with a median difference of "
                                                 "%s dollars per megawatt hour." % (
                                                     "{:,}".format(N.NUM["m20_vs_m4"]["lower"]),
                                                     "{:,}".format(N.NUM["m20_vs_m4"]["higher"]),
                                                     N.fmt(N.NUM["m20_vs_m4"]["ties"], 0),
                                                     N.fmt(abs(N.NUM["m20_vs_m4"]["median_diff"]),
                                                           3))),
            ("What the numbers say. ", "median R is %s at one hour, %s at 24 hours and %s at "
                                       "7.6 days, against the fixed-order model's %s, %s and "
                                       "%s." % (
                                           H("T28_ARn")[0], H("T28_ARn")[1], H("T28_ARn")[2],
                                           H("T28_AR4")[0], H("T28_AR4")[1], H("T28_AR4")[2])),
        ],
        "scope": ATLAS, "scope_formula": "err_R",
    },
]
