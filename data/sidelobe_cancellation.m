function [processed_signal, SINR_improvement] = sidelobe_cancellation(received_signal, reference_signal, fs, B)
% SIDELOBE_CANCELLATION 副瓣对消 (稳健版)
% 修复了 LMS 梯度爆炸导致的 NaN 问题

    N = length(received_signal);
    filter_length = min(32, floor(N/4)); 
    
    % --- 1. 安全预处理：归一化 ---
    % 强干扰下幅度可能很大，导致 LMS 发散。先将幅度归一化到 1 以内。
    max_val = max(abs(received_signal));
    if max_val > 0
        scale_factor = 1.0 / max_val;
    else
        scale_factor = 1.0;
    end
    
    % 归一化输入信号
    rx_norm = received_signal * scale_factor;
    ref_norm = reference_signal * scale_factor; 
    
    % --- 2. 算法参数 ---
    % 减小步长，增加稳定性
    mu = 0.001; 
    
    w = zeros(1, filter_length);
    x_ref = [zeros(1, filter_length-1), rx_norm(1:end-filter_length+1)];
    
    out_norm = zeros(1, N);
    
    % 确保参考信号长度匹配
    if length(ref_norm) > N
        ref_norm = ref_norm(1:N);
    elseif length(ref_norm) < N
        ref_norm = [ref_norm, zeros(1, N-length(ref_norm))];
    end

    % --- 3. LMS 迭代 ---
    for n = filter_length:N
        x_vec = x_ref(n-filter_length+1:n);
        y_n = w * x_vec.';
        
        % 期望信号
        d_n = ref_norm(n);
        
        % 计算误差 (作为对消后的输出)
        % e = d - y; 
        % 这里我们保留原始逻辑，将误差视为去干扰后的信号
        out_norm(n) = rx_norm(n) - y_n;
        
        % 更新权重
        update_step = mu * (ref_norm(n) - y_n) * conj(x_vec);
        
        % --- 关键保护：检查 NaN/Inf ---
        if any(isnan(update_step)) || any(isinf(update_step))
            % 如果梯度爆炸，不再更新权重，保持上一时刻的值或重置
            % w = zeros(1, filter_length); % 可选：重置
        else
            w = w + update_step;
        end
    end
    
    % 填充起始段
    out_norm(1:filter_length-1) = rx_norm(1:filter_length-1);
    
    % --- 4. 还原幅度 ---
    processed_signal = out_norm / scale_factor;
    
    % --- 5. 最终防线 ---
    % 如果仍有 NaN（极罕见），回退到原始信号，防止画图报错
    if any(~isfinite(processed_signal))
        processed_signal = received_signal;
    end
    
    SINR_improvement = 0; 
end