function probe_coverage()
   % Minimal shape and coverage probe for official_60d.mat. Prints sizes and
   % band counts so a wrong coverage number cannot reach the deck.
   f = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data\level_multiwindow_figs\official_60d.mat";
   O = matfile(f);
   SRC4 = O.SRC4;
   d_score = double(O.d_score);
   fprintf("class(SRC4) = %s\n", class(SRC4));
   fprintf("size(SRC4) = %s\n", mat2str(size(SRC4)));
   fprintf("size(d_score) = %s  d_score(1)=%g  d_score(end)=%g\n", ...
      mat2str(size(d_score)), d_score(1), d_score(end));

   sr = SRC4(:, :, d_score);
   fprintf("size(sr) = %s   numel=%d\n", mat2str(size(sr)), numel(sr));

   b1 = (1:size(SRC4, 2))' < 12;     % first eleven columns, 5 to 55 minutes
   fprintf("sum(b1) = %d   size(b1) = %s\n", sum(b1), mat2str(size(b1)));

   a = sr(:, b1);
   fprintf("size(sr(:,b1)) = %s  numel=%d\n", mat2str(size(a)), numel(a));
   fprintf("nonzero in band 1 over the scored days: %d\n", sum(a(:) ~= 0));
   fprintf("nonzero in band 1 over all 60 days     : %d\n", sum(sum(SRC4(:, b1, :) ~= 0, 'all')));

   % how many days carry a band-1 value at all
   per_day = squeeze(sum(sum(sr(:, b1, :) ~= 0, 2), 1));
   fprintf("band-1 nonzeros per scored day: min %d max %d  (288*11 = %d)\n", ...
      min(per_day), max(per_day), 288*11);
   fprintf("days with zero band-1 coverage: %d of %d\n", sum(per_day == 0), numel(per_day));

   b2 = ~b1;
   per_day2 = squeeze(sum(sum(sr(:, b2, :) ~= 0, 2), 1));
   fprintf("band-2 nonzeros over the scored days: %d of %d (%.1f%%)\n", ...
      sum(per_day2), 288*sum(b2)*numel(d_score), 100*sum(per_day2)/(288*sum(b2)*numel(d_score)));
   fprintf("band-2 nonzeros per scored day: min %d max %d  (288*365 = %d)\n", ...
      min(per_day2), max(per_day2), 288*sum(b2));
end
