# -*- coding: utf-8 -*-
"""Put the short gloss on every symbol in deck_notation.py.

The notation pages print the symbol and its gloss on one line, and the column is
3.66 in wide at 9 pt, which holds about 74 characters. A gloss longer than that
wraps to a second line and the table then needs three pages instead of two, so the
glosses are kept to one line: what the quantity is, over what it is taken, and its
unit where it has one.

The script rewrites only the second element of each SYMBOLS entry and leaves the
name, the keys and the comments alone. It is idempotent: running it twice gives the
same file.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# key -> the one-line gloss. 74 characters is the measured limit.
GLOSS = {
    "k": "The interval that has just closed. The forecast is made at its end.",
    "h": "Forecast lead in minutes: 5 minutes to 183.0 hours, 376 of them.",
    "s": "Position in the day, 1 to 288, five minutes each. Slot 1 is 00:00.",
    "u(k,h)": "The slot the target interval lands on. It is the time of day.",
    "d": "A calendar day. The window has 60, and days 29 to 60 are scored.",
    "y(k)": "The actual price, dollars per megawatt hour, after clamping.",
    "y-hat(k+h|k)": "A model's forecast for interval k+h, made at origin k.",
    "e(k,h)": "Actual minus forecast, dollars per megawatt hour. Positive is low.",
    "R(s,h)": "The error of one cell: RMSE over the 32 scored days, $/MWh.",
    "T(s)": "Mean price of slot s over its last 28 values, one per day.",
    "S(k)": "Mean of the last 12 five-minute prices at the origin.",
    "L(d)": "Mean price of one whole day.",
    "r(k)": "Price minus template: what the template does not explain.",
    "q1, q99": "Bounds of the target day: the 1st and 99th percentile of 30 days.",
    "D_score": "The 32 days every cell is averaged over.",
    "n_d": "How many scored days carry a value in this cell. 32, or 0.",
    "y_prev(u)": "The price of slot u one day earlier.",
    "n_T": "The template window: 28 observations, one per day at that slot.",
    "theta(s)": "One correction per slot, applied to yesterday's price.",
    "phi": "The AR coefficients: weights on the last p residuals.",
    "p": "AR order: how many past residuals the model uses.",
    "p*(s,h)": "The order chosen for one cell, slot s at lead h.",
    "D_h": "The fitted coefficients for lead h in the direct multi-step fit.",
    "a_h, b_h": "Weights on the current price and on the template, at lead h.",
    "L-hat(D)": "The fitted mean price of the target day.",
    "T_w(s)": "The per-slot mean over a window of w days instead of 28.",
    "alpha": "EWMA decay per day: today's weight over yesterday's, 0.15.",
    "W_c": "Past values of one slot, kept apart for weekdays and weekends.",
    "P": "The orders the rule tries: 1, 2, 3, 4, 5, 6, 8.",
    "y_s(i)": "The i-th most recent value of slot s.",
    "k_s": "How many values slot s has, capped at the 28 of the window.",
    "G": "RLS step size on the newest observation.",
    "P_rls": "RLS uncertainty. Starts at 100 and falls as evidence arrives.",
    "lambda": "Forgetting factor, 0.98: older evidence fades two percent a step.",
    "r-hat(k+s|k)": "The residual the model predicts for the target.",
    "D'_h": "The fitted row for lead h when the fit is on price changes.",
    "Delta y(k)": "The price change, y(k) minus y(k-1).",
    "c_h": "The constant the fit adds at lead h.",
    "a_h": "Weight on the price that has just closed, at lead h.",
    "b_h": "Weight on the slot template, at lead h.",
    "phi_h": "Weights on the recent residuals, at lead h.",
    "psi_h": "Weights on the recent price changes, at lead h.",
    "c": "The constant of the daily level fit, over 56 days.",
    "b1": "How much of yesterday's level carries into today, over 56 days.",
    "L-bar": "The mean daily level over the fitting window.",
    "W": "The averaging windows used: 7, 28, 56 and 112 days.",
    "T_mw(s)": "Average of the four window templates at slot s.",
    "T-bar_mw": "The multi-window template averaged over the slots.",
    "rho(k)": "Share of today's 288 slots already closed at the origin.",
    "y-bar_run(k)": "Mean price of the part of today that has already closed.",
    "L(d-1)": "The realised mean price of the last complete day.",
    "xi": "Forgetting factor of the online template update, 0.98.",
    "A": "The inputs the anchor combination is fitted on, one row per interval.",
    "C": "How the members move together, so two alike members do not count twice.",
    "K": "How many past days the weighted template keeps.",
    "G(h,s)": "One shift per cell: how far the model moves its forecast.",
    "w_min": "The weight below which a past day is dropped, 0.01.",
    "y(i)(s)": "The value slot s took on the i-th most recent complete day.",
    "T_e(s)": "Per-slot mean with recent days weighted more than old ones.",
    "w": "How many points the smoothing covers. 12 points is one hour.",
    "y(k-i)": "The price i intervals before the origin.",
    "(w-1)/2": "The delay a trailing mean carries: half its window.",
    "S(k-1)": "The same smoothed price one interval earlier.",
    "median": "The value with half the numbers above it and half below.",
    "N_c": "How many past values the class buffer holds for this slot.",
    "y_d(s)": "The value slot s took on day d, a day of the target's class.",
    "T_c(s)": "Per-slot mean over one class: weekdays, or weekend days.",
    "phi(p)": "The residual weights for candidate order p.",
    "r-hat(p)": "The residual forecast from candidate order p.",
    "D_28": "The trailing days a candidate is scored on: 7 to 28.",
    "r-hat(p*)(h)": "The residual forecast from the order this cell chose.",
    "p*(u,h)": "The chosen order, read at the target slot and the lead.",
}


def main():
    path = os.path.join(HERE, "deck_notation.py")
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    # A gloss is written as SEVERAL adjacent string literals, one per source line.
    # Replacing only the first of them is what left the rest of the old sentence
    # in the file, so the pattern consumes every adjacent literal up to the comma
    # that closes the tuple.
    changed, missing = 0, []
    for key, gloss in GLOSS.items():
        pattern = re.compile(
            r'("%s": \(\s*"[^"]*",)(\s*"(?:[^"\\]|\\.)*")+\s*\)' % re.escape(key),
            re.S)
        new, n = pattern.subn(lambda m: m.group(1) + '\n              "%s")' % gloss,
                              text, count=1)
        if n == 0:
            missing.append(key)
        else:
            changed += n
            text = new
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    print("glosses replaced: %d of %d" % (changed, len(GLOSS)))
    if missing:
        print("no match for: %s" % ", ".join(missing))
    return 0 if not missing else 1


if __name__ == "__main__":
    sys.exit(main())
