clear; clc; close all;

%% === 1. 全局配置 ===
dataset_root = 'D:\桌面\项目\干扰\456\data\dataset'; % 数据集保存路径
num_samples_per_class = 1000; % 每类生成的数量
image_size = [224, 224];     % 图片统一大小

% 基础雷达参数
% 带宽固定为20MHz
B = 20e6;  % 固定带宽20MHz
% 采样率设置：根据奈奎斯特定理，采样率至少为带宽的2倍，实际需要2.5-3倍以上
% 当前使用B=20MHz，fs=50MHz
fs = max(2.5 * B, 50e6);  % 基于固定带宽B计算采样率
fo = 0;  % 基带仿真，中心频率为0
tau = 20e-6; Tr = 200e-6; 
ext = 0; tr = 50e-6;

% 干扰名称映射表
jam_names = {
    'J1_Spot',          % 1: 瞄频
    'J2_Barrage',       % 2: 阻塞
    'J3_Swept',         % 3: 扫频
    'J4_Comb',          % 4: 梳状谱
    'J5_Interrupted',   % 5: 切片转发
    'J6_DenseTarget',   % 6: 密集假目标
    'J7_NarrowPulse'    % 7: 窄脉冲
};

%% === 2. 构建任务列表 (单干扰 + 四种干扰复合) ===
tasks = {}; 

% A. 添加纯信号
tasks{end+1} = {'0_Pure_Signal', []};

% B. 添加 7 种单干扰
for i = 1:7
    name = sprintf('Single_%s', jam_names{i});
    tasks{end+1} = {name, [i]};
end

% C. 添加 35 种四种干扰复合 (C(7,4) = 35)
for i = 1:7
    for j = (i+1):7
        for k = (j+1):7
            for l = (k+1):7
                name = sprintf('Comp_%s_%s_%s_%s', jam_names{i}, jam_names{j}, jam_names{k}, jam_names{l});
                tasks{end+1} = {name, [i, j, k, l]};
            end
        end
    end
end

fprintf('计划生成 %d 个类别，每类 %d 张，共 %d 张图片。\n', ...
    length(tasks), num_samples_per_class, length(tasks)*num_samples_per_class);

%% === 3. 准备基础信号 ===
if ~exist(dataset_root, 'dir'), mkdir(dataset_root); end
% 注意：基础时间轴t、t2t等将在循环内根据固定带宽B生成
P_sig_val = 1; 

%% === 4. 开始批量生成 ===
for c = 1:length(tasks)
    class_name = tasks{c}{1};
    jam_indices = tasks{c}{2};
    
    class_dir = fullfile(dataset_root, class_name);
    if ~exist(class_dir, 'dir'), mkdir(class_dir); end
    
    fprintf('[%d/%d] 正在生成: %s ...\n', c, length(tasks), class_name);
    
    % 【关键修改点】：此处已将 parfor 改为普通的 for，解决卡死问题
    for i = 1:num_samples_per_class
        
        % --- A. 参数设置 ---
        % 带宽固定为20MHz
        B_current = B;  % 固定带宽20MHz
        
        % 根据固定带宽计算采样率
        fs_current = max(2.5 * B_current, 50e6);  % 采样率基于固定带宽20MHz计算
        
        % 提前生成信号和chip_current，确保干扰叠加时使用正确的chip
        [sig_curr, t_current, t2t_current, ~, n0_current, N_current, ~, ~, ts_current, ~, chip_current] = signal(B_current, fs_current, fo, tau, Tr, 0, 0, tr, ext);
        
        % JSR 固定为 10dB（每个干扰相对于信号的功率比）
        JSR = 10;
        % JNR 固定为 5dB（干扰噪声比）
        % 计算：信号功率=0dB, 每个干扰功率=10dB
        % 对于N个干扰，总干扰功率 = 10dB + 10*log10(N)
        % JNR = 总干扰功率 - 噪声功率 = 5dB
        num_jams = length(jam_indices);
        if num_jams > 0
            total_jam_power = 10 + 10*log10(num_jams);  % 总干扰功率
        else
            total_jam_power = 0;  % 纯信号情况
        end
        JNR_target = 5;
        noise_p = total_jam_power - JNR_target;  % 根据总干扰功率和JNR计算噪声功率
        
        Jamming_Total = zeros(1, N_current);
        
        % --- B. 叠加干扰 ---
        for jam_id = jam_indices
            switch jam_id
                case 1 % J1: 瞄频
                    f_off = (rand()-0.5) * B_current * 0.15; 
                    Jamming_Total = Jamming_Total + namj(N_current, t_current, f_off, JSR, 0, 0.05, 0, Tr, ts_current, Tr);
                    
                case 2 % J2: 阻塞
                    Jamming_Total = Jamming_Total + nfmj(N_current, t_current, 0, JSR, 10e11, Tr, 1, 0, Tr, ts_current);
                    
                case 3 % J3: 扫频
                    if rand > 0.5, f_s = -B_current/2; f_e = B_current/2; else, f_s = B_current/2; f_e = -B_current/2; end
                    Jamming_Total = Jamming_Total + sfj1(N_current, JSR, f_s, f_e, Tr, fs_current, t_current);
                    
                case 4 % J4: 梳状谱
                    Jamming_Total = Jamming_Total + csj(N_current, t_current, JSR, chip_current, 0, ts_current, 3, tau, tau, B_current);
                    
                case 5 % J5: 切片转发 (使用 t2t_current 防止维度错误)
                    tmp = isfj(N_current, JSR, ts_current, chip_current, 0, n0_current, 4, tau, tau, 0.5, zeros(1,5), t2t_current);
                    if length(tmp) > N_current, tmp = tmp(1:N_current); elseif length(tmp)<N_current, tmp=[tmp, zeros(1,N_current-length(tmp))]; end
                    Jamming_Total = Jamming_Total + tmp;
                    
                case 6 % J6: 密集假目标 (使用 t2t_current 防止维度错误)
                    tmp = dftj(N_current, JSR, ts_current, chip_current, tr, 4, tau, tau, 0.5, zeros(1,10), t2t_current);
                    if length(tmp) > N_current, tmp = tmp(1:N_current); elseif length(tmp)<N_current, tmp=[tmp, zeros(1,N_current-length(tmp))]; end
                    Jamming_Total = Jamming_Total + tmp;
                    
                case 7 % J7: 窄脉冲
                    start_t = rand() * 10e-6; 
                    Jamming_Total = Jamming_Total + npj(N_current, t_current, 0, JSR, P_sig_val, 2e-6, 20e-6, 5, start_t);
            end
        end
        
        % --- C. 生成接收信号 ---
        % 噪声功率已在参数设置部分根据总干扰功率和JNR计算
        Noise = wgn(1, N_current, noise_p, 'complex');
        
        Received = sig_curr + Jamming_Total + Noise;
        
        % --- D. 应用动态抗干扰策略 ---
        % 使用脉冲压缩、副瓣对消、副瓣匿影等策略，提升信干噪比≥6dB
        % 带宽固定为20MHz
        % 使用与当前信号匹配的chip_current和fs_current
        [Received, strategy_used, SINR_improvement] = dynamic_anti_jamming(Received, chip_current, sig_curr, fs_current, B_current);
        
        % 可选：记录策略信息（用于调试）
        if mod(i, 100) == 1
            fprintf('  样本 %d: 策略=%s, SINR提升=%.2fdB\n', i, strategy_used, SINR_improvement);
        end
        
        % --- E. 生成图片 ---
        [S, ~, ~] = spectrogram(Received, 128, 120, 128, fs_current);
        S_log = 10*log10(abs(S) + 1e-9);
        
        % 归一化并转图像
        min_v = min(S_log(:)); max_v = max(S_log(:));
        S_img = (S_log - min_v) / (max_v - min_v + 1e-9);
        S_img_resized = imresize(S_img, image_size);
        
        % 伪彩色映射
        idx = round(S_img_resized * 255) + 1;
        rgb_img = ind2rgb(idx, jet(256));
        
        % 保存
        fname = sprintf('%s_%04d.png', class_name, i);
        imwrite(rgb_img, fullfile(class_dir, fname));
    end
end
fprintf('全部完成！所有复合类型已生成 (单干扰7种 + 四种干扰复合35种，共43类，JSR固定10dB，JNR固定5dB，已应用动态抗干扰策略，SINR提升≥6dB，带宽固定20MHz)。\n');