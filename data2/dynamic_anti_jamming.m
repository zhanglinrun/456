function [best_pc, strategy_name, sinr_improvement_db, sinr_base_db, sinr_best_db] = dynamic_anti_jamming(rx, reference_chip, clean_tx)
%DYNAMIC_ANTI_JAMMING  Dynamic anti-jamming strategy selection (simulation)
%   This function selects the best post-processing strategy in the
%   pulse-compressed (range) domain, using the known clean transmit/reference
%   waveform clean_tx as ground truth (only available in simulation).
%
% Outputs:
%   best_pc            : best pulse-compressed output (range profile)
%   strategy_name      : 'PC' | 'SLC' | 'SLB' | 'SLC+SLB'
%   sinr_improvement_db: SINR_best - SINR_base (dB)
%   sinr_base_db       : baseline SINR (PC only) (dB)
%   sinr_best_db       : best SINR (dB)
%
% Why update:
%   - Your previous version used correlation-difference * 100 as "improvement",
%     which is not dB and cannot support a "\ge 6 dB" claim.
%   - Here we compute an SINR-like metric in range domain.

    rx = rx(:).';
    reference_chip = reference_chip(:).';
    clean_tx = clean_tx(:).';

    % Ideal compressed target response (simulation ground truth)
    ideal = pulse_compression(clean_tx, reference_chip);
    [~, main_idx] = max(abs(ideal));
    guard_half = max(8, round(length(rx) * 0.01)); % protect ~1% of length

    % Baseline: pulse compression only
    pc = pulse_compression(rx, reference_chip);
    sinr_base_db = estimate_sinr_db(pc, ideal, main_idx, guard_half);

    % Strategy A: SLC template cancellation (range domain)
    slc = sidelobe_cancellation(pc, reference_chip, main_idx, guard_half, 3);
    sinr_slc_db = estimate_sinr_db(slc, ideal, main_idx, guard_half);

    % Strategy B: SLB blanking (range domain)
    slb = sidelobe_blanking(pc, main_idx, guard_half, 0.2);
    sinr_slb_db = estimate_sinr_db(slb, ideal, main_idx, guard_half);

    % Strategy C: SLC + SLB
    slc_slb = sidelobe_blanking(slc, main_idx, guard_half, 0.2);
    sinr_slc_slb_db = estimate_sinr_db(slc_slb, ideal, main_idx, guard_half);

    sinr_all = [sinr_base_db, sinr_slc_db, sinr_slb_db, sinr_slc_slb_db];
    [sinr_best_db, idx] = max(sinr_all);

    switch idx
        case 1
            best_pc = pc;
            strategy_name = 'PC';
        case 2
            best_pc = slc;
            strategy_name = 'SLC';
        case 3
            best_pc = slb;
            strategy_name = 'SLB';
        case 4
            best_pc = slc_slb;
            strategy_name = 'SLC+SLB';
    end

    sinr_improvement_db = sinr_best_db - sinr_base_db;
end

function sinr_db = estimate_sinr_db(y, ideal, main_idx, guard_half)
%ESTIMATE_SINR_DB  Range-domain SINR-like metric using ideal response
%   We estimate a complex scalar alpha on the protected mainlobe window to
%   best match y ≈ alpha*ideal, then compute residual energy as interference+noise.

    y = y(:).';
    ideal = ideal(:).';
    N = min(length(y), length(ideal));
    y = y(1:N);
    ideal = ideal(1:N);

    L = max(1, main_idx - guard_half);
    R = min(N, main_idx + guard_half);
    win = L:R;

    % Least-squares complex scaling on mainlobe window
    denom = sum(abs(ideal(win)).^2) + eps;
    alpha = sum(y(win) .* conj(ideal(win))) / denom;

    sig_energy = sum(abs(alpha * ideal(win)).^2);
    err = y - alpha * ideal;

    % Use full residual (including outside window) as interference+noise energy
    in_energy = sum(abs(err).^2) + eps;

    sinr_db = 10*log10(sig_energy / in_energy);
end
