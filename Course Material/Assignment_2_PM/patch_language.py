"""Apply the verified language and format corrections to the retrospective builder.

Only the items confirmed present in the built document are patched. The three misspellings and the
Appendix concatenation reported by an external review were absent from the file and are not patched.
"""

PATH = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Assignment_2_PM\build_retrospective.py"

# (label, exact old fragment, new fragment)
PATCHES = [
    ("milestones clause",
     "Three of the four planned milestones have been reached, and the third of them late. The fourth, the ",
     "Three of the four planned milestones have been reached, the third of which was late. The fourth, the "),

    ("effort transition",
     '"The effort tells a different story. Tasks that the plan sized at one to two weeks took three to five. "',
     '"Effort is where the plan came apart. Tasks that the plan sized at one to two weeks took three to five. "'),

    ("risk opening",
     '"All three major risks in the charter occurred. None was prevented, and all three were contained. "\n'
     '    "One further risk, which we had not identified, cost us a week and one month of data.")',
     '"All three charter risks happened. We did not prevent any of them, but we contained each one. "\n'
     '    "A fourth risk, which we had not identified, cost us a week and a month of data.")'),

    ("risk register sentence",
     '"the period and the metric it used. The risk register has been updated with this risk and with the "\n'
     '    "countermeasure, and the register is reviewed at the weekly meeting.")',
     '"the period and the metric it used. I have added this risk and its countermeasure to the risk register, "\n'
     '    "which the team now reviews weekly.")'),

    ("error figures preposition",
     '"from 15 to 42 dollars per megawatt-hour between two reports. The model had not degraded; the two "',
     '"from 15 to 42 dollars per megawatt-hour across two reports. The model had not degraded; the two "'),

    ("dates transition",
     '"Two dates matter for reporting and they are often confused. This retrospective covers Assignment 2 "',
     '"Two dates are easy to confuse. This retrospective covers Assignment 2 "'),

    ("weekly review sentence",
     '"chart is now reviewed at every weekly meeting rather than at milestones, which is the change that "\n'
     '    "would have caught this earlier.")',
     '"chart is now reviewed weekly rather than only at milestones, and that change would have caught the "\n'
     '    "slip earlier.")'),

    ("stakeholder opening",
     '"The stakeholder set has not changed since the charter. What changed is how we engage with them.")',
     '"The same three stakeholder groups remain, but our engagement with them has changed.")'),

    ("stakeholder change lead",
     '"The change concerns the adviser. He measures success in cost per day, not in forecast error, and in "\n'
     '    "the middle of the project I was sending him progress updates where he needed the decision framing. "\n'
     '    "The correction is a standalone cost comparison that states the figures plainly and sets out what they "\n'
     '    "do and do not show."',
     '"The main change is with the industry adviser. He measures success in cost per day rather than in "\n'
     '    "forecast error, and in the middle of the project I was sending him progress updates when what he "\n'
     '    "needed was decision framing. I have corrected this by producing a standalone cost comparison that "\n'
     '    "states the figures plainly and sets out what they do and do not show."'),

    ("delivery position",
     '"The process measures are ahead of the baseline. The delivery position is mixed and worth stating "\n'
     '    "precisely. Inside the control window our forecast beats the market operator\'s published forecast at "',
     '"The process measures are ahead of the baseline. Delivery is mixed, and the numbers matter. Inside "\n'
     '    "the control window our forecast beats the market operator\'s published forecast at "'),

    ("cost advantage wording",
     '"The cost comparison found no defensible cost advantage for either forecast source, and the reason is "',
     '"The cost comparison found no clear cost advantage for either forecast source, and the reason is "'),

    ("self assessment",
     '"The team performed well. My own record is stronger on technical recovery than on process discipline.")',
     '"The team performed well. I did better on technical recovery than on process discipline.")'),
]


def main():
    with open(PATH, encoding="utf-8") as handle:
        text = handle.read()

    applied, missing = 0, []
    for label, old, new in PATCHES:
        count = text.count(old)
        if count == 1:
            text = text.replace(old, new)
            applied += 1
            print(f"  applied  {label}")
        elif count == 0:
            missing.append(label)
            print(f"  MISSING  {label}")
        else:
            missing.append(f"{label} (x{count})")
            print(f"  AMBIGUOUS x{count}  {label}")

    with open(PATH, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)

    print(f"\napplied {applied} of {len(PATCHES)}")
    if missing:
        print("not applied:", missing)


if __name__ == "__main__":
    main()
