"""Cost comparison report: three forecast sources driving the same controller.

Written for a reader who does not know the field. Every figure comes from the closed-loop
runs shown in the accompanying figures and is stated with its unit.
"""

import sys
sys.path.insert(0, r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Assignment_2_PM")
from doc_kit import Doc, OUT_COST  # noqa: E402

d = Doc()
d.title(
    "Cost comparison: three forecast sources driving the same pump controller",
    "EMPC water pumping capstone  |  simulation results  |  16 October 2026  |  Ash",
    "The controller is fixed across the three cases. Only the forecast it receives changes, so any cost difference "
    "belongs to the forecast rather than to the controller.")

d.heading("What was compared")
d.body_para(
    "The controller decides, every five minutes, when to switch a pump on. It plans 24 hours ahead and executes only "
    "the first command of each plan. Three forecasts were offered to it in turn, all over the same two days of "
    "historical prices: a reference case that knows the future prices exactly, the forecast we built, and the forecast "
    "published by the market operator. The water demand, the tank, the pumps and the prices are identical in all three "
    "runs, so the comparison isolates the effect of forecast quality.")

d.heading("Results")
d.body_para(
    "Both test days show the same shape: the controller spends between three and five dollars a day, and the three "
    "forecast sources land within a few percent of each other.")
d.table(
    ["Case", "05 Sep cost (AUD)", "05 Sep volume (m3)", "24 Sep cost (AUD)", "24 Sep volume (m3)"],
    [
        ["Perfect information", "3.61", "3,165", "4.78", "1,516"],
        ["Our forecast", "3.87", "2,460", "2.69", "1,560"],
        ["Market operator", "1.87", "2,775", "5.08", "1,575"],
        ["Spread across cases", "2.01", "705", "2.39", "59"],
    ])
d.caption("Cost is the realised energy and switching cost of the executed schedule. Volume is the water pumped over "
          "the day. Both days run 288 solver calls per case.")

d.heading("What the numbers show")
d.body_para(
    "Forecast quality did not drive daily cost in this test. The spread across the three sources is 2.01 dollars on "
    "one day and 2.39 dollars on the other, against a daily total of three to five dollars, and the ranking reverses "
    "between the two days. On 05 September the perfect forecast is cheapest and the market operator is dearest. On "
    "24 September our forecast is cheapest and the market operator is dearest again.")
d.body_para(
    "The reversals are larger than the differences they are meant to explain. On 24 September the perfect forecast "
    "costs 4.78 dollars against our 2.69 dollars, so foresight was worth less than nothing on that day. That is not a "
    "defect of the forecast. It is what a single tank with one pump does: with one decision variable and a hard level "
    "constraint, a better price forecast has almost nothing to act on.")
d.body_para(
    "A second reason to read the totals with care is that the cases pump different volumes. The perfect-information "
    "case moved 3,165 cubic metres on 05 September against 2,460 for our forecast, and it also finished the day with a "
    "fuller tank. Comparing daily cost alone therefore compares different amounts of work. Put on a common footing, the "
    "three cases cost 1.14, 1.57 and 0.67 dollars per cubic metre on 05 September, and 3.15, 1.72 and 3.23 on "
    "24 September. The ordering still changes between days.")

d.heading("Limitations")
d.bullet("One tank, one pump, two days. The decision space is too small for forecast quality to separate the cases.")
d.bullet("Pump power varies with the combination running, so cost per cubic metre is not constant across cases.")
d.bullet("No terminal inventory target is imposed, so a case may end the day with more water than another and appear "
         "cheaper for that reason alone. Final level and pumped volume must be reported with cost.")
d.bullet("Prices are historical, so the comparison measures control performance rather than market outcomes.")
d.bullet("The official forecast is a thirty-minute traded price while the plant pays the five-minute dispatch price, "
         "so its cost carries a basis difference that the other two cases do not.")

d.heading("Conclusion and next step")
d.body_para(
    "Neither forecast source produced a defensible cost advantage over the other in this configuration, and the "
    "perfect-information reference was not reliably the cheapest. The result is evidence about the test case, not about "
    "the forecasts. A cost comparison can only discriminate once the controller has enough freedom to act differently "
    "on a better forecast.")
d.body_para(
    "The next step is therefore to widen the test rather than to tune the forecasts: more storage, more than one pump, "
    "and a terminal inventory requirement so that each case ends the day at the same level. Until then, cost should be "
    "reported alongside pumped volume and final level, never on its own.")

count = d.save(OUT_COST)
print("wrote", OUT_COST)
print("body words:", count)
