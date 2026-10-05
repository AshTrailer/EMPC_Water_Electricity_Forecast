function mode = pump_state_to_mode(pump_state)
%PUMP_STATE_TO_MODE Map [P1 P2 P3] states to specified modes 0..7.

validateattributes(pump_state, {'numeric', 'logical'}, ...
    {'2d', 'ncols', 3, 'finite'});
pump_state = double(pump_state);
if any(pump_state(:) ~= 0 & pump_state(:) ~= 1)
    error('pump_state_to_mode:NonBinary', ...
        'Pump states must be binary.');
end
mode_states = [0 0 0; 1 0 0; 0 1 0; 0 0 1; ...
    1 1 0; 1 0 1; 0 1 1; 1 1 1];
[found, location] = ismember(pump_state, mode_states, 'rows');
if ~all(found)
    error('pump_state_to_mode:UnknownState', ...
        'A pump state did not match a defined mode.');
end
mode = location-1;
end
