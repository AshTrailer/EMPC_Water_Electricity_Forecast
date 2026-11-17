%% Verify that the extended atlas preserves the original 12 columns bit for bit.
%  Run with:  matlab -batch "run('C:\Ash\_research_20261013\verify_atlas_ext.m')"

d = 'C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data\level_multiwindow_figs';
A = matfile(fullfile(d, 'atlas_full.mat'));
B = matfile(fullfile(d, 'atlas_ext.mat'));

szA = size(A, 'E4');  szB = size(B, 'E4');
fprintf('atlas_full %s | atlas_ext %s\n', mat2str(szA), mat2str(szB));
assert(szA(1) == szB(1) && szA(2) == szB(2) && szA(3) == szB(3), 'grid differs');
assert(szB(4) == 18, 'expected 18 models, got %d', szB(4));

same = true;
for m = 1:12
   Ea = A.E4(:, :, :, m);
   Eb = B.E4(:, :, :, m);
   if isequal(Ea, Eb)
      fprintf('  column %2d  identical\n', m);
   else
      df = max(abs(double(Ea(:)) - double(Eb(:))));
      nz = sum(double(Ea(:)) ~= double(Eb(:)));
      fprintf('  column %2d  DIFFERS  max %.3e over %d entries\n', m, df, nz);
      same = false;
   end
   clear Ea Eb
end
fprintf('FIRST 12 COLUMNS BIT IDENTICAL: %d\n', same);

Ra = A.Rall;  Rb = B.Rall;
fprintf('Rall first 12 identical: %d\n', isequal(Ra, Rb(1:12)));
names = B.names;
for m = 1:numel(Rb)
   fprintf('  %-26s %7.2f\n', names(m), Rb(m));
end
[~, ib] = min(Rb);
fprintf('BEST SINGLE: %s at %.2f\n', names(ib), Rb(ib));
fprintf('=== VERIFY DONE ===\n');
