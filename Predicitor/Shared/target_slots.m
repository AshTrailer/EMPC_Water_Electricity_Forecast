function u = target_slots(origin_slot, horizon, n_slots)
   % TARGET_SLOTS  Slot indices of the next `horizon` target points
   %
   %    Given the current origin slot (1..n_slots), returns the slot
   %    index of every target point of a full-horizon forecast:
   %    u(h) = slot of the point reached h steps ahead. Slots wrap
   %    around the daily cycle (u(1) = origin_slot + 1).

   arguments
      origin_slot (1,1) double
      horizon (1,1) double
      n_slots (1,1) double = 288
   end

   u = mod(origin_slot - 1 + (1:horizon)' - 1, n_slots) + 1;
end
