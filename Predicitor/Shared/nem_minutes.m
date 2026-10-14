function m = nem_minutes(t, epoch)
   % NEM_MINUTES  NEM timestamps as whole minutes since a fixed epoch
   %
   %    All AEMO timestamps in this project are NEM time, which is UTC+10 all
   %    year with no daylight saving, so they are compared as plain integers.
   %    Doing the arithmetic on datenums instead invites a silent offset the
   %    day a timestamp is parsed with a time zone attached.
   %
   %    Input:
   %       t     - datetime array, or a char/cellstr/string of
   %               'yyyy-mm-dd HH:MM:SS'
   %       epoch - optional datetime or string, default 2025-01-01 00:00:00
   %    Output:
   %       m     - int64 vector, minutes since the epoch
   %
   %    See also OFFICIAL_COMPOSITE, OFFICIAL_COMPOSITE_LOAD.

   arguments
      t
      epoch = datetime(2025,1,1,0,0,0)
   end

   if ~isdatetime(epoch)
      epoch = datetime(epoch, "InputFormat", "yyyy-MM-dd HH:mm:ss");
   end

   if isdatetime(t)
      dt = t(:);
   else
      dt = datetime(string(t(:)), "InputFormat", "yyyy-MM-dd HH:mm:ss");
   end
   bad = isnat(dt);
   assert(~any(bad), 'nem_minutes:unparsed', ...
      '%d of %d timestamps did not parse as yyyy-mm-dd HH:MM:SS', sum(bad), numel(dt));

   m = int64(round(minutes(dt - epoch)));
end
