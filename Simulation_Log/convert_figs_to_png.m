function convert_figs_to_png()
   % Convert result .fig files to high-resolution PNG with clean names.

   root = "C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\Simulation_Log";
   outdir = fullfile(root, "figures_png");
   if ~exist(outdir, "dir")
      mkdir(outdir);
   end

   jobs = {
      fullfile(root, "Ash_20260827", "Predicitor_AR", "Comparison of three forecasting models.fig"),                                  "exp1_three_models.png"
      fullfile(root, "Ash_20260827", "Predicitor_AR", "Comparison of template window strategies of AR(4) with template.fig"),       "exp2_window_strategies.png"
      fullfile(root, "Ash_20260827", "Predicitor_Order_Testing", "AR_Order_Testing.fig"),                                          "exp3_ar_order.png"
      fullfile(root, "Ash_20260827", "Predicitor_Update_Different", "Update_Time_Different_on_AR_Predicitor.fig"),                  "exp4_update_cadence.png"
      fullfile(root, "Ash_20260827", "Predicitor_Long_Term_Test", "Different_Template_Compare.fig"),                               "exp5_template_class.png"
      fullfile(root, "Ash_20260915", "Two-week Comparison-Week Aligned with clamped prices and 1 step forecast.fig"),              "bench_week_aligned.png"
      fullfile(root, "Ash_20260915", "RMSE vs Lead Time(mean and median over 288 target slots).fig"),                              "bench_rmse_lead.png"
      fullfile(root, "Ash_20260915", "RMSE by target slot(average over 288 lead times).fig"),                                      "bench_rmse_slot.png"
      fullfile(root, "Ash_20260915", "RMSE(slot, lead) with 288x288 matrics.fig"),                                                 "bench_rmse_matrix.png"
   };

   for i = 1:size(jobs, 1)
      p = jobs{i, 1};
      out = fullfile(outdir, jobs{i, 2});
      if ~isfile(p)
         fprintf("SKIP (missing): %s\n", p);
         continue;
      end
      try
         f = openfig(p, "invisible");
         set(f, "Visible", "off");
         exportgraphics(f, out, "Resolution", 200);
         close(f);
         fprintf("OK: %s\n", out);
      catch ME
         fprintf("FAIL %s: %s\n", p, ME.message);
      end
   end
end
