%% ============================================================
%  BUILD_OFFICIAL_ATLAS  Official AEMO forecast on the atlas grid
%
%  Evaluates OFFICIAL_COMPOSITE at every forecast origin of the 60-day window
%  and stores slot x lead x day cubes, on exactly the indexing the model atlas
%  uses, so the two can be differenced cell by cell without any realignment.
%
%  WINDOW
%     warm-up   153 days, streamed only to seed the causal clamp
%     targets   2026-08-11 .. 2026-10-09, 60 days
%
%  STORED, all (slot x lead x day)
%     O4      the official value, $/MWh, NaN where no run reached the target
%     E4_off  the clamped error against the actual price, $/MWh
%     SRC4    1 P5MIN, 2 PREDISPATCH, 3 PD7DAY, 0 none
%     AGE4    age of the run that supplied the value, minutes
%
%  The axis comes from OFFICIAL_LEAD_AXIS, never from a written-out list.
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(project_root, "MPC", "First_Version_MPC"));
addpath(predictor_root);
addpath(fullfile(predictor_root, "Shared"));
addpath(fullfile(predictor_root, "PriceClamp"));

n_s = 288;  n_q = 30;  n_d = 60;  n_w = 28;

train_start = datetime(2026,3,11,0,5,0);
train_end   = datetime(2026,8,11,0,0,0);
test_start  = datetime(2026,8,11,0,5,0);
test_end    = train_end + days(n_d);

aemo = load_aemo_data(fullfile(project_root, "AEMO_Data"));
t_all = aemo.time;  y_all = aemo.price;

tm = (t_all >= train_start) & (t_all <= train_end);
xm = (t_all >= test_start)  & (t_all <= test_end);
t_train = t_all(tm);  y_train = y_all(tm);
t_test  = t_all(xm);  y_test  = y_all(xm);
n_train = numel(y_train);  n_test = numel(y_test);
assert(n_train == 153*n_s, 'warm-up is not 153 whole days: %d', n_train);
assert(n_test == n_d*n_s, 'test window mismatch: %d', n_test);
t_seq = [t_train; t_test];  y_seq = [y_train; y_test];
n_seq = n_train + n_test;
i_start = n_train + 1;
fprintf("targets %s .. %s (%d days)\n", t_test(1), t_test(end), n_d);

% ---- causal clamp, identical to run_full_ensemble_test.m -------------------
y_win0 = reshape(y_train(end - n_q*n_s + 1:end), n_s, n_q)';
cs = init_price_clamp(y_win0);
q_by_day = zeros(n_d,2); q_by_day(1,:) = cs.q;
for d = 1:n_d-1
   cs = update_price_clamp(cs, y_test((d-1)*n_s + (1:n_s))');
   q_by_day(d+1,:) = cs.q;
end
q1_seq = repelem(q_by_day(:,1), n_s);
q2_seq = repelem(q_by_day(:,2), n_s);
yc_seq = clamp_price(y_test, [q1_seq, q2_seq]);

% ---- the lead axis and the official index ---------------------------------
[lead_min, lead_step, band] = official_lead_axis();
n_h = numel(lead_min);
fprintf("lead axis %d columns, %g min to %g h\n", n_h, lead_min(1), lead_min(end)/60);
cfg = official_composite_load(fullfile(project_root, "AEMO_Data"));

slot_seq = get_slot_index(t_seq);
h_all = lead_step;

% ---- origin loop ----------------------------------------------------------
O4     = nan(n_s, n_h, n_d, 'single');
E4_off = nan(n_s, n_h, n_d, 'single');
SRC4   = zeros(n_s, n_h, n_d, 'uint8');
AGE4   = nan(n_s, n_h, n_d, 'single');

tmr = tic;
for idx = i_start:n_seq
   s = slot_seq(idx);
   u = mod(s - 1 + h_all, n_s) + 1;
   tj = idx + h_all;  jtest = tj - n_train;
   valid = (jtest >= 1) & (jtest <= n_test);
   if ~any(valid), continue; end
   hv = find(valid);
   jv = jtest(valid);
   d_tgt = floor((jv - 1)/n_s) + 1;

   [v, sr, ag] = official_composite(t_seq(idx), lead_min(hv), cfg);

   lin = u(valid) + n_s*(hv - 1) + n_s*n_h*(d_tgt - 1);
   O4(lin) = single(v);
   SRC4(lin) = uint8(sr);

   age_full = nan(numel(hv), 1);
   have = sr > 0;
   age_full(have) = ag(have);
   AGE4(lin) = single(age_full);

   ycv = yc_seq(jv);
   q1 = q1_seq(jv);  q2 = q2_seq(jv);
   ee = nan(numel(hv), 1);
   vv = v(have);
   ee(have) = ycv(have) - clamp_price(vv, [q1(have), q2(have)]);
   E4_off(lin) = single(ee);
end
fprintf("origin loop finished in %.1f s\n", toc(tmr));

% ---- census ---------------------------------------------------------------
have = isfinite(O4);
fprintf("\n--- coverage of the official composite ---\n");
for b = 1:2
   m = band == b;
   sub = have(:, m, :);
   fprintf("  band %d, leads %g to %g min: %d of %d cells have a value (%.1f%%)\n", ...
      b, lead_min(find(m,1)), lead_min(find(m,1,'last')), sum(sub(:)), numel(sub), ...
      100*sum(sub(:))/numel(sub));
end
nm = squeeze(sum(sum(have, 1), 3));            % per lead, over slots and days
ns = squeeze(sum(any(have, 3), 1));            % per lead, slots that ever have a value
nd = squeeze(sum(any(have, 1), 3));            % per lead, days that ever have a value
fprintf("  per-lead coverage:\n");
for k = [1 5 11 12 18 30 58 106 202 376]
   fprintf("    lead %7.1f h  cells %6d of %6d  slots %3d of 288  days %2d of %d\n", ...
      lead_min(k)/60, nm(k), n_s*n_d, ns(k), nd(k), n_d);
end

fprintf("\n--- which product supplied the value ---\n");
for p = 1:numel(cfg.names)
   fprintf("  %-12s %8d cells (%.2f%%)\n", cfg.names(p), sum(SRC4(:) == p), ...
      100*sum(SRC4(:) == p)/numel(SRC4));
end
fprintf("  %-12s %8d cells (%.2f%%)\n", "none", sum(SRC4(:) == 0), ...
   100*sum(SRC4(:) == 0)/numel(SRC4));

fprintf("\n--- age of the supplying run, hours ---\n");
for p = 1:numel(cfg.names)
   a = double(AGE4(SRC4 == p)) / 60;
   if isempty(a), continue; end
   fprintf("  %-12s n %8d  min %5.2f  median %5.2f  max %6.2f\n", ...
      cfg.names(p), numel(a), min(a), median(a), max(a));
end
fprintf("  age at selected leads:\n");
for k = [1 11 12 18 30 58 106 202 376]
   a = double(AGE4(:, k, :));  a = a(:);  a = a(isfinite(a)) / 60;
   if isempty(a), continue; end
   fprintf("    lead %7.1f h  min %6.2f  median %6.2f  max %7.2f  n %6d\n", ...
      lead_min(k)/60, min(a), median(a), max(a), numel(a));
end

% ---- error surface --------------------------------------------------------
d_score = (n_w+1):n_d;
R_off = sqrt(mean(double(E4_off(:, :, d_score)).^2, 3, 'omitnan'));
R_off_all = sqrt(mean(double(E4_off).^2, 3, 'omitnan'));
fp = sqrt(mean(reshape(double(E4_off(:, :, d_score)), [], 1).^2, 'omitnan'));
% mean(A, 'omitnan') averages along the first non-singleton dimension, so
% leaving the dimension out returns a vector and fprintf then recycles the
% format once per element. Assert the shapes instead of trusting them.
assert(isscalar(fp), 'build_official_atlas:fp', ...
   'the pooled fingerprint is %s, not a scalar', mat2str(size(fp)));
assert(isequal(size(R_off), [n_s n_h]), 'build_official_atlas:rsize', ...
   'R_off is %s, expected %s', mat2str(size(R_off)), mat2str([n_s n_h]));
fprintf("\n--- official RMSE ---\n");
fprintf("  over days %d to %d, pooled fingerprint %.3f $/MWh\n", ...
   d_score(1), d_score(end), fp);
for k = [1 11 12 18 58 106 202 376]
   fprintf("    lead %7.1f h  median over 288 slots %8.3f  min %8.3f  max %9.3f\n", ...
      lead_min(k)/60, median(R_off(:, k)), min(R_off(:, k)), max(R_off(:, k)));
end

% ---- save -----------------------------------------------------------------
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
if ~exist(fig_dir, "dir"), mkdir(fig_dir); end
out_name = string(getenv("OFFICIAL_OUT"));
if strlength(out_name) == 0, out_name = "official_60d.mat"; end
save(fullfile(fig_dir, out_name), "O4", "E4_off", "SRC4", "AGE4", ...
   "lead_min", "lead_step", "band", "d_score", "R_off", "R_off_all", ...
   "t_test", "n_d", "n_w", "-v7.3");
fprintf("\nwritten %s (%.0f MB)\n", fullfile(fig_dir, out_name), ...
   (numel(O4)*4 + numel(E4_off)*4 + numel(AGE4)*4 + numel(SRC4))/1048576);

% ---- one day as CSV, for inspection outside MATLAB ------------------------
csv_day = string(getenv("OFFICIAL_CSV_DAY"));
if strlength(csv_day) == 0, csv_day = "2026-09-01"; end
csv_out = fullfile(project_root, "Weekly", "2026-10-13", "predictor", "runs", ...
   "official_sample_" + csv_day + ".csv");
write_day_csv(csv_out, t_test, csv_day, lead_min, cfg, n_s);
fprintf("### SCRIPT COMPLETED ###\n");

%% ---------- local helpers ----------
function write_day_csv(path, t_test, day, lead_min, cfg, n_s)
   want = datetime(day, "InputFormat", "yyyy-MM-dd");
   idx = find(dateshift(t_test, "start", "day") == want);
   assert(~isempty(idx), 'build_official_atlas:csv_day', ...
      'no test samples on %s', day);
   idx = idx(1:n_s);
   C = cell(n_s*numel(lead_min) + 1, 6);
   C(1,:) = {'origin_time','lead_min','target_time','value','source','age_min'};
   r = 1;
   for i = 1:n_s
      [v, ~, ag, tgt, nm] = official_composite(t_test(idx(i)), lead_min, cfg);
      for k = 1:numel(lead_min)
         r = r + 1;
         C{r,1} = datestr(t_test(idx(i)), 'yyyy-mm-dd HH:MM:SS');
         C{r,2} = sprintf('%g', lead_min(k));
         C{r,3} = datestr(double(tgt(k))/1440 + datenum(2025,1,1), 'yyyy-mm-dd HH:MM:SS');
         if isnan(v(k))
            C{r,4} = '';
         else
            C{r,4} = sprintf('%.5f', v(k));
         end
         C{r,5} = char(nm(k));
         if isnan(ag(k))
            C{r,6} = '';
         else
            C{r,6} = sprintf('%g', ag(k));
         end
      end
   end
   fid = fopen(path, 'w');
   assert(fid > 0, 'build_official_atlas:csv_open', 'cannot write %s', path);
   for i = 1:size(C,1)
      fprintf(fid, '%s,%s,%s,%s,%s,%s\n', C{i,:});
   end
   fclose(fid);
   fprintf("csv evidence: %s (%d rows)\n", path, size(C,1)-1);
end
