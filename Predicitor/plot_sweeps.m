%% ============================================================
%  PLOT_SWEEPS  Figures for the AR order sweep and the refresh cadence sweep
%
%  Reads AEMO_Data/level_multiwindow_figs/ar_sweep.mat and cadence_sweep.mat.
%  Figure titles are short labels, the reading is left to the caption, which is
%  the convention of the two reference decks.
%
%  Writes ar_order_sweep.png and cadence_sweep.png next to the data.
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(predictor_root, "Shared"));
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");

ink = [0.106 0.141 0.188];      % 1B2430
navy = [0.118 0.153 0.380];     % 1E2761
teal = [0.055 0.486 0.482];     % 0E7C7B
amber = [0.914 0.659 0.125];    % E9A820
grey = [0.353 0.420 0.482];     % 5A6B7B

%% ---------------- AR order ----------------
A = load(fullfile(fig_dir, "ar_sweep.mat"));
p_list = A.p_list;  Rp_all = A.Rp_all;  Rp_lead = A.Rp_lead;
[best, ib] = min(Rp_all);

fh = figure('Name', 'AR order', 'Position', [60 60 1180 470]);
tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile; hold on;
plot(p_list, Rp_all, '-', 'Color', navy, 'LineWidth', 2, 'Marker', 'o', 'MarkerSize', 2);
plot(p_list(ib), best, 'o', 'Color', amber, 'MarkerSize', 8, 'MarkerFaceColor', amber);
yline(Rp_all(4), ':', 'Color', grey, 'LineWidth', 1);
hold off; grid on; box off;
xlabel('AR order p'); ylabel('pooled RMSE ($/MWh)');
title('Whole atlas', 'FontSize', 11, 'Color', ink);
text(p_list(ib), best, sprintf('  best p = %d, %.2f', p_list(ib), best), ...
   'FontSize', 9, 'Color', ink, 'VerticalAlignment', 'bottom');

nexttile; hold on;
h_show = [1 12 72 288];
h_lab  = {'5 min', '1 h', '6 h', '24 h'};
cols = [teal; navy; amber; grey];
for k = 1:numel(h_show)
   plot(p_list, Rp_lead(:, h_show(k)), '-', 'Color', cols(k,:), 'LineWidth', 1, ...
      'DisplayName', h_lab{k});
end
hold off; grid on; box off;
xlabel('AR order p'); ylabel('RMSE ($/MWh)');
title('By lead', 'FontSize', 11, 'Color', ink);
legend('Location', 'northwest', 'FontSize', 9, 'Box', 'off');

title(tl, 'AR order', 'FontSize', 13, 'Color', ink);
subtitle(tl, sprintf('VIC1 5-min RRP, 120 days, clamped, ingest-first, %d orders', numel(p_list)), ...
   'FontSize', 8, 'Color', grey);
exportgraphics(fh, fullfile(fig_dir, "ar_order_sweep.png"), 'Resolution', 130);
fprintf("wrote ar_order_sweep.png\n");

%% ---------------- refresh cadence ----------------
C = load(fullfile(fig_dir, "cadence_sweep.mat"));
K_list = C.K_list;  K_lab = C.K_lab;  cad_all = C.cad_all;  cad_comb = C.cad_comb;
cad_base = C.cad_base;  names = string(C.names);

i_champ = model_index("anchor_mix");
x = 1:numel(K_list);

fh = figure('Name', 'Refresh cadence', 'Position', [80 80 1180 470]);
tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile; hold on;
plot(x, cad_all(:, i_champ), '-o', 'Color', navy, 'LineWidth', 2, 'MarkerSize', 3, ...
   'DisplayName', names(i_champ));
plot(x, cad_comb, '-s', 'Color', teal, 'LineWidth', 2, 'MarkerSize', 3, ...
   'DisplayName', 'Equal weights, all models');
hold off; grid on; box off;
set(gca, 'XTick', x, 'XTickLabel', K_lab);
xlabel('Refresh interval'); ylabel('pooled RMSE ($/MWh)');
title('Pooled', 'FontSize', 11, 'Color', ink);
legend('Location', 'northwest', 'FontSize', 9, 'Box', 'off');

nexttile; hold on;
% Fair comparison: on the SAME refresh origins, refreshing every step costs
% cad_base, refreshing every K costs cad_all. Comparing cadences against each
% other would confound staleness with which origins each cadence samples.
b = bar(x, [cad_base(:,i_champ), cad_all(:,i_champ)], 'grouped');
b(1).FaceColor = grey;  b(2).FaceColor = navy;
b(1).EdgeColor = 'none';  b(2).EdgeColor = 'none';
hold off; grid on; box off;
set(gca, 'XTick', x, 'XTickLabel', K_lab);
xlabel('Refresh interval'); ylabel('pooled RMSE ($/MWh)');
title('Cost of staleness', 'FontSize', 11, 'Color', ink);
legend({'refreshed every step', 'refreshed every K'}, 'Location', 'northwest', ...
   'FontSize', 9, 'Box', 'off');

title(tl, 'Refresh cadence', 'FontSize', 13, 'Color', ink);
subtitle(tl, sprintf('VIC1 5-min RRP, %d days, clamped, ingest-first, model %s', ...
   C.n_d, names(i_champ)), 'FontSize', 8, 'Color', grey);
exportgraphics(fh, fullfile(fig_dir, "cadence_sweep.png"), 'Resolution', 130);
fprintf("wrote cadence_sweep.png\n");
