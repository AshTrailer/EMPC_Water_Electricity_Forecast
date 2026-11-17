%% Why do the two ranking rules differ between the online engine and the offline study?
%
%  Both compute the same trailing mean RMSE per (lead, day, model) and keep the
%  best K. The offline study gets it through filter(), the engine through
%  mean(). If the top of the ranking is nearly tied, the two summation paths
%  can pick different models. This script recomputes the rule both ways from the
%  same atlas and counts how many (lead, day) selections actually differ.
%
%  Run: matlab -batch "run('C:\Ash\_research_20261013\check_rank_tie.m')"

d = 'C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data\level_multiwindow_figs';
S = load(fullfile(d, 'atlas_v3.mat'));
E4 = S.E4;
[n_s, ~, n_d, n_m] = size(E4);
n_w = 28;
d_score = (n_w+1):n_d;

Mrr = zeros(n_s, n_d, n_m);
for m = 1:n_m
   Mrr(:, :, m) = squeeze(sqrt(mean(double(E4(:, :, :, m)).^2, 1)));
end
fprintf('Mrr built, %s\n', mat2str(size(Mrr)));

for kB = [3 5]
   Ec_a = zeros(n_s, n_s, n_d, 'single');
   Ec_b = zeros(n_s, n_s, n_d, 'single');
   n_diff = 0;
   for h = 1:n_s
      tr = squeeze(Mrr(h, :, :));                       % n_d x n_m
      trs = filter(ones(n_w,1)/n_w, 1, tr, [], 1);      % offline path
      for dd = d_score
         [~, ord_a] = sort(trs(dd-1, :));
         [~, ord_b] = sort(mean(tr(dd-n_w:dd-1, :), 1));
         sel_a = ord_a(1:kB);  sel_b = ord_b(1:kB);
         if ~isequal(sort(sel_a), sort(sel_b))
            n_diff = n_diff + 1;
         end
         Ec_a(:, h, dd) = single(sum(double(E4(:, h, dd, sel_a)), 4) / kB);
         Ec_b(:, h, dd) = single(sum(double(E4(:, h, dd, sel_b)), 4) / kB);
      end
   end
   va = sqrt(mean(reshape(Ec_a(:, :, d_score), [], 1).^2));
   vb = sqrt(mean(reshape(Ec_b(:, :, d_score), [], 1).^2));
   fprintf('K = %d : filter path %.4f   mean path %.4f   difference %.4f   selections differing %d of %d\n', ...
      kB, va, vb, vb - va, n_diff, n_s*numel(d_score));
end
fprintf('=== CHECK DONE ===\n');
