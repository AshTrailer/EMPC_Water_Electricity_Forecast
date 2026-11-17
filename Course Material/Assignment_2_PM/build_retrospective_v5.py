"""The Assignment 2 Part 1 retrospective, v5, rewritten for a non-specialist sponsor.

Changes from v4, on the author's instruction:
  - jargon removed wherever a plain phrase does the same work
  - conversational asides deleted ("we did make one significant change...")
  - the process shortfall stated once, as a management finding with its cause and its fix
  - the controller and its owner appear in every section that describes work
  - lessons written as problem, what we did, what changed
  - the whole text brought inside the 850-word limit

Everything asserted here is traceable to a source the author supplied: the project brief, the
charter work breakdown, the repository history, or the weekly supervisor reports.
"""

import sys
sys.path.insert(0, r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Assignment_2_PM")
from doc_kit_v5 import Doc, OUT_RETRO, BASE, words  # noqa: E402

SUMMARY_CHART = BASE + r"\schedule_final.png"
APPENDIX_A = BASE + r"\appendix_A.png"
APPENDIX_B = BASE + r"\appendix_B.png"

LIMIT = 850

d = Doc()
d.title(
    "Project Retrospective",
    "ENGR90037 Capstone  |  Assignment 2 Part 1, Project Management option  |  Ash  |  16 October 2026",
    "The plan referred to throughout is the charter the team submitted on 28 August 2026. AEMO is the "
    "market operator, and the full work breakdown is in Appendix A and Appendix B.",
    counted=False)

# ----------------------------------------------------------------- 1
d.heading("Objective and scope")
d.body_para(
    "We are building a forecaster and a controller. The controller shifts pumping to the cheaper hours "
    "of the day without letting the tanks empty or overflow, using prices the forecaster supplies. We "
    "deliver the two together, tested against the market operator's forecasts.")
d.body_para(
    "The objective has not changed. The charter combined the two halves early; our adviser advised "
    "keeping them apart until each was sound on its own, and we followed that advice. They were combined "
    "on 24 September.")
d.body_para(
    "Scope narrowed twice. One price series became the benchmark, so the comparison is fair rather than "
    "favourable to us. On the forecast side we stopped looking for one best model and compare several "
    "across a range of horizons, because no single model wins at all of them.")

# ----------------------------------------------------------------- 2
d.heading("Risks and countermeasures")
d.body_para(
    "The risk we identified was data integrity. A gap or mismatch in the market operator's price series "
    "would reach the forecast, the control decision and the cost figure. The work needs a continuous "
    "feed.")
d.body_para(
    "Two countermeasures held. Each member owned a module and decided inside it without waiting to be "
    "asked, and we met our adviser weekly, so a stalled task could not stay hidden.")
d.body_para(
    "The risk that occurred was unforeseen. Our own capture code wrote records against the wrong clock, "
    "and a parsing defect had discarded most of them, so the series we report on was incomplete. We "
    "found both by auditing our own tooling. The fix and the rebuild took a week, and the audit is now "
    "repeatable rather than a one-off.")

# ----------------------------------------------------------------- 3
d.heading("Milestones and progress")
d.table(
    ["Milestone", "Plan", "Delivered", "Status"],
    [
        ["Baseline control operational", "mid-August", "14 August", "Met"],
        ["Forecast model", "end of August", "August, continuing", "Met"],
        ["Controller framework", "mid-September", "September", "Met"],
        ["Forecaster and controller combined", "week of 21 September", "24 September", "Met"],
        ["Mid-semester review", "13 November", "pending", "Pending"],
    ],
    widths=[5.6, 2.9, 3.4, 2.7])
d.body_para(
    "Every milestone the charter set has been met. The time lost is in the tasks behind them: data "
    "collection and the pipeline ran about a month over, predictor testing five weeks, and controller "
    "development four. Reconciling the market operator's products into one comparable series is what "
    "pushed the integration to 24 September.")
d.body_para(
    "The critical path no longer runs through building. It runs through proving that the controller "
    "saves money. That is what the cost comparison is for, and it is the only item at risk; it has one "
    "owner and ends on 18 October.")
d.picture(SUMMARY_CHART, width_cm=15.6)
d.caption("Figure 1. Summarised schedule: plan against actual, at 16 October. The full thirty-two task "
          "work breakdown is in Appendix A and Appendix B.")

# ----------------------------------------------------------------- 4
d.heading("People and teamwork")
d.body_para(
    "The team performed well. The three of us each own a component: the forecast model and data "
    "pipeline, the controller, and the pump decision. Working a week apart and still having something "
    "to show has worked.")
d.body_para(
    "Two things cost us time. Decisions argued out in a meeting went unwritten, so they came back. Work "
    "that had stalled waited until the next weekly meeting to surface. We changed both: each person "
    "owns an end-to-end test, and the weekly review opens with a written list of decisions and "
    "blockers.")
d.body_para(
    "My own shortfall is in the second of those. I track progress in Notion and report weekly, but I "
    "stopped updating the project file, so the schedule in the repository went stale. It is rebuilt, and "
    "the schedule is now checked at the weekly review.")

# ----------------------------------------------------------------- 5
d.heading("Stakeholders")
d.body_para(
    "The adviser and the team are the two stakeholder groups. The adviser owns the objectives and the "
    "assessment: he advised evaluating the forecaster and the controller separately, which set our "
    "sequence, and asked early for forecast error at each horizon rather than one average, the "
    "comparison we rely on.")
d.body_para(
    "The team delivers the work, so nothing outside the three of us presses on the schedule. The weekly "
    "review keeps that pressure inside the team: a decision or blocker that is not in the written list "
    "is not visible to anyone else.")

# ----------------------------------------------------------------- 6
d.heading("How we measure success")
d.body_para(
    "We measure three things: whether the work is moving, whether the forecast is accurate, and whether "
    "the controller saves money. The third is the deliverable; the other two are the means to it.")
d.body_para(
    "Progress is reported weekly, from July to 15 October without a gap. Forecast accuracy is measured "
    "as error against actual prices by horizon and time of day, widened twice as we learned what one "
    "average hides.")
d.body_para(
    "The controller is measured by the cost of the schedule it produces. Over fifty days in September "
    "and October it costs about six per cent more than perfect foresight and six per cent less than the "
    "market operator's forecasts, but the three are close and rank differently by day, so they do not "
    "yet support a claim either way.")

# ----------------------------------------------------------------- 7
d.heading("Lessons and the actions taken")
d.body_para(
    "Lesson one: check our own data before questioning the market's. The defects that cost us a week "
    "were in our own capture code, not the feed we were ready to blame. Action: the cross-source audit "
    "is required before any result is reported.")
d.body_para(
    "Lesson two: settle the comparison before building the model. Deciding what counts as better, and "
    "at which horizon, changed which models were worth building and what we are willing to claim. "
    "Action: every result states the window and the measure it was scored on.")

# ----------------------------------------------------------------- appendices
d.page_break()
d.heading("Appendix A: schedule as planned")
d.caption("The charter baseline submitted on 28 August 2026, showing all thirty-two tasks in the seven "
          "work breakdown groups and the milestones the plan committed to.")
d.picture(APPENDIX_A, width_cm=16.0)

d.page_break()
d.heading("Appendix B: schedule as delivered")
d.caption("The same thirty-two tasks with actual dates at 16 October 2026. Colour gives the state of each "
          "task, the dashed line marks today, and tasks without a bar have not begun.")
d.picture(APPENDIX_B, width_cm=16.0)

# ----------------------------------------------------------------- references
d.heading("References")
for ref in [
    "Australian Energy Market Operator (2026). NEM market data: price and demand. https://aemo.com.au",
    "Box, G. E. P., Jenkins, G. M., Reinsel, G. C. and Ljung, G. M. (2015). Time Series Analysis: "
    "Forecasting and Control, 5th ed. Hoboken: Wiley.",
    "Diebold, F. X. and Mariano, R. S. (1995). Comparing predictive accuracy. Journal of Business and "
    "Economic Statistics, 13(3), 253-263.",
    "Ellis, M., Durand, H. and Christofides, P. D. (2014). A tutorial review of economic model predictive "
    "control methods. Journal of Process Control, 24(8), 1156-1178.",
    "Haykin, S. (2014). Adaptive Filter Theory, 5th ed. Harlow: Pearson.",
    "Lago, J., Marcjasz, G., De Schutter, B. and Weron, R. (2021). Forecasting day-ahead electricity "
    "prices: a review of state-of-the-art algorithms, best practices and an open-access benchmark. "
    "Applied Energy, 293, 116983.",
    "Nowotarski, J. and Weron, R. (2018). Recent advances in electricity price forecasting: a review of "
    "probabilistic forecasting. Renewable and Sustainable Energy Reviews, 81, 1548-1568.",
    "Wang, Y., Wang, Z., Huang, Y. and Zhang, X. (2021). Minimising pumping energy cost in real-time "
    "operations of water distribution systems using economic model predictive control. Journal of Water "
    "Resources Planning and Management, 147(8), 04021042.",
]:
    d.bullet(ref)

# ----------------------------------------------------------------- ai
d.heading("Declaration of AI use")
d.body_para(
    "A generative AI assistant (DeepSeek Harness, accessed 16 October 2026) was used in four ways: to "
    "audit the project repository and reconstruct the timeline from commit history and working "
    "documents; to draft this retrospective and revise its wording; to generate the schedule chart in "
    "Appendix A and Appendix B from task data I supplied; and to draft the separate cost comparison "
    "report from simulation results produced by the team. All figures quoted here were checked against "
    "project files by the author. The modelling, the simulation runs and the engineering decisions were "
    "performed by the team. The choice of the two elective components and the two lessons are the "
    "author's own judgement. The author is responsible for the final content. The same declaration "
    "applies to the accompanying slides.",
    counted=False)

count = d.save(OUT_RETRO)
print("wrote", OUT_RETRO)
print("BODY words (four required aspects + two elective components):", count)
print("limit check:", "PASS" if count <= LIMIT else "FAIL", f"(limit {LIMIT}, headroom {LIMIT - count})")
for para in d.body:
    print(f"  {words(para):4d}  {para[:70]}")
