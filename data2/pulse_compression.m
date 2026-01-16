function y = pulse_compression(x, reference_chip)
%PULSE_COMPRESSION  Matched-filter pulse compression for LFM radar
%   y = pulse_compression(x, reference_chip)
%
%   - x: received complex baseband (1xN)
%   - reference_chip: transmit/reference waveform for matched filter
%
% Notes:
%   1) 为避免你原版本的“时间平移”与“整段 chip 太长”问题，这里
%      会自动截取 reference_chip 的有效脉冲段(通过阈值法)。
%   2) 输出 y 长度与 x 相同 (conv(...,'same')).

    x = x(:).';
    reference_chip = reference_chip(:).';

    % --- Extract effective chip (remove long zero padding) ---
    thr = max(abs(reference_chip)) * 1e-4; % 1e-4 of peak
    idx = find(abs(reference_chip) > thr);
    if ~isempty(idx)
        chip_eff = reference_chip(idx(1):idx(end));
    else
        chip_eff = reference_chip;
    end

    % Matched filter
    h = conj(fliplr(chip_eff));

    % Pulse compression
    y = conv(x, h, 'same');

    % Energy normalization (optional but helps stability)
    y = y * (norm(x) / (norm(y) + eps));
end
