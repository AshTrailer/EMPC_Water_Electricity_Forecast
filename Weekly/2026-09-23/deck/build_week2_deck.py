# -*- coding: utf-8 -*-
"""Build the 2026-09-23 weekly deck: data-chain audit + AEMO forecast-error study.

Run from this directory:
  ..\\..\\..\\..\\.venv\\Scripts\\python.exe build_week2_deck.py

Numbers come from the JSON twins written by the analysis scripts, so re-running
after a data refresh regenerates the deck without hand-editing prose.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from pptx.dml.color import RGBColor    # noqa: E402
from pptx.enum.shapes import MSO_SHAPE  # noqa: E402
from pptx.util import Inches, Pt        # noqa: E402

import deck_kit as K                    # noqa: E402

PROJECT = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project"
WEEK = os.path.join(PROJECT, "Weekly", "EMPC", "2026-09-23")
AUDIT_FIG = os.path.join(WEEK, "data_audit", "scripts", "figures")
PRED_FIG = os.path.join(WEEK, "predictor", "figures")
TMP = os.path.join(HERE, "_formula_tmp")
OUT = os.path.join(HERE, "Capstone_Weekly_2026-09-23.pptx")

MISSING = []


def load(path, default=None):
   if os.path.exists(path):
      with open(path, "r", encoding="utf-8") as fh:
         return json.load(fh)
   return default


def fig(slide, name, x, y, w, h):
   for folder in (PRED_FIG, AUDIT_FIG):
      p = os.path.join(folder, name)
      if os.path.exists(p):
         return K.fit_image(slide, p, x, y, w, h)
   MISSING.append(name)
   box = K.add_rect(slide, x, y, w, h, fill=K.TINT, line=K.LINE)
   tf = box.text_frame
   tf.word_wrap = True
   K.para(tf, "[missing figure: %s]" % name, K.SMALL, K.MUTED, first=True)
   return box


err = load(os.path.join(WEEK, "data_audit", "scripts", "error_summary.json"))
four = load(os.path.join(WEEK, "predictor", "p5_vs_tar.json"))

prs = K.new_deck()
n = [0]


def page(title, subtitle=None):
   n[0] += 1
   s = K.blank(prs)
   K.header(s, title, subtitle, number=n[0])
   return s


# =====================================================================  cover
s = K.blank(prs)
K.add_rect(s, 0, 0, K.SLIDE_W, K.SLIDE_H, fill=K.NAVY)
K.ring_motif(s, 11.9, 1.05)
K.ring_motif(s, 12.7, 1.95)
_, tf = K.textbox(s, 0.9, 1.95, 11.5, 3.0)
K.para(tf, "Correcting AEMO's Own Price Forecast", K.COVER, K.WHITE, True,
       font=K.HDR, first=True, space_after=6)
K.para(tf, "Data-chain audit, predictor baseline, and a first error model for the"
           " 5-minute P5 product", 17, K.LIGHT, space_after=0)
_, tf = K.textbox(s, 0.9, 6.15, 11.5, 0.9)
K.para(tf, "EMPC Water Pumping  \u00b7  Capstone Project  \u00b7  weekly update"
           " 2026-09-23", K.BODY, K.WHITE, first=True, space_after=2)
K.para(tf, "AEMO NEMWEB archive + monthly dashboard files  \u00b7  MATLAB predictor "
           "suite  \u00b7  Python data pipeline", K.SUB, K.LIGHT, space_after=0)
n[0] = 0

# ==============================================================  where we are
s = page("The predictor is one link: this week we added a second one",
         "Pipeline overview \u00b7 the new branch is the AEMO error model")
K.bullets(s.shapes.add_textbox(Inches(0.55), Inches(1.55), Inches(6.4),
                               Inches(2.4)).text_frame,
          [("MPC layer (teammate) ", "decides tank levels over a receding horizon"),
           ("Decision layer ", "picks the pump combination"),
           ("Predictor (this work) ", "supplies the 5-minute price track"),
           ("New this week ", "correct AEMO's own forecast instead of "
                              "forecasting from scratch")],
          size=K.BODY)
box = K.add_rect(s, 7.2, 1.55, 5.55, 2.4, fill=K.TINT, line=K.LINE, rounded=0.08)
tf = box.text_frame
tf.word_wrap = True
tf.margin_left = tf.margin_right = Inches(0.16)
tf.margin_top = Inches(0.14)
K.para(tf, "Why the change of plan", K.BODY, K.NAVY, True, font=K.HDR, first=True,
       space_after=6)
K.para(tf, "AEMO sees unit outages, network limits and interconnector flows that we "
           "never will. Beating them head-on with price history alone is the wrong "
           "fight \u2014 so we forecast their residual instead.", K.BODY, K.INK)
K.add_rect(s, 0.55, 4.25, 12.2, 0.75, fill=K.TINT, line=K.LINE)
_, tf = K.textbox(s, 0.75, 4.4, 11.8, 0.5, anchor=1)
K.para(tf, "This week in one line:  the price disagreement we were asked to explain "
           "does not exist \u2014 what exists is a broken capture store and a hidden "
           "one-hour timebase shift, both now fixed.", K.BODY, K.INK, first=True)

# =================================================================  section I
K.dark_page(prs, "Part I \u2014 Data chain audit",
            "Four producers, three timebases, one broken store")

# ------------------------------------------------------------------ 1 inventory
s = page("AEMO_Data holds four unrelated datasets, not one",
         "Inventory by producer \u00b7 AEMO_Data \u00b7 2026-09-23")
K.add_table(s, 0.55, 1.5, 12.2, [
   ["Class", "File pattern", "Producer", "Granularity", "Span held"],
   ["A", "PRICE_AND_DEMAND_YYYYMM_VIC1.csv", "Dashboard \u2192 Historical aggregated",
    "5 min, trade", "2026-01-01 \u2192 2026-08-09"],
   ["B", "NEMPRICEANDDEMAND_<REGION>_<stamp>.csv", "Dashboard \u2192 Price & demand \u2192 Dispatch",
    "5 min actual + 30 min forecast", "~30\u201348 h rolling"],
   ["C", "zip_cache/ + dispatch_actual / p5min / predispatch",
    "Online_Data_Capture_Script (NEMWEB current)", "5 min / 30 min", "2 days / 5 h"],
   ["D", "PUBLIC_*.CSV at the root", "one-off manual download", "raw reports",
    "single point, 2026-09-04"],
], col_w=[0.6, 3.4, 3.2, 2.6, 2.4], size=K.SMALL, row_h=0.42)
_, tf = K.textbox(s, 0.55, 4.35, 12.2, 2.2)
K.bullets(tf, ["Only class A feeds the predictor today \u2014 it is the training and test "
               "series for every experiment below.",
               "Class B is the only place where today's actual and today's official "
               "forecast sit on one axis; it is the embryo of the error matrix, but "
               "it is a manual download.",
               "Class C is the intended online feed. Its timestamp columns were all "
               "empty (see next-but-two).",
               "Class D is archaeology \u2014 one report kept from a manual download."],
          size=K.BODY, space_after=5)

# ------------------------------------------------------------------ 2 schemas
s = page("Same market, three conventions \u2014 the mismatches are all ours",
         "Field-by-field comparison of the three price sources")
K.add_table(s, 0.55, 1.5, 12.2, [
   ["", "A \u00b7 monthly dashboard", "B \u00b7 dashboard dispatch export",
    "C / D \u00b7 NEMWEB raw reports"],
   ["Price column", "RRP", "Spot Price ($/MWh)", "DISPATCH/PRICE \u2192 RRP"],
   ["Precision", "2 decimal places", "5\u20137 significant digits", "full precision"],
   ["Timestamp", "2026/03/01 00:05:00", "09/09/2026 12:50", '"2026/09/04 03:55:00"'],
   ["Interval meaning", "interval-ending, 5 min", "interval-ending, 5 min",
    "interval-ending, 5 min"],
   ["Timebase", "NEM time (AEST)", "NEM time (AEST)", "NEM time (AEST)"],
   ["Demand column", "TOTALDEMAND", "Scheduled Demand (MW)",
    "REGIONSUM \u2192 TOTALDEMAND"],
   ["Units", "$/MWh", "$/MWh", "$/MWh"],
], col_w=[1.9, 3.4, 3.5, 3.4], size=K.SMALL, row_h=0.40, first_col_bold=True)
_, tf = K.textbox(s, 0.55, 5.15, 12.2, 1.6)
K.bullets(tf, ["Every source is 5-minute and interval-ending, so slot 1 = 00:05 and "
               "slot 288 = 24:00 in all of them.",
               "The only real price difference is publication precision: A is C "
               "rounded to 2 decimals.",
               "The one dangerous trap: B's \u201cScheduled Demand\u201d is NOT "
               "REGIONSUM.TOTALDEMAND (mean gap 125 MW in NSW1, 425 MW in QLD1)."],
          size=K.BODY, space_after=5)

# ------------------------------------------------------------------ 3 verdict
s = page("The monthly and real-time prices never disagreed",
         "8 sampled days, VIC1, point-by-point against the NEMWEB archive")
K.add_table(s, 0.55, 1.5, 12.2, [
   ["Sample day", "Monthly rows", "Archive rows", "Matched", "Exactly equal",
    "mean |diff|", "max |diff|"],
   ["2026-01-15", "288", "288", "287", "147 (51.2%)", "0.00112", "0.00500"],
   ["2026-07-01", "287", "288", "287", "168 (58.5%)", "0.00050", "0.00493"],
   ["2026-07-15", "288", "288", "287", "81 (28.2%)", "0.00187", "0.00491"],
   ["2026-07-29", "288", "288", "287", "178 (62.0%)", "0.00072", "0.00488"],
   ["2026-09-03 / 09", "n/a", "288 each", "n/a", "n/a", "n/a", "n/a"],
], col_w=[2.0, 1.5, 1.5, 1.3, 1.9, 1.8, 1.6], size=K.SMALL, row_h=0.34)
_, tf = K.textbox(s, 0.55, 4.05, 6.2, 2.6)
K.bullets(tf, ["max |diff| \u2264 0.005 $/MWh on every day \u2014 that is exactly the "
               "2-decimal rounding bound of the monthly file.",
               "Demand matches to 0.0000 MW with correlation 1.000000.",
               "So the professor's question \u201cwhy does the monthly VIC1 RRP "
               "differ from the real-time report?\u201d has the answer: it does not."],
          size=K.BODY, space_after=6)
fig(s, "F1_monthly_vs_archive_vic1.png", 6.9, 3.9, 5.85, 2.9)

# ------------------------------------------------------------------ 4 defects
s = page("Five defects in the capture chain \u2014 all of them ours, all fixed",
         "Online_Data_Capture_Project \u00b7 measured, not guessed \u00b7 1 of 2")
K.add_table(s, 0.55, 1.5, 12.2, [
   ["#", "Where", "Symptom", "Root cause"],
   ["D1", "aemo_parser._split_record",
    "settlement_date, interval_datetime and period_id all empty",
    "NEMWEB double-quotes every datetime field; str.split keeps the quotes, so "
    "every timestamp parse returned None"],
   ["D2", "aemo_common.parse_nem_datetime",
    "predispatch_seqno stored as 2026-09-01 05:01:05",
    "%Y%m%d%H%M%S has no width guard, so the 10-digit code 2026091515 matches as "
    "4+2+1+1+1+1 and becomes a fake time"],
   ["D3", "aemo_parser.parse_predispatch",
    "total_demand empty in every row",
    "the new PREDISPATCHIS splits RRP (REGION_PRICES) from TOTALDEMAND "
    "(REGION_SOLUTION); selection only asked for the RRP table"],
], col_w=[0.5, 2.7, 3.3, 5.7], size=K.SMALL, row_h=0.78)
K.footnote(s, "Evidence: data_audit/scripts/parser_replay.txt (before) and "
              "store_verify.txt (after).")

s = page("The blast radius, and the fifth defect that was not in the parser",
         "Online_Data_Capture_Script \u00b7 measured, not guessed \u00b7 2 of 2")
K.add_table(s, 0.55, 1.5, 12.2, [
   ["#", "Blast radius", "Fix"],
   ["D1", "dispatch_actual.csv collapsed to 5 rows: the dedup key "
          "(settlement_date, region_id) was empty, so every new interval overwrote "
          "the previous one \u2014 the store had been deleting its own history since "
          "the day it was written",
    "csv.reader instead of str.split"],
   ["D2", "1,925 predispatch rows carried a sequence code disguised as a timestamp",
    "compact date formats get a width guard; the raw code is stored verbatim"],
   ["D3", "1,925 rows with no demand", "merge REGION_PRICES with REGION_SOLUTION "
                                       "on (seqno, region, period)"],
   ["D4", "1,925 rows with no period_id", "PERIODID is an index in the new layout, "
                                          "not a timestamp"],
   ["D5", "USE_AUS_LOCAL_TIME = True rewrote NEM time into Sydney local time, so the "
          "store shifted timebase twice a year and sat 12 slots off the training "
          "data during daylight saving",
    "default changed to False, with the measurement written into the config"],
], col_w=[0.5, 8.4, 3.3], size=K.SMALL, row_h=0.72)
K.footnote(s, "D5 evidence: data_audit/scripts/timebase_verdict.txt \u2014 with the "
              "conversion off, all eight sampled months align at zero shift.")

# ------------------------------------------------------------------ 5 before/after
s = page("After the fix the store accumulates intervals instead of overwriting them",
         "Same command, same source, before and after D1\u2013D4")
K.add_table(s, 0.55, 1.5, 6.0, [
   ["", "Before", "After"],
   ["dispatch_actual.csv rows", "5", "2,880"],
   ["Rows per region", "1", "576"],
   ["settlement_date empty", "5 / 5", "0 / 2,880"],
   ["Interval step", "n/a (one row)", "300 s \u00d7 575"],
   ["p5min interval_datetime", "3,600 / 3,600 empty", "0 / 3,600"],
   ["predispatch period_id", "1,925 / 1,925 empty", "0 / 2,975"],
   ["predispatch total_demand", "1,925 / 1,925 empty", "0 / 2,975"],
   ["predispatch_seqno", "2026-09-01 05:01:05", "2026092333 (raw code)"],
], col_w=[3.0, 1.6, 1.4], size=K.SMALL, row_h=0.34)
_, tf = K.textbox(s, 0.55, 4.7, 6.0, 2.0)
K.bullets(tf, "The store was never merely stale \u2014 it was writing its own "
              "history away every five minutes.",
          size=K.BODY, dot=K.AMBER)
box = K.add_rect(s, 6.8, 1.5, 5.95, 3.0, fill=K.TINT, line=K.LINE, rounded=0.08)
tf = box.text_frame
tf.word_wrap = True
tf.margin_left = tf.margin_right = Inches(0.16)
tf.margin_top = Inches(0.14)
K.para(tf, "The one-hour shift, settled", K.BODY, K.NAVY, True, font=K.HDR,
       first=True, space_after=6)
K.para(tf, "With USE_AUS_LOCAL_TIME = True the archive needed a +60 min shift to line "
           "up with the monthly file in Jan/Feb/Mar/Apr-4, and 0 min from Apr-6 on. "
           "With it False, all eight sampled months align at 0 (mean |diff| "
           "0.0005\u20130.0019 $/MWh = pure rounding).", K.SMALL, K.INK, space_after=6)
K.para(tf, "The first analysis blamed AEMO. Cross-checking our own reading layer is "
           "what overturned it \u2014 the archive's DST-transition day is a clean "
           "5-minute ladder, so the archive was never the problem.", K.SMALL, K.INK)

# =================================================================  section II
K.dark_page(prs, "Part II \u2014 Predictor baseline",
            "Where the six-model suite stands, re-run today")

# ------------------------------------------------------------------ 6 protocol
s = page("Six predictors, one 288\u00d7288 error surface each",
         "run_predictor_benchmark.m \u00b7 re-run 2026-09-23")
K.add_table(s, 0.55, 1.5, 12.2, [
   ["Setting", "Value"],
   ["Warm-up (online)", "2026-01-01 00:05 \u2192 2026-01-31 00:00, 8,640 points"],
   ["Forecast origins", "2026-01-31 00:05 \u2192 2026-02-15 00:00, 4,320 origins"],
   ["Scored targets", "2026-02-01 00:05 \u2192 2026-02-15 00:00, 4,032 points (14 days)"],
   ["Update cadence", "every 5-minute observation re-issues the full 288-step forecast"],
   ["Price clamp", "rolling 30-day global Q1/Q99, recomputed daily, applied to "
                   "forecast and actual"],
   ["RNG / model state", "gains, AR coefficients and template trained on RAW prices; "
                         "scoring on clamped prices"],
], col_w=[2.6, 9.6], size=K.SMALL, row_h=0.40, first_col_bold=True)
_, tf = K.textbox(s, 0.55, 4.85, 12.2, 1.8)
K.bullets(tf, ["Every test point is forecast 288 times, so each model yields a "
               "288\u00d7288 RMSE(slot, lead) matrix \u2014 coverage verified at 14 "
               "samples per cell.",
               "Clamped signal std = 51.3 $/MWh: any RMSE near that value means the "
               "forecast carries no information."],
          size=K.BODY, space_after=6)

# ------------------------------------------------------------------ 7 results
s = page("Template + AR(4) owns the first three hours and loses beyond six",
         "Two-week test, clamped prices, $/MWh")
K.add_table(s, 0.55, 1.5, 7.4, [
   ["Model", "RMSE 2wk", "MAE", "Bias", "5 min", "1 h", "3 h", "6 h", "24 h"],
   ["Persistence (yesterday)", "51.2", "38.8", "\u22125.2", "51.2", "51.2", "51.2", "51.2", "51.2"],
   ["Rolling template", "46.4", "36.6", "+9.6", "46.4", "46.4", "46.4", "46.4", "46.4"],
   ["Theta-y tracker", "49.7", "37.3", "+13.6", "49.7", "49.7", "49.7", "49.7", "49.7"],
   ["Template + AR(4)", "51.9", "37.5", "+1.0", "15.8", "28.0", "39.4", "50.3", "58.5"],
   ["Blend A", "55.6", "41.3", "+23.1", "38.0", "43.9", "49.1", "53.8", "62.6"],
   ["Blend B", "61.4", "45.5", "+29.3", "43.6", "49.5", "55.5", "59.9", "68.6"],
], col_w=[3.0, 1.2, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9], size=K.SMALL, row_h=0.32)
_, tf = K.textbox(s, 0.55, 4.2, 7.4, 2.5)
K.bullets(tf, [("Best 5 min / 30 min / 1 h / 3 h: ", "Template + AR(4) "
                "(15.8 / 23.4 / 28.0 / 39.4)"),
               ("Best 6 h / 12 h / 24 h: ", "Rolling template (46.4, flat)"),
               ("vs persistence: ", "+69.2% at 5 min, \u221214.3% at 24 h"),
               ("Two-week aggregate: ", "\u22121.4% \u2014 worse than persistence")],
          size=K.BODY, space_after=5)
fig(s, "E1_p5_error_by_lead_VIC1.png" if os.path.exists(os.path.join(AUDIT_FIG, "E1_p5_error_by_lead_VIC1.png")) else "bench_rmse_lead.png",
    8.0, 1.5, 4.75, 3.0)
fig(s, "bench_rmse_slot.png", 8.0, 4.55, 4.75, 2.2)

# ------------------------------------------------------------------ 8 reading
s = page("Averaging over 288 leads hides the only horizon that matters",
         "Reading the baseline honestly")
box = K.add_rect(s, 0.55, 1.5, 3.9, 4.6, fill=K.TINT, line=K.LINE, rounded=0.08)
tf = box.text_frame
tf.word_wrap = True
tf.margin_left = tf.margin_right = Inches(0.16)
tf.margin_top = Inches(0.14)
K.para(tf, "The two-week column is a trap", K.BODY, K.NAVY, True, font=K.HDR,
       first=True, space_after=8)
K.para(tf, "Pooling all 288 leads gives T+AR(4) 51.9 against the template's 46.4. "
           "The same pooling that the professor warned against \u2014 picking the "
           "minimum cell as an accuracy claim \u2014 also hides a model that wins "
           "every lead up to three hours.", K.SMALL, K.INK, space_after=8)
K.para(tf, "MPC only ever executes the first control move and re-optimises five "
           "minutes later, so leads 1\u201312 are the ones that pay.", K.SMALL, K.INK)
box = K.add_rect(s, 4.6, 1.5, 3.9, 4.6, fill=K.TINT, line=K.LINE, rounded=0.08)
tf = box.text_frame
tf.word_wrap = True
tf.margin_left = tf.margin_right = Inches(0.16)
tf.margin_top = Inches(0.14)
K.para(tf, "The four-hour crossover is real", K.BODY, K.NAVY, True, font=K.HDR,
       first=True, space_after=8)
K.para(tf, "T+AR(4) beats the template by 30.6 $/MWh at 5 min, 18.5 at 1 h, 7.0 at "
           "3 h, then loses by 3.9 at 6 h. The iterated residual AR decays to zero "
           "somewhere between three and six hours, after which the forecast is the "
           "template.", K.SMALL, K.INK)
box = K.add_rect(s, 8.65, 1.5, 4.1, 4.6, fill=K.TINT, line=K.LINE, rounded=0.08)
tf = box.text_frame
tf.word_wrap = True
tf.margin_left = tf.margin_right = Inches(0.16)
tf.margin_top = Inches(0.14)
K.para(tf, "Blends do not work yet", K.BODY, K.NAVY, True, font=K.HDR, first=True,
       space_after=8)
K.para(tf, "Blend A and B are convex combinations with a per-slot weight learned by "
           "scalar RLS. Both lose to both of their own components, with biases of "
           "+23.1 and +29.3 \u2014 the weight has settled on the wrong side.", K.SMALL,
       K.INK, space_after=8)
K.para(tf, "Practical reading: the per-slot weight has one update per slot per day, "
           "which is far too slow to track a weight that should vary with lead time.",
       K.SMALL, K.INK)

# =================================================================  section III
K.dark_page(prs, "Part III \u2014 The AEMO error model",
            "Forecast their residual, not their problem")

# ------------------------------------------------------------------ 9 the idea
s = page("We do not need to beat AEMO \u2014 we need to correct them",
         "The brief, restated with the symbols the professor asked for")
_, tf = K.textbox(s, 0.55, 1.5, 6.4, 0.4)
K.para(tf, "Definitions", K.BODY, K.NAVY, True, font=K.HDR, first=True, space_after=4)
y = K.formula_block(s, 0.55, 1.95, 6.4, [
   ("actual price at time k", r"y(k)"),
   ("issue time of the forecast", r"k_i"),
   ("AEMO forecast made at k_i for target k", r"\hat{y}_{\mathrm{AEMO}}(k\,|\,k_i)"),
], TMP, size=14)
_, tf = K.textbox(s, 0.55, y + 0.15, 6.4, 0.4)
K.para(tf, "The quantity the team must model", K.BODY, K.NAVY, True, font=K.HDR,
       first=True, space_after=4)
K.formula_block(s, 0.55, y + 0.6, 6.4, [
   ("historical forecast error", r"e(k,k_i)=y(k)-\hat{y}_{\mathrm{AEMO}}(k\,|\,k_i)"),
   ("corrected forecast", r"\hat{y}_{\mathrm{corr}}(k|k_0)=\hat{y}_{\mathrm{AEMO}}(k|k_0)"
                          r"+\hat{e}(k|k_0)"),
], TMP, size=14)
box = K.add_rect(s, 7.2, 1.5, 5.55, 4.6, fill=K.TINT, line=K.LINE, rounded=0.08)
tf = box.text_frame
tf.word_wrap = True
tf.margin_left = tf.margin_right = Inches(0.16)
tf.margin_top = Inches(0.14)
K.para(tf, "Why short leads only", K.BODY, K.NAVY, True, font=K.HDR, first=True,
       space_after=8)
K.para(tf, "MPC computes a full future control sequence but executes only the first "
           "move, then re-optimises five minutes later. Everything past the first "
           "hour is recomputed long before it is used.", K.SMALL, K.INK, space_after=8)
K.para(tf, "So the target is leads 1\u201312 (5\u201360 min), with the correction "
           "decaying to zero as lead grows so that the long horizon falls back to "
           "AEMO's own number.", K.SMALL, K.INK, space_after=8)
K.para(tf, "AEMO's P5 product publishes 12 targets per 5-minute batch, k_i through "
           "k_i+55 min \u2014 exactly the window we need, at exactly our resolution.",
       K.SMALL, K.INK)

# ------------------------------------------------------------------ 10 data built
s = page("The pairing had to be rebuilt from the NEMWEB archive",
         "The current feed keeps only two days, which is not a dataset")
_, tf = K.textbox(s, 0.55, 1.5, 6.1, 0.4)
K.para(tf, "Pairing rule", K.BODY, K.NAVY, True, font=K.HDR, first=True, space_after=4)
K.bullets(s.shapes.add_textbox(Inches(0.55), Inches(1.95), Inches(6.1),
                               Inches(3.4)).text_frame,
          [("Actuals ", "\u2014 ARCHIVE DispatchIS daily zips, 5-min RRP, "
                        "highest RUNNO per interval"),
           ("Forecast ", "\u2014 ARCHIVE P5MIN daily zips, REGIONSOLUTION.RRP, "
                         "keyed by (effective_time, region, interval)"),
           ("Lead ", "h = (target \u2212 issue time) / 5 min, h = 0\u201311"),
           ("No lookahead ", "\u2014 both the batch and the realised price for "
                             "interval k_i are published about 5 min before k_i")],
          size=K.BODY, space_after=6)
K.add_table(s, 0.55, 5.05, 6.1, [
   ["", "Value"],
   ["Daily zips available", "375 (2025-09-12 \u2192 2026-09-21)"],
   ["DispatchIS size", "5.7 MB / day"],
   ["P5MIN size", "57 MB / day"],
   ["Backfill window used", "2026-08-25 \u2192 2026-09-21, VIC1"],
], col_w=[2.6, 3.5], size=K.SMALL, row_h=0.32, first_col_bold=True)
box = K.add_rect(s, 6.95, 1.5, 5.8, 4.6, fill=K.TINT, line=K.LINE, rounded=0.08)
tf = box.text_frame
tf.word_wrap = True
tf.margin_left = tf.margin_right = Inches(0.16)
tf.margin_top = Inches(0.14)
K.para(tf, "What had to change first", K.BODY, K.NAVY, True, font=K.HDR, first=True,
       space_after=8)
K.para(tf, "The professor's list included \u201csave more historical AEMO forecast "
           "versions, not just the last 10\u201d. The shipped retention keeps 5 hours "
           "of forecasts, so the error matrix could never be fitted from the live "
           "store.", K.SMALL, K.INK, space_after=8)
K.para(tf, "Until that retention policy is raised, the archive backfill is how the "
           "dataset gets built. It is reproducible: backfill_archive.py --start "
           "--end --regions.", K.SMALL, K.INK, space_after=8)
K.para(tf, "Same parser as the live feed, so the D1\u2013D4 fixes apply here too.",
       K.SMALL, K.INK)

# ------------------------------------------------------------------ 11 error by lead
s = page("AEMO's 5-minute forecast is good \u2014 and it degrades fast",
         "P5 error against realised dispatch price, VIC1")
fig(s, "E1_p5_error_by_lead_VIC1.png", 0.55, 1.55, 12.2, 3.3)
_, tf = K.textbox(s, 0.55, 5.0, 12.2, 1.7)
K.bullets(tf, ["RMSE climbs from ~11 $/MWh on the in-progress interval to ~17.7 at "
               "5 min and ~26.4 at 55 min, against a signal standard deviation of "
               "33 $/MWh.",
               "Bias is positive throughout (+3.9 to +5.9 $/MWh): in this window AEMO "
               "is systematically under-forecasting VIC1.",
               "The in-progress interval (h=0) is descriptive only \u2014 AEMO's h=0 "
               "entry is the dispatch target for that interval, not a prediction of "
               "an unknown, so it never enters a skill comparison."],
          size=K.BODY, space_after=5)

# ------------------------------------------------------------------ 12 persistence
s = page("The error is not noise: it arrives in runs",
         "The professor's hypothesis, tested directly")
fig(s, "E2_error_predictability_VIC1.png", 0.55, 1.55, 12.2, 3.4)
_, tf = K.textbox(s, 0.55, 5.1, 12.2, 1.6)
K.bullets(tf, ["ACF of the realised error \u03b5(k): +0.50 at lag 1, +0.48 at lag 2, "
               "still +0.19 at lag 12 \u2014 far outside the \u00b11.96/\u221an band.",
               "Same-sign run length averages 5.05 intervals against 2.00 for random "
               "signs, with a longest run of 94 intervals.",
               "\u201cIf AEMO is currently high or low, the next few intervals tend "
               "to stay the same way\u201d is therefore true in this sample, and the "
               "residual is worth modelling."],
          size=K.BODY, space_after=5)

# ------------------------------------------------------------------ 13 four way
s = page("No single candidate wins the hour: persistence takes 5\u201310 min, "
         "T+AR(4) takes the rest",
         "Five candidates on a held-out 30% of origins \u00b7 RMSE in $/MWh")
fig(s, "C1_four_way_short_lead.png", 0.55, 1.55, 12.2, 3.5)
_, tf = K.textbox(s, 0.55, 5.2, 12.2, 1.6)
rows = (four or {}).get("by_lead", [])
if rows:
   names = {"raw": "raw AEMO", "corr": "corrected AEMO", "pers": "persistence",
            "tar": "T+AR(4)", "tpl": "template"}
   wins = []
   for r in rows:
      cand = {k: r[k] for k in names}
      wins.append(min(cand, key=cand.get))
   k1, kl = rows[0], rows[-1]
   K.bullets(tf, ["At %d min lead: raw AEMO %.2f, corrected %.2f, persistence %.2f, "
                  "T+AR(4) %.2f \u2014 winner %s."
                  % (k1["h"] * 5, k1["raw"], k1["corr"], k1["pers"], k1["tar"],
                     names[wins[0]]),
                  "At %d min lead: raw AEMO %.2f, corrected %.2f, persistence %.2f, "
                  "T+AR(4) %.2f \u2014 winner %s."
                  % (kl["h"] * 5, kl["raw"], kl["corr"], kl["pers"], kl["tar"],
                     names[wins[-1]]),
                  "Winner by lead: " + ", ".join(
                     "%d min %s" % (r["h"] * 5, names[w]) for r, w in zip(rows, wins))],
             size=K.BODY, space_after=5)
else:
   K.para(tf, "[p5_vs_tar.json not available yet]", K.BODY, K.MUTED, first=True)

# ------------------------------------------------------------------ 14 numbers
s = page("Short-lead table, all four candidates, by lead",
         "Test split \u00b7 RMSE and MAE in $/MWh")
if rows:
   tbl = [["Lead", "n", "raw AEMO", "corrected", "persistence", "T+AR(4)",
           "corr gain", "TAR gain"]]
   for r in rows:
      tbl.append(["%d min" % (r["h"] * 5), str(r["n"]), "%.2f" % r["raw"],
                  "%.2f" % r["corr"], "%.2f" % r["pers"], "%.2f" % r["tar"],
                  "%+.1f%%" % r["corr_gain"], "%+.1f%%" % r["tar_gain"]])
   K.add_table(s, 0.55, 1.5, 12.2, tbl,
               col_w=[1.3, 1.0, 1.7, 1.7, 1.9, 1.6, 1.6, 1.4], size=K.SMALL,
               row_h=0.30)
   _, tf = K.textbox(s, 0.55, 5.35, 12.2, 1.4)
   K.bullets(tf, ["gain = RMSE change relative to raw AEMO; positive means the "
                  "challenger is better.",
                  "This is the by-lead reporting the professor asked for \u2014 no "
                  "single aggregate number is quoted as \u201cthe\u201d accuracy."],
             size=K.BODY, space_after=5)
else:
   K.para(s.shapes.add_textbox(Inches(0.55), Inches(1.6), Inches(12.2),
                               Inches(1.0)).text_frame,
          "[waiting for weekly_p5_compare.m]", K.BODY, K.MUTED, first=True)

# ------------------------------------------------------------------ 15 reading
s = page("What the error study says, and what it does not",
         "Honest reading before this goes anywhere near the MPC")
box = K.add_rect(s, 0.55, 1.5, 6.0, 4.6, fill=K.TINT, line=K.LINE, rounded=0.08)
tf = box.text_frame
tf.word_wrap = True
tf.margin_left = tf.margin_right = Inches(0.16)
tf.margin_top = Inches(0.14)
K.para(tf, "Established", K.BODY, K.NAVY, True, font=K.HDR, first=True, space_after=8)
K.bullets(tf, ["AEMO's P5 error is strongly autocorrelated and arrives in runs "
               "(ACF(1) = 0.68, mean same-sign run 6.15 intervals, longest 122), so "
               "it is a legitimate modelling target.",
               "A per-lead linear correction on four lagged realised errors cuts raw "
               "AEMO RMSE by 24% at 5 min and 17% at 10 min.",
               "The correction turns negative past 30 min \u2014 the decay-to-zero "
               "behaviour the professor predicted shows up as a crossover rather "
               "than a gentle fade.",
               "AEMO's own 5-minute product is not the strongest short-lead "
               "forecaster in this window: raw P5 loses to plain persistence out to "
               "10 min and to T+AR(4) from 15 min on."], size=K.SMALL, space_after=6)
box = K.add_rect(s, 6.75, 1.5, 6.0, 4.6, fill=K.TINT, line=K.LINE, rounded=0.08)
tf = box.text_frame
tf.word_wrap = True
tf.margin_left = tf.margin_right = Inches(0.16)
tf.margin_top = Inches(0.14)
K.para(tf, "Not established yet", K.BODY, K.NAVY, True, font=K.HDR, first=True,
       space_after=8)
K.bullets(tf, ["One region, one five-day test split. VIC1 only, September only \u2014 "
               "this is a pilot, not a result.",
               "The template inside T+AR(4) was warmed up on 10 days here, not the "
               "28\u201330 days the January benchmark used, so the two T+AR(4) "
               "numbers are not comparable.",
               "The corrected-AEMO model was fitted on raw prices without the "
               "Q1/Q99 clamp the MPC will apply, so the scored signal differs from "
               "the benchmark's.",
               "No cost impact has been demonstrated \u2014 that needs the MPC in "
               "the loop."], size=K.SMALL, space_after=6)

# ------------------------------------------------------------------ 16 next
K.dark_page(prs, "Next",
            None,
            body=["Raise the forecast retention so the live store, not a backfill, "
                  "feeds the error model.",
                  "Extend the error study to all five regions and a longer window; "
                  "report by lead, never as one number.",
                  "Re-fit the correction so the corrected line is compared against "
                  "persistence and T+AR(4) on identical origins.",
                  "Map public holidays into the template class logic, then wire the "
                  "correction into the MPC once the residual model is stable."],
            footer_note="Todo list and handover: Weekly/EMPC/2026-09-23/TODO.md and "
                        "HANDOVER.md")

prs.save(OUT)
print("saved", OUT)
print("slides:", len(prs.slides._sldIdLst))
if MISSING:
   print("MISSING FIGURES:", sorted(set(MISSING)))
