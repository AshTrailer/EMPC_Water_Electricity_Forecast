function compare_official_on_deck_object()
   % COMPARE_OFFICIAL_ON_DECK_OBJECT  The official composite and the corrected
   % official composite on the identical object the model table uses: per-cell R
   % over the 32 scored days, the median over the 288 times of day at one lead.
   %
   % The first version of this comparison took the median over DAYS and put it
   % next to the model table's median over SLOTS, which is not the same number and
   % not even the same kind of number. This script fixes the object and nothing
   % else, so the three columns below can be read side by side.
   %
   % Read only.

   project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   addpath(genpath(fullfile(project_root, "Predicitor")));
   fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
   deck_dir = fullfile(project_root, "Weekly", "2026-10-13", "deck");
   out_json = fullfile(deck_dir, "deck_correction.json");

   W = load(fullfile(fig_dir, "official_60d.mat"), "E4_off", "d_score", "lead_min");
   E = double(W.E4_off);
   d_score = double(W.d_score(:)');
   lead_min = double(W.lead_min(:));
   n_s = size(E, 1);  n_h = size(E, 2);
   [~, ~, band] = official_lead_axis();

   col = zeros(1, 3);
   for i = 1:3
      want = [60, 1440, 10980];
      col(i) = find(lead_min == want(i), 1);
   end
   fprintf("horizon columns: %s, leads %s min\n", mat2str(col), mat2str(lead_min(col)'));

   R0 = per_cell_R(E, d_score, 0);
   R14 = per_cell_R(E, d_score, 14);
   med0 = median(R0, 1, "omitnan");
   med14 = median(R14, 1, "omitnan");

   fprintf("\n%-34s %8s %8s %8s\n", "object", "1 h", "24 h", "7.6 d");
   fprintf("%-34s %8.2f %8.2f %8.2f\n", "Official, no correction", med0(col));
   fprintf("%-34s %8.2f %8.2f %8.2f\n", "Official + 14-day correction", med14(col));
   fprintf("%-34s %8.2f %8.2f %8.2f\n", "Official + 14-day, short band only", ...
      median(R14(band == 1, col(1)), "omitnan"), NaN, NaN);

   % The lead where each takes over from the other, on the profile the deck uses.
   t28 = read_model_median(deck_dir, "T28");
   cross0 = find(med0 > t28, 1);
   cross14 = find(med14 > t28, 1);
   fprintf("\nthe plain template holds %.2f at every lead\n", t28);
   fprintf("official crosses it at column %d, corrected official at column %d\n", ...
      cross0, cross14);

   out = struct();
   out.leads_min = [60 1440 10980];
   out.leads_h = [1 24 183];
   out.cols = col;
   out.official_med_over_slots = med0(col);
   out.corrected_med_over_slots = med14(col);
   out.template_med_over_slots = repmat(t28, 1, 3);
   out.cross_col_uncorrected = cross0;
   out.cross_col_corrected = cross14;
   out.median_over_slots_of_column_medians_official = median(med0, "omitnan");
   out.median_over_slots_of_column_medians_corrected = median(med14, "omitnan");
   out.correction_window_days = 14;
   out.object = "per-cell R over the 32 scored days, then the median over the 288 times of day at one lead";
   fid = fopen(out_json, "w");
   fwrite(fid, jsonencode(out, "PrettyPrint", true));
   fclose(fid);
   fprintf("\nwrote %s\n", out_json);
end


function R = per_cell_R(E, d_score, w)
   n_s = size(E, 1);  n_h = size(E, 2);
   R = zeros(n_s, n_h);
   for j = 1:numel(d_score)
      d = d_score(j);
      ec = E(:, :, d);
      if w > 0
         lo = max(1, d - w);
         if lo <= d - 1
            ec = ec - mean(E(:, :, lo:(d - 1)), 3, "omitnan");
         end
      end
      R = R + ec.^2;
   end
   R = sqrt(R / numel(d_score));
end


function v = read_model_median(deck_dir, key)
   J = jsondecode(fileread(fullfile(deck_dir, "deck_numbers_60d.json")));
   v = NaN;
   for i = 1:numel(J.model)
      if string(J.model(i).key) == key
         v = double(J.model(i).med32(1));
      end
   end
end
