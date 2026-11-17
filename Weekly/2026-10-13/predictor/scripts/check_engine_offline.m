%% Localise the rule-2 discrepancy: is it the engine or the driver?
%
%  Runs the SAME Ensemble_predictor functions offline, day by day, from the
%  saved atlas, and compares with the offline study. If this reproduces the
%  offline number the engine is fine and the fault is in the streaming driver;
%  if it reproduces the engine number the fault is in the engine.
%
%  Run: matlab -batch "run('C:\Ash\_research_20261013\check_engine_offline.m')"

project_root = 'C:\Ash\Projects\EMPC_Water_Electricity_Forecast';
addpath(fullfile(project_root, 'Predicitor', 'Shared'));
addpath(fullfile(project_root, 'Predicitor', 'Ensemble_predictor'));

d = fullfile(project_root, 'AEMO_Data', 'level_multiwindow_figs');
S = load(fullfile(d, 'atlas_v3.mat'));
E4 = S.E4;
[n_s, ~, n_d, n_m] = size(E4);
n_w = 28;  kB = 3;
d_score = (n_w+1):n_d;

% offline reference, filter path
Mrr = zeros(n_s, n_d, n_m);
for m = 1:n_m
   Mrr(:, :, m) = squeeze(sqrt(mean(double(E4(:, :, :, m)).^2, 1)));
end
Ec_ref = zeros(n_s, n_s, n_d, 'single');
for h = 1:n_s
   trs = filter(ones(n_w,1)/n_w, 1, squeeze(Mrr(h, :, :)), [], 1);
   for dd = d_score
      [~, ord] = sort(trs(dd-1, :));
      Ec_ref(:, h, dd) = single(sum(double(E4(:, h, dd, ord(1:kB))), 4) / kB);
   end
end
v_ref = sqrt(mean(reshape(Ec_ref(:, :, d_score), [], 1).^2));
fprintf('offline reference (filter path)      %.4f\n', v_ref);

% engine path, driven offline through the same functions
st = init_ensemble(n_m, n_s, n_w, 'K_sel', kB, 'eps', 0, 'B', 48);
Ec_eng = zeros(n_s, n_s, n_d, 'single');
n_diff = 0;  first_diff = [];
for dd = 1:n_d
   if dd >= n_w + 1
      [W, ~] = combine_ensemble(st, (1:n_s)', 'sel');
      Wbig = repelem(W, n_s, 1);
      Fd = reshape(double(E4(:, :, dd, :)), [], n_m)';
      Ec_eng(:, :, dd) = single(reshape(predict_ensemble(Fd, Wbig), n_s, n_s));
      for h = 1:n_s
         a = find(W(h, :));
         trs = filter(ones(n_w,1)/n_w, 1, squeeze(Mrr(h, :, :)), [], 1);
         [~, ord] = sort(trs(dd-1, :));
         b = ord(1:kB)';
         if ~isequal(sort(a(:)), sort(b(:)))
            n_diff = n_diff + 1;
            if isempty(first_diff), first_diff = [dd h]; end
         end
      end
   end
   st = update_ensemble(st, dd, single(E4(:, :, dd, :)));
end
v_eng = sqrt(mean(reshape(Ec_eng(:, :, d_score), [], 1).^2));
fprintf('engine path, driven offline         %.4f\n', v_eng);
fprintf('difference %.4f | selections differing %d of %d', ...
   v_eng - v_ref, n_diff, n_s*numel(d_score));
if ~isempty(first_diff)
   fprintf(' | first at day %d lead %d\n', first_diff(1), first_diff(2));
else
   fprintf('\n');
end

% where do the two surfaces actually differ?
D = abs(double(Ec_eng) - double(Ec_ref));
D(:, :, 1:n_w) = 0;
[mx, li] = max(D(:));
[a, b, c] = ind2sub(size(D), li);
fprintf('largest cell difference %.4f at slot %d lead %d day %d\n', mx, a, b, c);
fprintf('cells differing by more than 0.01: %d\n', sum(D(:) > 0.01));

% Bypass predict_ensemble: apply the very same weight matrix directly.
dd = 44;
W = engine_weights_upto(dd - 1, n_s, n_m);
Ed = double(squeeze(E4(:, :, dd, :)));            % n_s x n_s x n_m
Fd = reshape(Ed, [], n_m)';
y_pred = predict_ensemble(Fd, repelem(W, n_s, 1));
y_direct = reshape(sum(Ed .* reshape(W, 1, n_s, n_m), 3), 1, []);
fprintf('sizes: y_pred %s  y_direct %s\n', mat2str(size(y_pred)), mat2str(size(y_direct)));
if isequal(size(y_pred), size(y_direct))
   fprintf('predict_ensemble vs direct application, day %d: max difference %.3e\n', ...
      dd, max(abs(y_pred - y_direct)));
end
sel = find(W(b, :));
trs = filter(ones(n_w,1)/n_w, 1, squeeze(Mrr(b, :, :)), [], 1);
[~, ord] = sort(trs(dd-1, :));
fprintf('at slot %d lead %d: engine keeps %s, reference keeps %s\n', ...
   a, b, mat2str(sel), mat2str(ord(1:kB)));
fprintf('  engine value %10.4f   reference value %10.4f   mean of engine-kept %.4f   mean of ref-kept %.4f\n', ...
   Ec_eng(a, b, dd), Ec_ref(a, b, dd), mean(Ed(a, b, sel)), mean(Ed(a, b, ord(1:kB))));
fprintf('=== CHECK DONE ===\n');

function W = engine_weights_upto(last_day, ns, nm)
   % rebuild the engine window by streaming days 1..last_day, then ask for weights
   project_root = 'C:\Ash\Projects\EMPC_Water_Electricity_Forecast';
   S = load(fullfile(project_root, 'AEMO_Data', 'level_multiwindow_figs', 'atlas_v3.mat'));
   E = S.E4;  clear S
   st = init_ensemble(nm, ns, 28, 'K_sel', 3, 'eps', 0, 'B', 48);
   for k = 1:last_day
      st = update_ensemble(st, k, single(E(:, :, k, :)));
   end
   [W, ~] = combine_ensemble(st, (1:ns)', 'sel');
end
