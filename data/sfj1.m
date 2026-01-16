function SFJ = sfj1(N, JSR, f_start, f_end, T_sweep, fs, t)
% SFJ1 生成线性锯齿波扫频干扰 (Linear Sawtooth Sweep Jamming)
% 输入参数:
%   N:       信号总长度 (点数)
%   JSR:     干信比 (dB) - 控制幅度
%   f_start: 扫频起始频率 (Hz)
%   f_end:   扫频终止频率 (Hz)
%   T_sweep: 扫频周期 (s)
%   fs:      采样率 (Hz)
%   t:       时间轴向量
% 返回:
%   SFJ:     生成的干扰信号

    % 1. 计算幅度
    % 假设信号功率归一化为1，或者由JSR直接控制幅度
    A = sqrt(10^(JSR/10)); 

    % 2. 计算扫频斜率 k (Hz/s)
    BW = f_end - f_start;
    k = BW / T_sweep;

    % 3. 生成锯齿波相位的关键：t_mod
    % t_mod 是周期性复位的时间，从 0 变到 T_sweep，再变回 0
    t_mod = mod(t, T_sweep);

    % 4. 生成线性调频信号 (LFM)
    % 相位 phi = 2*pi * (f_start * t_mod + 0.5 * k * t_mod^2)
    % 这里只针对每个周期内的 t_mod 进行积分
    phase = 2 * pi * (f_start * t_mod + 0.5 * k * t_mod.^2);
    
    % 生成复信号
    SFJ = A * exp(1j * phase);

    % 5. (可选) 加上随机初始相位，让每次生成的干扰有点区别
    fi = 2 * pi * rand();
    SFJ = SFJ * exp(1j * fi);

    % 注意：这里去掉了滤波器部分。
    % 因为LFM信号本身的频谱就是由 f_start 和 f_end 精确控制的，
    % 不需要额外滤波，滤波反而容易引入边缘效应。
end