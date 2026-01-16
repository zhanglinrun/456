function [processed_signal, SINR_improvement] = sidelobe_blanking(received_signal, threshold_factor, fs)
% 副瓣匿影 (逻辑修正版：切除高功率干扰)

    if nargin < 2, threshold_factor = 0.1; end
    
    N = length(received_signal);
    signal_power = abs(received_signal).^2;
    
    [max_power, max_idx] = max(signal_power);
    threshold = max_power * threshold_factor;
    
    mask = ones(1, N);
    
    % 保护主瓣
    window_size = floor(N * 0.05);
    mainlobe_start = max(1, max_idx - window_size);
    mainlobe_end = min(N, max_idx + window_size);
    
    for i = 1:N
        if i < mainlobe_start || i > mainlobe_end
            % 如果副瓣区域功率异常大（大于阈值），视为干扰并置零
            if signal_power(i) > threshold 
                mask(i) = 0; 
            end
        end
    end
    
    processed_signal = received_signal .* mask;
    SINR_improvement = 0; 
end