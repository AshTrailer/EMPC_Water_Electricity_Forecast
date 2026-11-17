%% export_figures.m  --  caller-side export for run_predictor_suite.m
%
%  The suite itself never writes a file (repository rule: no saveas/print/
%  exportgraphics/writematrix inside MATLAB scripts). This wrapper runs it and
%  exports every figure it produced, in the same MATLAB call, because the host
%  clears figure windows between calls.
%
%  The PNG file name comes from each figure's own Name property, so this
%  wrapper does not need editing when the suite changes its figure set.
%
%  Usage:  run('...\Weekly\EMPC\2026-10-08\predictor\export_figures.m')

set(0, 'DefaultFigureVisible', 'off');     % never steal focus
logfile = 'C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\EMPC\2026-10-08\predictor\suite_console.txt';
diary(logfile); diary on;

run("C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor\run_predictor_suite.m");

outdir = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\EMPC\2026-10-08\predictor\figures";
if ~exist(outdir, "dir")
   mkdir(outdir);
end

f = findall(0, 'Type', 'figure');
[~, order] = sort([f.Number]);
f = f(order);
fprintf("\n[export] %d figures -> %s\n", numel(f), outdir);
for k = 1:numel(f)
   nm = regexprep(string(f(k).Name), '[^A-Za-z0-9_+-]', '_');
   exportgraphics(f(k), fullfile(outdir, nm + ".png"), 'Resolution', 150);
   fprintf("  %s.png\n", nm);
end
fprintf("[export] done\n");
diary off;
