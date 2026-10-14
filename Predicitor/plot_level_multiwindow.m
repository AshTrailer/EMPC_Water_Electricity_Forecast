%% ============================================================
%  PLOT_LEVEL_MULTIWINDOW  Redraw the comparison figures from a saved atlas
%
%  Loads AEMO_Data/level_multiwindow_figs/atlas.mat and draws the two figures
%  of run_level_multiwindow_test.m. Split out so the figures can be redrawn
%  without re-running the 120-day stream.
%
%  Figure 1  Lead profile  how each model's error grows with the forecast lead
%  Figure 2  Error surface which (target time of day, lead) cells each model
%            gets wrong
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
S = load(fullfile(fig_dir, "atlas_full.mat"));   % written by run_full_ensemble_test.m
E4 = S.E4;  names = S.names;  n_days = size(E4, 3);
n_models = numel(names);
hx = (1:288)'/12;
scope = sprintf("VIC1 5-min RRP | %d days | clamped | one forecast per 5-min origin | unit $/MWh", n_days);

% indices into the 12-model atlas
i_T28 = 2;  i_AR4 = 4;  i_ANCH = 8;  i_LVL = 9;  i_MW = 10;  i_MWLVL = 11;  i_MWRUN = 12;

%% ---------- figure 1: lead profile ----------
pick = [i_T28 i_AR4 i_LVL i_MW i_MWLVL i_MWRUN];
fh1 = figure('Name','Lead profile','Position',[60 60 1240 460]);
tl = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
for m = pick
   Rm = sqrt(mean(double(E4(:,:,:,m)).^2, 3));      % 288 slots x 288 leads
   nexttile(1); hold on; plot(hx, mean(Rm,1), 'LineWidth', 1.4);
   nexttile(2); hold on; plot(hx, median(Rm,1), 'LineWidth', 1.4);
end
nexttile(1); grid on; xlim([0 24]); xticks(0:3:24); ylim([0 70]);
xlabel('lead (hour)'); ylabel('pooled RMSE ($/MWh)');
title('pooled over 288 slots', 'FontSize', 10);
legend(names(pick), 'Location', 'northwest', 'FontSize', 8);
nexttile(2); grid on; xlim([0 24]); xticks(0:3:24); ylim([0 70]);
xlabel('lead (hour)'); ylabel('median over slots ($/MWh)');
title('median over 288 slots', 'FontSize', 10);
title(tl, 'Lead profile', 'FontSize', 12);
subtitle(tl, scope, 'FontSize', 8);

%% ---------- figure 2: error surface ----------
show = [i_T28 i_AR4 i_ANCH i_MW i_MWLVL i_MWRUN];
fh2 = figure('Name','RMSE surface','Position',[100 100 1340 640]);
tl2 = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
colormap(turbo);
for m = show
   nexttile;
   imagesc(sqrt(sum(double(E4(:,:,:,m)).^2,3)/n_days), [0 60]);
   set(gca,'XTick',[1 72 144 216 288],'XTickLabel',{'0','6','12','18','24'});
   set(gca,'YTick',[1 72 144 216 288],'YTickLabel',{'0','6','12','18','24'});
   xlabel('lead (hour)'); ylabel('target slot (hour of day)');
   title(names(m), 'FontSize', 9);
end
cb = colorbar; cb.Layout.Tile = 'east';
cb.Label.String = 'RMSE ($/MWh, colour clipped at 60)';
title(tl2, 'RMSE by target slot and lead', 'FontSize', 12);

exportgraphics(fh1, fullfile(fig_dir, "lead_profile.png"), "Resolution", 130);
exportgraphics(fh2, fullfile(fig_dir, "rmse_surface.png"), "Resolution", 130);
fprintf("figures rewritten in %s\n", fig_dir);

%% ---------- where the short-lead model should hand over ----------
RmAR = sqrt(mean(double(E4(:,:,:,i_AR4)).^2, 3));      % T28 + AR4
RmMW = sqrt(mean(double(E4(:,:,:,i_MWRUN)).^2, 3));    % MW + level, running state
aAR = mean(RmAR, 1);                               % over slots, by lead
aMW = mean(RmMW, 1);
cross = find(aAR < aMW, 1, 'last');
if isempty(cross)
   fprintf("\nAR4 never wins at any lead\n");
else
   fprintf("\nAR4 is the better of the two up to lead %d, i.e. %.2f hours\n", cross, cross/12);
   fprintf("  at lead %d   AR4 %.2f   MW+run %.2f\n", cross, aAR(cross), aMW(cross));
   fprintf("  at lead %d   AR4 %.2f   MW+run %.2f\n", cross+1, aAR(cross+1), aMW(cross+1));
end

% switched predictor: AR4 below the crossover, MW + running state above
Esw = E4(:, :, :, i_MWRUN);
if ~isempty(cross)
   Esw(:, 1:cross, :) = E4(:, 1:cross, :, i_AR4);
end
fprintf("\nswitched model (AR4 up to the crossover, MW+run after):\n");
fprintf("  pooled RMSE over the whole atlas   %.2f\n", sqrt(mean(double(Esw(:)).^2)));
fprintf("  pooled RMSE of MW+run alone        %.2f\n", sqrt(mean(double(E4(:,:,:,i_MWRUN)).^2, 'all')));
fprintf("  pooled RMSE of T28 + AR4 alone     %.2f\n", sqrt(mean(double(E4(:,:,:,i_AR4)).^2, 'all')));
fprintf("  pooled RMSE of Template T28        %.2f\n", sqrt(mean(double(E4(:,:,:,i_T28)).^2, 'all')));
fprintf("  pooled RMSE of Anchor-mix          %.2f\n", sqrt(mean(double(E4(:,:,:,i_ANCH)).^2, 'all')));
for lv = [1 12 36 72 144 288]
   fprintf("  lead %3d (%4.1f h)  AR4 %6.2f  MW+run %6.2f  switched %6.2f\n", ...
      lv, lv/12, aAR(lv), aMW(lv), mean(sqrt(mean(double(Esw(:,lv,:)).^2, 3))));
end
fprintf("### PLOT COMPLETED ###\n");
