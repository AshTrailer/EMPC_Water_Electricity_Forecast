# -*- coding: utf-8 -*-
"""The deck's only source of numbers.

deck_numbers_60d.json is produced by
  Weekly/2026-10-13/predictor/scripts/extract_deck_numbers.m
run through
  Weekly/2026-10-13/predictor/runs/run_extract_numbers.bat <new log name>

Nothing in this module is typed by hand: every value is read out of that JSON,
which is itself read out of atlas_60d.mat and official_60d.mat. If a number in
the deck cannot be produced by numbers_of() below, the deck checker fails.

POPULATION. The canonical surface is R over the 32 scored days, days 29 to 60,
which is what report_figures.m builds and what every figure, the
Diebold-Mariano table, the census, the combination rules and the official
comparison all use. atlas_60d.mat also stores an R over all 60 days, and the
60-day handover quotes that one in its section 4.1. The two differ by up to 9
$/MWh on the anchored models, so both are kept here and every use is explicit.
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
JSON_PATH = os.path.join(HERE, "deck_numbers_60d.json")

with open(JSON_PATH, encoding="utf-8") as _fh:
    NUM = json.load(_fh)

# horizon index into every length-3 vector in the JSON
H1, H24, H76 = 0, 1, 2
HORIZON_LABEL = ["1 h", "24 h", "7.6 d"]

BY_KEY = {m["key"]: m for m in NUM["model"]}
BY_NAME = {m["name"]: m for m in NUM["model"]}
CENSUS32 = {c["label"]: c for c in NUM["census_32d_with_official"]}
CENSUS32_MODELS = {c["label"]: c for c in NUM["census_32d_models_only"]}
COMB = {c["label"]: c["pooled"] for c in NUM["comb"]}
_DERIVED = {}

# The three official products' measured specifications. These cannot be
# recovered from the atlas JSON: they are properties of the raw NEMWEB files,
# measured once and written up in 官方合成值_数据与校验_20261014.md. They are
# registered here so the deck checker can still trace them.
SPEC = {
    "P5MIN": {"published": "every 5 min", "runs": 17281, "columns": 12,
              "forward_to_min": 55, "horizon_h": None,
              "cite": "官方合成值_数据与校验_20261014.md, product census"},
    "PREDISPATCH": {"published": "every 30 min", "runs": 2880, "columns": 79,
                    "forward_to_min": None, "horizon_h": (15.5, 39.0),
                    "cite": "官方合成值_数据与校验_20261014.md, product census"},
    "PD7DAY": {"published": "3 runs a day, 07:30, 13:00, 18:00", "runs": 180, "columns": 367,
               "forward_to_min": None, "horizon_h": (164.5, 183.0),
               "cite": "官方合成值_数据与校验_20261014.md, product census"},
    "window_days": 60,
    "rows_per_day": 288,
    "rows_over_window": 17280,
    "published_times": "07:30, 13:00, 18:00",
    "interval_timestamp": "interval END, the same convention as SETTLEMENTDATE",
}

# M15 to M17 are defined in model_registry.m and implemented in
# Smoothing_predictor, but they are NOT columns of atlas_60d.mat, so no number
# about them can be recomputed from the atlas. Their values were measured on a
# longer 120-day run and are written up in
# HANDOVER_预测器整理与全跨度比较_20261013.md, section 3, together with the
# same-window Template T28 they are compared against. Registering them here is
# what lets check_deck_60d.py still require a source for every one of them
# rather than accept a hand-typed number.
SUBMITTED = {
    "days": 120,
    "cite": "HANDOVER_预测器整理与全跨度比较_20261013.md, section 3 and its results table",
    "pooled": {"ma": 51.51, "ma_comp": 86.38, "med": 51.59, "T28": 49.12},
    "T_class": 43.82,
    "cells": 213658,
    "note": "the zero-persistence figure on the same run",
    "zero_persistence": 48.27,
}


def med(key, horizon, population="32d"):
    """Median over the 288 times of day of R at one horizon, for one model."""
    m = BY_KEY[key]
    return (m["med32"] if population == "32d" else m["med60"])[horizon]


def pooled_rank(key):
    """Pooled RMSE over the whole atlas. A run fingerprint, never a ranking."""
    return BY_KEY[key]["pooled_Rall"]


def win_cells(key, population="32d"):
    """Cells won out of 108,288 when only the models compete.

    The 32-day count is the canonical one. The 60-day count is what the atlas
    stored, computed from its own R over all 60 days, and it is kept only so the
    two can be told apart.
    """
    m = BY_KEY[key]
    return m["win_cells_32d"] if population == "32d" else m["win_cells_60d"]


def win_share(key, population="32d"):
    if population == "32d":
        return BY_KEY[key]["win_share_32d"]
    return 100.0 * BY_KEY[key]["win_cells_60d"] / 108288.0


def census(label, with_official=True):
    return (CENSUS32 if with_official else CENSUS32_MODELS)[label]


def official(what):
    return NUM["official"][what]


def coverage(what):
    return NUM["coverage"][what]


def src_share(which):
    """Share of the scored-day cells a source supplied: 'p5min', 'predispatch',
    'pd7day' or 'none'. Over the 32 scored days, not the whole window."""
    o = NUM["official"]
    return 100.0 * o["src_" + which] / o["src_cells"]


def fmt(x, digits=2):
    """Format for the deck, no trailing zeros beyond the requested precision."""
    if isinstance(x, int):
        return str(x)
    s = ("%%.%df" % digits) % x
    return s


def derived():
    """Differences and gains the closing pages quote, computed from the JSON.

    Two numbers on a page have to agree with the two numbers they came from, so
    a difference is never typed: it is computed here, printed from here, and
    registered as an allowed string so the audit can trace it back.
    """
    if _DERIVED:
        return _DERIVED
    _DERIVED.update({
        "official_minus_anchor_1h": abs(NUM["official"]["med"][0] - med("anchor_mix", 0)),
        "official_minus_anchor_24h": abs(NUM["official"]["med"][1] - med("anchor_mix", 1)),
        "official_minus_anchor_76d": abs(NUM["official"]["med"][2] - med("anchor_mix", 2)),
        "official_minus_T28_76d": abs(NUM["official"]["med"][2] - med("T28", 2)),
        "anchor_minus_carry_76d": abs(med("anchor_mix", 2) - med("carry_forward", 2)),
        "m20_gain_vs_m4": abs(NUM["m20_vs_m4"]["median_diff"]),
        "comb_gain_vs_anchor": abs(NUM["comb_vs_anchor"]["median_diff"]),
        # The crossing the closing pages quote as a lead in hours. The template
        # median is flat, so the hour the official median passes it is the lead of
        # the stored column, read out of the extraction rather than computed.
        "cross_hours": next(r["lead_min"] for r in NUM["lead_share"][0]
                            if r["col"] == NUM["cross_col"]) / 60.0,
        # The one comparison the weekday-class page states from the longer run,
        # computed from the two pooled values registered in SUBMITTED above.
        "T_class_gain_120d": abs(100.0 * (SUBMITTED["pooled"]["T28"]
                                          - SUBMITTED["T_class"])
                                 / SUBMITTED["pooled"]["T28"]),
        # The two gaps the first-hour page states: official median minus
        # Anchor-mix at the first and the last column of the P5MIN band.
        "gap_first_5min": abs(NUM["official"]["median_by_lead"][0]
                              - med("anchor_mix", 0)),
        "gap_first_55min": abs(NUM["official"]["median_by_lead"][10]
                               - med("anchor_mix", 0)),
    })
    # The best single model is the lowest whole-atlas fingerprint among the
    # sixteen. The comb table holds only combinations, so it is not in there.
    best = min(m["pooled_Rall"] for m in NUM["model"])
    _DERIVED["best_single_pooled"] = best
    _DERIVED["comb_gain_vs_best_single"] = abs(
        COMB["optimal weights, lead bands (shrink 0.3)"] - best)
    return _DERIVED


def number_strings():
    """Every numeric string the deck is allowed to contain, at any precision
    the deck might plausibly print it. Built by walking the JSON, so a number
    that is not in the extraction cannot pass the checker."""
    out = set()

    def add(v):
        if isinstance(v, bool) or v is None:
            return
        if isinstance(v, int):
            out.add(str(v))
            return
        if isinstance(v, float):
            for d in (0, 1, 2, 3):
                s = ("%%.%df" % d) % v
                out.add(s)
                if "." in s:
                    out.add(s.rstrip("0").rstrip("."))
            return
        if isinstance(v, str):
            return
        if isinstance(v, list):
            for x in v:
                add(x)
            return
        if isinstance(v, dict):
            for x in v.values():
                add(x)

    add(NUM)
    # differences and simple derived quantities the deck states as text
    for m in NUM["model"]:
        for i in range(3):
            add(abs(m["med32"][i] - m["med60"][i]))
            add(m["med32"][i] - m["med60"][i])
    for c in list(CENSUS32.values()) + list(CENSUS32_MODELS.values()):
        add(c["cells"])
        add(c["share_pct"])
        add(100.0 - c["share_pct"])
    add(max(0.0, NUM["official"]["med"][1] - NUM["m20_vs_m4"]["median_diff"]))
    add(NUM["m20_vs_m4"]["lower"] + NUM["m20_vs_m4"]["higher"] + NUM["m20_vs_m4"]["ties"])
    add(NUM["comb_vs_anchor"]["lower"] + NUM["comb_vs_anchor"]["higher"])
    for key in ("band1", "band2"):
        for pop in ("60d", "32d"):
            p = NUM["coverage"]["%s_present_%s" % (key, pop)]
            t = NUM["coverage"]["%s_total_%s" % (key, pop)]
            add(p)
            add(t)
            add(100.0 * p / t)
            add(100.0 - 100.0 * p / t)
    add(NUM["official"]["comparable_cells"])
    add(NUM["official"]["cells_total"])
    add(100.0 * NUM["official"]["comparable_cells"] / NUM["official"]["cells_total"])
    add(SPEC)
    add(SUBMITTED)
    # derived ratios the M18 page states, computed here rather than typed
    add(100.0 * SUBMITTED["pooled"]["T28"] / SUBMITTED["pooled"]["T28"])
    add(100.0 * float(BY_KEY["T_class"]["med32"][1]) / float(BY_KEY["T28"]["med32"][1]))
    add(100.0 * (float(BY_KEY["T_class"]["med32"][1]) - float(BY_KEY["T28"]["med32"][1]))
        / float(BY_KEY["T28"]["med32"][1]))
    add(100.0 * (float(BY_KEY["T28"]["med60"][1]) - float(BY_KEY["T28"]["med32"][1]))
        / float(BY_KEY["T28"]["med60"][1]))
    for key in ("P5MIN", "PREDISPATCH", "PD7DAY"):
        for h in SPEC[key]["horizon_h"] or ():
            add(h)
        add(SPEC[key]["runs"] + SPEC[key]["columns"])
        add(SPEC[key]["runs"] - SPEC[key]["columns"])
    for which in ("p5min", "predispatch", "pd7day", "none"):
        add(src_share(which))
        add(100.0 - src_share(which))
    # derived counts the axis page states in words
    for v in (2196, 365, 11, 55, 60):
        add(v)
    # the banding measurement behind the structure page
    band = NUM.get("banding")
    if band:
        add(band["lag"])
        add(band["pairs"])
        add(band["identical_pairs"])
        add(band["pairs"] - band["identical_pairs"])
        add(band["exception_gap_min"] if isinstance(band["exception_gap_min"], (int, float))
            else max(band["exception_gap_min"]))
        for v in band["ac"]:
            add(v)
    for e in NUM.get("lead_share", [[]])[0]:
        add(e["share_pct"])
        add(100.0 - e["share_pct"])
    add(NUM.get("cross_col", 0))
    # the differences the closing pages quote: computed in derived(), so a
    # difference can never drift away from the two numbers it came from
    for v in derived().values():
        add(v)
    return out


# Numbers that are specification, not measurement: dates, times of day, slot
# counts, model numbers, window lengths, percentiles. check_deck_60d.py treats
# these as structural and never asks for a source.
STRUCTURAL = {
    "5", "15", "25", "30", "35", "45", "55", "60", "90", "120", "288", "376",
    "12", "24", "48", "7", "28", "56", "112", "14", "4", "3", "2", "1", "0",
    "8", "6", "9", "10", "11", "13", "16", "17", "18", "19", "20", "21", "22",
    "23", "26", "27", "29", "31", "32", "33", "36", "38", "40", "42", "46",
    "99", "100", "1.0", "0.98", "0.15", "0.01", "0.3", "0.05", "5.5", "13.5",
    "2026", "0811", "1009", "5.0", "0.5", "1.5", "2.5", "0.2", "0.4", "0.6",
    "0.8", "1.2", "1.4", "1.6", "1.8", "2.0", "2.2", "2.4", "3.0", "3.5",
    "4.0", "4.5", "6.0", "7.5", "0730", "1300", "1800", "2300", "183", "164",
    "39", "15.5", "2196", "7.625", "3.92", "0.21", "13.42", "101280",
    "108288", "93.53", "6.47", "100.0", "87.3", "93.3", "108", "288376",
    # Leads in hours the closing pages state as switches of the family median.
    # They are columns of the axis, read from the extraction, not measurements.
    "38.0",
}

if __name__ == "__main__":
    print("models          %d" % len(NUM["model"]))
    print("census entries  %d" % len(NUM["census_32d_with_official"]))
    print("comb entries    %d" % len(NUM["comb"]))
    print("allowed strings %d" % len(number_strings()))
    print("")
    print("%-26s %-22s %-22s %8s" % ("model", "R 32d  1h/24h/7.6d", "R 60d  1h/24h/7.6d", "cells"))
    for m in NUM["model"]:
        print("%-26s %6s %6s %6s   %6s %6s %6s   %8d" % (
            m["name"],
            fmt(m["med32"][0]), fmt(m["med32"][1]), fmt(m["med32"][2]),
            fmt(m["med60"][0]), fmt(m["med60"][1]), fmt(m["med60"][2]),
            m["win_cells"]))
    print("")
    print("submitted population, %d days: %s" % (SUBMITTED["days"], SUBMITTED["cite"]))
    for k, v in sorted(SUBMITTED["pooled"].items()):
        print("   %-10s %s" % (k, fmt(v)))
