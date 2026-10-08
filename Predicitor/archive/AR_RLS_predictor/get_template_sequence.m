function tpl = get_template_sequence(templates, t_target)
   % GET_TEMPLATE_SEQUENCE  提取目标时刻对应的模板值序列
   %
   %   对预测目标时刻向量 t_target (H×1)，逐点取其槽位和类别，
   %   返回模板值 (H×1)。用于预测:
   %       ŷ(t+h|t) = 模板值(t+h) + AR残差递归预测(t+h|t)
   %
   %   类别按目标时刻自身判断——预测跨天时 (周五 00:00 预测周六)，
   %   模板会自动在午夜切换到周末类。
   %
   %   输入:
   %       templates - 模板结构体 (build_daily_template / update_template_ewma)
   %       t_target  - 目标时刻 (H×1 datetime)
   %
   %   输出:
   %       tpl - (H×1) 模板值

   arguments
      templates struct
      t_target (:,1) datetime
   end

   h = length(t_target);
   tpl = zeros(h, 1);

   for i = 1:h
      s = get_slot_index(t_target(i));
      if templates.mode == "none"
         c = 1;
      else
         c = get_day_class(t_target(i));
      end
      tpl(i) = templates.values(c, s);
   end
end