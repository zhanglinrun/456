function [processed_signal, SINR_improvement] = pulse_compression(received_signal, reference_chip, fs)
% PULSE_COMPRESSION 脉冲压缩 (最终诊断版)
% 彻底修复时间平移问题，并增加打印诊断

    % 1. 智能裁剪：提取有效的参考脉冲
    % 设定阈值 (最大值的万分之一)
    threshold = max(abs(reference_chip)) * 0.0001;
    
    % 找到有效索引
    valid_idx = find(abs(reference_chip) > threshold);
    
    if ~isempty(valid_idx)
        % 截取有效部分
        effective_chip = reference_chip(valid_idx(1):valid_idx(end));
    else
        effective_chip = reference_chip;
    end
    
    % --- [诊断信息] 只有当截取未发生时才打印警告 ---
    if length(effective_chip) > length(reference_chip) * 0.9 && length(reference_chip) > 1000
        fprintf('[警告] 脉冲压缩参考信号未被截断 (Len=%d)。可能导致时间平移！请检查 signal.m 的 chip 输出。\n', length(effective_chip));
    end

    % 2. 生成匹配滤波器 (只翻转有效部分)
    matched_filter = conj(fliplr(effective_chip));
    
    % 3. 执行卷积
    % 'same' 模式自动对齐中心
    processed_signal = conv(received_signal, matched_filter, 'same');
    
    % 4. 能量归一化
    energy_ratio = norm(received_signal) / (norm(processed_signal) + eps);
    processed_signal = processed_signal * energy_ratio;
    
    SINR_improvement = 0; 
end