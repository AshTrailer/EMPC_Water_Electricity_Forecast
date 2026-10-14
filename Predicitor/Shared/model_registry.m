function reg = model_registry()
   % MODEL_REGISTRY  Atlas column order and labels for every predictor
   %
   %   Single source of truth for which model sits in which atlas column.
   %   Scripts that build or read the error atlas take their order and labels
   %   from here, never from a written-out index, so appending a model cannot
   %   silently renumber one that already exists.
   %
   %   A new model is APPENDED, never inserted. Atlas column m is the m-th
   %   entry of this list.
   %
   %   Output reg, struct array, one row per model:
   %      key      stable identifier, resolved by model_index
   %      name     short label for tables and figures, at most 26 characters
   %      folder   subfolder under Predicitor, empty when the model is inline
   %      spec     section of HANDOVER_预测器整理与全跨度比较_20261013.md
   %
   %   See also MODEL_INDEX.

   reg = struct('key', {}, 'name', {}, 'folder', {}, 'spec', {});

   reg = add(reg, "persistence",   "Persistence(yest)",      "",                        "M1");
   reg = add(reg, "T28",           "Template T28",           "Template_AR_predictor",   "M2");
   reg = add(reg, "theta_y",       "Theta-y tracker",        "ThetaY_Tracker",          "M3");
   reg = add(reg, "T28_AR4",       "T28 + AR4",              "Template_AR_predictor",   "M4");
   reg = add(reg, "carry_forward", "Carry-forward",          "",                        "M5");
   reg = add(reg, "T28_DMS4",      "T28 + DMS4",             "",                        "M6");
   reg = add(reg, "CF_DMS4",       "CF + DMS4",              "",                        "M7");
   reg = add(reg, "anchor_mix",    "Anchor-mix",             "Anchor_AR_predictor",     "M8");
   reg = add(reg, "T28_level",     "T28 + level offset",     "Level_Offset_predictor",  "M9");
   reg = add(reg, "MW",            "Multi-window T",         "Multi_Window_predictor",  "M10");
   reg = add(reg, "MW_level",      "MW + level offset",      "Level_Offset_predictor",  "M11");
   reg = add(reg, "MW_run",        "MW + level (run state)",  "Level_Offset_predictor", "M12");

   % appended, never inserted: column m of the atlas is entry m of this list
   reg = add(reg, "kalman_harm",   "Kalman harmonic SS",     "Kalman_predictor",          "M13");
   reg = add(reg, "T_ewma",        "EWMA template",          "EWMA_Template_predictor",   "M14");
   reg = add(reg, "ma",            "Moving average 1h",      "Smoothing_predictor",       "M15");
   reg = add(reg, "ma_comp",       "Moving avg 1h comp",     "Smoothing_predictor",       "M16");
   reg = add(reg, "med",           "Moving median 1h",       "Smoothing_predictor",       "M17");
   reg = add(reg, "T_class",       "Weekday-class T",        "Day_Class_predictor",       "M18");

   % M19 and M20 are the same numbers reached two ways, and both entries are
   % kept because they are two different objects. M19 is the ORDER SOLUTION:
   % which AR order minimises the trailing squared error at each (slot, lead)
   % cell. M20 is the PREDICTOR that consumes it, T28 + AR(n) with n per cell.
   % The atlas stores only M20, because two identical columns would split every
   % tie in a win census arbitrarily; the solution survives as ar_sel and
   % ar_sel_hist in the atlas file.
   reg = add(reg, "ar_adapt",      "AR order per cell (rule)", "Template_AR_predictor",   "M19");
   reg = add(reg, "T28_ARn",       "T28 + AR(n per cell)",   "Template_AR_predictor",     "M20");
end

function reg = add(reg, key, name, folder, spec)
   reg(end+1) = struct('key', key, 'name', name, 'folder', folder, 'spec', spec);
end
