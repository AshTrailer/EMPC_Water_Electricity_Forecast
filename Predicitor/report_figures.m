function out = report_figures(S, out_dir)
   % Draw the admissible comparisons from an error atlas, as figures.
   %
   % S.E4 is E(slot, lead, day, model). Every figure below is one of four
   % objects, and no figure is a single number taken over the whole of E:
   %   the surface R(slot, lead)
   %   a row of R, one lead against the times of day
   %   a column of R, one time of day against the leads
   %   a census of R, how many of its cells each model wins
   % A census is drawn only next to the surface it counts, never on its own,
   % because which cell a model wins matters as much as how many it wins.
   %
   % A fifth object appears when the official composite is available: the
   % difference R(model) - R(official), which is only meaningful next to a map
   % of how many days actually contributed to each cell and which product
   % supplied the official value there.
   %
   % S.keys holds the registry keys and S.names the display labels. They are
   % different strings and must never be used interchangeably.
   %
   % out is a struct array of what was written, one entry per figure.

   E4 = S.E4;
   names = string(S.names(:));
   if isfield(S, "keys") && numel(S.keys) == numel(names)
      keys = string(S.keys(:));
   else
      keys = names;
   end
   if isfield(S, "specs") && numel(S.specs) == numel(names)
      specs = string(S.specs(:));
   else
      specs = strings(numel(names), 1);
   end
   [n_s, n_h, n_d, n_m] = size(E4);
   if isfield(S, "lead_min") && numel(S.lead_min) == n_h
      lead_min = double(S.lead_min(:));
   else
      lead_min = 5*(1:n_h)';
   end
   if isfield(S, "d_score") && ~isempty(S.d_score)
      d_score = S.d_score;
   else
      d_score = 1:n_d;
   end
   has_off = isfield(S, "official") && ~isempty(S.official);
   if has_off
      O4 = S.official.O4;  SRC4 = S.official.SRC4;  AGE4 = S.official.AGE4;
   end

   % R is the object every claim is made about, on the days the combination
   % rules can also be scored on, so a single model and a rule share one axis.
   R = zeros(n_s, n_h, n_m);
   for m = 1:n_m
      R(:, :, m) = sqrt(mean(double(E4(:, :, d_score, m)).^2, 3));
   end

   INK  = [27 36 48]/255;    HEAD = [30 39 97]/255;   SEC = [90 107 123]/255;
   TEAL = [14 124 123]/255;  AMB  = [233 168 32]/255; RED = [176 42 55]/255;
   BLUE = [31 78 156]/255;

   set(groot, "defaultAxesFontName", "Calibri", "defaultTextFontName", "Calibri", ...
      "defaultAxesFontSize", 8.5, "defaultAxesXColor", INK, ...
      "defaultAxesYColor", INK, "defaultAxesGridColor", [0.78 0.80 0.84], ...
      "defaultAxesTickDir", "out", "defaultFigureColor", "w", ...
      "defaultTextInterpreter", "none", "defaultLegendInterpreter", "none", ...
      "defaultAxesTickLabelInterpreter", "none");

   if ~exist(out_dir, "dir"), mkdir(out_dir); end
   out = struct("file", {}, "what", {});

   s_tick = slot_ticks(n_s);  s_lab = slot_labels(n_s);
   [l_tick, l_lab] = lead_ticks_of(lead_min);
   base = [HEAD; TEAL; AMB; SEC; RED; [0.45 0.30 0.62]; [0.20 0.55 0.35]; ...
      [0.75 0.45 0.20]; [0.35 0.35 0.75]; [0.60 0.25 0.45]; [0.25 0.60 0.68]; ...
      [0.55 0.55 0.20]; [0.70 0.35 0.55]; [0.40 0.45 0.50]; [0.30 0.50 0.30]; ...
      [0.65 0.30 0.25]; [0.45 0.40 0.65]];

   % The line set is deliberately small: the two models that own the first hour,
   % the two that own the long end, and the official composite drawn as a dark
   % line of its own. A board of sixteen curves is unreadable, and the census in
   % F3 already accounts for the rest.
   line_keys = ["anchor_mix" "T28_AR4" "T28" "T_class"];
   line_keys = line_keys(ismember(line_keys, keys));
   % A column, not whatever shape line_keys happens to be: the official name is
   % appended below with a vertical concatenation.
   line_names = strings(numel(line_keys), 1);
   for j = 1:numel(line_keys), line_names(j) = names(idx_of(keys, line_keys(j))); end
   line_col = [AMB; RED; TEAL; HEAD];
   line_col = line_col(1:numel(line_keys), :);
   off_col = [0.10 0.10 0.10];
   off_name = "Official AEMO composite";
   off_R = [];
   if has_off, off_R = S.official.R_off; end
   if ~isempty(off_R)
      line_names = [line_names; off_name];
      line_col = [line_col; off_col];
   end
   leg_names = cellstr(line_names);

   day_txt = sprintf("days %d to %d of %d", d_score(1), d_score(end), n_d);
   axis_txt = sprintf("%d times of day x %d leads", n_s, n_h);

   %% ---- F1  every model on one shared colour scale ----
   lo = prctile(R(:), 2);  hi = prctile(R(:), 98);
   f = figure("Position", [40 30 1560 940]);
   tl = tiledlayout(f, 4, 4, "Padding", "compact", "TileSpacing", "compact");
   for m = 1:n_m
      nexttile(tl);
      imagesc(1:n_s, 1:n_h, R(:, :, m)');
      set(gca, "YDir", "normal");  clim([lo hi]);  colormap(gca, parula);
      axis tight;  box on;
      xticks(s_tick);  yticks(l_tick);
      if m > (n_m - 4), xticklabels(s_lab); else, xticklabels([]); end
      if mod(m-1, 4) == 0, yticklabels(l_lab); else, yticklabels([]); end
      ttl(specs(m) + "  " + names(m), "Color", HEAD, "FontWeight", "bold", "FontSize", 9);
   end
   for m = n_m+1:16
      nexttile(tl);  axis off;
   end
   cb = colorbar;  cb.Layout.Tile = "east";
   cb.Label.String = sprintf("RMS error, $/MWh, %s", day_txt);
   cb.TickLabelInterpreter = "none";  cb.Label.Interpreter = "none";
   ttl(tl, sprintf("R(slot, lead) for all %d models on one colour scale, %s", ...
      n_m, axis_txt), "Color", INK, "FontWeight", "bold");
   out = push(out, out_dir, "f1_surfaces.png", ...
      "all models, shared colour scale", f);

   %% ---- F2a, F2b  every model against the official composite ----
   % Both panels are drawn over ONE comparison set: the cells where the official
   % carries a value on every scored day. Measured, the official is either
   % complete on all scored days or absent on all of them, so that set is exactly
   % "the official has a value here". Every count printed below is out of its
   % size, never out of the whole surface, and outside it the cell is left at the
   % axes background colour and is NOT compared.
   if has_off
      ds = d_score;
      n_scored = numel(ds);
      comparable = squeeze(all(isfinite(O4(:, :, ds)), 3));   % slot x lead
      n_cmp = sum(comparable(:));
      notcmp = [0.90 0.90 0.92];
      fprintf("f2 comparison set: %d of %d cells carry the official on all %d scored days (%s drawn grey)\n", ...
         n_cmp, n_s*n_h, n_scored, mat2str(n_s*n_h - n_cmp));

      Dm = zeros(n_s, n_h, n_m);
      for m = 1:n_m
         Dm(:, :, m) = R(:, :, m) - S.official.R_off;
         Dm(~comparable) = NaN;
      end
      slim = prctile(abs(Dm(:)), 98);

      f = figure("Position", [40 30 1560 940]);
      tl = tiledlayout(f, 4, 4, "Padding", "compact", "TileSpacing", "compact");
      for m = 1:n_m
         nexttile(tl);
         imagesc(1:n_s, 1:n_h, Dm(:, :, m)');
         set(gca, "YDir", "normal", "Color", notcmp);
         clim([-slim slim]);  colormap(gca, diverging(256));
         axis tight;  box on;
         xticks(s_tick);  yticks(l_tick);
         if m > (n_m - 4), xticklabels(s_lab); else, xticklabels([]); end
         if mod(m-1, 4) == 0, yticklabels(l_lab); else, yticklabels([]); end
         ttl(sprintf("%s  (lower in %d of %d)", specs(m), ...
            sum(Dm(:,:,m) < 0, 'all'), n_cmp), ...
            "Color", HEAD, "FontWeight", "bold", "FontSize", 9);
      end
      for m = n_m+1:16
         nexttile(tl);  axis off;
      end
      cb = colorbar;  cb.Layout.Tile = "east";
      cb.Label.String = "model minus official, $/MWh, blue lower; grey not compared";
      cb.TickLabelInterpreter = "none";  cb.Label.Interpreter = "none";
      ttl(tl, sprintf("R(model) minus R(official), %s, %s", day_txt, axis_txt), ...
         "Color", INK, "FontWeight", "bold");
      out = push(out, out_dir, "f2a_diff_vs_official.png", ...
         "every model minus the official composite, over the comparable cells", f);

      % Significance over the same comparison set and the same scored days. The
      % first version of this panel passed all n_d days to CELL_DM while the
      % difference panel used d_score, so a single absent official day turned the
      % whole cell into NaN and it was drawn as unresolved. The day set is now
      % identical to the one R is taken over.
      f = figure("Position", [40 30 1560 940]);
      tl = tiledlayout(f, 4, 4, "Padding", "compact", "TileSpacing", "compact");
      n_res = zeros(n_m, 1);  n_lo = zeros(n_m, 1);  n_hi = zeros(n_m, 1);
      off_d = double(S.official.E4_off(:, :, ds));
      for m = 1:n_m
         [dm, rej] = cell_dm(double(E4(:, :, ds, m)), off_d, 7);
         Cs = zeros(n_s, n_h);
         Cs(comparable & ~rej) = 1;
         Cs(comparable & rej & (dm < 0)) = 2;
         Cs(comparable & rej & (dm > 0)) = 3;
         n_res(m) = sum(rej(:));
         n_lo(m) = sum(rej(:) & dm(:) < 0);
         n_hi(m) = sum(rej(:) & dm(:) > 0);
         nexttile(tl);
         imagesc(1:n_s, 1:n_h, Cs');
         set(gca, "YDir", "normal");
         colormap(gca, [notcmp; 0.97 0.97 0.98; BLUE; RED]);  clim([-0.5 3.5]);
         axis tight;  box on;
         xticks(s_tick);  yticks(l_tick);
         if m > (n_m - 4), xticklabels(s_lab); else, xticklabels([]); end
         if mod(m-1, 4) == 0, yticklabels(l_lab); else, yticklabels([]); end
         ttl(sprintf("%s  (%d cells resolved)", specs(m), n_res(m)), ...
            "Color", HEAD, "FontWeight", "bold", "FontSize", 9);
      end
      for m = n_m+1:16
         nexttile(tl);  axis off;
      end
      cb = colorbar;  cb.Layout.Tile = "east";
      cb.Ticks = 0:3;
      % Labelled from the OFFICIAL's side, because that is the thing being
      % compared against. "model lower" and "model higher" are correct but they
      % invite the reader to flip the meaning, and blue already means the model
      % is the better of the two.
      cb.TickLabels = {'not comparable', 'unresolved', 'model beats official', 'official beats model'};
      cb.Label.String = "blue: the model is lower;  red: the official is lower";
      cb.Label.Interpreter = "none";
      cb.FontSize = 8;  cb.TickLabelInterpreter = "none";
      ttl(tl, sprintf("paired Diebold-Mariano at every cell against the official composite, %s", day_txt), ...
         "Color", INK, "FontWeight", "bold");
      out = push(out, out_dir, "f2b_diff_significance.png", ...
         "whether each difference is resolvable, on the comparable cells", f);
      fprintf("f2b per model, of %d comparable cells: resolved %s | model lower %s | model higher %s\n", ...
         n_cmp, mat2str(n_res'), mat2str(n_lo'), mat2str(n_hi'));
   end

   %% ---- F2c  what the official side of the comparison actually rests on ----
   % Three panels, not four. The model side is deliberately absent: it carries
   % all scored days in every cell and that is asserted below, so a panel of it
   % would be a uniform rectangle saying one sentence. That sentence belongs in
   % the text, and it is printed.
   if has_off
      assert(n_scored == numel(ds));
      empty4 = all(E4 == 0, 4);                 % unreached cells read as zero
      cnt_model = squeeze(sum(~empty4(:, :, ds), 3));
      assert(all(cnt_model(:) == n_scored), 'report_figures:sample', ...
         'the model side has cells with %d to %d of the %d scored days; R would be diluted', ...
         min(cnt_model(:)), max(cnt_model(:)), n_scored);
      fprintf("f2c model side: %d of %d scored days in every one of the %d cells\n", ...
         n_scored, n_scored, n_s*n_h);

      S3 = double(SRC4(:, :, ds));
      cnt_off = squeeze(sum(isfinite(O4(:, :, ds)), 3));
      age_h = squeeze(mean(double(AGE4(:, :, ds)), 3, 'omitnan')) / 60;
      src_any = mode(S3, 3);                            % most common code
      src_any(squeeze(all(S3 == 0, 3))) = 0;            % 0 = no day had a value
      n_no_off = sum(cnt_off(:) == 0);

      f = figure("Position", [40 30 1560 460]);
      tl = tiledlayout(f, 1, 3, "Padding", "compact", "TileSpacing", "compact");

      nexttile(tl);
      imagesc(1:n_s, 1:n_h, cnt_off');  set(gca, "YDir", "normal");
      safe_clim(gca, [0 n_scored]);
      colormap(gca, parula);  axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      cb = colorbar;  cb.Label.String = "days";  cb.Label.Interpreter = "none";
      ttl(sprintf("days contributing, official side: %d of %d cells have none", ...
         n_no_off, n_s*n_h), "Color", HEAD, "FontWeight", "bold");

      nexttile(tl);
      imagesc(1:n_s, 1:n_h, src_any');  set(gca, "YDir", "normal");
      colormap(gca, [0.85 0.85 0.88; TEAL; AMB; HEAD]);  clim([-0.5 3.5]);
      axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      cb = colorbar;  cb.Ticks = 0:3;
      cb.TickLabels = {'none','P5MIN','PREDISPATCH','PD7DAY'};
      cb.TickLabelInterpreter = "none";
      ttl("which product supplied the official value", "Color", HEAD, "FontWeight", "bold");

      nexttile(tl);
      imagesc(1:n_s, 1:n_h, age_h');  set(gca, "YDir", "normal");
      clim([0 14]);  colormap(gca, parula);  axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      cb = colorbar;  cb.Label.String = "hours, age of the run at the origin";
      cb.Label.Interpreter = "none";
      ttl("how stale the official value is", "Color", HEAD, "FontWeight", "bold");

      ttl(tl, sprintf("the sample count and the source behind every cell, over the %d scored days", n_scored), ...
         "Color", INK, "FontWeight", "bold");
      out = push(out, out_dir, "f2c_sample_count.png", ...
         "official day count, source and staleness over the scored days", f);
   end

   %% ---- F3  who wins each cell, and how that changes with lead and with slot ----
   [~, wm] = min(R, [], 3);
   wins = zeros(n_m, 1);
   for m = 1:n_m, wins(m) = sum(sum(wm == m)); end
   [~, ow] = sort(wins, "descend");
   keep = ow(cumsum(wins(ow))/sum(wins) <= 0.98);
   if isempty(keep), keep = ow(1); end
   other = setdiff(1:n_m, keep)';
   n_grp = numel(keep) + 1;
   share_l = zeros(n_grp, n_h);
   share_s = zeros(n_grp, n_s);
   for i = 1:numel(keep)
      share_l(i, :) = mean(wm == keep(i), 1) * 100;
      share_s(i, :) = mean(wm == keep(i), 2)' * 100;
   end
   share_l(n_grp, :) = mean(ismember(wm, other), 1) * 100;
   share_s(n_grp, :) = mean(ismember(wm, other), 2)' * 100;
   cmap = [base(mod((1:numel(keep))-1, size(base,1)) + 1, :); 0.80 0.81 0.84];
   lbl = [names(keep); "all others"];
   assert(size(cmap,1) == n_grp && numel(lbl) == n_grp, 'report_figures:legend', ...
      'the colour map, the labels and the groups must agree in length');

   f = figure("Position", [40 30 1500 900]);
   tl = tiledlayout(f, 2, 2, "Padding", "compact", "TileSpacing", "compact");
   nexttile(tl, [2 1]);
   mapv = zeros(n_s, n_h);
   for i = 1:numel(keep), mapv(wm == keep(i)) = i; end
   mapv(ismember(wm, other)) = n_grp;
   imagesc(1:n_s, 1:n_h, mapv');  set(gca, "YDir", "normal");
   colormap(gca, cmap);  clim([0.5 n_grp+0.5]);
   axis tight;  box on;
   xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
   xlabel("time of day");  ylabel("forecast lead");
   ttl("winner of each cell", "Color", HEAD, "FontWeight", "bold");
   cb = colorbar;  cb.Ticks = 1:n_grp;  cb.TickLabels = cellstr(lbl);
   cb.FontSize = 7;  cb.TickLabelInterpreter = "none";

   nexttile(tl);
   % Colour each band from the map by hand. Letting area or the axes colour
   % order pick means the bands need not match the legend beside them.
   xl = log10(lead_min);
   hb = area(xl, share_l');
   for i = 1:n_grp, hb(i).FaceColor = cmap(i, :);  hb(i).EdgeColor = "none"; end
   box on;  grid on;  xlim([xl(1) xl(end)]);  ylim([0 100]);
   set_log_lead_ticks(gca, lead_min, l_tick, l_lab);
   xlabel("forecast lead, log scale");  ylabel("share of the times of day, percent");
   ttl("who wins, cut across lead", "Color", HEAD, "FontWeight", "bold");

   nexttile(tl);
   hb = area(1:n_s, share_s');
   for i = 1:n_grp, hb(i).FaceColor = cmap(i, :);  hb(i).EdgeColor = "none"; end
   box on;  grid on;  xlim([1 n_s]);  ylim([0 100]);
   xticks(s_tick);  xticklabels(s_lab);
   xlabel("time of day");  ylabel("share of the leads, percent");
   ttl("who wins, cut across time of day", "Color", HEAD, "FontWeight", "bold");
   ttl(tl, sprintf("no model wins the whole surface, %s, %s", day_txt, axis_txt), ...
      "Color", INK, "FontWeight", "bold");
   out = push(out, out_dir, "f3_winner_map.png", ...
      "winner map with its two cuts, across lead and across time of day", f);

   %% ---- F3b  the same census with the official composite competing ----
   % A separate figure rather than an extra band in F3, so the model-only census
   % stays comparable with the earlier 24-hour work. min() ignores NaN, so the
   % official simply cannot win a cell where it carries no value; those cells are
   % decided among the models and the count of them is printed.
   if has_off
      Rc = cat(3, R, S.official.R_off);
      nm3 = [names; "Official AEMO composite"];
      [~, wm3] = min(Rc, [], 3);
      n_m3 = numel(nm3);
      wins3 = zeros(n_m3, 1);
      for i = 1:n_m3, wins3(i) = sum(wm3(:) == i); end
      [~, ow3] = sort(wins3, "descend");
      keep3 = ow3(cumsum(wins3(ow3))/sum(wins3) <= 0.98);
      if isempty(keep3), keep3 = ow3(1); end
      other3 = setdiff(1:n_m3, keep3)';
      n_grp3 = numel(keep3) + 1;
      share_l3 = zeros(n_grp3, n_h);
      share_s3 = zeros(n_grp3, n_s);
      for i = 1:numel(keep3)
         share_l3(i, :) = mean(wm3 == keep3(i), 1) * 100;
         share_s3(i, :) = mean(wm3 == keep3(i), 2)' * 100;
      end
      share_l3(n_grp3, :) = mean(ismember(wm3, other3), 1) * 100;
      share_s3(n_grp3, :) = mean(ismember(wm3, other3), 2)' * 100;
      % The official gets a colour of its own rather than a slot in the cycle.
      cmap3 = zeros(n_grp3, 3);
      lab3 = strings(n_grp3, 1);
      ci = 0;
      for i = 1:numel(keep3)
         ci = ci + 1;
         lab3(ci) = nm3(keep3(i));
         if keep3(i) == n_m3, cmap3(ci, :) = off_col; else, cmap3(ci, :) = base(mod(ci-1, size(base,1)) + 1, :); end
      end
      lab3(n_grp3) = "all others";  cmap3(n_grp3, :) = [0.80 0.81 0.84];
      fprintf("f3b census with the official competing, out of %d cells:\n", n_s*n_h);
      for i = 1:numel(keep3)
         fprintf("  %-28s %6d cells %6.2f%%\n", nm3(keep3(i)), wins3(keep3(i)), 100*wins3(keep3(i))/(n_s*n_h));
      end
      fprintf("  other %d models %17d cells %6.2f%%\n", numel(other3), ...
         sum(wins3(other3)), 100*sum(wins3(other3))/(n_s*n_h));

      f = figure("Position", [40 30 1500 900]);
      tl = tiledlayout(f, 2, 2, "Padding", "compact", "TileSpacing", "compact");
      nexttile(tl, [2 1]);
      mapv3 = zeros(n_s, n_h);
      for i = 1:numel(keep3), mapv3(wm3 == keep3(i)) = i; end
      mapv3(ismember(wm3, other3)) = n_grp3;
      imagesc(1:n_s, 1:n_h, mapv3');  set(gca, "YDir", "normal");
      colormap(gca, cmap3);  clim([0.5 n_grp3+0.5]);
      axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl("winner of each cell, official included", "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Ticks = 1:n_grp3;  cb.TickLabels = cellstr(lab3);
      cb.FontSize = 7;  cb.TickLabelInterpreter = "none";

      nexttile(tl);
      xl3 = log10(lead_min);
      hb = area(xl3, share_l3');
      for i = 1:n_grp3, hb(i).FaceColor = cmap3(i, :);  hb(i).EdgeColor = "none"; end
      box on;  grid on;  xlim([xl3(1) xl3(end)]);  ylim([0 100]);
      set_log_lead_ticks(gca, lead_min, l_tick, l_lab);
      xlabel("forecast lead, log scale");  ylabel("share of the times of day, percent");
      ttl("who wins, cut across lead", "Color", HEAD, "FontWeight", "bold");

      nexttile(tl);
      hb = area(1:n_s, share_s3');
      for i = 1:n_grp3, hb(i).FaceColor = cmap3(i, :);  hb(i).EdgeColor = "none"; end
      box on;  grid on;  xlim([1 n_s]);  ylim([0 100]);
      xticks(s_tick);  xticklabels(s_lab);
      xlabel("time of day");  ylabel("share of the leads, percent");
      ttl("who wins, cut across time of day", "Color", HEAD, "FontWeight", "bold");
      ttl(tl, sprintf("the census with the official in the running, %s, %s", day_txt, axis_txt), ...
         "Color", INK, "FontWeight", "bold");
      out = push(out, out_dir, "f3b_winner_map_with_official.png", ...
         "winner map with the official composite competing", f);
   end

   %% ---- F4  one lead, all the times of day ----
   leads_show = col_of_min(lead_min, [5 30 60 360 1440 10980]);
   f = figure("Position", [40 30 1500 760]);
   tl = tiledlayout(f, 2, 3, "Padding", "compact", "TileSpacing", "compact");
   for k = 1:numel(leads_show)
      h = leads_show(k);
      nexttile(tl);  hold on;  grid on;  box on;
      for j = 1:numel(line_keys)
         m = idx_of(keys, line_keys(j));
         plot(1:n_s, R(:, h, m), "Color", line_col(j, :), "LineWidth", 1.1);
      end
      if ~isempty(off_R)
         plot(1:n_s, off_R(:, h), "Color", off_col, "LineWidth", 1.7);
      end
      xlim([1 n_s]);  xticks(s_tick);  xticklabels(s_lab);
      xlabel("time of day");  ylabel("RMSE over days, $/MWh");
      ttl(sprintf("lead %s", lead_label_of(lead_min(h))), "Color", HEAD, "FontWeight", "bold");
      if k == 1
         legend(leg_names, "Location", "best", "FontSize", 7, "Box", "off");
      end
   end
   ttl(tl, sprintf("R at one fixed lead, across the %d times of day, %s", n_s, day_txt), ...
      "Color", INK, "FontWeight", "bold");
   out = push(out, out_dir, "f4_fixed_lead_profiles.png", ...
      "time-of-day profiles at six fixed leads", f);

   %% ---- F4b  the first hour on its own, because that is what the MPC uses ----
   hour_show = col_of_min(lead_min, 5:5:55);
   hour_show = hour_show(ismember(5:5:55, lead_min));
   if numel(hour_show) >= 6
      pick = hour_show(round(linspace(1, numel(hour_show), 6)));
      f = figure("Position", [40 30 1500 760]);
      tl = tiledlayout(f, 2, 3, "Padding", "compact", "TileSpacing", "compact");
      for k = 1:numel(pick)
         h = pick(k);
         nexttile(tl);  hold on;  grid on;  box on;
         for j = 1:numel(line_keys)
            m = idx_of(keys, line_keys(j));
            plot(1:n_s, R(:, h, m), "Color", line_col(j, :), "LineWidth", 1.1);
         end
         if ~isempty(off_R)
            plot(1:n_s, off_R(:, h), "Color", off_col, "LineWidth", 1.7);
         end
         xlim([1 n_s]);  xticks(s_tick);  xticklabels(s_lab);
         xlabel("time of day");  ylabel("RMSE over days, $/MWh");
         ttl(sprintf("lead %s", lead_label_of(lead_min(h))), "Color", HEAD, "FontWeight", "bold");
         if k == 1
            legend(leg_names, "Location", "best", "FontSize", 7, "Box", "off");
         end
      end
      ttl(tl, sprintf("the first hour on its own, where the MPC actually spends its decisions, %s", day_txt), ...
         "Color", INK, "FontWeight", "bold");
      out = push(out, out_dir, "f4b_first_hour.png", ...
         "time-of-day profiles across the first hour", f);
   end

   %% ---- F5  one time of day, every lead ----
   slots_show = pick_vec([1 73 145 217], n_s);
   f = figure("Position", [40 30 1500 760]);
   tl = tiledlayout(f, 2, 2, "Padding", "compact", "TileSpacing", "compact");
   for k = 1:numel(slots_show)
      s = slots_show(k);
      nexttile(tl);  hold on;  grid on;  box on;
      for j = 1:numel(line_keys)
         m = idx_of(keys, line_keys(j));
         plot(log10(lead_min), R(s, :, m), "Color", line_col(j, :), "LineWidth", 1.1);
      end
      if ~isempty(off_R)
         plot(log10(lead_min), off_R(s, :), "Color", off_col, "LineWidth", 1.7);
      end
      xlim([log10(lead_min(1)) log10(lead_min(end))]);
      set_log_lead_ticks(gca, lead_min, l_tick, l_lab);
      xlabel("forecast lead, log scale");  ylabel("RMSE over days, $/MWh");
      ttl(sprintf("issued at %s", slot_label_of(s)), "Color", HEAD, "FontWeight", "bold");
      if k == 1
         legend(leg_names, "Location", "best", "FontSize", 7, "Box", "off");
      end
   end
   ttl(tl, sprintf("R at one fixed time of day, across all %d leads, %s", n_h, day_txt), ...
      "Color", INK, "FontWeight", "bold");
   out = push(out, out_dir, "f5_fixed_slot_profiles.png", ...
      "lead profiles at four fixed times of day", f);

   %% ---- F6  the recommended combination against the best single model ----
   if isfield(S, "comb_name") && ~isempty(S.comb_name)
      cn = string(S.comb_name(:));
      pick_r = find(contains(cn, "optimal weights") & contains(cn, "shrink 0.3") ...
         & ~contains(cn, "whole atlas"), 1);
      if isempty(pick_r), pick_r = numel(cn); end
      Cc = double(S.comb_surf{pick_r});
      % The opponent is named, never chosen by an argmin. There is no single
      % best model: the surface orders differently at every lead, so an argmin
      % would silently pick whichever model happens to win one particular
      % reduction of the surface.
      best_m = idx_of(keys, "anchor_mix");
      Mb = R(:, :, best_m);
      Df = Cc - Mb;
      fprintf("f6 %s minus %s: lower in %d cells, higher in %d\n", ...
         cn(pick_r), names(best_m), sum(Df(:) < 0), sum(Df(:) > 0));

      f = figure("Position", [40 30 1500 430]);
      tl = tiledlayout(f, 1, 3, "Padding", "compact", "TileSpacing", "compact");
      nexttile(tl);
      imagesc(1:n_s, 1:n_h, Cc');  set(gca, "YDir", "normal");
      clim([lo hi]);  colormap(gca, parula);  axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl(strtrim(cn(pick_r)), "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Label.String = "$/MWh";  cb.TickLabelInterpreter = "none";
      cb.Label.Interpreter = "none";

      nexttile(tl);
      imagesc(1:n_s, 1:n_h, Mb');  set(gca, "YDir", "normal");
      clim([lo hi]);  colormap(gca, parula);  axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl(strtrim(specs(best_m) + "  " + names(best_m)), "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Label.String = "same scale, $/MWh";
      cb.TickLabelInterpreter = "none";  cb.Label.Interpreter = "none";

      nexttile(tl);
      slim6 = prctile(abs(Df(:)), 98);
      imagesc(1:n_s, 1:n_h, Df');  set(gca, "YDir", "normal");
      clim([-slim6 slim6]);  colormap(gca, diverging(256));  axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl(sprintf("combination minus %s, blue means the combination is lower", names(best_m)), ...
         "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Label.String = "$/MWh";
      cb.TickLabelInterpreter = "none";  cb.Label.Interpreter = "none";
      ttl(tl, sprintf("combination against the best single model, %s", day_txt), ...
         "Color", INK, "FontWeight", "bold");
      out = push(out, out_dir, "f6_combination.png", ...
         "combination and the best single model, side by side and differenced", f);
   end

   %% ---- F7  what the AR order choice came to ----
   if isfield(S, "sweep") && ~isempty(S.sweep) && isfield(S, "ar_sel")
      sw = S.sweep;
      pl = sw.p_list(:)';
      cand = S.P_set(:)';
      ic = zeros(size(cand));
      for i = 1:numel(cand), ic(i) = find(pl == cand(i), 1); end
      stack = zeros(n_s, n_h, numel(cand));
      for i = 1:numel(cand), stack(:, :, i) = double(sw.ss_by_p{ic(i)}); end
      [bestv, bp] = min(stack, [], 3);
      gap = stack(:, :, 1) - bestv;
      causal = double(S.ar_sel);
      agree = (cand(bp) == causal);
      fprintf("f7 in-sample per-cell best order: %s\n", ...
         mat2str(arrayfun(@(i) sum(bp(:) == i), 1:numel(cand))));
      fprintf("f7 the causal choice agrees with it in %d of %d cells\n", ...
         sum(agree(:)), n_s*n_h);
      fprintf("f7 headroom from p=1 to the per-cell best: median %.3f, mean %.3f $/MWh\n", ...
         median(gap(:)), mean(gap(:)));

      f = figure("Position", [40 30 1500 430]);
      tl = tiledlayout(f, 1, 3, "Padding", "compact", "TileSpacing", "compact");
      nexttile(tl);
      imagesc(1:n_s, 1:n_h, bp');  set(gca, "YDir", "normal");
      colormap(gca, base(1:numel(cand), :));  clim([0.5 numel(cand)+0.5]);
      axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl("order that minimises R in sample, for each cell", "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Ticks = 1:numel(cand);
      cb.TickLabels = "p=" + string(cand);  cb.TickLabelInterpreter = "none";

      nexttile(tl);
      imagesc(1:n_s, 1:n_h, causal');  set(gca, "YDir", "normal");
      colormap(gca, base(1:numel(cand), :));  clim([0.5 numel(cand)+0.5]);
      axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl(sprintf("order M19 chose, agreeing in %d of %d cells", sum(agree(:)), n_s*n_h), ...
         "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Ticks = 1:numel(cand);
      cb.TickLabels = "p=" + string(cand);  cb.TickLabelInterpreter = "none";

      nexttile(tl);
      imagesc(1:n_s, 1:n_h, gap');  set(gca, "YDir", "normal");
      clim([0 prctile(gap(:), 98)]);  colormap(gca, parula);
      axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl("what a per-cell order choice could have bought", "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Label.String = "$/MWh over the order 1 surface";
      cb.TickLabelInterpreter = "none";  cb.Label.Interpreter = "none";
      ttl(tl, "the AR order is a per-cell quantity, so it is drawn per cell", ...
         "Color", INK, "FontWeight", "bold");
      out = push(out, out_dir, "f7_m19_order.png", ...
         "in-sample per-cell best order against the causal choice", f);
   end

   %% ---- F8, F9  the per-cell order predictor against a fixed order of four ----
   if all(ismember(["T28_ARn" "T28_AR4"], keys))
      mA = idx_of(keys, "T28_ARn");     % order chosen per cell
      mB = idx_of(keys, "T28_AR4");     % order fixed at four
      RA = R(:, :, mA);  RB = R(:, :, mB);
      Dp = RA - RB;
      fprintf("f8 %s minus %s: lower in %d cells, higher in %d, median %.3f $/MWh\n", ...
         names(mA), names(mB), sum(Dp(:) < 0), sum(Dp(:) > 0), median(Dp(:)));

      f = figure("Position", [40 30 1500 430]);
      tl = tiledlayout(f, 1, 3, "Padding", "compact", "TileSpacing", "compact");
      nexttile(tl);
      imagesc(1:n_s, 1:n_h, RA');  set(gca, "YDir", "normal");
      clim([lo hi]);  colormap(gca, parula);  axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl(strtrim(specs(mA) + "  " + names(mA)), "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Label.String = "$/MWh";  cb.TickLabelInterpreter = "none";
      cb.Label.Interpreter = "none";

      nexttile(tl);
      imagesc(1:n_s, 1:n_h, RB');  set(gca, "YDir", "normal");
      clim([lo hi]);  colormap(gca, parula);  axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl(strtrim(specs(mB) + "  " + names(mB)), "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Label.String = "same scale, $/MWh";
      cb.TickLabelInterpreter = "none";  cb.Label.Interpreter = "none";

      nexttile(tl);
      slim8 = prctile(abs(Dp(:)), 98);
      imagesc(1:n_s, 1:n_h, Dp');  set(gca, "YDir", "normal");
      clim([-slim8 slim8]);  colormap(gca, diverging(256));  axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl(sprintf("per-cell order minus fixed order 4, blue means the per-cell choice is lower"), ...
         "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Label.String = "$/MWh";
      cb.TickLabelInterpreter = "none";  cb.Label.Interpreter = "none";
      ttl(tl, sprintf("a per-cell AR order against a fixed AR(4), %s, %s", day_txt, axis_txt), ...
         "Color", INK, "FontWeight", "bold");
      out = push(out, out_dir, "f8_m20_vs_m4.png", ...
         "the per-cell order predictor against T28 + AR(4)", f);

      % The same comparison as a per-cell count, which is the object that says
      % WHERE the two differ rather than how much they differ on average.
      f = figure("Position", [40 30 1500 430]);
      tl = tiledlayout(f, 1, 3, "Padding", "compact", "TileSpacing", "compact");

      nexttile(tl);
      W = zeros(n_s, n_h);
      W(Dp < 0) = 1;  W(Dp > 0) = 2;
      imagesc(1:n_s, 1:n_h, W');  set(gca, "YDir", "normal");
      colormap(gca, [0.88 0.89 0.91; BLUE; RED]);  clim([-0.5 2.5]);
      axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl(sprintf("lower surface per cell: blue %s, red %s, ties %d", ...
         names(mA), names(mB), sum(Dp(:) == 0)), "Color", HEAD, "FontWeight", "bold");

      nexttile(tl);
      causal9 = double(S.ar_sel);
      imagesc(1:n_s, 1:n_h, causal9');  set(gca, "YDir", "normal");
      colormap(gca, base(1:numel(S.P_set), :));  clim([0.5 numel(S.P_set)+0.5]);
      axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl("the order that produced it", "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Ticks = 1:numel(S.P_set);
      cb.TickLabels = "p=" + string(S.P_set(:));  cb.TickLabelInterpreter = "none";

      nexttile(tl);
      G = RB - RA;                       % what the fixed order gave up
      imagesc(1:n_s, 1:n_h, G');  set(gca, "YDir", "normal");
      clim([0 prctile(G(:), 98)]);  colormap(gca, parula);
      axis tight;  box on;
      xticks(s_tick);  xticklabels(s_lab);  yticks(l_tick);  yticklabels(l_lab);
      xlabel("time of day");  ylabel("forecast lead");
      ttl("what the fixed order 4 gave up against the per-cell choice", ...
         "Color", HEAD, "FontWeight", "bold");
      cb = colorbar;  cb.Label.String = "$/MWh, positive means the per-cell choice is lower";
      cb.TickLabelInterpreter = "none";  cb.Label.Interpreter = "none";
      ttl(tl, "the per-cell order is only worth what the cells agree on", ...
         "Color", INK, "FontWeight", "bold");
      out = push(out, out_dir, "f9_order_cellwise.png", ...
         "per-cell winner, the order behind it, and what the fixed order gave up", f);
   end

   close all;
end

%% ---------- local helpers ----------

function t = ttl(varargin)
   % Title with the TeX interpreter off, so model keys keep their underscores.
   t = title(varargin{:}, "Interpreter", "none");
end

function safe_clim(ax, lims)
   % clim refuses equal limits, which happens whenever a quantity is the same in
   % every cell. Widen by one rather than failing the whole figure.
   if lims(1) == lims(2)
      lims = [lims(1) - 1, lims(2) + 1];
   end
   if any(~isfinite(lims)) || lims(2) <= lims(1)
      lims = [0 1];
   end
   clim(ax, lims);
end

function out = push(out, out_dir, name, what, f)
   p = fullfile(out_dir, name);
   exportgraphics(f, p, "Resolution", 140);
   out(end+1) = struct("file", string(p), "what", string(what));
   fprintf("  wrote %s\n", p);
end

function i = idx_of(keys, key)
   i = find(keys == string(key), 1);
   if isempty(i)
      error("report_figures:no_model", "the atlas has no key ""%s""", key);
   end
end

function cols = col_of_min(lead_min, want)
   % Columns of the leads asked for, in the order asked, skipping any the axis
   % does not carry. Naming a lead in minutes is the only form used here.
   cols = zeros(1, numel(want));
   n = 0;
   for i = 1:numel(want)
      k = find(lead_min == want(i), 1);
      if ~isempty(k), n = n + 1;  cols(n) = k; end
   end
   cols = cols(1:n);
end

function v = pick_vec(ideal, n)
   v = ideal(ideal <= n);
   if numel(v) < 4
      v = unique([v round(linspace(1, n, 4))]);
   end
end

function [dm, rej] = cell_dm(e1, e2, L)
   % Paired Diebold-Mariano at every cell, Newey-West with L lags, then
   % Benjamini-Hochberg at 5 percent across all cells.
   sq = e1.^2 - e2.^2;
   nd = size(sq, 3);
   m = mean(sq, 3);
   dev = sq - m;
   v = mean(dev.^2, 3);
   for l = 1:L
      if l >= nd, break; end
      w = 1 - l/(L + 1);
      v = v + 2*w*mean(dev(:, :, 1+l:end) .* dev(:, :, 1:end-l), 3);
   end
   dm = m ./ sqrt(max(v, eps)/nd);
   p = erfc(abs(dm)/sqrt(2));
   rej = bh_fdr(p, 0.05);
end

function rej = bh_fdr(p, q)
   sz = size(p);  pv = p(:);  n = numel(pv);
   [ps, o] = sort(pv);
   k = find(ps <= (1:n)'/n*q, 1, "last");
   r = false(n, 1);
   if ~isempty(k), r(o(1:k)) = true; end
   rej = reshape(r, sz);
end

function c = diverging(n)
   % Low values blue, high values red. Used for a difference surface.
   t = linspace(0, 1, n)';
   c = [min(1, 1.6*(1-t)) + 0.35*t, 1 - 0.75*abs(2*t-1), ...
        min(1, 1.6*t) + 0.35*(1-t)];
   c = flipud(min(max(c, 0), 1));
end

function tk = slot_ticks(n_s)
   if n_s == 288
      tk = [1 73 145 217 288];
   else
      tk = round(linspace(1, n_s, 5));
   end
end

function lb = slot_labels(n_s)
   if n_s == 288
      lb = {'00:05','06:05','12:05','18:05','24:00'};
   else
      lb = string(round((slot_ticks(n_s)-1)*5/60)) + " h";
   end
end

function [tk, lb] = lead_ticks_of(lead_min)
   % Tick positions on the lead axis, named in minutes or hours. The axis is not
   % uniform: the first eleven columns are 5 minutes apart and the rest are 30,
   % so a linear axis would hide the first hour in the leftmost three percent.
   want = [5 60 360 1440 5760 10980];
   name = {'5 min','1 h','6 h','24 h','4 d','183 h'};
   tk = [];  lb = {};
   for i = 1:numel(want)
      k = find(lead_min == want(i), 1);
      if ~isempty(k), tk(end+1) = k;  lb{end+1} = name{i}; end
   end
end

function set_log_lead_ticks(ax, lead_min, tk, lb)
   % The lead axis is drawn as log10(minutes) so that one hour and seven days are
   % both visible, with the ticks labelled by hand.
   if numel(tk) < 2
      tk = round(linspace(1, numel(lead_min), 5));
      lb = string(round(lead_min(tk)/60, 1)) + " h";
   end
   set(ax, "XTick", log10(lead_min(tk)), "XTickLabel", lb);
end

function s = slot_label_of(i)
   % Slot i is the point at i*5 minutes past midnight.
   tm = i*5;
   s = sprintf("%02d:%02d", floor(tm/60), mod(tm, 60));
end

function s = lead_label_of(m)
   % Lead in minutes, written the way a person would say it.
   if m < 60
      s = sprintf("%d min", m);
   elseif m < 1440
      s = sprintf("%g h", m/60);
   else
      s = sprintf("%g d", m/1440);
   end
end
