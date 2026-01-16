function NPJ = npj(N, t, f_jam, JSR_dB, signal_power, T_width, T_pri, num_pulses, start_time)
%NPJ  Narrow-Pulse Jamming (窄脉冲干扰)
%   在时间上发射一串宽度为 T_width、PRI 为 T_pri 的窄脉冲，
%   幅度由 JSR_dB (相对 signal_power) 控制，并调制到载频 f_jam。
%
% 修复点:
%   - 原 npj.m 中主函数名为 npj_paper，与文件名 npj.m 不匹配，MATLAB
%     会导致“未定义函数 npj”。这里修复为 npj。

    if nargin < 9 || isempty(start_time)
        start_time = 0;
    end

    % 1) 计算目标干扰幅度
    P_jam = signal_power * 10^(JSR_dB/10);
    A = sqrt(P_jam);

    % 2) 生成脉冲包络
    envelope = zeros(1, N);
    for k = 0:(num_pulses-1)
        t_start = start_time + k * T_pri;
        t_end = t_start + T_width;
        envelope = envelope + (t >= t_start & t <= t_end);
    end
    envelope = min(envelope, 1); % 防止重叠>1

    % 3) 载波调制
    carrier = exp(1i * 2 * pi * f_jam * t);

    NPJ = A * envelope .* carrier;
end
