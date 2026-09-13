function selected = select_interval_ending_history( ...
    history, operating_day, required_steps, dt_seconds)
%SELECT_INTERVAL_ENDING_HISTORY Select a continuous AEMO input window.
% An operating day starts with the interval ending at 00:05. Thus its
% 288th interval ends at the following 00:00.

validateattributes(operating_day, {'datetime'}, {'scalar'});
validateattributes(required_steps, {'numeric'}, ...
    {'scalar', 'integer', 'positive'});
validateattributes(dt_seconds, {'numeric'}, ...
    {'scalar', 'integer', 'positive'});
if timeofday(operating_day) ~= duration(0,0,0)
    error('select_interval_ending_history:StartOfDay', ...
        'operating_day must be at 00:00:00.');
end

expected_time = operating_day ...
    + seconds(dt_seconds)*(1:required_steps)';
first_index = find(history.time == expected_time(1), 1, 'first');
if isempty(first_index)
    error('select_interval_ending_history:MissingStart', ...
        'No AEMO interval ending at %s.', string(expected_time(1)));
end
index = first_index:first_index+required_steps-1;
if index(end) > numel(history.time)
    error('select_interval_ending_history:ShortHistory', ...
        'History ends before %d continuous samples are available.', ...
        required_steps);
end
if ~all(history.time(index) == expected_time)
    error('select_interval_ending_history:Discontinuous', ...
        'AEMO data do not match the required interval-ending timeline.');
end

selected.index_in_history = index(:);
selected.time = history.time(index(:));
selected.price = history.price(index(:));
selected.source = history.source;
selected.source_file = history.source_file;
selected.operating_day = operating_day;
selected.interval_convention = 'AEMO interval-ending';
end
