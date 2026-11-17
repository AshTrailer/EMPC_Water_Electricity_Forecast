%% ============================================================
%  VERIFY_OFFICIAL_COMPOSITE  Check the composite against an independent path
%
%  Every check below deliberately avoids the code it is checking:
%    - the P5MIN band is compared against the raw CSV read here, through a
%      containers.Map keyed on the two timestamps, not through the closed-form
%      column arithmetic OFFICIAL_COMPOSITE_LOAD uses;
%    - the stored cube is compared against OFFICIAL_COMPOSITE re-evaluated
%      from the source files;
%    - the CSV evidence file is compared against the cube it came from.
%
%  Run: matlab -batch "run('...\Weekly\2026-10-13\predictor\scripts\verify_official_composite.m')"
% ============================================================
clear; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(project_root, "MPC", "First_Version_MPC"));
addpath(predictor_root);
addpath(fullfile(predictor_root, "Shared"));

n_s = 288;  n_d = 60;
fails = strings(0);

%% ---- load the atlas cubes ------------------------------------------------
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
S = load(fullfile(fig_dir, "official_60d.mat"));
O4 = S.O4;  SRC4 = S.SRC4;  AGE4 = S.AGE4;
lead_min = S.lead_min;
n_h = numel(lead_min);
[n_sa, n_ha, n_da] = size(O4);
assert(n_sa == n_s && n_ha == n_h && n_da == n_d, 'verify:shape', ...
   'cube is %dx%dx%d, expected %dx%dx%d', n_sa, n_ha, n_da, n_s, n_h, n_d);
have = isfinite(O4);
fprintf("cube %d x %d x %d, %.0f MB, %.1f%% of cells carry a value\n", ...
   n_sa, n_ha, n_da, numel(O4)*4/1048576, 100*sum(have(:))/numel(have));

t_seq = S.t_test;
origins = t_seq(1:end-1);          % the last sample has no target in the window
[~, o_idx] = ismember(datetime(origins), t_seq);
d_of = floor((o_idx - 1)/n_s) + 1;

% The cell a value belongs to is indexed by the TARGET's day, not the origin's.
% A lead inside the first hour still crosses midnight for late origins, and
% reading the origin's day there silently compares different days.
day_of_target = @(t) floor(round(minutes(t - t_seq(1))) / (5*n_s)) + 1;

%% ---- check 1: the 5-minute band against the raw P5MIN file ---------------
p5_path = fullfile(project_root, "AEMO_Data", "window_60d_20260811_20261009", ...
   "p5min_vic1_partial", "p5min_20260811_20261009.csv");
fid = fopen(p5_path, 'r');
c = textscan(fid, '%s %s %s %s %s %s', 'Delimiter', ',', 'HeaderLines', 1);
fclose(fid);
M = containers.Map(cellstr(strcat(string(c{1}), "|", string(c{3}))), ...
   num2cell(str2double(c{4})));
fprintf("independent P5MIN map: %d keys\n", M.Count);

n_band1 = sum(lead_min <= 55);
pick = round(linspace(1, numel(origins), 60));
worst = 0;  n_cmp = 0;  n_dropped = 0;  n_invented = 0;
for i = pick
   o = origins(i);
   for k = 1:n_band1
      tgt = o + minutes(lead_min(k));
      dt = day_of_target(tgt);
      % Targets that fall past the end of the window are not scored and have no
      % cell in the cube, so there is nothing to compare them against.
      if dt < 1 || dt > n_d, continue; end
      key = char(string(datestr(o, 'yyyy-mm-dd HH:MM:SS')) + "|" + ...
         string(datestr(tgt, 'yyyy-mm-dd HH:MM:SS')));
      got = double(O4(slot_of(tgt, n_s), k, dt));
      if isKey(M, key)
         if isnan(got)
            n_dropped = n_dropped + 1;
         else
            n_cmp = n_cmp + 1;
            worst = max(worst, abs(got - M(key)));
         end
      elseif ~isnan(got)
         n_invented = n_invented + 1;
      end
   end
end
fprintf("check 1, P5MIN band against the raw file: %d compared, worst |diff| %.3g, dropped %d, invented %d\n", ...
   n_cmp, worst, n_dropped, n_invented);
if worst > 1e-4 || n_dropped > 0 || n_invented > 0
   fails(end+1) = "check 1: the 5-minute band does not reproduce the P5MIN file";
end

%% ---- check 2: the cube against the callable ------------------------------
cfg = official_composite_load(fullfile(project_root, "AEMO_Data"));
worst2 = 0;  mismatch = 0;  n2 = 0;
pick2 = round(linspace(1, numel(origins), 12));
for i = pick2
   o = origins(i);
   [v, sr, ag] = official_composite(o, lead_min, cfg);
   for k = 1:n_h
      tgt = o + minutes(lead_min(k));
      dt = day_of_target(tgt);
      if dt < 1 || dt > n_d, continue; end
      s_tgt = slot_of(tgt, n_s);
      got = double(O4(s_tgt, k, dt));
      if isnan(v(k)) && isnan(got), continue; end
      n2 = n2 + 1;
      if isnan(v(k)) || isnan(got)
         mismatch = mismatch + 1;
         continue
      end
      worst2 = max(worst2, abs(v(k) - got));
      if uint8(sr(k)) ~= SRC4(s_tgt, k, dt), mismatch = mismatch + 1; end
      if abs(ag(k) - double(AGE4(s_tgt, k, dt))) > 1e-4, mismatch = mismatch + 1; end
   end
end
fprintf("check 2, cube against the callable: %d cells, worst |diff| %.3g, mismatches %d\n", ...
   n2, worst2, mismatch);
% The cube is stored single, so the comparison is against single rounding, not
% against exact equality. At 23200 $/MWh one single ULP is 0.002.
if worst2 > 1e-5 * max(abs(S.O4(:))) || mismatch > 0
   fails(end+1) = "check 2: the stored cube disagrees with OFFICIAL_COMPOSITE";
end

%% ---- check 3: the structural shape of the 5-minute band -----------------
% Inside the first hour the only cells that can be absent are those whose
% origin falls before the first official publication, midnight on 2026-08-11.
% Those are exactly the day-1 cells whose origin crosses midnight, so at lead
% index k the number of absent cells must be exactly k, for k = 1 to 11.
absent = zeros(1, n_band1);
for k = 1:n_band1
   absent(k) = sum(~have(:, k, 1));
end
fprintf("check 3, absent cells on scored day 1 by lead index: %s\n", mat2str(absent));
if ~isequal(absent, 1:n_band1)
   fails(end+1) = "check 3: absent band-1 cells are not the midnight-crossing set";
end
if any(SRC4(:, 1:n_band1, :) ~= 1 & have(:, 1:n_band1, :), 'all')
   fails(end+1) = "check 3: a band-1 cell was supplied by something other than P5MIN";
end

%% ---- check 4: what supplies the far end ---------------------------------
fprintf("check 4, source mix:\n");
for b = 1:2
   m = (lead_min >= 60) == (b == 2);
   sub = SRC4(:, m, :);
   tot = numel(sub);
   fprintf("  band %d: P5MIN %5.2f%%  PREDISPATCH %5.2f%%  PD7DAY %5.2f%%  none %5.2f%%\n", ...
      b, 100*sum(sub(:) == 1)/tot, 100*sum(sub(:) == 2)/tot, ...
      100*sum(sub(:) == 3)/tot, 100*sum(sub(:) == 0)/tot);
end
k39 = find(lead_min > 2340, 1);
assert(~isempty(k39), 'verify:k39', 'the axis has no lead past 39 hours');
% sum(X) on a 3-D array reduces only the first dimension, so the obvious
% sum(sum(X)) still returns a vector and fprintf then recycles its format once
% per element. 'all' is the only form that is guaranteed to be a scalar.
bad39 = sum(SRC4(:, k39:end, :) == 2, 'all');
fprintf("  PREDISPATCH cells past the 39 h horizon: %d (must be 0)\n", bad39);
if bad39 > 0
   fails(end+1) = "check 4: PREDISPATCH is credited beyond its own horizon";
end
% P5MIN must never be credited past its own 55-minute horizon
bad55 = sum(SRC4(:, n_band1+1:end, :) == 1, 'all');
fprintf("  P5MIN cells past the 55 min horizon: %d (must be 0)\n", bad55);
if bad55 > 0
   fails(end+1) = "check 4: P5MIN is credited beyond its own horizon";
end
a = double(AGE4(SRC4 == 3)) / 60;
fprintf("  PD7DAY staleness at the origin: min %.2f h, median %.2f h, max %.2f h\n", ...
   min(a), median(a), max(a));
% PD7DAY publishes at 07:30, 13:00 and 18:00, so the overnight gap is 13.5
% hours and that, not the 5.5-hour daytime gap, is the bound.
if max(a) > 13.6
   fails(end+1) = "check 4: a PD7DAY run is older than one publication gap";
end

%% ---- check 5: the CSV evidence file against the cube --------------------
csv_path = fullfile(project_root, "Weekly", "2026-10-13", "predictor", "runs", ...
   "official_sample_2026-09-01.csv");
if isfile(csv_path)
   fid = fopen(csv_path, 'r');
   e = textscan(fid, '%s %f %s %s %s %f', 'Delimiter', ',', 'HeaderLines', 1);
   fclose(fid);
   e_ot = double(nem_minutes(e{1}));       % double: NEM minutes are combined below
   e_L = e{2};
   e_val = string(e{4});
   e_src = string(e{5});
   n5 = numel(e_ot);

   % Resolve everything as vectors. Looking the origin up row by row against
   % the 17280-sample grid is 108288 times 17280 comparisons and never finishes.
   otmin = double(nem_minutes(t_seq));
   [hit, jj] = ismember(e_ot, otmin);
   assert(all(hit), 'verify:csv_origin', ...
      '%d CSV rows carry an origin outside the scored window', sum(~hit));

   tod = mod(e_ot + e_L, 1440);  tod(tod == 0) = 1440;
   s5 = round(tod / 5);
   [has_lead, k5] = ismember(e_L, lead_min);
   assert(all(has_lead), 'verify:csv_lead', ...
      '%d CSV rows carry a lead not on the axis', sum(~has_lead));

   % The day comes from the TARGET, not from the origin. The slot index folds
   % at midnight, so deriving the day from the slot recovers nothing.
   d5 = floor((e_ot + e_L - otmin(1)) / 1440) + 1;
   keep5 = d5 >= 1 & d5 <= n_d;

   % Rows whose target falls past the window have no cell, so they are dropped
   % before indexing rather than clipped onto day 60.
   e_ot = e_ot(keep5);  e_L = e_L(keep5);  e_val = e_val(keep5);
   e_src = e_src(keep5);  s5 = s5(keep5);  k5 = k5(keep5);  d5 = d5(keep5);
   n5 = numel(d5);

   li = sub2ind(size(O4), s5, k5, d5);
   got = double(O4(li));
   filled = strlength(e_val) > 0;
   worst5 = 0;
   bad5 = sum(filled & isnan(got)) + sum(~filled & ~isnan(got));
   both = filled & ~isnan(got);
   if any(both)
      worst5 = max(abs(got(both) - str2double(e_val(both))));
   end
   sg = e_src;
   sg(sg == "") = "none";
   nm = cfg.names(:);
   sid = double(SRC4(li));
   ref = repmat("none", n5, 1);
   nz = sid > 0;
   ref(nz) = nm(sid(nz));
   bad5 = bad5 + sum(sg ~= ref);

   fprintf("check 5, CSV evidence against the cube: %d rows, worst |diff| %.3g, mismatches %d\n", ...
      n5, worst5, bad5);
   % The CSV is written from the double OFFICIAL_COMPOSITE returns, the cube is
   % stored single, so the expected difference is single rounding and not zero.
   % At 23200 $/MWh one single ULP is 0.002.
   if worst5 > 1e-5 * max(abs(S.O4(:))) || bad5 > 0
      fails(end+1) = "check 5: the CSV evidence file disagrees with the cube";
   end
else
   fprintf("check 5 skipped, %s not present\n", csv_path);
end

%% ---- verdict ------------------------------------------------------------
fprintf("\n");
if isempty(fails)
   fprintf("### ALL CHECKS PASSED ###\n");
else
   for f = fails, fprintf("FAIL %s\n", f); end
   error('verify_official_composite:failed', '%d checks failed', numel(fails));
end

%% ---------- local helpers ----------
function s = slot_of(t, n_slots)
   % Slot index of a NEM timestamp: slot 1 is the interval ending 00:05 and
   % slot 288 is the one ending 24:00 of the same nominal day.
   m = round(minutes(t - dateshift(t, 'start', 'day')));
   if m == 0, m = 1440; end
   s = round(m / 5);
   assert(s >= 1 && s <= n_slots, 'slot_of: %s maps to %d', datestr(t), s);
end
