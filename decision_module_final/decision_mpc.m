%% Economic MPC for Tank Pump Decision Module
% 可直接独立运行版本
clear; clc;
% ---------------------- 1. 系统参数 ----------------------
N = 12;                 % 预测时域 12步，每步5min
C = 1.075;              % 水箱动态系数
x_ref = 0.65;           % 目标水位 65%
x_min = 0.40;           % 水位下限 40%
x_max = 0.90;           % 水位上限 90%
lam = 10;               % 水位偏差惩罚系数
Qmax = 0.025;           % 泵流量系数
x0 = 0.50;              % 初始水位（仿真实时传入）

% Jerry预测输出电价序列（后续替换成predictor输出）
price = [0.08,0.12,0.15,0.14,0.09,0.07,0.06,0.11,0.13,0.16,0.14,0.10];
% 远期衰减权重：越往后预测可信度越低
weight = 1./(1 + (0:N-1)*0.2);
% 用水需求 dk
demand = 0.02 * ones(N,1);

% ---------------------- 2. 构建MILP矩阵 intlinprog ----------------------
% 优化变量: [u1,u2,...,uN, x1,x2,...,xN, xN+1]
% u: N个二元变量(0/1), x: N+1个连续变量
n_u = N;
n_x = N+1;
n_var = n_u + n_x;
intcon = 1:n_u;   % 前N个变量u是整数(0/1)

% 变量上下界
lb = zeros(n_var,1);
ub = ones(n_var,1);
lb(n_u+1:end) = x_min;
ub(n_u+1:end) = x_max;

% 目标函数系数 f'*var
f = zeros(n_var,1);
for k = 1:N
    f(k) = price(k)*Qmax;
    f(n_u + k) = lam * weight(k) * (-2*x_ref);
end

% 等式约束：状态递推 x_{k+1} = x_k + C*u_k - d_k
Aeq = zeros(N, n_var);
beq = zeros(N,1);
for k = 1:N
    Aeq(k, k) = C;
    Aeq(k, n_u + k) = -1;
    Aeq(k, n_u + k + 1) = 1;
    beq(k) = demand(k);
end
beq(1) = beq(1) - x0; % 初始水位x0

% 不等式约束（水位边界已经在lb/ub限制，这里可以空）
A = [];
b = [];

% ---------------------- 3. MILP求解 ----------------------
options = optimoptions('intlinprog','Display','iter');
[sol,fval,exitflag] = intlinprog(f,intcon,A,b,Aeq,beq,lb,ub,options);

% ---------------------- 4. 解析结果 ----------------------
u_sol = sol(1:N);
x_sol = sol(n_u+1 : n_u + N +1);

fprintf('==== 泵启停序列(0=关,1=开) ====\n');
disp(u_sol');
fprintf('==== 水位时序 ====\n');
disp(x_sol');
fprintf('MPC第一步执行控制指令 u0 = %.0f\n', u_sol(1));
