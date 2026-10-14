function idx = model_index(keys)
   % MODEL_INDEX  Atlas column of one or more models, looked up by key
   %
   %   idx = model_index("anchor_mix")
   %   idx = model_index(["anchor_mix" "MW_run"])
   %   idx = model_index({"T28_AR4", "MW"})
   %
   %   Matching ignores case. An unknown key raises an error rather than
   %   returning nothing, because a typo that quietly selects zero models
   %   still produces a number and would be read as a result.
   %
   %   Input keys, char, string, or cellstr of keys.
   %   Output idx, double row vector, atlas columns in the order requested.
   %
   %   See also MODEL_REGISTRY.

   reg = model_registry();
   known = string({reg.key});

   if ischar(keys) || (isstring(keys) && isscalar(keys))
      keys = {char(keys)};
   elseif isstring(keys)
      keys = cellstr(keys);
   end
   assert(iscell(keys), 'model_index: keys must be char, string, or cellstr');

   idx = zeros(1, numel(keys));
   for i = 1:numel(keys)
      hit = find(strcmpi(known, string(keys{i})), 1);
      assert(~isempty(hit), 'model_index: unknown model key "%s"', char(keys{i}));
      idx(i) = hit;
   end
end
