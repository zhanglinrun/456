clear; clc; close all;

%% 1. 基础参数设置 (对应雷达参数)
B = 20e6;       % 带宽 20MHz
fs = 50e6;      % 采样率 50MHz
fo = 0;         % 基带仿真，中心频率设为0
tau = 20e-6;    % 脉宽 20us
Tr = 200e-6;    % 脉冲重复周期 (窗口长度)
SP = 0;         % 信号功率 0dB
fi = 0;         % 初始相位
ext = 0;        % 扩展
tr = 50e-6;     % 目标回波延迟

% 调用 signal 生成雷达回波
[pureSignal, t, t2t, t0, n0, N, usignal, k, ts, nxt, chip] = signal(B, fs, fo, tau, Tr, SP, fi, tr, ext);

% 计算信号功率 (用于计算干信比)
P_signal = mean(abs(pureSignal).^2);

%% 2. 生成 7 类典型干扰 (单干扰库)
% 设定通用参数
JSR = 20; % 干信比 20dB

% --- J1: 窄带瞄频 (Narrowband Spot) ---
% 使用 namj，带宽 b 设很小，频率 f 设为 0 (对准中心)
J1 = namj(N, t, 0, JSR, 0, 0.1, 0, Tr, ts, Tr);

% --- J2: 宽带阻塞 (Broadband Barrage) ---
% 使用 nfmj，调频斜率 k 设大一些，覆盖整个带宽
J2 = nfmj(N, t, 0, JSR, 10e11, Tr, 0, 0, Tr, ts);

% --- J3: 扫频干扰 (Swept) ---
% 使用 sfj1 (锯齿波/正弦扫频)
% 参数: k调斜, B带宽, ws/wp滤波器参数
J3 = sfj1(N, JSR, -B/2, B/2, Tr, fs, t);

% --- J4: 梳状谱 (Comb) ---
% 使用 csj
J4 = csj(N, t, JSR, chip, 0, ts, 3, tau, tau, B);

% --- J5: 切片转发 (Interrupted Sampling) ---
% 使用 isfj
% 参数: n0=脉宽点数, Nr=转发次数
J5 = isfj(N, JSR, ts, chip, 0, n0, 4, tau, tau, 0.5, zeros(1,5), t2t);
% 注意：isfj 返回长度可能不一致，这里做个截断保护
if length(J5) > N, J5 = J5(1:N); elseif length(J5) < N, J5 = [J5, zeros(1, N-length(J5))]; end

% --- J6: 密集假目标 (Dense False Target) ---
% 使用 dftj (注意 dftj 内部参数较多，这里给典型值)
fd_vec = zeros(1, 10); % 无频移
J6 = dftj(N, JSR, ts, chip, tr, 4, tau, tau, 0.5, fd_vec, t2t);

% --- J7: 窄脉冲 (Narrow Pulse - Paper Version) ---
% 使用我们新建的 npj_paper
% 参数: 脉宽 2us, 周期 20us, 5个脉冲
J7 = npj(N, t, 0, JSR, P_signal, 2e-6, 20e-6, 5, 10e-6);


%% 3. 复合干扰生成 (Composite Jamming)
% 例如：复合 = 扫频 (J3) + 窄脉冲 (J7)

Jamming_Composite = J3 + J7; 

% 生成最终接收信号 = 纯信号 + 复合干扰 + 噪声
Noise = wgn(1, N, -10, 'complex'); % -10dB 底噪
Received_Signal = pureSignal + Jamming_Composite + Noise;

%% 4. 画图验证 (时频图)
figure('Name', '复合干扰分析', 'Color', 'white');

% (1) 时域波形
subplot(2, 2, 1);
plot(t*1e6, real(Received_Signal));
title('接收信号时域图 (复合干扰)');
xlabel('时间 (us)'); ylabel('幅度');
grid on;

% (2) 原始信号时频图
subplot(2, 2, 2);
spectrogram(pureSignal, 128, 120, 128, fs, 'yaxis');
title('原始雷达信号 STFT');

% (3) 干扰信号时频图 (J_A)
subplot(2, 2, 3);
spectrogram(J3, 128, 120, 128, fs, 'yaxis');
title('干扰A (扫频) STFT');

% (4) 复合干扰时频图 (J_A + J_B)
subplot(2, 2, 4);
spectrogram(Jamming_Composite, 128, 120, 128, fs, 'yaxis');
title('复合干扰 (扫频+窄脉冲) STFT');

% 提示：如果想看其他组合，修改 "Jamming_Composite = ..." 那一行即可