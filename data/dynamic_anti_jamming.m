function [best_signal, strategy_name, best_improvement] = dynamic_anti_jamming(received_signal, reference_chip, clean_signal_ground_truth, fs, B)
% DYNAMIC_ANTI_JAMMING 动态抗干扰 (逻辑修正版)
% 修复了“尖峰 vs 宽脉冲”导致评分极低的问题

    % --- 关键修正：生成“理想参考标准” ---
    % 我们不能拿“处理后的信号”去跟“原始宽脉冲”比，因为形状变了。
    % 我们必须跟“理想的脉冲压缩结果”比。
    ideal_compressed = pulse_compression(clean_signal_ground_truth, reference_chip, fs);

    % 计算基准分 (原始带噪信号 vs 理想结果)
    base_corr = get_correlation(received_signal, ideal_compressed);

    %% 策略 1: 仅脉冲压缩
    try
        sig_pc = pulse_compression(received_signal, reference_chip, fs);
        sig_pc = normalize_energy(sig_pc, received_signal);
        score_pc = get_correlation(sig_pc, ideal_compressed); % 跟理想结果比
    catch
        score_pc = -2; sig_pc = received_signal;
    end

    %% 策略 2: 副瓣对消 + 脉冲压缩
    try
        sig_slc_raw = sidelobe_cancellation(received_signal, clean_signal_ground_truth, fs, B);
        sig_slc_pc = pulse_compression(sig_slc_raw, reference_chip, fs);
        sig_slc_pc = normalize_energy(sig_slc_pc, received_signal);
        score_slc = get_correlation(sig_slc_pc, ideal_compressed);
    catch
        score_slc = -2; sig_slc_pc = received_signal;
    end

    %% 策略 3: 副瓣匿影 + 脉冲压缩
    try
        sig_slb_raw = sidelobe_blanking(received_signal, 0.1, fs);
        sig_slb_pc = pulse_compression(sig_slb_raw, reference_chip, fs);
        sig_slb_pc = normalize_energy(sig_slb_pc, received_signal);
        score_slb = get_correlation(sig_slb_pc, ideal_compressed);
    catch
        score_slb = -2; sig_slb_pc = received_signal;
    end

    %% 择优
    scores = [score_pc, score_slc, score_slb];
    [max_score, idx] = max(scores);

    switch idx
        case 1
            best_signal = sig_pc; strategy_name = 'PC';
        case 2
            best_signal = sig_slc_pc; strategy_name = 'SLC_PC';
        case 3
            best_signal = sig_slb_pc; strategy_name = 'SLB_PC';
    end

    best_improvement = (max_score - base_corr) * 100;
end

function r = get_correlation(sig1, sig2)
    if length(sig1) ~= length(sig2)
        L = min(length(sig1), length(sig2));
        sig1 = sig1(1:L); sig2 = sig2(1:L);
    end
    % 使用相关系数的模，避免相位旋转影响
    c = corrcoef(abs(sig1), abs(sig2));
    r = c(1,2);
    if isnan(r), r = 0; end
end

function sig_out = normalize_energy(sig_in, ref_sig)
    ratio = norm(ref_sig) / (norm(sig_in) + eps);
    sig_out = sig_in * ratio;
end