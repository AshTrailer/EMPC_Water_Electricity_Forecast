%% ============================================================
%  RUN_UPDATE_CADENCE_SWEEP  Refresh cadence under the unified protocol
%
%  Question: if the controller refreshes its price vector only every K steps
%  instead of every 5 minutes, how much accuracy does it lose?
%
%  Semantics, the same as the archived AR cadence sweep: for every target point
%  the forecast used is the one issued at the most recent refresh origin, so the
%  effective lead is
%
%     eff(jj) = mod(jj - 1, K) + 1        jj = position inside the test window
%
%  and lies in 1..K. This needs no re-streaming: the saved atlas already holds
%  the error of the (jj - r)-step forecast issued at origin r for target jj, so
%  the cadence sweep is a re-indexing of the atlas.
%
%  ONE THING THIS SWEEP CANNOT DO. With a fixed cadence the effective lead and
%  the target slot are locked together, eff = mod(jj-1,K)+1 against
%  slot = mod(jj-1,n_s)+1, so the gather visits a one-dimensional curve of
%  cells, not the full n_s-by-n_s grid. K = n_s therefore does NOT reproduce the
%  whole-atlas RMSE, it reproduces the RMSE along the diagonal slot = lead.
%  The only cadence with complete coverage is K = 1, where every cell of the
%  lead-1 column is visited, and that is the check this script asserts.
%
%  K = 1 uses the 1-step forecast for every target and is therefore the easiest
%  possible reading, not the best controller setting. The pooled number conflates
%  refresh rate with average lead; the same-horizon table is the one to quote,
%  and it only compares cadences with K >= h.
%
%  Output: AEMO_Data/level_multiwindow_figs/cadence_sweep.mat
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(predictor_root, "Shared"));

n_s = 288;
K_list = [1 6 12 72 288];
K_lab  = {'5 min','30 min','1 h','6 h','24 h'};
atlas_name = string(getenv("ATLAS_OUT"));
if strlength(atlas_name) == 0
   atlas_name = "atlas_ext.mat";
end
atlas_path = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs", atlas_name);
% Load once rather than slicing the HDF5 container per model. Reading 18
% compressed columns one at a time costs about 70 s each, one load costs a
% minute in total. The atlas is a single array, so this needs about 0.7 GB.
fprintf("loading %s\n", atlas_path);
S = load(atlas_path);
E4 = S.E4;
clear S
sz = size(E4);
assert(sz(1) == n_s && sz(2) == n_s, 'atlas is not %d by %d: %s', n_s, n_s, mat2str(sz));
n_d = sz(3);  n_m = sz(4);
reg = model_registry();
assert(n_m == numel(reg), 'atlas has %d models but the registry has %d', n_m, numel(reg));

n_test = n_d * n_s;
jj = (1:n_test)';
d_of = floor((jj-1)/n_s) + 1;
s_of = mod(jj-1, n_s) + 1;

n_K = numel(K_list);
eff_of = cell(n_K,1);
lin_of = cell(n_K,1);
for ki = 1:n_K
   eff_of{ki} = mod(jj - 1, K_list(ki)) + 1;
   lin_of{ki} = s_of + n_s*(eff_of{ki}-1) + n_s*n_s*(d_of-1);
end

% Per-lead curve, indexed by REFRESH ORIGIN rather than by target.
% For refresh origin r and lead h <= K the target is r + h, so at a fixed h the
% targets form an arithmetic progression of step K. Indexing by target instead
% would confound the lead with the slot: targets at effective lead h are exactly
% those with slot = mod(h-1,K)+1, which is only n_s/gcd(K,n_s) distinct slots.
% Origin indexing spreads each lead over every origin slot, which is the honest
% within-cadence shape.
lin_lead = cell(n_K, n_s);
lin_base = cell(n_K, 1);
for ki = 1:n_K
   K = K_list(ki);
   for h = 1:K
      tgt = 1 + h + K*(0:floor((n_test - 1 - h)/K));
      tgt = tgt(tgt >= 1 & tgt <= n_test);
      lin_lead{ki, h} = s_of(tgt) + n_s*(h-1) + n_s*n_s*(d_of(tgt)-1);
   end
   % same origins, but refreshed at every step, so the lead is always one
   tgt1 = 1 + 1 + K*(0:floor((n_test - 2)/K));
   tgt1 = tgt1(tgt1 >= 1 & tgt1 <= n_test);
   lin_base{ki} = s_of(tgt1) + n_s*n_s*(d_of(tgt1)-1);
end

fprintf("atlas %s | %d models | %d days | cadences %s\n", ...
   atlas_name, n_m, n_d, mat2str(K_list));

% One pass over the atlas columns. Each column is read once and feeds both the
% per-model cadence numbers and the equal-weight combination accumulator, which
% is valid because sum_m w_m = 1 makes e_c = mean_m e_m.
cad_all  = zeros(n_K, n_m);
cad_lead = nan(n_K, n_s, n_m);
cad_base = zeros(n_K, n_m);
Rall     = zeros(n_m, 1);
accK     = zeros(n_test, n_K);
accA     = zeros(n_s, n_s, n_d, 'single');

for m = 1:n_m
   E = double(E4(:,:,:,m));
   Rall(m) = sqrt(mean(E(:).^2));
   accA = accA + single(E);
   for ki = 1:n_K
      K = K_list(ki);
      v = E(lin_of{ki});
      e2 = v.^2;
      accK(:,ki) = accK(:,ki) + v;
      cad_all(ki,m) = sqrt(mean(e2));
      for h = 1:K
         if ~isempty(lin_lead{ki,h})
            cad_lead(ki, h, m) = sqrt(mean(E(lin_lead{ki,h}).^2));
         end
      end
      cad_base(ki,m) = sqrt(mean(E(lin_base{ki}).^2));
   end
   clear E
   if mod(m, 4) == 0 || m == n_m
      fprintf("  %2d/%2d\n", m, n_m);
   end
end

%% ---- check: K = 1 visits the whole lead-1 column, so it must match it ----
i1 = find(K_list == 1, 1);
d_chk = 0;
for m = 1:n_m
   col = double(E4(:, 1, :, m));
   d_chk = max(d_chk, abs(cad_all(i1,m) - sqrt(mean(col(:).^2))));
end
fprintf("\ncheck K = 1 against the atlas lead-1 column: max difference %.3e $/MWh\n", d_chk);
assert(d_chk < 1e-6, 'cadence re-indexing is wrong: %.3e $/MWh', d_chk);
fprintf("  RE-INDEXING CONSISTENT\n");

%% ---- the equal-weight combination ----
ec_all = accK / n_m;
cad_comb = sqrt(mean(ec_all.^2, 1))';
Rall_comb = sqrt(mean(double(accA).^2 / n_m^2, 'all'));
clear accA

%% ---- table: pooled RMSE per cadence ----
names = string({reg.name});
fprintf("\n%-26s %9s", "model", "atlas");
for ki = 1:n_K, fprintf("%10s", "K = " + string(K_list(ki))); end
fprintf("\n");
for m = 1:n_m
   fprintf("%-26s %9.2f", names(m), Rall(m));
   for ki = 1:n_K, fprintf("%10.2f", cad_all(ki,m)); end
   fprintf("\n");
end
fprintf("%-26s %9.2f", "equal weights, all models", Rall_comb);
for ki = 1:n_K, fprintf("%10.2f", cad_comb(ki)); end
fprintf("\n");

%% ---- table: same-horizon comparison for the champion ----
h_show = [1 6 12 36 72 144 288];
h_lab  = {'5min','30min','1h','3h','6h','12h','24h'};
i_champ = model_index("anchor_mix");
fprintf("\nsame-horizon RMSE, %s, only cadences that reach h\n", names(i_champ));
fprintf("%-18s", "cadence");
for k = 1:numel(h_show), fprintf("%10s", h_lab{k}); end
fprintf("\n");
for ki = 1:n_K
   fprintf("K = %-6d %-7s", K_list(ki), K_lab{ki});
   for k = 1:numel(h_show)
      h = h_show(k);
      if h <= K_list(ki)
         fprintf("%10.2f", cad_lead(ki, h, i_champ));
      else
         fprintf("%10s", "-");
      end
   end
   fprintf("\n");
end

%% ---- best single model and best cadence ----
fprintf("\nbest single model per cadence:\n");
for ki = 1:n_K
   [v, mi] = min(cad_all(ki,:));
   fprintf("  K = %-4d (%s)  %7.3f  %s\n", K_list(ki), K_lab{ki}, v, names(mi));
end
fprintf("\ncost of staleness alone, same refresh origins, champion %s\n", names(i_champ));
fprintf("%-18s %12s %12s %10s\n", "cadence", "every step", "every K", "delta");
for ki = 1:n_K
   b = cad_base(ki, i_champ);  c = cad_all(ki, i_champ);
   fprintf("K = %-6d %-7s %12.3f %12.3f %+9.2f%%\n", K_list(ki), K_lab{ki}, ...
      b, c, 100*(c/b - 1));
end

fprintf("\nloss from refreshing less often, champion %s, compared with refreshing every step on every origin\n", names(i_champ));
base = cad_all(i1, i_champ);
for ki = 1:n_K
   fprintf("  K = %-4d (%s)  %7.3f  %+6.2f%%\n", K_list(ki), K_lab{ki}, ...
      cad_all(ki,i_champ), 100*(cad_all(ki,i_champ)/base - 1));
end

fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
save(fullfile(fig_dir, "cadence_sweep.mat"), "K_list", "K_lab", "cad_all", ...
   "cad_lead", "cad_comb", "cad_base", "names", "Rall", "n_d", "-v7.3");
fprintf("\nsweep written to %s\n", fullfile(fig_dir, "cadence_sweep.mat"));
fprintf("### SCRIPT COMPLETED ###\n");
