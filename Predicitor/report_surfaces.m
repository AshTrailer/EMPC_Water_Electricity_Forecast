%% ============================================================
%  REPORT_SURFACES  Build every figure the handover report cites
%
%  Reads one model atlas and, when it is present, the official composite cube
%  for the same window, and writes the figure set into
%  Weekly/<date>/predictor/figures.
%
%  ATLAS_IN    model atlas,    default atlas_60d.mat
%  OFFICIAL_IN official cube,  default official_60d.mat, skipped when absent
%  FIG_DIR     output folder,  default Weekly/2026-10-13/predictor/figures
%
%  The atlas now carries its own `keys`, because a run may exclude models and
%  the columns then no longer line up with the registry. Rows are matched on
%  keys and never on position or on a display label.
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(predictor_root);
addpath(fullfile(predictor_root, "Shared"));

fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
out_dir = string(getenv("FIG_DIR"));
if strlength(out_dir) == 0
   out_dir = fullfile(project_root, "Weekly", "2026-10-13", "predictor", "figures");
end

atlas_name = string(getenv("ATLAS_IN"));
if strlength(atlas_name) == 0
   atlas_name = "atlas_60d.mat";
end
src = fullfile(fig_dir, atlas_name);
assert(isfile(src), 'report_surfaces:no_atlas', 'no atlas at %s', src);
fprintf("atlas %s\n", src);
S = load(src);
fprintf("loaded %s\n", strjoin(string(fieldnames(S))', " "));

% The atlas carries the keys it was built with. Fall back to the registry only
% for an atlas written before keys were saved there, and say so.
reg = model_registry();
reg_keys = string({reg.key})';
if ~isfield(S, "keys") || numel(S.keys) ~= numel(S.names)
   warning('report_surfaces:no_keys', ...
      'the atlas carries no keys, falling back to the registry order');
   assert(numel(reg_keys) == numel(S.names), 'report_surfaces:registry_mismatch', ...
      'the atlas holds %d models, the registry holds %d', numel(S.names), numel(reg_keys));
   S.keys = reg_keys;
end
S.keys = string(S.keys(:));
S.names = string(S.names(:));

miss = S.keys(~ismember(S.keys, reg_keys));
assert(isempty(miss), 'report_surfaces:unknown_key', ...
   'the atlas carries keys the registry does not: %s', strjoin(miss, ", "));
for i = 1:numel(S.keys)
   r = find(reg_keys == S.keys(i), 1);
   assert(S.names(i) == string(reg(r).name), 'report_surfaces:label', ...
      'atlas column %d is key "%s" labelled "%s", the registry calls it "%s"', ...
      i, S.keys(i), S.names(i), reg(r).name);
end
S.specs = strings(numel(S.keys), 1);
for i = 1:numel(S.keys)
   r = find(reg_keys == S.keys(i), 1);
   S.specs(i) = string(reg(r).spec);
end
fprintf("keys %s\n", strjoin(S.keys', " "));

% The AR order sweep kept the full surface of every order, so the per-cell best
% order can be compared against what M19 chose causally. It belongs to the
% 120-day 288-column atlas and only lines up when the axes agree.
sweep_path = fullfile(fig_dir, "ar_sweep.mat");
if isfile(sweep_path) && isequal(size(S.E4, 1:2), [288 288])
   S.sweep = load(sweep_path, "p_list", "Rp_all", "Rp_lead", "ss_by_p");
   fprintf("sweep orders %d to %d\n", S.sweep.p_list(1), S.sweep.p_list(end));
else
   fprintf("no sweep for this axis, the order figures are skipped\n");
end

% The official composite, on the same window and the same lead axis.
off_name = string(getenv("OFFICIAL_IN"));
if strlength(off_name) == 0
   off_name = "official_60d.mat";
end
off_path = fullfile(fig_dir, off_name);
if isfile(off_path)
   O = load(off_path);
   if isfield(S, "lead_min") && isequal(double(O.lead_min(:)), double(S.lead_min(:))) ...
         && size(O.O4, 3) == size(S.E4, 3)
      S.official = O;
      fprintf("official composite %s, %d of %d cells carry a value\n", ...
         off_name, sum(isfinite(O.O4(:))), numel(O.O4));
   else
      fprintf("official cube %s does not share this window and axis, skipped\n", off_name);
   end
else
   fprintf("no official cube at %s, the difference figures are skipped\n", off_path);
end

out = report_figures(S, out_dir);
if ~exist(out_dir, "dir"), mkdir(out_dir); end
save(fullfile(out_dir, "report_figures.mat"), "out", "atlas_name");
fprintf("\n%d figures written to %s\n", numel(out), out_dir);
fprintf("### SCRIPT COMPLETED ###\n");
