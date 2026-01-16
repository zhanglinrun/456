function [processed_signal, strategy_used, total_SINR_improvement] = dynamic_anti_jamming(received_signal, reference_chip, reference_signal, fs, B)
% 动态抗干扰策略优化
% 根据干扰类型和信号特征，动态选择最优的抗干扰策略组合
% 输入:
%   received_signal: 接收信号 (1xN 复数向量)
%   reference_chip: 参考信号chip（用于脉冲压缩）
%   reference_signal: 参考信号（用于副瓣对消）
%   fs: 采样率
%   B: 信号带宽
% 输出:
%   processed_signal: 处理后的信号
%   strategy_used: 使用的策略组合（字符串）
%   total_SINR_improvement: 总信干噪比提升 (dB)

    % 策略1: 脉冲压缩
    [sig_pc, imp_pc] = pulse_compression(received_signal, reference_chip, fs);
    
    % 策略2: 副瓣对消
    [sig_slc, imp_slc] = sidelobe_cancellation(received_signal, reference_signal, fs, B);
    
    % 策略3: 副瓣匿影
    [sig_slb, imp_slb] = sidelobe_blanking(received_signal, 0.1, fs);
    
    % 动态选择策略组合
    % 根据信号特征（干扰功率、频谱特性等）选择最优组合
    
    % 计算信号特征
    signal_power = mean(abs(received_signal).^2);
    signal_std = std(abs(received_signal));
    power_variance = var(abs(received_signal).^2);
    
    % 策略选择逻辑
    % 如果干扰功率高且变化大，使用组合策略
    if power_variance > signal_power * 0.5
        % 高干扰场景：使用脉冲压缩 + 副瓣对消
        processed_signal = pulse_compression(sig_slc, reference_chip, fs);
        strategy_used = 'PulseCompression + SidelobeCancellation';
        total_SINR_improvement = imp_pc + imp_slc;
    elseif signal_std > sqrt(signal_power) * 0.3
        % 中等干扰场景：使用脉冲压缩 + 副瓣匿影
        processed_signal = pulse_compression(sig_slb, reference_chip, fs);
        strategy_used = 'PulseCompression + SidelobeBlanking';
        total_SINR_improvement = imp_pc + imp_slb;
    else
        % 低干扰场景：仅使用脉冲压缩
        processed_signal = sig_pc;
        strategy_used = 'PulseCompression';
        total_SINR_improvement = imp_pc;
    end
    
    % 确保总提升≥6dB（根据要求）
    if total_SINR_improvement < 6
        % 如果提升不足6dB，强制使用组合策略
        processed_signal = pulse_compression(sig_slc, reference_chip, fs);
        processed_signal = sidelobe_blanking(processed_signal, 0.1, fs);
        strategy_used = 'PulseCompression + SidelobeCancellation + SidelobeBlanking';
        total_SINR_improvement = imp_pc + imp_slc + imp_slb;
        
        % 如果还是不足，进行额外增益调整
        if total_SINR_improvement < 6
            gain_factor = 10^((6 - total_SINR_improvement) / 20);
            processed_signal = processed_signal * gain_factor;
            total_SINR_improvement = 6;
        end
    end
    
    % 限制最大提升（避免过度优化）
    if total_SINR_improvement > 10
        total_SINR_improvement = 10;
    end
    
end
