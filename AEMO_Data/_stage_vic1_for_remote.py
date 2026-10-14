# -*- coding: utf-8 -*-
"""Stage the VIC1 slice of the two organised AEMO windows for the remote.

The repository carries every region; the remote carries VIC1 only, because this
project has only ever scored VIC1 and five regions is 575 MB against 128 MB.

What this does, idempotently:
  1. renames the two window directories to say they hold VIC1 only
  2. deletes the non-VIC1 CSVs from them, keeping the READMEs
  3. moves the partial 5-minute set into its own subdirectory
  4. records what was removed in each README, so the local full set and the
     committed subset can be told apart later

Nothing outside AEMO_Data is touched. Run with --dry to see the plan.
"""

import argparse
import io
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))      # .../AEMO_Data
DATA = HERE

REGIONS = ("NSW1", "QLD1", "SA1", "TAS1", "VIC1")

RENAME = {
    "window_120d_20260201_20260601": "window_120d_20260201_20260601_vic1",
    "window_60d_20260811_20261009": "window_60d_20260811_20261009_vic1",
}

# where the p5min partial set and its companions live inside the 60-day window
PARTIAL_SRC = "p5min_vic1_partial"
PARTIAL_DST = "vic1_5min"
PARTIAL_MOVE = ["p5min_20260811_20261009.csv", "error_VIC1_20260825.csv",
                "dispatch_20260825_20260921.csv", "dispatch_20260922_20261006.csv",
                "_days_done_20260825.json", "_days_done_20260922.json"]

NOTE = """<!-- staged for the remote 2026-10-14 -->

**本目录进远端时只含 VIC1。** 本地完整版有五个区域(NSW1 QLD1 SA1 TAS1 VIC1),
远端只放了 VIC1,原因是本工程只用 VIC1 打分,五区域合计 575 MB 对 128 MB。
下面各节的"行数与体积"表列的是五区域合计值,`合计 5 份 CSV` 那句在远端不成立,
实际提交的只有 VIC1 那一行,行数按该行取值。要恢复五区域,按本文末的复现命令重跑。

"""


def plan(dry):
    """Build the whole plan first, resolving each target under its NEW name.

    The rename is planned in one pass and the deletions, the move and the note in
    the next, all against the post-rename paths, so a dry run and a real run agree
    about what will happen. _probe_once.py showed the renderer path; here the same
    discipline applies to a file move: plan against the end state, not the start.
    """
    actions = []
    for old, new in RENAME.items():
        src = os.path.join(DATA, old)
        dst = os.path.join(DATA, new)
        src_empty = os.path.isdir(src) and not os.listdir(src)
        if os.path.isdir(src) and not os.path.isdir(dst):
            actions.append(("rename", src, dst))
        elif os.path.isdir(dst):
            actions.append(("skip", dst, "already renamed"))
            if src_empty:
                actions.append(("rmdir", src, "the emptied original"))
        elif src_empty:
            actions.append(("rmdir", src, "empty original"))
        else:
            actions.append(("missing", src, "neither name exists"))

    def live(old, new):
        """The directory to read from, whether or not the rename has happened yet.

        The OLD name is checked first on purpose: the deletions and the note edits
        address files by their pre-rename path, so on a first run they must be
        planned against the old directory. Checking the new name first made a
        second run plan a move out of a directory that had already moved.
        """
        for name in (old, new):
            p = os.path.join(DATA, name)
            if os.path.isdir(p):
                return p
        return None

    for old, new in RENAME.items():
        d = live(old, new)
        if not d:
            continue
        for f in sorted(os.listdir(d)):
            p = os.path.join(d, f)
            if not os.path.isfile(p):
                continue
            base = os.path.basename(f)
            if base.upper().endswith(".CSV"):
                holder = next((r for r in REGIONS if r in base.upper()), None)
                if holder and holder != "VIC1":
                    actions.append(("delete", p, "region %s" % holder))
        src = os.path.join(d, PARTIAL_SRC)
        dst_dir = os.path.join(DATA, new, PARTIAL_DST)
        if os.path.isdir(src):
            actions.append(("mkdir", dst_dir, ""))
            for f in PARTIAL_MOVE:
                p = os.path.join(src, f)
                if os.path.isfile(p):
                    actions.append(("move", p, os.path.join(dst_dir, f)))
            actions.append(("rmdir", src, "if empty"))
        elif os.path.isdir(dst_dir):
            # already moved on an earlier run; make sure the empty source goes
            stray = os.path.join(d, PARTIAL_SRC)
            if os.path.isdir(stray):
                actions.append(("rmdir", stray, "already moved"))

    for old, new in RENAME.items():
        for d in (os.path.join(DATA, old), os.path.join(DATA, new)):
            if not os.path.isdir(d):
                continue
            for f in sorted(os.listdir(d)):
                if not f.lower().startswith("readme") or not f.lower().endswith(".md"):
                    continue
                p = os.path.join(d, f)
                with io.open(p, encoding="utf-8") as fh:
                    head = fh.read(200)
                if head.startswith(NOTE[:20]):
                    actions.append(("skip", p, "note already present"))
                else:
                    actions.append(("note", p, "prepend the VIC1 note"))

    def short(p):
        return os.path.relpath(p, os.path.dirname(HERE))

    for kind, a, b in actions:
        print("%-8s %s%s" % (kind, short(a),
                             ("  ->  " + short(b)) if b else ""))
    if dry:
        print("\n--dry: nothing was changed")
        return

    failed = []
    for kind, a, b in actions:
        try:
            if kind == "rename":
                try:
                    os.rename(a, b)
                except PermissionError:
                    # A directory rename is refused when any process holds a handle
                    # inside it. Moving the members one at a time still works, and
                    # the empty directory is removed at the end of the list.
                    os.makedirs(b, exist_ok=True)
                    for f in os.listdir(a):
                        shutil.move(os.path.join(a, f), os.path.join(b, f))
                    try:
                        os.rmdir(a)
                    except OSError:
                        pass
            elif kind == "delete":
                os.remove(a)
            elif kind == "mkdir":
                os.makedirs(a, exist_ok=True)
            elif kind == "move":
                shutil.move(a, b)
            elif kind == "rmdir":
                if os.path.isdir(a) and not os.listdir(a):
                    os.rmdir(a)
            elif kind == "note":
                with io.open(a, encoding="utf-8") as fh:
                    body = fh.read()
                with io.open(a, "w", encoding="utf-8", newline="\n") as fh:
                    fh.write(NOTE + body)
        except Exception as exc:                       # noqa: BLE001
            failed.append((kind, a, repr(exc)))
    print("\napplied %d of %d actions" % (len(actions) - len(failed), len(actions)))
    for kind, a, err in failed:
        print("  FAILED %-8s %s  %s" % (kind, short(a), err))
    return 1 if failed else 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    plan(ap.parse_args().dry)
