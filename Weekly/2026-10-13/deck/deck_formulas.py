# -*- coding: utf-8 -*-
"""Every formula the deck renders, in one place.

Strings are WITHOUT the surrounding dollar signs: render_formula.render() adds
them. They must stay inside what matplotlib mathtext accepts, because there is
no TeX distribution on this machine. The measured deny list lives in
check_formulas.py; the short version is:

   denied  \\big \\Big \\bigg   \\tfrac   \\begin \\end   \\le   \\overbrace
           \\underbrace   \\color
   allowed \\frac \\dfrac \\sum_{}^{} \\min \\max \\arg\\min \\left( \\right)
           \\hat{} \\bar{} \\tilde{} \\mathrm{} \\text{} \\operatorname{}
           \\mathbf{} \\mathcal{} \\mathbb{R} \\substack{a\\\\b} \\{ \\} \\#
           \\mid \\top \\Delta \\times \\pm \\partial \\approx \\leftarrow
           \\vdots \\cdots \\lfloor \\rfloor \\|x\\| := D'_h p^{\\ast}

Each entry is (latex, caption). The caption is what the proof sheet prints under
the formula; it is not deck text.
"""

FORMULAS = {
    # ------------------------------------------------------- the metrics, once
    # The teacher asked four times what these mean, so the deck states them
    # explicitly rather than describing them: what is averaged over what, and in
    # what unit. Every other page's numbers are one of these five objects.
    "m_err": (
        r"e(k,h) = y\left(k+h\right) - \hat{y}\left(k+h \mid k\right)",
        "error of one interval, in dollars per megawatt hour",
    ),
    "m_mse": (
        r"\mathrm{MSE}(s,h) = \frac{1}{n_d}\sum_{d\,\in\,D_{\mathrm{score}}}"
        r" e\left(k(d,s,h),\,h\right)^{2}",
        "MSE of one cell: mean of the squared errors over the 32 scored days",
    ),
    "m_rmse": (
        r"R(s,h) = \sqrt{\mathrm{MSE}(s,h)}",
        "RMSE of one cell: the number every surface, census and test is built on",
    ),
    "m_med_lead": (
        r"\mathrm{med}_s\,R(s,h) \quad \mathrm{over\ the\ 288\ times\ of\ day}",
        "the median used for every fixed-lead number",
    ),
    "m_med_slot": (
        r"\mathrm{med}_h\,R(s,h) \quad \mathrm{over\ the\ 376\ leads}",
        "the median used for every fixed-time-of-day number",
    ),
    "m_pooled": (
        r"\mathrm{pooled} = \sqrt{\frac{1}{|\Omega|}\sum_{(s,h)\in\Omega}R(s,h)^{2}}",
        "one number over the whole grid: a fingerprint, never a ranking",
    ),
    "m_units": (
        r"\left[e\right] = \left[R\right] = \frac{\$}{\mathrm{MWh}},"
        r"\qquad n_d = 32,\qquad s \in 1..288,\qquad h \in 1..376",
        "units, sample count and index ranges, stated once",
    ),
    "m_mse_alt": (
        r"\mathrm{MSE} = \frac{1}{32}\sum_{i=1}^{32} e_i^{2}"
        r"\quad \mathrm{across\ dates\ only}",
        "the same definition in the short form",
    ),

    # ---------------------------------------------------------------- shared
    "slot": (
        r"u(k,h) = \mathrm{mod}\left(s(k)-1+h,\; n_s\right)+1",
        "target slot of lead h, wrapping the day",
    ),
    "clamp": (
        r"y_c(k) = \min\left(\max\left(y(k),\, q_1(d)\right),\, q_{99}(d)\right)",
        "clamped price, the scored signal",
    ),
    "clampq": (
        r"q_1(d),\,q_{99}(d) = \mathrm{prctile}\left(\left\{y(j)\right\},\,[1,99]\right)"
        r"\quad \mathrm{over\ the\ 30\ complete\ days\ before\ } d",
        "clamp thresholds, recomputed daily",
    ),
    "rlsv": (
        r"G = \frac{P_{rls}\,u}{\lambda + u^{\top} P_{rls}\,u},\qquad "
        r"\theta \leftarrow \theta + G\left(z - u^{\top}\theta\right),\qquad "
        r"P_{rls} \leftarrow \frac{1}{\lambda}\left(P_{rls} - G\,u^{\top} P_{rls}\right)",
        "vector RLS with exponential forgetting",
    ),
    "rlss": (
        r"G = \frac{P_{rls}\,u}{\lambda + P_{rls}\,u^{2}},\qquad "
        r"\theta \leftarrow \theta + G\left(z - \theta u\right),\qquad "
        r"P_{rls} \leftarrow \frac{(1 - G u)\,P_{rls}}{\lambda}",
        "scalar RLS, the special case used by Theta-y",
    ),
    "tmpl": (
        r"T(s) = \frac{1}{\min(k_s,\,n_T)}\sum_{i=1}^{\min(k_s,\,n_T)} y_s^{(i)}",
        "rolling per-slot template, n_T = 28 days",
    ),
    "resid": (
        r"r(k) = y(k) - T_{k-1}\left(s(k)\right)",
        "residual against the template as it stood before this point",
    ),
    "diff": (
        r"\Delta y(k) = y(k) - y(k-1)",
        "first difference",
    ),

    # ------------------------------------------------------- official series
    "off_rule": (
        r"T = O + L \quad (L \leq 55\ \mathrm{min}),\qquad "
        r"T = \mathrm{ceil}_{30}\left(O + L\right) \quad (L > 55\ \mathrm{min})",
        "the target the official composite is sampled at",
    ),
    "off_pick": (
        r"\mathrm{choose\ the\ first\ } p \in \left\{\mathrm{P5MIN},\ \mathrm{PREDISPATCH},\ "
        r"\mathrm{PD7DAY}\right\}\ \mathrm{with}\ \mathrm{eff}(p) \leq O\ \mathrm{and}\ T\ \mathrm{in\ its\ horizon}",
        "causal selection: a run may only be used after it is published",
    ),
    "off_age": (
        r"\mathrm{age} = O - \mathrm{eff}(p)",
        "staleness of the official value at the origin",
    ),
    "off_col": (
        r"\mathrm{col} = 1 + \frac{T - \mathrm{eff}(p)}{\mathrm{step}(p)}",
        "publication identity: target = effective time + step x (period - 1)",
    ),

    # ------------------------------------------------------------- the bench
    "lead_axis": (
        r"\ell_i = 5i\ \mathrm{min}\ \ (i = 1\ldots11),\qquad "
        r"\ell_i = 30\left(i - 11\right)\ \mathrm{min}\ \ (i = 12\ldots376)",
        "the 376-column lead axis",
    ),
    "err_e": (
        r"e(k,h) = y_c(k+h) - \mathrm{clip}\left(\hat{y}(k+h\mid k),\, q_1,\, q_{99}\right)",
        "one scored error",
    ),
    "err_E": (
        r"E(s,h,d) = e(k,h)\quad \mathrm{for\ the\ } k \mathrm{\ with\ } s(k+h) = s,\ d(k+h) = d",
        "the error cube, one sample per cell per day",
    ),
    "err_R": (
        r"R(s,h) = \sqrt{\frac{1}{n_d}\sum_{d\,\in\,D_{score}} E(s,h,d)^{2}}",
        "the RMSE surface, n_d = 32 scored days",
    ),
    "err_pool": (
        r"\bar{R} = \sqrt{\frac{1}{n_s\,n_h\,n_d}\sum_{s,h,d} E(s,h,d)^{2}}"
        r"\qquad \mathrm{fingerprint\ only,\ never\ a\ ranking\ basis}",
        "the pooled RMSE the deck refuses to rank on",
    ),
    "dm": (
        r"d_i = e^{2}_{m,i} - e^{2}_{o,i},\qquad "
        r"DM(s,h) = \frac{\bar{d}(s,h)}{\sqrt{\widehat{\mathrm{Var}}\left(\bar{d}(s,h)\right)}}"
        r"\quad \mathrm{NeweyWest,\ lag\ 7}",
        "paired per-cell Diebold-Mariano",
    ),
    "dm_bh": (
        r"\mathrm{Benjamini-Hochberg\ at\ } \alpha = 0.05\ \mathrm{over\ all\ } 108{,}288\ \mathrm{cells}",
        "false discovery control",
    ),

    # ------------------------------------------------------------- predictors
    "m1": (
        r"\hat{y}(k+h\mid k) = y_{prev}\left(u(k,h)\right)",
        "M1 Persistence: the same slot on the previous day",
    ),
    "m2": (
        r"\hat{y}(k+h\mid k) = T\left(u(k,h)\right)",
        "M2 Template T28: lead independent",
    ),
    "m3": (
        r"\hat{y}(k+h\mid k) = \theta\left(u(k,h)\right)\cdot y_{prev}\left(u(k,h)\right)",
        "M3 Theta-y: one scalar gain per slot",
    ),
    "m4_rec": (
        r"\hat{r}(k+s\mid k) = \sum_{j=1}^{p}\phi_j\,\tilde{r}(k+s-j),\qquad "
        r"\tilde{r} = r\ \mathrm{if}\ s-j \leq 0,\ \ \tilde{r} = \hat{r}\ \mathrm{otherwise}",
        "M4 residual recursion, iterated",
    ),
    "m4": (
        r"\hat{y}(k+h\mid k) = T\left(u(k,h)\right) + \hat{r}(k+h\mid k)",
        "M4 T28 + AR4",
    ),
    "m5": (
        r"\hat{y}(k+h\mid k) = y(k)",
        "M5 Carry-forward: lead independent",
    ),
    "m6": (
        r"\hat{y}(k+h\mid k) = T\left(u(k,h)\right) + D_h\left[1,\ r(k),\ \ldots,\ r(k-p+1)\right]^{\top}",
        "M6 T28 + DMS4: one least-squares row per lead",
    ),
    "m7": (
        r"\hat{y}(k+h\mid k) = y(k) + D'_h\left[1,\ \Delta y(k),\ \ldots,\ \Delta y(k-p+1)\right]^{\top}",
        "M7 CF + DMS4",
    ),
    "m8": (
        r"\hat{y}(k+h\mid k) = c_h + a_h\,y(k) + b_h\,T\left(u(k,h)\right)"
        r"+ \sum_{j=1}^{p}\phi_{hj}\,r(k-j+1) + \sum_{j=1}^{p}\psi_{hj}\,\Delta y(k-j+1)",
        "M8 Anchor-mix",
    ),
    "m8_convex": (
        r"b_h = 1 - a_h,\qquad a_h \leftarrow \mathrm{clip}\left(a_h,\,0,\,1\right)",
        "M8 optional constraint, implemented but not switched on",
    ),
    "m9_fit": (
        r"\hat{L}(d) = c + b_1\,L(d-1),\qquad \hat{L}(d+1) = c + b_1\,\hat{L}(d)",
        "M9 daily level recursion, refitted on a 56-day window",
    ),
    "m9": (
        r"\hat{y}(k+h\mid k) = T\left(u(k,h)\right) + \left(\hat{L}(D) - \bar{L}\right)",
        "M9 T28 + level offset",
    ),
    "m10": (
        r"T_{mw}(s) = \frac{1}{\left|W\right|}\sum_{w\,\in\,W} T_w(s),\qquad W = \left\{7,\,28,\,56,\,112\right\}",
        "M10 Multi-window template",
    ),
    "m10p": (
        r"\hat{y}(k+h\mid k) = T_{mw}\left(u(k,h)\right)",
        "M10 as a forecast",
    ),
    "m11": (
        r"\hat{y}(k+h\mid k) = T_{mw}\left(u(k,h)\right) + \left(\hat{L}(D) - \bar{T}_{mw}\right)",
        "M11 MW + level offset",
    ),
    "m12_rho": (
        r"\rho(k) = \frac{\#\left\{\mathrm{slots\ of\ today\ already\ observed}\right\}}{n_s}",
        "M12 observed share of the day",
    ),
    "m12": (
        r"\hat{L}(D_{today}) = \rho(k)\,\bar{y}_{run}(k) + \left(1-\rho(k)\right)\left(c + b_1 L(d-1)\right)",
        "M12 MW + level in run state",
    ),
    "m13_ss": (
        r"\xi_k = A\,\xi_{k-1} + w_k,\qquad w_k \sim \mathcal{N}\left(0, Q_w\right),\qquad "
        r"y(k) = C_k\,\xi_k + v_k,\qquad v_k \sim \mathcal{N}\left(0, R_v\right)",
        "M13 harmonic state space",
    ),
    "m13_upd": (
        r"\hat{\xi}_{k\mid k-1} = A\,\hat{\xi}_{k-1\mid k-1},\qquad "
        r"K_k = P_{k\mid k-1}C_k^{\top}\left(C_k P_{k\mid k-1} C_k^{\top} + R_v\right)^{-1}",
        "M13 predict and gain",
    ),
    "m13": (
        r"\hat{y}(k+h\mid k) = C_{k+h}A^{h}\hat{\xi}_{k\mid k} = G\left(h,\,u(k,h)\right)\hat{\xi}_{k\mid k}",
        "M13 forecast, collapsed onto the precomputed basis",
    ),
    "m13_g": (
        r"G(h,s) = C_s A^{h},\qquad \hat{y}(k+h\mid k) = G\left(h,\,u(k,h)\right)\hat{\xi}_{k\mid k}",
        "M13 basis table, 7 MB, shared by every origin",
    ),
    "m13_rot": (
        r"\omega_j = \frac{2\pi j}{n_s},\qquad A^{n_s}\ \mathrm{harmonic\ block} = I",
        "M13 the rotation property used as a self check",
    ),
    "m14": (
        r"T_e(s) = \frac{\sum_{i=0}^{K-1}(1-\alpha)^{i}\,y^{(i)}(s)}{\sum_{i=0}^{K-1}(1-\alpha)^{i}},\qquad "
        r"K = \left\lfloor \frac{\log w_{min}}{\log(1-\alpha)}\right\rfloor",
        "M14 EWMA template, alpha = 0.15, K = 28 days",
    ),
    "m14p": (
        r"\hat{y}(k+h\mid k) = T_e\left(u(k,h)\right)",
        "M14 as a forecast",
    ),
    "m15": (
        r"S(k) = \frac{1}{w}\sum_{i=0}^{w-1} y(k-i),\qquad \hat{y}(k+h\mid k) = S(k)",
        "M15 trailing mean, w = 12 points",
    ),
    "m16": (
        r"\hat{y}(k+h\mid k) = S(k) + \left(\frac{w-1}{2} + h\right)\left(S(k) - S(k-1)\right)",
        "M16 delay compensation",
    ),
    "m17": (
        r"S(k) = \mathrm{median}\left\{y(k),\,\ldots,\,y(k-w+1)\right\},\qquad \hat{y}(k+h\mid k) = S(k)",
        "M17 trailing median",
    ),
    "m18": (
        r"T_c(s) = \frac{1}{N_c}\sum_{d\,\in\,W_c} y_d(s),\qquad c \in \left\{\mathrm{weekday},\ \mathrm{weekend}\right\}",
        "M18 class-split template, N_c counts days in the class",
    ),
    "m19_cand": (
        r"\hat{r}^{(p)}(s) = \mathrm{filter}\left(1,\ \left[1,\,-\phi^{(p)}\right],\ 0,\ "
        r"r(k-1),\,\ldots,\,r(k-p)\right)",
        "M19 one iterated candidate forecast per order",
    ),
    "m19_rule": (
        r"p^{\ast}(s,h) = \arg\min_{p\,\in\,P}\ \sum_{d\,\in\,D_{28}}"
        r"\left(y_c - \mathrm{clip}\left(T(u) + \hat{r}^{(p)}_{d}\right)\right)^{2},\qquad P = \left\{1,2,3,4,5,6,8\right\}",
        "M19 the order is chosen per cell from trailing error",
    ),
    "m20": (
        r"\hat{y}(k+h\mid k) = T\left(u(k,h)\right) + \hat{r}^{\left(p^{\ast}(u,h)\right)}(h)",
        "M20 T28 + AR(n per cell)",
    ),

    # ------------------------------------------------------------- structure
    "band48": (
        r"\mathrm{lag\ }48\ \mathrm{autocorrelation\ of\ } R(s,\cdot):\ "
        r"\mathrm{T28}\ 0.998,\ \ \mathrm{carry\text{-}forward}\ 0.781,\ \ \mathrm{Kalman}\ 0.675",
        "the 48-column daily periodicity of the grid",
    ),
    "win_share": (
        r"\mathrm{share}(m) = \frac{1}{n_s\,n_h}\sum_{s,h} \mathbf{1}\left[m = \arg\min_{m'} R(s,h,m')\right]",
        "the per-cell win census",
    ),
}
