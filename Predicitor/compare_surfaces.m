function compare_surfaces(idx_a, idx_b, out_png)
   % COMPARE_SURFACES  Compare two predictors when a plain heatmap cannot
   %
   %    Two 288x288 RMSE surfaces that differ by only a few $/MWh look
   %    identical side by side. This function replaces that comparison with
   %    four instruments:
   %
   %      1. a signed difference surface, diverging colour scale
   %      2. the two-way decomposition R = Rbar + a(h) + b(s) + c(s,h), which
   %         separates the lead profile, the time-of-day profile and what is
   %         left over
   %      3. the singular value spectrum of the difference surface, which says
   %         whether the difference is one pattern or many
   %      4. a per-cell paired Diebold-Mariano test with Benjamini-Hochberg
   %         false discovery rate control
   %
   %    Every claim produced here comes with a sample size. A single day or a
   %    single time band is not admissible evidence on its own, so the daily
   %    win rate is reported alongside every pooled number.
   %
   %    Input:
   %       idx_a   - model index into the atlas, the reference
   %       idx_b   - model index into the atlas, the challenger
   %       out_png - optional output figure path
   %
   %    Atlas: AEMO_Data\level_multiwindow_figs\atlas_full.mat

   arguments
      idx_a (1,1) double
      idx_b (1,1) double
      out_png (1,:) char = ''
   end

   project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   atlas_path = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs", "atlas_full.mat");
   S = load(atlas_path);
   E = S.E4;  names = S.names;
   [n_s, n_h, n_d, n_m] = size(E);
   assert(idx_a >= 1 && idx_a <= n_m && idx_b >= 1 && idx_b <= n_m, 'model index out of range');

   EA = double(E(:,:,:,idx_a));   EB = double(E(:,:,:,idx_b));
   RA = sqrt(mean(EA.^2, 3));     RB = sqrt(mean(EB.^2, 3));
   DEL = RA - RB;

   fprintf("A = %s\nB = %s\n", names(idx_a), names(idx_b));
   fprintf("days n = %d | cells %d | lead steps %d\n\n", n_d, n_s*n_h, n_h);

   %% ---- 1. headline numbers ----
   fprintf("whole atlas pooled RMSE   A %8.3f   B %8.3f   change %+7.2f%%\n", ...
      sqrt(mean(EA(:).^2)), sqrt(mean(EB(:).^2)), 100*(sqrt(mean(EB(:).^2))/sqrt(mean(EA(:).^2)) - 1));
   fprintf("difference surface        min %+8.3f  max %+8.3f  mean %+8.3f  max|.| %8.3f\n\n", ...
      min(DEL(:)), max(DEL(:)), mean(DEL(:)), max(abs(DEL(:))));

   %% ---- 2. two-way decomposition ----
   Rbar = mean(RA(:));
   a = mean(RA, 1) - Rbar;             % 1 x n_h, lead main effect
   b = mean(RA, 2) - Rbar;             % n_s x 1, slot main effect
   c = RA - Rbar - a - b;              % interaction
   rec = Rbar + a + b + c;
   fprintf("decomposition check  max|R - (Rbar + a + b + c)| = %.3e\n", max(abs(rec(:) - RA(:))));
   fprintf("variance shares      lead %.1f%%  slot %.1f%%  interaction %.1f%%\n\n", ...
      100*var(a(:))/var(RA(:)), 100*var(b(:))/var(RA(:)), 100*var(c(:))/var(RA(:)));

   %% ---- 3. singular value spectrum of the difference ----
   [U, Sig, V] = svd(DEL, 'econ');
   sv = diag(Sig);
   share = cumsum(sv.^2) / sum(sv.^2);
   fprintf("difference spectrum, share of energy in the first k modes:\n   ");
   for k = [1 2 3 5 10 20]
      fprintf("k=%d %.1f%%   ", k, 100*share(k));
   end
   fprintf("\n\n");

   %% ---- 4. per-cell paired test with HAC and FDR ----
   Dm = EA.^2 - EB.^2;                          % slot x lead x day, loss differential
   mu = mean(Dm, 3);
   L = min(10, n_d - 1);
   g0 = mean(Dm.^2, 3) - mu.^2;
   vh = g0;
   for l = 1:L
      gl = mean(Dm(:,:,1+l:end) .* Dm(:,:,1:end-l), 3) - mu.^2;
      vh = vh + 2*(1 - l/(L+1))*gl;
   end
   vh = max(vh, 1e-12);
   dm = mu ./ sqrt(vh / n_d);
   pv = erfc(abs(dm)/sqrt(2));                  % two-sided normal p-value

   m = numel(pv);
   [ps, ord] = sort(pv(:));
   thr = (1:m)'/m * 0.05;
   k_max = find(ps <= thr, 1, 'last');
   if isempty(k_max), k_max = 0; end
   sig_mask = false(size(pv));
   if k_max > 0
      sig_mask(ord(1:k_max)) = true;
   end
   % loss differential D = e_A^2 - e_B^2, so a POSTIVE mean means A has the
   % larger squared error, i.e. B is the better model in that cell
   better_b = sig_mask & (mu > 0);
   better_a = sig_mask & (mu < 0);
   fprintf("per-cell DM test, HAC lag %d, BH-FDR at 5%%\n", L);
   fprintf("  A significantly better  %7d cells  (%.1f%%)\n", sum(better_a(:)), 100*sum(better_a(:))/m);
   fprintf("  B significantly better  %7d cells  (%.1f%%)\n", sum(better_b(:)), 100*sum(better_b(:))/m);
   fprintf("  not significant         %7d cells  (%.1f%%)\n\n", m - sum(sig_mask(:)), 100*(m - sum(sig_mask(:)))/m);

   %% ---- 5. daily win rate, the robustness check ----
   % RMSE over slots for each (lead, day), then the share of days B is better
   dA = sqrt(mean(EA.^2, 1));   dA = reshape(dA, n_h, n_d);
   dB = sqrt(mean(EB.^2, 1));   dB = reshape(dB, n_h, n_d);
   winB = mean(dB < dA, 2);
   fprintf("daily win rate for B, share of the %d days:\n", n_d);
   for hh = [1 6 12 36 72 144 288]
      fprintf("  lead %3d (%4.1f h)   B wins %5.1f%%   median daily RMSE  A %7.2f  B %7.2f\n", ...
         hh, hh/12, 100*winB(hh), median(dA(hh,:)), median(dB(hh,:)));
   end
   fprintf("\n");

   %% ---- 6. figure ----
   fh = figure('Name', 'Surface comparison', 'Position', [40 40 1400 900]);
   tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

   nexttile;  imagesc(RA, [0 60]);  colormap(gca, turbo);  colorbar;
   set(gca,'XTick',[1 72 144 216 288],'XTickLabel',{'0','6','12','18','24'});
   set(gca,'YTick',[1 72 144 216 288],'YTickLabel',{'0','6','12','18','24'});
   xlabel('lead (hour)'); ylabel('target slot (hour of day)');
   title(sprintf('A  %s', names(idx_a)), 'FontSize', 9);

   nexttile;  imagesc(RB, [0 60]);  colormap(gca, turbo);  colorbar;
   set(gca,'XTick',[1 72 144 216 288],'XTickLabel',{'0','6','12','18','24'});
   set(gca,'YTick',[1 72 144 216 288],'YTickLabel',{'0','6','12','18','24'});
   xlabel('lead (hour)'); ylabel('target slot (hour of day)');
   title(sprintf('B  %s', names(idx_b)), 'FontSize', 9);

   nexttile;
   lim = max(abs(DEL(:)));
   imagesc(DEL, [-lim lim]);  colormap(gca, diverging_map(256));  colorbar;
   set(gca,'XTick',[1 72 144 216 288],'XTickLabel',{'0','6','12','18','24'});
   set(gca,'YTick',[1 72 144 216 288],'YTickLabel',{'0','6','12','18','24'});
   xlabel('lead (hour)'); ylabel('target slot (hour of day)');
   title(sprintf('A minus B, colour to +-%.1f $/MWh', lim), 'FontSize', 9);

   nexttile;
   img = zeros(n_s, n_h);
   img(better_a) = 1;  img(better_b) = -1;
   imagesc(img, [-1 1]);
   cmap = [0.20 0.35 0.75; 0.92 0.92 0.92; 0.75 0.20 0.20];
   colormap(gca, cmap);  cb = colorbar;
   cb.Ticks = [-1 0 1];  cb.TickLabels = {'B better','n.s.','A better'};
   set(gca,'XTick',[1 72 144 216 288],'XTickLabel',{'0','6','12','18','24'});
   set(gca,'YTick',[1 72 144 216 288],'YTickLabel',{'0','6','12','18','24'});
   xlabel('lead (hour)'); ylabel('target slot (hour of day)');
   title(sprintf('paired DM with BH-FDR 5%%, %d days', n_d), 'FontSize', 9);

   title(tl, sprintf('A = %s     B = %s', names(idx_a), names(idx_b)), 'FontSize', 12);
   subtitle(tl, sprintf('VIC1 5-min RRP | %d days | clamped | one forecast per 5-min origin | unit $/MWh', n_d), 'FontSize', 8);

   if ~isempty(out_png)
      exportgraphics(fh, out_png, 'Resolution', 130);
      fprintf("figure written to %s\n", out_png);
   end
end

function cm = diverging_map(n)
   % blue to white to red, symmetric around zero
   if mod(n,2) == 0, n = n + 1; end
   half = (n - 1) / 2;
   lo = [linspace(0.13, 1, half+1)', linspace(0.35, 1, half+1)', linspace(0.65, 1, half+1)'];
   hi = [linspace(1, 0.70, half+1)', linspace(1, 0.12, half+1)', linspace(1, 0.13, half+1)'];
   cm = [lo; hi(2:end,:)];
end
