function probe_d02_offset()
   % PROBE_D02_OFFSET  Which sample of the price series the cube calls the actual.
   %
   % The official forecast is stored unclamped, so clamping it and subtracting it
   % from a candidate actual must reproduce the stored error. Tries the candidate
   % actual offsets one at a time and reports which one closes the identity.
   %
   % Run: runs\run_probe_d02_offset.bat

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   fig_dir = fullfile(root, "AEMO_Data", "level_multiwindow_figs");
   data_dir = fullfile(root, "AEMO_Data");
   addpath(genpath(fullfile(root, "Predicitor")));

   n_s = 288;
   [lead_min, lead_step, ~] = official_lead_axis();
   lead_min = lead_min(:)';
   lead_step = lead_step(:)';
   band = find(lead_min >= 360 & lead_min <= 1440);
   n_b = numel(band);
   step_b = lead_step(band);

   A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
   O = matfile(fullfile(fig_dir, "official_60d.mat"));
   dsc = double(A.d_score);
   dsc = dsc(:)';
   t_test = A.t_test;
   t_test = t_test(:);

   n_q = 30;
   [tp, yp] = read_vic1(data_dir, ["202607", "202608", "202609", "202610"]);
   y_win0 = yp(tp >= datetime(2026, 7, 12, 0, 5, 0) & tp <= datetime(2026, 8, 11, 0, 0, 0));
   mt = tp >= t_test(1) & tp <= t_test(end);
   y_test = yp(mt);
   cs = init_price_clamp(reshape(y_win0, n_s, n_q)');
   n_win = numel(y_test) / n_s;
   q_by_day = zeros(n_win, 2);
   q_by_day(1, :) = cs.q;
   for d = 1:n_win - 1
      cs = update_price_clamp(cs, y_test((d - 1) * n_s + (1:n_s))');
      q_by_day(d + 1, :) = cs.q;
   end
   q1_seq = repelem(q_by_day(:, 1), n_s);
   q2_seq = repelem(q_by_day(:, 2), n_s);

   nmax = numel(y_test);
   off_of_slot = mod(-5 * (0:n_s - 1), 30)';

   names = ["as is", "one sample earlier", "one sample later", ...
      "fold offset later", "fold offset earlier", "five samples later"];
   shifts = [0, -1, 1, NaN, NaN, 5];
   for dd = [1 16 32]
      Eo = double(O.E4_off(1:n_s, band, dsc(dd)));
      Ocl = double(O.O4(1:n_s, band, dsc(dd)));
      j = (dsc(dd) - 1) * n_s + (1:n_s)';
      jt = j + step_b;
      fprintf("\n--- day index %d, window day %d ---\n", dd, dsc(dd));
      fprintf("  official forecast median %.2f, error median %.2f, rms %.2f\n", ...
         median(Ocl(:)), median(Eo(:)), sqrt(mean(Eo(:) .^ 2)));
      for h = 1:numel(names)
         if h == 4
            k = repmat(off_of_slot / 5, 1, n_b);
         elseif h == 5
            k = -repmat(off_of_slot / 5, 1, n_b);
         else
            k = shifts(h) * ones(size(jt));
         end
         jq = min(max(jt + k, 1), nmax);
         yv = y_test(jq);
         qv1 = q1_seq(jq);
         qv2 = q2_seq(jq);
         PoC = yv - Eo;
         dv = abs(PoC - min(max(Ocl, qv1), qv2));
         fprintf("  %-22s median |diff| %9.3f, within 0.01: %5d of %6d\n", ...
            names(h), median(dv(:)), sum(dv(:) < 0.01), numel(dv));
      end
      % candidate: the stored error is raw actual minus raw forecast, no clamp
      y_hyp = Eo + Ocl;
      yr = y_test(min(max(jt, 1), nmax));
      fprintf("  %-22s median |diff| %9.3f, within 0.01: %5d of %6d\n", ...
         "unclamped, error = y - f", median(abs(y_hyp(:) - yr(:))), ...
         sum(abs(y_hyp(:) - yr(:)) < 0.01), numel(Eo));
   end
end

% =========================================================================
function [tp, yp] = read_vic1(data_dir, months)
   T = strings(0, 1);
   V = zeros(0, 1);
   for m = months
      p = fullfile(data_dir, "PRICE_AND_DEMAND_" + m + "_VIC1.csv");
      fid = fopen(p, "r");
      assert(fid > 0, "probe:file", "cannot open %s", p);
      c = textscan(fid, "%s %s %f %f %s", "Delimiter", ",", "HeaderLines", 1);
      fclose(fid);
      keep = string(c{1}) == "VIC1";
      T = [T; string(c{2}(keep))];
      V = [V; c{4}(keep)];
   end
   t = datetime(strrep(T, "/", "-"), "InputFormat", "yyyy-MM-dd HH:mm:ss");
   y = V;
   [t, o] = sort(t);
   y = y(o);
   u = [true; diff(t) > minutes(0)];
   tp = t(u);
   yp = y(u);
end
