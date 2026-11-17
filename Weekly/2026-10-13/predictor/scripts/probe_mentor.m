function probe_mentor()
   % PROBE_MENTOR  What official_60d.mat holds, and what the long products'
   % horizons actually are. Read only, seconds to run.

   project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   addpath(genpath(fullfile(project_root, "Predicitor")));
   fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
   f = fullfile(fig_dir, "official_60d.mat");
   w = whos("-file", f);
   fprintf("official_60d.mat, %d variables, %.1f MB\n", numel(w), sum([w.bytes])/1e6);
   for i = 1:numel(w)
      fprintf("   %-14s %-10s %s\n", w(i).name, w(i).class, mat2str(w(i).size));
   end

   cfg = official_composite_load(fullfile(project_root, "AEMO_Data"));
   fprintf("\n%-14s %8s %8s %12s %12s %10s\n", "product", "runs", "cols", ...
      "leadmax min", "leadmax h", "step");
   for p = 1:numel(cfg.products)
      pr = cfg.products(p);
      fprintf("%-14s %8d %8d %12.0f %12.1f %10.0f\n", cfg.names(p), numel(pr.eff), ...
         pr.n_col, max(pr.leadmax), max(pr.leadmax)/60, pr.step);
      fprintf("   leadmax percentiles: %.0f %.0f %.0f min\n", ...
         prctile(double(pr.leadmax), [5 50 95]));
   end

   [lead_min, ~, band] = official_lead_axis();
   fprintf("\naxis: %d columns, %.0f to %.0f min\n", numel(lead_min), ...
      lead_min(1), lead_min(end));
   % which columns can carry two products at once, from the horizons alone
   for p = 1:numel(cfg.products)
      pr = cfg.products(p);
      fprintf("%-14s reaches up to %.1f h, step %g min, so columns %d..%d\n", ...
         cfg.names(p), max(pr.leadmax)/60, pr.step, ...
         find(lead_min <= max(pr.leadmax), 1), ...
         find(lead_min <= max(pr.leadmax), 1, "last"));
   end
end
