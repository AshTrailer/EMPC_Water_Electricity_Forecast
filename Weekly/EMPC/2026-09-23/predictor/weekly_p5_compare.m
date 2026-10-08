function out = weekly_p5_compare(actual_csv, p5_csv, warmup_days, ar_order, tpl_window)
   % WEEKLY_P5_COMPARE  Score "template + intraday AR(4)" against AEMO's own P5
   % forecast and against persistence, on the NEMWEB-archive VIC1 window.
   %
   %   Why: the professor's brief is to predict the error of AEMO's official
   %   forecast rather than the price itself, which means the existing best
   %   short-term model has to be scored on exactly the same targets and leads
   %   as AEMO's P5 product. This routine does that on the realised-price series
   %   rebuilt from the NEMWEB archive (AEMO_Data/forecast_actual/).
   %
   %   Timing convention. A P5 batch published for effective time k_i appears
   %   about 5 min before k_i, and the realised price for interval k_i is
   %   published at the same moment. So at that instant the fair information set
   %   is "actuals up to and including k_i", and the batch's entry for target
   %   k_i + 5h is an h-step-ahead forecast from there. This routine therefore
   %   UPDATES the predictor with y(k_i) first and only then forecasts
   %   k_i .. k_i+55min, so both forecasters see the same information.
   %
   %   h = 0 is dropped from the comparison: AEMO's h=0 entry is the dispatch
   %   target for the interval it belongs to, not a forecast of an unknown.
   %
   %   Inputs
   %      actual_csv   dispatch_5min.csv (settlement_date, region_id, rrp, ...)
   %      p5_csv       p5min.csv        (effective_time, region_id,
   %                                     interval_datetime, rrp, ...)
   %      warmup_days  days of online warm-up before scoring (default 10)
   %      ar_order     intraday residual AR order (default 4)
   %      tpl_window   rolling template window in days (default 28)
   %
   %   Output: table with one row per (origin, lead) holding
   %      origin, target, h, y, y_aemo, y_tar, y_pers, e_aemo, e_tar, e_pers
   %
   %   Note: this function returns data only - it never writes a file, so the
   %   caller decides where results land.

   arguments
      actual_csv (1,1) string
      p5_csv (1,1) string
      warmup_days (1,1) double = 10
      ar_order (1,1) double = 4
      tpl_window (1,1) double = 28
   end

   project_root = "C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project";
   predictor_root = fullfile(project_root, "Predicitor");
   addpath(project_root);
   addpath(genpath(predictor_root));

   n_slots = 288;
   rls_lambda = 0.98;
   rls_delta = 100;
   region = "VIC1";

   % ---------------- actuals ----------------
   A = readtable(actual_csv);
   A.region_id = string(A.region_id);
   A = A(A.region_id == region, :);
   A.settlement_date = datetime(A.settlement_date, "InputFormat", "yyyy-MM-dd HH:mm:ss");
   A = sortrows(A, "settlement_date");
   t_act = A.settlement_date;
   y_act = double(A.rrp);

   % ---------------- AEMO P5 ----------------
   F = readtable(p5_csv);
   F.region_id = string(F.region_id);
   F = F(F.region_id == region, :);
   F.effective_time = datetime(F.effective_time, "InputFormat", "yyyy-MM-dd HH:mm:ss");
   F.interval_datetime = datetime(F.interval_datetime, "InputFormat", "yyyy-MM-dd HH:mm:ss");
   F.h = round(minutes(F.interval_datetime - F.effective_time) / 5);
   F = F(F.h >= 0, :);

   origins = unique(F.effective_time);
   origins = sort(origins);

   % only keep origins that the actual series also covers
   have = ismember(origins, t_act);
   origins = origins(have);

   % ---------------- warm-up phase ----------------
   t0 = origins(1);
   t_warm_end = t0 + days(warmup_days);
   warm_mask = t_act < t_warm_end;
   fprintf("warm-up: %s .. %s (%d points)\n", ...
      char(t_act(find(warm_mask, 1, 'first'))), ...
      char(t_act(find(warm_mask, 1, 'last'))), sum(warm_mask));
   fprintf("scoring: %s .. %s (%d origins)\n", ...
      char(origins(warmup_days * n_slots + 1)), char(origins(end)), ...
      numel(origins) - warmup_days * n_slots);

   st = init_template_ar(n_slots, ar_order, tpl_window, rls_lambda, rls_delta);
   for i = find(warm_mask)'
      st = update_template_ar(st, get_slot_index(t_act(i)), y_act(i));
   end

   % ---------------- scoring loop ----------------
   n_lead = 11;                                   % h = 1..11  (5 .. 55 min)
   y_by_time = containers.Map(cellstr(string(t_act, "yyyy-MM-dd HH:mm:ss")), num2cell(y_act));

   n_org = numel(origins) - warmup_days * n_slots;
   origin_col = NaT(n_org * n_lead, 1);
   target_col = NaT(n_org * n_lead, 1);
   h_col = zeros(n_org * n_lead, 1);
   y_col = nan(n_org * n_lead, 1);
   aemo_col = nan(n_org * n_lead, 1);
   tar_col = nan(n_org * n_lead, 1);
   tpl_col = nan(n_org * n_lead, 1);
   pers_col = nan(n_org * n_lead, 1);
   row = 0;

   f_origin = F.effective_time;
   f_target = F.interval_datetime;
   f_h = F.h;
   f_rrp = double(F.rrp);

   for i = (warmup_days * n_slots + 1):numel(origins)
      k_i = origins(i);
      key = char(string(k_i, "yyyy-MM-dd HH:mm:ss"));
      if ~isKey(y_by_time, key)
         continue;
      end
      y_now = y_by_time(key);

      % update FIRST so the predictor has exactly the information AEMO had
      st = update_template_ar(st, get_slot_index(k_i), y_now);

      slot = get_slot_index(k_i);
      % y_hat = template + iterated intraday AR residual (the model under test)
      % t_vec = template alone, kept as a reference column
      [y_hat, ~, t_vec] = predict_template_ar(st, slot, n_slots);

      sel = (f_origin == k_i) & (f_h >= 1) & (f_h <= n_lead);
      idx = find(sel);
      for j = 1:numel(idx)
         h = f_h(idx(j));
         row = row + 1;
         origin_col(row) = k_i;
         target_col(row) = f_target(idx(j));
         h_col(row) = h;
         aemo_col(row) = f_rrp(idx(j));
         tar_col(row) = y_hat(h + 1);            % target_slots: u(h+1) = slot + h
         tpl_col(row) = t_vec(h + 1);
         pers_col(row) = y_now;
         tk = char(string(f_target(idx(j)), "yyyy-MM-dd HH:mm:ss"));
         if isKey(y_by_time, tk)
            y_col(row) = y_by_time(tk);
         end
      end
      if mod(i, 2000) == 0
         fprintf("  scored origin %d / %d\n", i, numel(origins));
      end
   end

   keep = row > 0;
   out = table(origin_col(1:row), target_col(1:row), h_col(1:row), y_col(1:row), ...
      aemo_col(1:row), tar_col(1:row), tpl_col(1:row), pers_col(1:row), ...
      'VariableNames', {'origin', 'target', 'h', 'y', 'y_aemo', 'y_tar', 'y_tpl', ...
                        'y_pers'});
   out.e_aemo = out.y - out.y_aemo;
   out.e_tar = out.y - out.y_tar;
   out.e_tpl = out.y - out.y_tpl;
   out.e_pers = out.y - out.y_pers;
   assert(keep, 'no rows scored');
end
