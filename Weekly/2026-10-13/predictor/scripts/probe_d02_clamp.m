function probe_d02_clamp()
   % PROBE_D02_CLAMP  Where the rebuilt clamp and the official cube disagree.
   %
   % One scored day, all band columns. Prints how many cells differ, by how much,
   % and whether the official forecast is stored clamped, which decides whether the
   % clamp has to be rebuilt at all.
   %
   % Run: runs\run_probe_d02_clamp.bat

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
   fprintf("warm-up %d samples, test %d samples\n", numel(y_win0), numel(y_test));

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
   yc_seq = clamp_price(y_test, [q1_seq, q2_seq]);
   fprintf("q_by_day around the scored window:\n");
   for d = 28:34
      fprintf("  day %2d  q1 %8.3f  q2 %8.3f\n", d, q_by_day(d, 1), q_by_day(d, 2));
   end

   for dd = [1 16 32]
      Eo = double(O.E4_off(1:n_s, band, dsc(dd)));
      Ocl = double(O.O4(1:n_s, band, dsc(dd)));
      j = (dsc(dd) - 1) * n_s + (1:n_s)';
      jt = j + step_b;
      jc = min(max(jt, 1), numel(yc_seq));
      yv = yc_seq(jc);
      qv1 = q1_seq(jc);
      qv2 = q2_seq(jc);
      Yc = yv;
      PoC = Yc - Eo;
      Ochk = min(max(Ocl, qv1), qv2);
      dv = abs(PoC - Ochk);
      fprintf("\nday index %d (window day %d): target day %d to %d\n", ...
         dd, dsc(dd), min(floor((jt(:) - 1) / n_s)) + 1, max(floor((jt(:) - 1) / n_s)) + 1);
      fprintf("  official forecast: min %.2f  median %.2f  max %.2f\n", ...
         min(Ocl(:)), median(Ocl(:)), max(Ocl(:)));
      fprintf("  clamp Q2 on those targets: min %.2f  max %.2f\n", min(qv2(:)), max(qv2(:)));
      fprintf("  O4 above its Q2: %d cells, O4 below its Q1: %d cells\n", ...
         sum(Ocl(:) > qv2(:)), sum(Ocl(:) < qv1(:)));
      fprintf("  rebuilt clamped forecast vs clamp(O4): %d cells, >0.01: %d, >1: %d, max %.3g\n", ...
         numel(dv), sum(dv(:) > 0.01), sum(dv(:) > 1), max(dv(:)));
      q = quantile(dv(:), [0.5 0.9 0.99 0.999 1]);
      fprintf("  quantiles of the difference: %s\n", mat2str(q, 4));
      fprintf("  rebuilt forecast == O4 on %d of %d cells\n", sum(abs(PoC(:) - Ocl(:)) < 1e-3), numel(dv));
      fprintf("  |rebuilt - O4| quantiles: %s\n", ...
         mat2str(quantile(abs(PoC(:) - Ocl(:)), [0.5 0.9 0.99 1]), 4));
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
