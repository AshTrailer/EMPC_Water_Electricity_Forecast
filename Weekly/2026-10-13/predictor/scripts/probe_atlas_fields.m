function probe_atlas_fields()
   % PROBE_ATLAS_FIELDS  Variable census of every score cube on disk.
   %
   % D02 and D03 both need the forecast value itself, not only the stored error,
   % because the stored error is a clamped actual minus a clamped forecast. This
   % lists what each cube holds so the diagnostic is written against a cube that
   % has the forecast, or against one whose clamp can be undone.
   %
   % Run: runs\run_probe_atlas_fields.bat

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   fig_dir = fullfile(root, "AEMO_Data", "level_multiwindow_figs");
   files = ["atlas_60d.mat", "atlas_full.mat", "atlas_ext.mat", "atlas_regress.mat", ...
      "atlas_v3.mat", "atlas_v4.mat", "atlas_v5.mat", "official_60d.mat", "ar_sweep.mat"];

   for f = files
      p = fullfile(fig_dir, f);
      if ~isfile(p), fprintf("\n=== %s  MISSING ===\n", f); continue; end
      w = whos("-file", p);
      fprintf("\n=== %s  %d variables ===\n", f, numel(w));
      for i = 1:numel(w)
         fprintf("  %-16s %-10s %-24s %10d bytes\n", w(i).name, w(i).class, ...
            mat2str(w(i).size), w(i).bytes);
      end
   end
end
