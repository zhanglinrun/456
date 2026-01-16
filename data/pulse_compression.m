function [processed_signal, SINR_improvement] = pulse_compression(received_signal, reference_chip, fs)
% PULSE_COMPRESSION 脉冲压缩 (最终修正版)
% 修复了因 signal.m 输出的 chip 含大量补零导致的严重时间平移问题

    % 1. 智能裁剪：提取有效的参考脉冲
    % signal.m 输出的 chip 格式是 [脉冲信号, 0, 0, ... 0]
    % 直接反转会让几千个0跑到前面，导致输出信号严重右移。
    % 必须先切除尾部的零。
    
    % 设定阈值，防止底噪干扰（这里取最大值的万分之一）
    threshold = max(abs(reference_chip)) * 0.0001;
    
    % 找到大于阈值（非零）的区域索引
    valid_idx = find(abs(reference_chip) > threshold);
    
    if ~isempty(valid_idx)
        % 截取有效部分：从第一个非零点到最后一个非零点
        % 通常 signal.m 的 chip 是从第1个点开始有值的，所以这里主要是切除尾部
        effective_chip = reference_chip(valid_idx(1):valid_idx(end));
    else
        % 如果全是0（极罕见异常），保持原样防止报错
        effective_chip = reference_chip;
    end

    % 2. 生成匹配滤波器
    % 仅对切出来的有效脉冲进行反转和共轭
    matched_filter = conj(fliplr(effective_chip));
    
    % 3. 执行卷积
    % 'same' 模式保证输出长度与输入一致，且相位对齐
    processed_signal = conv(received_signal, matched_filter, 'same');
    
    % 4. 能量归一化 (保持信号量级)
    energy_ratio = norm(received_signal) / (norm(processed_signal) + eps);
    processed_signal = processed_signal * energy_ratio;
    
    % 移除随机值
    SINR_improvement = 0; 
end