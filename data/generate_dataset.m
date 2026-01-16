clear; clc; close all;

%% === 1. 全局配置 ===
dataset_root = 'D:\桌面\项目\干扰\456\data\dataset'; % 请确认路径
num_samples_per_class = 1000; % 每类生成的数量
image_size = [224, 224];      % 图片统一大小

fo = 0;         % 基带仿真
tau = 20e-6;    % 脉宽
Tr = 200e-6;    % 脉冲重复周期
ext = 0; 
tr = 50e-6;

jam_names = {
    'J1_Spot', 'J2_Barrage', 'J3_Swept', 'J4_Comb', ...
    'J5_Interrupted', 'J6_DenseTarget', 'J7_NarrowPulse'
};

%% === 2. 构建任务列表 ===
tasks = {}; 
% A. 纯信号
tasks{end+1} = {'0_Pure_Signal', []};
% B. 单干扰
for i = 1:7
    name = sprintf('Single_%s', jam_names{i});
    tasks{end+1} = {name, [i]};
end
% C. 复合干扰
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

fprintf('计划生成 %d 个类别，每类 %d 张。\n', length(tasks), num_samples_per_class);

%% === 3. 批量生成 ===
if ~exist(dataset_root, 'dir'), mkdir(dataset_root); end

for c = 1:length(tasks)
    class_name = tasks{c}{1};
    jam_indices = tasks{c}{2};
    
    class_dir = fullfile(dataset_root, class_name);
    if ~exist(class_dir, 'dir'), mkdir(class_dir); end
    
    fprintf('[%d/%d] 正在生成: %s ...\n', c, length(tasks), class_name);
    
    for i = 1:num_samples_per_class
        
        % --- A. 带宽随机化 (10MHz ~ 80MHz) ---
        B_current = (10 + 70 * rand()) * 1e6; 
        fs_current = ceil(2.5 * B_current); % 采样率随带宽变化
        
        [sig_curr, t_current, t2t_current, ~, n0_current, N_current, ~, ~, ts_current, ~, chip_current] = ...
            signal(B_current, fs_current, fo, tau, Tr, 0, 0, tr, ext);
        
        % JSR 设置
        JSR = 10;
        num_jams = length(jam_indices);
        if num_jams > 0
            total_jam_power = 10 + 10*log10(num_jams); 
        else
            total_jam_power = 0;
        end
        JNR_target = 5;
        noise_p = total_jam_power - JNR_target;
        
        Jamming_Total = zeros(1, N_current);
        
        % --- B. 叠加干扰 ---
        for jam_id = jam_indices
            switch jam_id
                case 1 % J1
                    f_off = (rand()-0.5) * B_current * 0.15; 
                    Jamming_Total = Jamming_Total + namj(N_current, t_current, f_off, JSR, 0, 0.05, 0, Tr, ts_current, Tr);
                case 2 % J2
                    Jamming_Total = Jamming_Total + nfmj(N_current, t_current, 0, JSR, 10e11, Tr, 1, 0, Tr, ts_current);
                case 3 % J3
                    if rand > 0.5, f_s = -B_current/2; f_e = B_current/2; else, f_s = B_current/2; f_e = -B_current/2; end
                    Jamming_Total = Jamming_Total + sfj1(N_current, JSR, f_s, f_e, Tr, fs_current, t_current);
                case 4 % J4
                    Jamming_Total = Jamming_Total + csj(N_current, t_current, JSR, chip_current, 0, ts_current, 3, tau, tau, B_current);
                case 5 % J5
                    tmp = isfj(N_current, JSR, ts_current, chip_current, 0, n0_current, 4, tau, tau, 0.5, zeros(1,5), t2t_current);
                    if length(tmp) > N_current, tmp = tmp(1:N_current); elseif length(tmp)<N_current, tmp=[tmp, zeros(1,N_current-length(tmp))]; end
                    Jamming_Total = Jamming_Total + tmp;
                case 6 % J6
                    tmp = dftj(N_current, JSR, ts_current, chip_current, tr, 4, tau, tau, 0.5, zeros(1,10), t2t_current);
                    if length(tmp) > N_current, tmp = tmp(1:N_current); elseif length(tmp)<N_current, tmp=[tmp, zeros(1,N_current-length(tmp))]; end
                    Jamming_Total = Jamming_Total + tmp;
                case 7 % J7
                    start_t = rand() * 10e-6; 
                    Jamming_Total = Jamming_Total + npj(N_current, t_current, 0, JSR, 1, 2e-6, 20e-6, 5, start_t);
            end
        end
        
        % --- C. 接收信号 ---
        Noise = wgn(1, N_current, noise_p, 'complex');
        Received = sig_curr + Jamming_Total + Noise;
        
        % --- D. 动态抗干扰 ---
        [Received_Processed, strategy_used, ~] = dynamic_anti_jamming(Received, chip_current, sig_curr, fs_current, B_current);
        
        % --- 【关键修改】异常检测，防止 spectrogram 报错 ---
        if any(~isfinite(Received_Processed))
            % 如果检测到 NaN/Inf，强制重置为零信号（或者原信号）
            % warning('样本 %d 异常，已跳过处理。', i);
            Received_Processed = zeros(size(Received_Processed));
        end

        % --- E. 生成图片 ---
        [S, ~, ~] = spectrogram(Received_Processed, 128, 120, 128, fs_current);
        S_log = 10*log10(abs(S) + 1e-9);
        
        min_v = min(S_log(:)); max_v = max(S_log(:));
        S_img = (S_log - min_v) / (max_v - min_v + 1e-9);
        S_img_resized = imresize(S_img, image_size); 
        
        idx = round(S_img_resized * 255) + 1;
        rgb_img = ind2rgb(idx, jet(256));
        
        fname = sprintf('%s_%04d.png', class_name, i);
        imwrite(rgb_img, fullfile(class_dir, fname));
    end
end
fprintf('全部生成完成！\n');