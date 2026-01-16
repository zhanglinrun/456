function NPJ = npj_paper(N, t, f_jam, JSR, signal_power, T_width, T_pri, num_pulses, start_time)
% 依据论文公式 (6) 实现的窄脉冲干扰
% N: 采样点数
% t: 时间轴
% f_jam: 干扰载频 (通常对准雷达频率)
% JSR: 干信比 (dB)
% signal_power: 信号功率
% T_width: 脉冲宽度 (论文中的 T_np)
% T_pri: 脉冲重复周期 (论文中的 tau_np)
% num_pulses: 脉冲个数 (论文中的 N)
% start_time: 起始时间 (论文中的 Theta)

    % 1. 计算干扰幅度
    P_jam = signal_power * 10^(JSR/10);
    A = sqrt(P_jam);
    
    % 2. 生成脉冲包络 (矩形波串)
    envelope = zeros(1, N);
    for k = 0 : num_pulses-1
        % 计算每个脉冲的中心或起始位置
        t_start = start_time + k * T_pri;
        t_end = t_start + T_width;
        
        % 生成矩形窗 (Rect function)
        % 在时间范围内置为 1
        envelope = envelope + (t >= t_start & t <= t_end);
    end
    
    % 3. 调制到高频 (加上载波)
    % 论文提到是 "high-frequency, high-energy bursts"
    carrier = exp(1i * 2 * pi * f_jam * t);
    
    NPJ = A * envelope .* carrier;
end