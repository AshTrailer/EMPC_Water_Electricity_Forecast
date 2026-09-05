function C = make_harmonic_C(model, slot)
   % MAKE_HARMONIC_C  观测矩阵 C(t)
   %
   %   C(t) = [1, sin θ1, cos θ1, ..., sin θK, cos θK, 1, 0, ..., 0]
   %   θ_k = 2πk(slot-1)/288
   %
   %   输入:
   %       model - build_harmonic_ss_model 输出的模型结构体
   %       slot  - 当日槽位 1..288
   %   输出:
   %       C - 1×nx 行向量

   arguments
      model struct
      slot (1,1) double
   end

   n_slots_day = 288;
   theta = 2*pi*(slot - 1) / n_slots_day;
   C = zeros(1, model.nx);
   C(1) = 1;
   for k = 1:model.n_harm
      C(1 + 2*(k-1) + 1) = sin(k*theta);
      C(1 + 2*(k-1) + 2) = cos(k*theta);
   end
   C(1 + 2*model.n_harm + 1) = 1;   % r(t) 直接进入观测
end