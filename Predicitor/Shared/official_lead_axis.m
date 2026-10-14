function [lead_min, lead_step, band] = official_lead_axis()
   % OFFICIAL_LEAD_AXIS  The 376-column lead axis, in minutes and in 5-min steps
   %
   %    Column 1 to 11 are 5 to 55 minutes at 5-minute cadence, which is the
   %    whole forward horizon of a P5MIN run. Column 12 to 376 are 60 minutes
   %    to 183.0 hours at 30-minute cadence, which is the cadence of both
   %    30-minute products. Every column therefore lands exactly on an official
   %    grid point, so nothing is interpolated anywhere on the axis.
   %
   %    P5MIN's own grid is offsets 0 to 55 minutes from its effective time.
   %    Offset 0 describes the interval that has just closed and is already
   %    known at the origin, so it is not a forecast and is not a column.
   %    60 minutes is therefore NOT available from P5MIN and comes from
   %    PREDISPATCH, which is why the 5-minute cadence stops at 55.
   %
   %    Output:
   %       lead_min  (376 x 1) double, forecast lead in minutes
   %       lead_step (376 x 1) double, the same lead in 5-minute steps
   %       band      (376 x 1) double, 1 for the 5-minute band and 2 after
   %
   %    Single source of truth for the axis. The atlas, the composite and the
   %    figures all take it from here, so a change cannot leave one of them
   %    on the old axis.

   lead_min = [5:5:55, 60:30:10980]';
   lead_step = lead_min / 5;
   band = ones(numel(lead_min), 1);
   band(lead_min >= 60) = 2;

   assert(numel(lead_min) == 376, 'official_lead_axis:count', ...
      'the axis is %d columns, expected 376', numel(lead_min));
   assert(lead_min(end) == 10980, 'official_lead_axis:end', ...
      'the last lead is %g minutes, expected 10980', lead_min(end));
   assert(all(mod(lead_step, 1) == 0), 'official_lead_axis:grid', ...
      'every lead must be a whole number of 5-minute steps');
end
