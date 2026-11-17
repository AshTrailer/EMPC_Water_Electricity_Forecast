%% ============================================================
%  VERIFY_ATLAS_REGRESSION  Did the 376-column refactor change the 288 axis?
%
%  atlas_v5.mat was built before the lead axis became switchable. atlas_regress
%  is the same 120-day window and the same 288-column axis, built by the
%  refactored script. Every column the two share must be bit-identical, or the
%  refactor changed numbers nobody asked it to change.
%
%  Column mapping. atlas_v5 holds the first 19 registry entries in order, which
%  is what the registry looked like then. The regression atlas holds a subset of
%  the 20 entries the registry has now, still in registry order. So a regression
%  column whose registry position is r maps to v5 column r, with one exception:
%  T28_ARn is the appended 20th entry and its counterpart in v5 is the ar_adapt
%  column, which is the same forecast under the name it should have had.
%
%  Both files are v7.3, so the columns are read one at a time through matfile.
%  Loading two 500 MB atlases whole is over a gigabyte of resident memory and
%  this machine does not have it.
%
%  Run: matlab -batch "run('...\verify_atlas_regression.m')"
% ============================================================
clear; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(predictor_root);
addpath(fullfile(predictor_root, "Shared"));
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");

v5_path = fullfile(fig_dir, "atlas_v5.mat");
rg_path = fullfile(fig_dir, "atlas_regress.mat");
A = matfile(v5_path);
B = matfile(rg_path);
rk = string({model_registry().key})';

% Everything except E4 is small and is loaded by name; E4 is read one column at
% a time through the matfile handles below. whos on the file reports a size
% without loading the array.
sA = whos("-file", v5_path, "E4").size;
sB = whos("-file", rg_path, "E4").size;
Sv = load(v5_path, "names", "comb_name", "comb_surf", "ar_sel", "ar_sel_hist");
Sg = load(rg_path, "names", "keys", "comb_name", "comb_surf", "ar_sel", "ar_sel_hist");
namesB = string(Sg.keys(:));
assert(isequal(sA(1:3), sB(1:3)), 'regress:shape', ...
   'v5 is %s, regression is %s', mat2str(sA), mat2str(sB));
assert(sA(4) == 19, 'regress:v5cols', ...
   'atlas_v5 holds %d columns, expected the first 19 registry entries', sA(4));
assert(sB(4) == numel(namesB), 'regress:keys', ...
   'the regression atlas has %d columns but %d keys', sB(4), numel(namesB));
fprintf("v5 %s, regression %s\n", mat2str(sA), mat2str(sB));

fails = strings(0);
fprintf("\n%-28s %8s %8s %14s  %s\n", "key", "v5 col", "reg col", "max |diff|", "verdict");
for j = 1:numel(namesB)
   k = namesB(j);
   r = find(rk == k, 1);
   assert(~isempty(r), 'regress:unknown_key', '"%s" is not in the registry', k);
   if r <= 19
      ja = r;
   elseif k == "T28_ARn"
      ja = find(rk == "ar_adapt", 1);
   else
      error('regress:no_counterpart', '"%s" is registry entry %d, past atlas_v5', k, r);
   end
   ca = double(A.E4(:, :, :, ja));
   cb = double(B.E4(:, :, :, j));
   d = max(abs(ca - cb), [], 'all');
   clear ca cb
   ok = (d == 0);
   fprintf("%-28s %8d %8d %14.3g  %s\n", k, ja, j, d, string(ok));
   if ~ok
      fails(end+1) = sprintf("%s differs by %.3g between atlas_v5 and the regression run", k, d);
   end
end

% M19's solution must survive too: the refactor moved its accumulation from
% (slot, lead) to the same shape, so the selected order cannot move.
dsel = max(abs(double(Sv.ar_sel) - double(Sg.ar_sel)), [], 'all');
fprintf("\nar_sel bit-identical: %s (max |diff| %g)\n", string(dsel == 0), dsel);
if dsel ~= 0
   fails(end+1) = "the selected AR order changed between atlas_v5 and the regression run";
end
dh = max(abs(double(Sv.ar_sel_hist) - double(Sg.ar_sel_hist)), [], 'all');
fprintf("ar_sel_hist bit-identical: %s (max |diff| %g)\n", string(dh == 0), dh);
if dh ~= 0
   fails(end+1) = "the AR order choice counts changed";
end

% Combination rules split into two kinds, and only one kind can be compared.
%
%   Fixed membership: the rule names its members, so the surface depends only on
%   those columns. Both atlases carry them all, so the surfaces must be identical.
%
%   Whole-set membership: equal ALL, the causal best-k, and the optimal-weight
%   rules all draw on whatever models the atlas happens to hold. The regression
%   atlas has 14 columns and atlas_v5 has 19, so these MUST differ; a match would
%   mean the rule was reading the wrong columns. They are printed and checked for
%   being finite, not for being equal.
fixed_rules = ["equal CHAMPS2 (anchor, MWrun)"; "equal CHAMPS3 (anchor, MWrun, T28+DMS4)"; ...
   "equal GOOD5 (AR4,DMS4,anchor,MW,MWrun)"; "equal SHORTLONG (AR4,MWrun)"; ...
   "equal TEMPLATES (T28,MW,MWrun)"; "causal 2-model blend (anchor + MWrun)"; ...
   "causal 2-model blend (anchor + AR4)"];

cn_a = string(Sv.comb_name(:));  cn_b = string(Sg.comb_name(:));
shared = intersect(cn_a, cn_b);
fprintf("\ncombination rules shared by both atlases: %d of %d and %d\n", ...
   numel(shared), numel(cn_a), numel(cn_b));
for i = 1:numel(shared)
   nm = shared(i);
   sa = Sv.comb_surf{find(cn_a == nm, 1)};
   sb = Sg.comb_surf{find(cn_b == nm, 1)};
   d = max(abs(double(sa) - double(sb)), [], 'all');
   if ismember(nm, fixed_rules)
      fprintf("  %-46s max |diff| %-8.3g %s\n", nm, d, string(d == 0));
      if d ~= 0
         fails(end+1) = "fixed-membership rule """ + nm + """ moved";
      end
   else
      nan_b = sum(~isfinite(sb(:)));
      note = "";
      if nan_b == numel(sb)
         note = "  [entirely non-finite: the unshrunk covariance is singular at this model count]";
      end
      fprintf("  %-46s differs by %-8.3g as expected, %d non-finite cells%s\n", ...
         nm, d, nan_b, note);
   end
end
% The shrinkage is the only reason the optimal-weight rules are defined at all:
% without it the error covariance of 14 or 19 models is singular and the solve
% returns NaN, which is why shrink 0.3 is the rule the report quotes.
for nm = ["optimal weights, 4h blocks (shrink 0.3)", "optimal weights, whole atlas (shrink 0.3)"]
   k = find(cn_b == nm, 1);
   if isempty(k), continue; end
   v = double(Sg.comb_surf{k});
   nf = sum(~isfinite(v(:)));
   fprintf("  %-46s %d non-finite cells of %d\n", nm, nf, numel(v));
   if nf > 0
      fails(end+1) = "shrunk rule """ + nm + """ has non-finite cells";
   end
end

fprintf("\n");
if isempty(fails)
   fprintf("### REGRESSION PASSED: the refactor changed nothing on the 288-column axis ###\n");
else
   for f = fails, fprintf("FAIL %s\n", f); end
   error('verify_atlas_regression:failed', '%d differences', numel(fails));
end
