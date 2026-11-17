// Rename entry-script locals to the symbols registered in section 2 of
// HANDOVER_预测器整理与全跨度比较_20261013.md.
//   node rename_symbols.mjs            dry run, prints per-file counts
//   node rename_symbols.mjs --apply    write
// Whole-word only. Refuses to write a file where a source name never matched,
// so a rename that silently stopped applying cannot pass unnoticed.
import { readFileSync, writeFileSync } from 'node:fs';

const ROOT = 'C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast\\Predicitor\\';
const APPLY = process.argv.includes('--apply');

// symbol map: code name -> section 2 symbol
const COMMON = {
  n_slots: 'n_s',        // n_s   slots per day
  win_days: 'n_T',       // n_T   template window, days
  clamp_days: 'n_q',     // n_q   clamp quantile window, days
  n_days: 'n_d',         // n_d   scored days
  refit_days: 'n_fit',   // n_fit daily refit window, days
  hv: 'h_all',           // h     lead grid 1..n_s
  t_vec: 'T_tgt',        // T(s)  template at the target slot
  rhat: 'r_hat',         // r_hat residual forecast
  cf: 'y_now',           // y(k)  newest observation
  y_anchor: 'y_hat_anchor',
  th_trk: 'st_theta',
  C_t: 'D_r',            // D_h   direct multi-step coefficient matrix
  C_c: 'D_dy',
  C_a_sum: 'D_anchor_sum',
  C_a_n: 'D_anchor_n',
  C_a: 'D_anchor',
};

const PER_FILE = {
  'run_full_ensemble_test.m': {
    ...COMMON,
    mw_windows: 'W',           // W     multi-window set
    level_fit_days: 'n_lvl',   // n_lvl level recursion window, days
    comb_win: 'n_w',           // n_w   combination weight window, days
    y_lvl: 'y_hat_lvl',
    y_mw: 'y_hat_mw',
    t_mw: 'T_mw',
    off2: 'off_run',
    // here hh is only the forecast-origin lead vector
    hh: 'h_used',
  },
  // here hh is both the lead vector and the loop variable of the tables, and
  // both are h in section 2
  'run_predictor_suite.m': { ...COMMON, hh: 'h_lead' },
  'run_ensemble_combos.m': { n_slots: 'n_s', n_days: 'n_d', comb_win: 'n_w' },
};

// `off` is renamed only after `off2`, otherwise the boundary rule would split it
const LATE = { 'run_full_ensemble_test.m': { off: 'off_lvl' } };

function rename(text, table, late) {
  const counts = {};
  for (const [from, to] of Object.entries(table)) {
    const re = new RegExp(`\\b${from}\\b`, 'g');
    const n = (text.match(re) ?? []).length;
    counts[`${from} -> ${to}`] = n;
    text = text.replace(re, to);
  }
  if (late) {
    const lateText = text;
    for (const [from, to] of Object.entries(late)) {
      const re = new RegExp(`\\b${from}\\b`, 'g');
      const n = (lateText.match(re) ?? []).length;
      counts[`${from} -> ${to} (late)`] = n;
      text = text.replace(re, to);
    }
  }
  return { text, counts };
}

let bad = 0;
for (const [file, table] of Object.entries(PER_FILE)) {
  const path = ROOT + file;
  const src = readFileSync(path, 'utf8');
  const { text, counts } = rename(src, table, LATE[file]);
  const missing = Object.entries(counts).filter(([, n]) => n === 0).map(([k]) => k);
  console.log(`--- ${file}`);
  for (const [k, n] of Object.entries(counts)) console.log(`    ${String(n).padStart(4)}  ${k}`);
  if (missing.length) {
    console.log(`    NEVER MATCHED: ${missing.join(', ')}`);
    bad += 1;
  }
  if (APPLY && !missing.length) writeFileSync(path, text);
}
console.log(APPLY ? (bad ? `APPLIED WITH ${bad} PROBLEM FILE(S)` : 'APPLIED') : 'DRY RUN');
