function u = target_slots(origin_slot, horizon, n_slots)
   % TARGET_SLOTS  Slot indices of the next `horizon` target points
   %
   %    Given the current origin slot (1..n_slots), returns the slot
   %    index of every target point of a full-horizon forecast:
   %    u(h) = slot of the point reached h steps ahead. Slots wrap
   %    around the daily cycle (u(1) = origin_slot + 1).
   %
   %    `horizon` is either a count of steps or the explicit list of step
   %    numbers to hit. The explicit form exists because the atlas lead axis
   %    stops being every step once it leaves the first hour: the first eleven
   %    columns are consecutive 5-minute steps, the rest are every sixth step
   %    out to 183 hours. A scalar behaves exactly as it always did.

   arguments
      origin_slot (1,1) double
      horizon (:,1) double
      n_slots (1,1) double = 288
   end

   if isscalar(horizon)
      steps = (1:horizon)';
   else
      steps = horizon(:);
   end
   u = mod(origin_slot - 1 + steps, n_slots) + 1;
end
