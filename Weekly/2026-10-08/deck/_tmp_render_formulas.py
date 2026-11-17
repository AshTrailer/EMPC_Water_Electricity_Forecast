# 临时件：把公式用 matplotlib mathtext 渲染成透明底 PNG，并做逐张自检。
# 自检不过的公式不写文件，脚本退出码非零。
import json
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "formulas")
os.makedirs(OUT, exist_ok=True)

DPI = 300
PAD_PX = 8
MIN_INK = 0.004

# (key, mathtext, fontsize)
FORMULAS = [
    ("rolling_template", r"$\hat{y}(k+h\mid k) = T(s(k+h))$", 30),
    ("persistence", r"$\hat{y}(k+h\mid k) = y(k-288)$", 30),
    ("carry_forward", r"$\hat{y}(k+h\mid k) = y(k)\ \ \ \ \ h = 1,\dots,288$", 24),
    ("template_fill", r"$\hat{y} = T + \hat{r}$", 30),
    ("t_ar4", r"$\hat{r}(k+h) = \sum_{j=1}^{4}\varphi_j\,\hat{r}(k+h-j)$", 26),
    ("t_dms4", r"$\hat{r}(k+h\mid k) = \beta_0^{(h)} + \sum_{j=1}^{4}\beta_j^{(h)}\,r(k-j+1)$", 24),
    ("cf_dms4", r"$\hat{y}(k+h\mid k) = y(k) + \hat{\delta}^{(h)}$", 28),
    ("theta_y", r"$\hat{y}(k+h\mid k) = T(s(k+h)) + \theta$", 26),
    ("anchor_mix_a", r"$\hat{y}(k+h\mid k) = c_h + a_h\,y(k) + b_h\,T(s(k+h))$", 24),
    ("anchor_mix_b", r"$+\ \sum_{j=1}^{4}\varphi_{hj}\,r(k-j+1) + \sum_{j=1}^{4}\psi_{hj}\,\Delta y(k-j+1)$", 24),
    ("residual_def", r"$r(k) = y(k) - T(s(k))$", 28),
    ("delta_y", r"$\Delta y(k) = y(k) - y(k-1)$", 28),
    ("template_def", r"$T_c(s) = \frac{1}{N_c}\sum_{d \in W_c} y_d(s)$", 26),
    ("p5_gap", r"$g(k) = \pi(k) - T(s(k))$", 28),
    ("rmse", r"$\mathrm{RMSE} = \sqrt{\frac{1}{N}\sum_{i=1}^{N}(\hat{y}_i - y_i)^2}$", 26),
    ("y_clamp", r"$y(k) = \min(\max(\mathrm{RRP}(k),\, Q_1),\, Q_{99})$", 22),
]

report = []
ok = True
for key, tex, size in FORMULAS:
    fig = plt.figure(figsize=(40, 10), dpi=DPI)
    fig.patch.set_alpha(0.0)
    fig.text(0.01, 0.5, tex, fontsize=size, va="center", ha="left", color="#1B2430")
    tmp = os.path.join(OUT, "_tmp_" + key + ".png")
    fig.savefig(tmp, dpi=DPI, transparent=True)
    plt.close(fig)

    with Image.open(tmp) as im:
        im = im.convert("RGBA")
        arr = np.asarray(im)
    alpha = arr[:, :, 3]
    ink_mask = alpha > 16
    ys, xs = np.nonzero(ink_mask)
    if xs.size == 0:
        report.append({"key": key, "pass": False, "why": "empty render"})
        ok = False
        os.remove(tmp)
        continue
    tight = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    W, H = im.size
    touches_edge = tight[0] <= 0 or tight[1] <= 0 or tight[2] >= W or tight[3] >= H
    crop = im.crop(tight)
    canvas = Image.new("RGBA", (crop.width + 2 * PAD_PX, crop.height + 2 * PAD_PX), (0, 0, 0, 0))
    canvas.paste(crop, (PAD_PX, PAD_PX))
    dest = os.path.join(OUT, key + ".png")
    canvas.save(dest)

    a2 = np.asarray(canvas)[:, :, 3]
    ink_ratio = float((a2 > 16).mean())
    corner_clear = bool(a2[0, 0] == 0 and a2[0, -1] == 0 and a2[-1, 0] == 0 and a2[-1, -1] == 0)
    single_line = canvas.height < 4 * canvas.width / 12
    passed = (not touches_edge) and (ink_ratio >= MIN_INK) and corner_clear
    if not passed:
        ok = False
    report.append({
        "key": key, "pass": bool(passed), "file": os.path.basename(dest),
        "px": [canvas.width, canvas.height], "ink_ratio": round(ink_ratio, 4),
        "touches_canvas_edge_before_crop": bool(touches_edge),
        "corners_transparent": corner_clear, "dpi": DPI, "fontsize": size,
        "single_line_guess": bool(single_line),
        "aspect": round(canvas.width / canvas.height, 2),
    })
    os.remove(tmp)

with open(os.path.join(OUT, "render_check.json"), "w", encoding="utf-8") as fh:
    json.dump({"dpi": DPI, "count": len(report), "all_pass": ok, "items": report}, fh, indent=1)
print(json.dumps(report, indent=1))
print("ALL_PASS", ok)
sys.exit(0 if ok else 3)
