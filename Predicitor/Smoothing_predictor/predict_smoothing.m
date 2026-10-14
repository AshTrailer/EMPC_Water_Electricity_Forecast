function y_hat = predict_smoothing(st, horizon, compensate)
   % PREDICT_SMOOTHING  Constant or delay-compensated projection of the smoother
   %
   %    Uncompensated   y_hat(h) = S(k)
   %    Compensated     y_hat(h) = S(k) + ( delay + h ) * slope(k)
   %
   %    The uncompensated form is the honest reading of "smooth the signal
   %    first": it forecasts the current smoothed level, which is what the
   %    smoothed series says the price is right now, and it therefore carries
   %    the smoother's delay of about delay steps.
   %
   %    The compensated form adds that delay back and projects the smoothed
   %    slope forward. It is a different model, not a correction: it trades the
   %    delay for an extrapolation error that grows with the lead.
   %
   %    Input:
   %       st         - state from init_smoothing
   %       horizon    - number of steps to forecast
   %       compensate - false gives S(k), true adds (delay + h) * slope
   %    Output:
   %       y_hat - (horizon x 1) forecast

   arguments
      st struct
      horizon (:,1) double
      compensate (1,1) logical = false
   end

   if isscalar(horizon)
      steps = (1:horizon)';
   else
      steps = horizon(:);
   end

   if compensate
      y_hat = st.S + (steps + st.delay) * st.slope;
   else
      y_hat = repmat(st.S, numel(steps), 1);
   end
end
