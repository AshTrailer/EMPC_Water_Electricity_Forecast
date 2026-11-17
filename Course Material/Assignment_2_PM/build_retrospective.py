"""The Assignment 2 Part 1 retrospective.

Every statement here is traceable to a source the author supplied: the project brief, the charter
work breakdown, the repository history, or the weekly supervisor reports. Nothing is asserted about
charter risks, stakeholders or events beyond what the author confirmed.
"""

import sys
sys.path.insert(0, r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Assignment_2_PM")
from doc_kit import Doc, OUT_RETRO, BASE  # noqa: E402

SUMMARY_CHART = BASE + r"\schedule_final.png"
APPENDIX_A = BASE + r"\appendix_A.png"
APPENDIX_B = BASE + r"\appendix_B.png"

d = Doc()
d.title(
    "Project Retrospective",
    "ENGR90037 Capstone  |  Assignment 2 Part 1, Project Management option  |  Ash  |  16 October 2026",
    "The plan referred to throughout is the charter the team submitted on 28 August 2026. The full work "
    "breakdown is in Appendix A and Appendix B.")

# ----------------------------------------------------------------- 1
d.heading("Objective and scope")
d.body_para(
    "The objective is to model the error in the market operator's electricity price forecasts with "
    "parameterised models, to estimate those model parameters for use inside an economic model "
    "predictive controller, and to implement that controller so that pumping is shifted to cheaper "
    "periods without breaching the storage limits. The deliverable is a working combination of a "
    "forecaster and a controller, assessed against the market operator's own published forecasts.")
d.body_para(
    "The objective has not changed. What changed is the order in which we built it, and that change was "
    "deliberate rather than forced.")
d.body_para(
    "The charter treated the forecaster and the controller as one deliverable to be combined early. Our "
    "supervisor advised the opposite, and we followed that advice. A forecaster can be evaluated in "
    "isolation, and so can a controller; a combination cannot be evaluated until both halves are sound. "
    "We therefore ran the two as parallel workstreams and held the integration back until each was ready. "
    "This is why the two did not meet until 24 September.")
d.body_para(
    "The scope grew in one direction only, and not by choice. The market operator publishes several "
    "forecast products with different horizons, different release intervals and different price bases. "
    "Combining them into a single comparable series took longer than the plan allowed and became a "
    "workstream of its own. It is the one item that ran well past its planned window.")

# ----------------------------------------------------------------- 2
d.heading("Risks and countermeasures")
d.body_para(
    "The main risk we identified was a team risk rather than a technical one, and it did not occur.")
d.body_para(
    "The charter was written in a hurry and did not list specific risks. The risk we were alert to was "
    "the ordinary one on a three-person project: that work would stall, that someone would wait to be "
    "told what to do, or that a problem would stay unspoken until it became expensive. Two things kept "
    "that from happening. Each member owned a module outright and made day-to-day decisions inside it "
    "without asking, and we met the supervisor every week, so a stalled task could not stay hidden.")
d.body_para(
    "We did make one significant change to the team, in response to progress rather than to a risk. On "
    "24 September, at the meeting where the integration began, we dropped the pump decision module. The "
    "controller was already producing pump schedules on its own, so a separate decision layer duplicated "
    "work. The member who owned it moved to reviewing the optimisation literature for the controller. "
    "That decision has held.")
d.body_para(
    "The problem that actually cost us time was not on any list. The market operator's products are "
    "published on different bases, and reconciling them took about a week longer than planned. It is "
    "recorded here as the project's main unforeseen difficulty.")

# ----------------------------------------------------------------- 3
d.heading("Milestones, progress and the critical path")
d.body_para(
    "The project is ahead of where the charter expected it to be at this date. The forecast and "
    "controller workstreams were both running by the end of August, and the two were combined on "
    "24 September, four days inside the week the charter allowed for it.")
d.picture(SUMMARY_CHART, width_cm=15.6)
d.caption("Figure 1. Summarised schedule. Task names are grouped; the full thirty-two task work "
          "breakdown is in Appendix A and Appendix B.")
d.table(
    ["Milestone", "Charter plan", "Delivered", "Status"],
    [
        ["Baseline control operational", "mid-August", "14 August", "Met"],
        ["Forecast developed and evaluated", "end of August", "August onward, continuing", "Met"],
        ["Controller developed", "early September", "October", "Met"],
        ["Forecaster and controller combined", "week of 21 September", "24 September", "Met, inside the week"],
        ["Mid-semester review", "13 November", "13 November", "Ahead of us"],
    ],
    widths=[6.4, 3.6, 5.0, 3.6])
d.body_para(
    "The critical path no longer runs through building anything. Every component of the objective now "
    "exists. What remains is judgement about how good the combination is, and the two items on that path "
    "are the cost comparison and the mid-semester review. The cost comparison is the only item currently "
    "at risk, and its mitigation is a single named owner and an internal deadline of 18 October, after "
    "which the report is written from whatever results exist.")
d.body_para(
    "The remaining work to June 2027 is optimisation rather than construction. The controller performs "
    "acceptably today; the open question is how to demonstrate that it performs better than the market "
    "operator's forecasts on the objectives that matter, and that is a measurement problem before it is "
    "an engineering one.")
d.body_para(
    "One process failure is mine and it is a small one. I keep the schedule in my head and in the weekly "
    "reports, and I have not kept the project file up to date, so the bar chart in the repository is "
    "stale. The weekly reports carry the real status and always have.")

# ----------------------------------------------------------------- 4
d.heading("People and teamwork")
d.body_para(
    "The team performed well. Three people, three modules at the start, and every module was delivered.")
d.body_para(
    "I own the forecast model and the data pipeline. The second member owns the controller and its "
    "optimisation. The third originally owned the pump decision module, and after that module was dropped "
    "on 24 September he moved to reviewing the optimisation literature and the options for the controller. "
    "The three of us met the supervisor weekly, and those meetings were where progress was reported and "
    "where the two structural decisions of the project were taken: holding the integration back, and "
    "dropping the decision module.")
d.body_para(
    "What worked was ownership. Each person could be left alone for a week and would still have something "
    "to show. What we could have done better is write decisions down. Two decisions that changed the "
    "shape of the project were settled verbally in a meeting and recorded only later, and both were "
    "revisited at least once. A written decision log would have saved that repetition.")
d.body_para(
    "To keep the team moving through the remaining months I have made two changes. Each person now owns "
    "one end-to-end test of the delivered system rather than one module, so that the combination is "
    "everybody's problem. And the weekly review now opens with a written list of decisions and blockers "
    "from the previous week, which is the record we did not keep before.")

# ----------------------------------------------------------------- elective 1
d.heading("Stakeholders and their interests")
d.body_para(
    "There are two stakeholder groups on this project, the supervisor and the team, and neither has "
    "changed.")
d.body_para(
    "The supervisor owns the objectives and the assessment, and he has shaped the project twice. He "
    "advised building the controller and the forecaster separately before combining them, which set the "
    "sequence we followed. He also asked early for the forecast error to be reported at several horizons "
    "rather than as a single figure, and that request produced the comparison the project now rests on.")
d.body_para(
    "The team produces the work, and the three members are described in the section above. Within the "
    "team the change was the reassignment of the third member once the decision module was dropped.")
d.body_para(
    "The engagement that could be improved is inside the team rather than outside it. I report progress "
    "weekly and keep the schedule myself, but I have not kept the shared project file current, so anyone "
    "reading it sees a stale picture. The weekly report has been the accurate channel.")

# ----------------------------------------------------------------- elective 2
d.heading("Performance measurement")
d.body_para(
    "We measure two things: whether the work is proceeding, and whether the forecast is any good.")
d.body_para(
    "Progress is measured through the weekly report to the supervisor and through the schedule. This "
    "measurement has worked. Weekly reporting ran from July to the final report on 15 October, and no "
    "week passed without a status.")
d.body_para(
    "Forecast quality is measured as error against actual prices, reported at each forecast horizon "
    "rather than as one average, and now at each combination of time of day and horizon. The measure has "
    "been widened twice, once when the single average proved to hide the effect of the horizon, and once "
    "when the comparison extended to the market operator's long-range products.")
d.body_para(
    "The current standing is mixed and we will report it as such. Over horizons of minutes our forecast "
    "and the market operator's are close, and theirs is slightly better at one hour. Over horizons of a "
    "day or more no single model beats the market operator, although two of our longer-range models beat "
    "it at particular times of day. Because we combine several predictors and compare the combination "
    "against the market operator's combined series, the result varies by horizon and by time of day. On "
    "the controller's objective the market operator currently holds a small edge.")
d.body_para(
    "That is not yet a satisfactory measure, and it is the reason the next phase is a measurement problem "
    "rather than an engineering one. The controller is now being run against three price inputs over the "
    "same days: the market operator's forecasts, our own, and perfect foresight as a reference. The three "
    "cases produce different costs, but the differences are small and they do not always favour the same "
    "input, so the comparison is not yet sharp enough to support a claim either way. We are looking for an "
    "indicator that quantifies the difference rather than describing it.")

# ----------------------------------------------------------------- lessons
d.heading("Lessons and the actions taken")
d.body_para(
    "Lesson one: build the pieces before the combination. We were advised to develop the controller and "
    "the forecaster separately and to hold the integration until both were sound. That sequence worked. "
    "The combination was delivered inside its week even though both halves took longer than the plan "
    "allowed, because neither half was waiting on the other. The action is that where a deliverable "
    "depends on two developments, the plan now schedules the combination as a distinct milestone with its "
    "own date rather than treating it as the natural end of the second one.")
d.body_para(
    "Lesson two: measure the seam, not only the parts. The one item that ran seriously late was "
    "reconciling the market operator's forecast products, which sits between our data pipeline and our "
    "evaluation and therefore belonged to nobody's module. The data pipeline itself was built early and "
    "worked; the interface between the official products and our comparison is what had no owner. The "
    "action is that each person now owns one end-to-end test, so that anything falling between two "
    "modules has a name against it.")

# ----------------------------------------------------------------- appendices
d.page_break()
d.heading("Appendix A: schedule as planned")
d.caption("The charter baseline submitted on 28 August 2026, showing all thirty-two tasks in the seven "
          "work breakdown groups and the milestones the plan committed to.")
d.picture(APPENDIX_A, width_cm=16.0)

d.page_break()
d.heading("Appendix B: schedule as delivered")
d.caption("The same thirty-two tasks with actual dates at 16 October 2026. Colour gives the state of each "
          "task, and tasks without a bar have not begun.")
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
    "A generative AI assistant (DeepSeek Harness, accessed 12 to 16 October 2026) was used in four ways: "
    "to audit the project repository and reconstruct the timeline from commit history and working "
    "documents; to draft this retrospective and revise its wording; to generate the schedule chart in "
    "Appendix A and Appendix B from task data I supplied; and to draft the separate cost comparison "
    "report from simulation results produced by the team. All figures quoted here were checked against "
    "project files by the author. The modelling, the simulation runs and the engineering decisions were "
    "performed by the team. The choice of the two elective components and the two lessons are the "
    "author's own judgement. The author is responsible for the final content. The same declaration "
    "applies to the accompanying slides.")

count = d.save(OUT_RETRO)
print("wrote", OUT_RETRO)
print("body words (excludes headings, references and declaration):", count)
