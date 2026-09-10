function data = load_historical_price_data(csv_file, expected_region)
%LOAD_HISTORICAL_PRICE_DATA Load and validate a five-minute AEMO RRP CSV.

if nargin < 2 || isempty(expected_region)
    expected_region = "VIC1";
end
if ~isfile(csv_file)
    error('load_historical_price_data:MissingFile', ...
        'Historical price file not found: %s', csv_file);
end

opts = detectImportOptions(csv_file);
opts.VariableNamingRule = 'preserve';
table_data = readtable(csv_file, opts);
required = ["REGION", "SETTLEMENTDATE", "TOTALDEMAND", "RRP"];
names = string(table_data.Properties.VariableNames);
if ~all(ismember(required, names))
    error('load_historical_price_data:Columns', ...
        'CSV must contain REGION, SETTLEMENTDATE, TOTALDEMAND and RRP.');
end

region = string(table_data.REGION);
if any(region ~= expected_region)
    error('load_historical_price_data:Region', ...
        'CSV contains a region other than %s.', expected_region);
end
time = datetime(string(table_data.SETTLEMENTDATE), ...
    'InputFormat', 'yyyy/MM/dd HH:mm:ss');
price = double(table_data.RRP);
electrical_demand = double(table_data.TOTALDEMAND);
[time, order] = sort(time(:));
price = price(order);
electrical_demand = electrical_demand(order);
region = region(order);

if any(isnat(time)) || any(~isfinite(price)) || ...
        any(~isfinite(electrical_demand))
    error('load_historical_price_data:InvalidData', ...
        'Historical data contains invalid timestamps or numeric values.');
end
if numel(unique(time)) ~= numel(time)
    error('load_historical_price_data:DuplicateTime', ...
        'Historical data contains duplicate timestamps.');
end
if any(seconds(diff(time)) ~= 300)
    error('load_historical_price_data:Cadence', ...
        'Historical data is not a continuous five-minute series.');
end

data.time = time;
data.price = price;
data.electrical_demand_mw = electrical_demand;
data.region = region;
data.source_file = csv_file;
data.source = 'AEMO_history_from_GitHub_origin_main';
end
